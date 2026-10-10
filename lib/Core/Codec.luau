--!strict
--!optimize 2

--[[
	Encodes the schema into one buffer and decodes definitions out of it on demand.

	Layout, all integers little endian:

		u8  magic "V"
		u8  format version
		u16 string count, then each string as u16 length + bytes
		u16 group count, then a u16 string id per group
		u32 preload count, then a u16 string id per sound name
		u32 definition count, then per definition: u16 name string id, u32 offset into the body
		body: the definitions, in the order they were written

	A definition in the body:

		u16 name string id
		u16 group index, 0 for none
		u16 property count, then the properties
		u8  effect count, then per effect: u16 class string id, u16 property count, the properties

	A property is a u16 key string id, a u8 type tag and the value:

		1 number        f64
		2 string        u32 length + bytes
		3 boolean       u8
		4 EnumItem      u16 enum type string id, u16 item name string id
		5 NumberRange   f64 min, f64 max

	Property names, enum names, class names and sound names go through the string table, so none of them repeat
	per sound. String values such as SoundId are stored inline.
]]

local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local Types = require(script.Parent.Parent.Types)

local MAGIC = 0x56
local VERSION = 1

local TAG_NUMBER = 1
local TAG_STRING = 2
local TAG_BOOLEAN = 3
local TAG_ENUM = 4
local TAG_RANGE = 5

local MAX_STRINGS = 0xFFFF
local MAX_U16 = 0xFFFF
local MAX_U8 = 0xFF

local INITIAL_CAPACITY = 64 * 1024

--Properties that are never encoded. Parent and ClassName are structural, SoundGroup is stored as the group index,
--and Name is already in the string table (the sound name, or the effect's class name) so it is restored on read.
local SKIPPED_PROPERTIES: { [string]: boolean } = {
	Parent = true,
	ClassName = true,
	SoundGroup = true,
	Name = true,
}

--Resolved EnumItems keyed by enum string id * 65536 + item string id. false marks a pair that does not exist here.
local enumCache: { [number]: EnumItem | false } = {}

local function resolveEnum(enumName: string, itemName: string): EnumItem
	return (Enum :: any)[enumName][itemName]
end

export type Writer = {
	Buffer: buffer,
	Length: number,

	StringIds: { [string]: number },
	Strings: { string },

	NameIds: { number },
	Offsets: { number },
	Count: number,
}

export type Loaded = {
	Buffer: buffer,
	Strings: { string },

	GroupNames: { string },
	PreloadNames: { string },

	Names: { string },
	Offsets: { [string]: number },
	Count: number,
}

local Codec = {}

------------------------------------------------------------------------------------------------------------------------
--WRITING---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local function newWriter(): Writer
	return {
		Buffer = buffer.create(INITIAL_CAPACITY),
		Length = 0,

		StringIds = {},
		Strings = {},

		NameIds = {},
		Offsets = {},
		Count = 0,
	}
end

local function reserve(writer: Writer, bytes: number)
	local needed = writer.Length + bytes
	local capacity = buffer.len(writer.Buffer)

	if needed <= capacity then
		return
	end

	while capacity < needed do
		capacity *= 2
	end

	local grown = buffer.create(capacity)
	buffer.copy(grown, 0, writer.Buffer, 0, writer.Length)
	writer.Buffer = grown
end

local function writeU8(writer: Writer, value: number)
	reserve(writer, 1)
	buffer.writeu8(writer.Buffer, writer.Length, value)
	writer.Length += 1
end

local function writeU16(writer: Writer, value: number)
	reserve(writer, 2)
	buffer.writeu16(writer.Buffer, writer.Length, value)
	writer.Length += 2
end

local function writeU32(writer: Writer, value: number)
	reserve(writer, 4)
	buffer.writeu32(writer.Buffer, writer.Length, value)
	writer.Length += 4
end

local function writeF64(writer: Writer, value: number)
	reserve(writer, 8)
	buffer.writef64(writer.Buffer, writer.Length, value)
	writer.Length += 8
end

local function writeString(writer: Writer, value: string)
	local length = #value

	reserve(writer, 4 + length)
	buffer.writeu32(writer.Buffer, writer.Length, length)
	buffer.writestring(writer.Buffer, writer.Length + 4, value)
	writer.Length += 4 + length
end

--Strings in the string table are limited to u16 lengths; these are names, not content.
local function writeShortString(writer: Writer, value: string)
	local length = #value
	if length > MAX_U16 then
		FormatMessage.Error(
			`A name is longer than {MAX_U16} bytes and cannot be stored: "{string.sub(value, 1, 40)}..."`
		)
	end

	reserve(writer, 2 + length)
	buffer.writeu16(writer.Buffer, writer.Length, length)
	buffer.writestring(writer.Buffer, writer.Length + 2, value)
	writer.Length += 2 + length
end

local function intern(writer: Writer, value: string): number
	local id = writer.StringIds[value]
	if id then
		return id
	end

	if #value > MAX_U16 then
		FormatMessage.Error(
			`A name is longer than {MAX_U16} bytes and cannot be stored: "{string.sub(value, 1, 40)}..."`,
			6
		)
	end

	local count = #writer.Strings
	if count >= MAX_STRINGS then
		FormatMessage.Error(`The schema has more than {MAX_STRINGS} unique names and cannot be stored!`, 6)
	end

	local newId = count + 1
	writer.Strings[newId] = value
	writer.StringIds[value] = newId

	return newId
end

local function tagFor(value: any): number?
	local valueType = typeof(value)

	if valueType == "number" then
		return TAG_NUMBER
	elseif valueType == "string" then
		return TAG_STRING
	elseif valueType == "boolean" then
		return TAG_BOOLEAN
	elseif valueType == "EnumItem" then
		return TAG_ENUM
	elseif valueType == "NumberRange" then
		return TAG_RANGE
	end

	return nil
end

local function writeValue(writer: Writer, tag: number, value: any)
	writeU8(writer, tag)

	if tag == TAG_NUMBER then
		writeF64(writer, value)
	elseif tag == TAG_STRING then
		writeString(writer, value)
	elseif tag == TAG_BOOLEAN then
		writeU8(writer, if value then 1 else 0)
	elseif tag == TAG_ENUM then
		local item = value :: EnumItem
		writeU16(writer, intern(writer, tostring(item.EnumType)))
		writeU16(writer, intern(writer, item.Name))
	elseif tag == TAG_RANGE then
		local range = value :: NumberRange
		writeF64(writer, range.Min)
		writeF64(writer, range.Max)
	end
end

--[[
	Writes a property table as a u16 count followed by the properties. The count is patched in once it is known.
]]
local function writeProperties(writer: Writer, owner: string, properties: { [string]: any })
	local countOffset = writer.Length
	writeU16(writer, 0)

	local count = 0

	for name, value in pairs(properties) do
		if SKIPPED_PROPERTIES[name] then
			continue
		end

		local tag = tagFor(value)
		if not tag then
			FormatMessage.Warn(
				`"{owner}" property "{name}" is a {typeof(value)}, which cannot be stored. It was skipped.`
			)
			continue
		end

		if count == MAX_U16 then
			FormatMessage.Warn(`"{owner}" has more than {MAX_U16} properties. The rest were skipped.`)
			break
		end

		writeU16(writer, intern(writer, name))
		writeValue(writer, tag, value)
		count += 1
	end

	buffer.writeu16(writer.Buffer, countOffset, count)
end

--[[
	@return Writer -- A writer to add definitions to.

	Starts a new schema buffer.
]]
function Codec.NewWriter(): Writer
	return newWriter()
end

--[[
	@param writer Writer -- The writer to add to.
	@param name string -- The sound name. This is the key the definition is fetched by.
	@param groupIndex number -- The 1-based index of the sound's group in the group list given to Finish, or 0.
	@param definition SoundDefinition -- The definition to store.

	Adds one definition to the buffer.
]]
function Codec.WriteDefinition(writer: Writer, name: string, groupIndex: number, definition: Types.SoundDefinition)
	local offset = writer.Length
	local nameId = intern(writer, name)

	writeU16(writer, nameId)
	writeU16(writer, groupIndex)
	writeProperties(writer, name, definition.Properties :: any)

	local effects = definition.Effects :: { [string]: { [string]: any } }
	local effectCountOffset = writer.Length
	writeU8(writer, 0)

	local effectCount = 0

	for className, effectProperties in pairs(effects) do
		if effectCount == MAX_U8 then
			FormatMessage.Warn(`"{name}" has more than {MAX_U8} effects. The rest were skipped.`)
			break
		end

		writeU16(writer, intern(writer, className))
		writeProperties(writer, `{name}.{className}`, effectProperties)
		effectCount += 1
	end

	buffer.writeu8(writer.Buffer, effectCountOffset, effectCount)

	local count = writer.Count + 1
	writer.NameIds[count] = nameId
	writer.Offsets[count] = offset
	writer.Count = count
end

--[[
	@param writer Writer -- The writer holding the definitions.
	@param groupNames { string } -- The group names, in the order the group indices refer to.
	@param preloadNames { string } -- The names of the sounds to preload on the client.

	@return buffer -- The finished schema buffer.

	Builds the header in front of the definitions and returns the whole schema as one buffer.
]]
function Codec.Finish(writer: Writer, groupNames: { string }, preloadNames: { string }): buffer
	if #groupNames > MAX_U16 then
		FormatMessage.Error(`The schema has more than {MAX_U16} SoundGroups!`)
	end

	--names referenced by the header have to be in the string table before it is written
	local groupIds: { number } = table.create(#groupNames)
	for index, groupName in ipairs(groupNames) do
		groupIds[index] = intern(writer, groupName)
	end

	local preloadIds: { number } = table.create(#preloadNames)
	for index, preloadName in ipairs(preloadNames) do
		preloadIds[index] = intern(writer, preloadName)
	end

	local header = newWriter()

	writeU8(header, MAGIC)
	writeU8(header, VERSION)

	writeU16(header, #writer.Strings)
	for _, value in ipairs(writer.Strings) do
		writeShortString(header, value)
	end

	writeU16(header, #groupIds)
	for _, id in ipairs(groupIds) do
		writeU16(header, id)
	end

	writeU32(header, #preloadIds)
	for _, id in ipairs(preloadIds) do
		writeU16(header, id)
	end

	writeU32(header, writer.Count)
	for index = 1, writer.Count do
		writeU16(header, writer.NameIds[index])
		writeU32(header, writer.Offsets[index])
	end

	local result = buffer.create(header.Length + writer.Length)
	buffer.copy(result, 0, header.Buffer, 0, header.Length)
	buffer.copy(result, header.Length, writer.Buffer, 0, writer.Length)

	return result
end

------------------------------------------------------------------------------------------------------------------------
--READING---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

type Cursor = { Buffer: buffer, Offset: number }

local function readU8(cursor: Cursor): number
	local value = buffer.readu8(cursor.Buffer, cursor.Offset)
	cursor.Offset += 1

	return value
end

local function readU16(cursor: Cursor): number
	local value = buffer.readu16(cursor.Buffer, cursor.Offset)
	cursor.Offset += 2

	return value
end

local function readU32(cursor: Cursor): number
	local value = buffer.readu32(cursor.Buffer, cursor.Offset)
	cursor.Offset += 4

	return value
end

local function readF64(cursor: Cursor): number
	local value = buffer.readf64(cursor.Buffer, cursor.Offset)
	cursor.Offset += 8

	return value
end

local function readString(cursor: Cursor): string
	local length = readU32(cursor)
	local value = buffer.readstring(cursor.Buffer, cursor.Offset, length)
	cursor.Offset += length

	return value
end

local function readShortString(cursor: Cursor): string
	local length = readU16(cursor)
	local value = buffer.readstring(cursor.Buffer, cursor.Offset, length)
	cursor.Offset += length

	return value
end

local function lookupString(strings: { string }, id: number): string
	local value = strings[id]
	if value == nil then
		FormatMessage.Error(`The schema buffer is damaged: string {id} does not exist.`)
	end

	return value
end

local function readValue(cursor: Cursor, strings: { string }, owner: string, name: string): (boolean, any)
	local tag = readU8(cursor)

	if tag == TAG_NUMBER then
		return true, readF64(cursor)
	elseif tag == TAG_STRING then
		return true, readString(cursor)
	elseif tag == TAG_BOOLEAN then
		return true, readU8(cursor) ~= 0
	elseif tag == TAG_ENUM then
		local enumId = readU16(cursor)
		local itemId = readU16(cursor)

		local cacheKey = enumId * 65536 + itemId
		local cached = enumCache[cacheKey]
		if cached then
			return true, cached
		elseif cached == false then
			return false, nil
		end

		local enumName = lookupString(strings, enumId)
		local itemName = lookupString(strings, itemId)

		local success, item = pcall(resolveEnum, enumName, itemName)
		if not success or typeof(item) ~= "EnumItem" then
			enumCache[cacheKey] = false
			FormatMessage.Warn(
				`"{owner}" property "{name}" uses Enum.{enumName}.{itemName}, which does not exist here.`
			)

			return false, nil
		end

		enumCache[cacheKey] = item

		return true, item
	elseif tag == TAG_RANGE then
		local min = readF64(cursor)
		local max = readF64(cursor)

		return true, NumberRange.new(min, max)
	end

	FormatMessage.Error(`The schema buffer is damaged: unknown value type {tag} on "{owner}".`)

	return false, nil
end

local function readProperties(cursor: Cursor, strings: { string }, owner: string): { [string]: any }
	local count = readU16(cursor)
	local properties: { [string]: any } = {}

	for _ = 1, count do
		local name = lookupString(strings, readU16(cursor))
		local success, value = readValue(cursor, strings, owner, name)

		if success then
			properties[name] = value
		end
	end

	return properties
end

--[[
	@param schemaBuffer buffer -- A buffer made by Finish.

	@return Loaded -- The header: names, groups, preloads, and where each definition lives in the buffer.

	Reads the header of a schema buffer. Definitions are not decoded here; use ReadDefinition for one at a time.
]]
function Codec.Load(schemaBuffer: buffer): Loaded
	if buffer.len(schemaBuffer) < 2 or buffer.readu8(schemaBuffer, 0) ~= MAGIC then
		FormatMessage.Error("The schema buffer is not a VluxySF schema!")
	end

	local version = buffer.readu8(schemaBuffer, 1)
	if version ~= VERSION then
		FormatMessage.Error(
			`The schema buffer is format {version} but this version of the library reads format {VERSION}. The server and client are running different versions of VluxySF.`
		)
	end

	local cursor: Cursor = { Buffer = schemaBuffer, Offset = 2 }

	--enum cache keys are string ids, which belong to one buffer
	table.clear(enumCache)

	local stringCount = readU16(cursor)
	local strings: { string } = table.create(stringCount)
	for index = 1, stringCount do
		strings[index] = readShortString(cursor)
	end

	local groupCount = readU16(cursor)
	local groupNames: { string } = table.create(groupCount)
	for index = 1, groupCount do
		groupNames[index] = lookupString(strings, readU16(cursor))
	end

	local preloadCount = readU32(cursor)
	local preloadNames: { string } = table.create(preloadCount)
	for index = 1, preloadCount do
		preloadNames[index] = lookupString(strings, readU16(cursor))
	end

	local definitionCount = readU32(cursor)
	local names: { string } = table.create(definitionCount)
	local relativeOffsets: { number } = table.create(definitionCount)
	for index = 1, definitionCount do
		names[index] = lookupString(strings, readU16(cursor))
		relativeOffsets[index] = readU32(cursor)
	end

	local bodyStart = cursor.Offset
	local offsets: { [string]: number } = {}
	for index = 1, definitionCount do
		offsets[names[index]] = bodyStart + relativeOffsets[index]
	end

	return {
		Buffer = schemaBuffer,
		Strings = strings,

		GroupNames = groupNames,
		PreloadNames = preloadNames,

		Names = names,
		Offsets = offsets,
		Count = definitionCount,
	}
end

--[[
	@param loaded Loaded -- The loaded schema.
	@param offset number -- The definition's offset from Loaded.Offsets.

	@return SoundDefinition -- The decoded definition. Its SoundGroup is not set; use the group index for that.
	@return number -- The 1-based index of the sound's group in Loaded.GroupNames, or 0.

	Decodes one definition out of the buffer.
]]
function Codec.ReadDefinition(loaded: Loaded, offset: number): (Types.SoundDefinition, number)
	local strings = loaded.Strings
	local cursor: Cursor = { Buffer = loaded.Buffer, Offset = offset }

	local name = lookupString(strings, readU16(cursor))
	local groupIndex = readU16(cursor)
	local properties = readProperties(cursor, strings, name)
	properties.Name = name

	local effectCount = readU8(cursor)
	local effects: { [string]: { [string]: any } } = {}

	for _ = 1, effectCount do
		local className = lookupString(strings, readU16(cursor))
		local effectProperties = readProperties(cursor, strings, `{name}.{className}`)
		effectProperties.Name = className

		effects[className] = effectProperties
	end

	local definition: Types.SoundDefinition = {
		Properties = properties :: any,
		Effects = effects :: any,
		EffectsCount = effectCount,
	}

	return definition, groupIndex
end

return Codec
