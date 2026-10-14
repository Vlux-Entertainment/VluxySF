--!strict
--!optimize 2

--[[
	Encodes the schema into one buffer and decodes definitions out of it on demand.

	Every count, id, length and offset is a varint: 7 bits per byte, low bits first, the high bit set on every byte
	but the last. Values under 128 take one byte.

		varint string count, then each string as varint length + bytes
		varint group count, then a varint string id per group
		varint preload count, then a varint string id per sound name
		varint definition count, then per definition: varint name string id, varint gap from the previous definition
		body: the definitions, back to back in the order they were written

	A definition in the body (its name is known from the index, so it is not repeated):

		varint group index, 0 for none
		varint property count, then the properties
		varint effect count, then per effect: varint class string id, varint property count, the properties

	A property is a varint key string id, a u8 tag and the value. The tag carries part of the value where it can:

		1 number        f32, used when the number survives a round trip through f32 exactly
		2 number        f64
		3 string        varint length + bytes
		4 false         nothing
		5 true          nothing
		6 EnumItem      varint enum type string id, varint item name string id
		7 NumberRange   f32 min, f32 max, used when both survive a round trip through f32 exactly
		8 NumberRange   f64 min, f64 max
		9 asset id      varint number, for a string that is exactly "rbxassetid://" followed by that number

	Property names, enum names, class names and sound names go through the string table, so none of them repeat
	per sound. Other strings are stored inline.
]]

local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local Types = require(script.Parent.Parent.Types)

local TAG_F32 = 1
local TAG_F64 = 2
local TAG_STRING = 3
local TAG_FALSE = 4
local TAG_TRUE = 5
local TAG_ENUM = 6
local TAG_RANGE_F32 = 7
local TAG_RANGE_F64 = 8
local TAG_ASSET_ID = 9

local ASSET_ID_FORMAT = "rbxassetid://%d"
local ASSET_ID_PATTERN = "^rbxassetid://(%d+)$"

--Whole numbers above this lose precision as doubles, so asset ids past it stay strings.
local MAX_SAFE_INTEGER = 2 ^ 53

local INITIAL_CAPACITY = 64 * 1024

--Properties that are never encoded. Parent and ClassName are structural, SoundGroup is stored as the group index,
--and Name is already in the string table (the sound name, or the effect's class name) so it is restored on read.
local SKIPPED_PROPERTIES: { [string]: boolean } = {
	Parent = true,
	ClassName = true,
	SoundGroup = true,
	Name = true,
}

--Value types a property can hold.
local STORED_TYPES: { [string]: boolean } = {
	number = true,
	string = true,
	boolean = true,
	EnumItem = true,
	NumberRange = true,
}

--Resolved EnumItems keyed by enum string id * 65536 + item string id. false marks a pair that does not exist here.
--String ids belong to one buffer, so every loaded schema has its own.
type EnumCache = { [number]: EnumItem | false }

local function resolveEnum(enumName: string, itemName: string): EnumItem
	return (Enum :: any)[enumName][itemName]
end

--Scratch space for checking whether a number survives f32.
local f32Scratch = buffer.create(4)

local function fitsF32(value: number): boolean
	buffer.writef32(f32Scratch, 0, value)

	return buffer.readf32(f32Scratch, 0) == value
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

	EnumCache: EnumCache,
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

--Any whole number from 0 to 2^53. Uses arithmetic rather than bit32 so values past 32 bits stay exact.
local function writeVarint(writer: Writer, value: number)
	reserve(writer, 8)

	local target = writer.Buffer
	local offset = writer.Length

	while value >= 128 do
		buffer.writeu8(target, offset, value % 128 + 128)
		value //= 128
		offset += 1
	end

	buffer.writeu8(target, offset, value)
	writer.Length = offset + 1
end

local function writeF32(writer: Writer, value: number)
	reserve(writer, 4)
	buffer.writef32(writer.Buffer, writer.Length, value)
	writer.Length += 4
end

local function writeF64(writer: Writer, value: number)
	reserve(writer, 8)
	buffer.writef64(writer.Buffer, writer.Length, value)
	writer.Length += 8
end

local function writeString(writer: Writer, value: string)
	local length = #value

	writeVarint(writer, length)
	reserve(writer, length)
	buffer.writestring(writer.Buffer, writer.Length, value)
	writer.Length += length
end

local function intern(writer: Writer, value: string): number
	local id = writer.StringIds[value]
	if id then
		return id
	end

	local newId = #writer.Strings + 1
	writer.Strings[newId] = value
	writer.StringIds[value] = newId

	return newId
end

--Returns the asset number only when formatting it back gives exactly the same string, so the round trip is exact.
local function assetIdOf(value: string): number?
	local digits = string.match(value, ASSET_ID_PATTERN)
	if not digits then
		return nil
	end

	local number = tonumber(digits)
	if not number or number > MAX_SAFE_INTEGER or string.format(ASSET_ID_FORMAT, number) ~= value then
		return nil
	end

	return number
end

--[[
	Writes the tag and the value. The value's type has to be in STORED_TYPES.
]]
local function writeValue(writer: Writer, value: any)
	local valueType = typeof(value)

	if valueType == "number" then
		if fitsF32(value) then
			writeU8(writer, TAG_F32)
			writeF32(writer, value)
		else
			writeU8(writer, TAG_F64)
			writeF64(writer, value)
		end
	elseif valueType == "string" then
		local assetId = assetIdOf(value)

		if assetId then
			writeU8(writer, TAG_ASSET_ID)
			writeVarint(writer, assetId)
		else
			writeU8(writer, TAG_STRING)
			writeString(writer, value)
		end
	elseif valueType == "boolean" then
		writeU8(writer, if value then TAG_TRUE else TAG_FALSE)
	elseif valueType == "EnumItem" then
		local item = value :: EnumItem

		writeU8(writer, TAG_ENUM)
		writeVarint(writer, intern(writer, tostring(item.EnumType)))
		writeVarint(writer, intern(writer, item.Name))
	elseif valueType == "NumberRange" then
		local range = value :: NumberRange

		if fitsF32(range.Min) and fitsF32(range.Max) then
			writeU8(writer, TAG_RANGE_F32)
			writeF32(writer, range.Min)
			writeF32(writer, range.Max)
		else
			writeU8(writer, TAG_RANGE_F64)
			writeF64(writer, range.Min)
			writeF64(writer, range.Max)
		end
	end
end

--[[
	Writes a property table as a varint count followed by the properties.
]]
local function writeProperties(writer: Writer, owner: string, properties: { [string]: any })
	local stored: { string } = {}

	for name, value in pairs(properties) do
		if SKIPPED_PROPERTIES[name] then
			continue
		end

		if not STORED_TYPES[typeof(value)] then
			FormatMessage.Warn(
				`"{owner}" property "{name}" is a {typeof(value)}, which cannot be stored. It was skipped.`
			)
			continue
		end

		table.insert(stored, name)
	end

	writeVarint(writer, #stored)

	for _, name in ipairs(stored) do
		writeVarint(writer, intern(writer, name))
		writeValue(writer, properties[name])
	end
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

	writeVarint(writer, groupIndex)
	writeProperties(writer, name, definition.Properties :: any)

	local effects = definition.Effects :: { [string]: { [string]: any } }
	local classNames: { string } = {}
	for className in pairs(effects) do
		table.insert(classNames, className)
	end

	writeVarint(writer, #classNames)

	for _, className in ipairs(classNames) do
		writeVarint(writer, intern(writer, className))
		writeProperties(writer, `{name}.{className}`, effects[className])
	end

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

	writeVarint(header, #writer.Strings)
	for _, value in ipairs(writer.Strings) do
		writeString(header, value)
	end

	writeVarint(header, #groupIds)
	for _, id in ipairs(groupIds) do
		writeVarint(header, id)
	end

	writeVarint(header, #preloadIds)
	for _, id in ipairs(preloadIds) do
		writeVarint(header, id)
	end

	writeVarint(header, writer.Count)
	local previous = 0
	for index = 1, writer.Count do
		local offset = writer.Offsets[index]

		writeVarint(header, writer.NameIds[index])
		writeVarint(header, offset - previous)
		previous = offset
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

local function readVarint(cursor: Cursor): number
	local source = cursor.Buffer
	local offset = cursor.Offset

	local value = 0
	local scale = 1

	while true do
		local byte = buffer.readu8(source, offset)
		offset += 1

		if byte < 128 then
			value += byte * scale
			break
		end

		value += (byte - 128) * scale
		scale *= 128
	end

	cursor.Offset = offset

	return value
end

local function readF32(cursor: Cursor): number
	local value = buffer.readf32(cursor.Buffer, cursor.Offset)
	cursor.Offset += 4

	return value
end

local function readF64(cursor: Cursor): number
	local value = buffer.readf64(cursor.Buffer, cursor.Offset)
	cursor.Offset += 8

	return value
end

local function readString(cursor: Cursor): string
	local length = readVarint(cursor)
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

local function readValue(
	cursor: Cursor,
	strings: { string },
	enumCache: EnumCache,
	owner: string,
	name: string
): (boolean, any)
	local tag = readU8(cursor)

	if tag == TAG_F32 then
		return true, readF32(cursor)
	elseif tag == TAG_ASSET_ID then
		return true, string.format(ASSET_ID_FORMAT, readVarint(cursor))
	elseif tag == TAG_TRUE then
		return true, true
	elseif tag == TAG_FALSE then
		return true, false
	elseif tag == TAG_STRING then
		return true, readString(cursor)
	elseif tag == TAG_F64 then
		return true, readF64(cursor)
	elseif tag == TAG_ENUM then
		local enumId = readVarint(cursor)
		local itemId = readVarint(cursor)

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
	elseif tag == TAG_RANGE_F32 then
		local min = readF32(cursor)
		local max = readF32(cursor)

		return true, NumberRange.new(min, max)
	elseif tag == TAG_RANGE_F64 then
		local min = readF64(cursor)
		local max = readF64(cursor)

		return true, NumberRange.new(min, max)
	end

	FormatMessage.Error(`The schema buffer is damaged: unknown value type {tag} on "{owner}".`)

	return false, nil
end

local function readProperties(
	cursor: Cursor,
	strings: { string },
	enumCache: EnumCache,
	owner: string
): { [string]: any }
	local count = readVarint(cursor)
	local properties: { [string]: any } = {}

	for _ = 1, count do
		local name = lookupString(strings, readVarint(cursor))
		local success, value = readValue(cursor, strings, enumCache, owner, name)

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
	local cursor: Cursor = { Buffer = schemaBuffer, Offset = 0 }

	local stringCount = readVarint(cursor)
	local strings: { string } = table.create(stringCount)
	for index = 1, stringCount do
		strings[index] = readString(cursor)
	end

	local groupCount = readVarint(cursor)
	local groupNames: { string } = table.create(groupCount)
	for index = 1, groupCount do
		groupNames[index] = lookupString(strings, readVarint(cursor))
	end

	local preloadCount = readVarint(cursor)
	local preloadNames: { string } = table.create(preloadCount)
	for index = 1, preloadCount do
		preloadNames[index] = lookupString(strings, readVarint(cursor))
	end

	local definitionCount = readVarint(cursor)
	local names: { string } = table.create(definitionCount)
	local relativeOffsets: { number } = table.create(definitionCount)
	local previous = 0
	for index = 1, definitionCount do
		names[index] = lookupString(strings, readVarint(cursor))
		previous += readVarint(cursor)
		relativeOffsets[index] = previous
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

		EnumCache = {},
	}
end

--[[
	@param loaded Loaded -- The loaded schema.
	@param name string -- The sound name.

	@return SoundDefinition? -- The decoded definition, or nil when no sound has that name. Its SoundGroup is not set;
	use the group index for that.
	@return number -- The 1-based index of the sound's group in Loaded.GroupNames, or 0.

	Decodes one definition out of the buffer.
]]
function Codec.ReadDefinition(loaded: Loaded, name: string): (Types.SoundDefinition?, number)
	local offset = loaded.Offsets[name]
	if not offset then
		return nil, 0
	end

	local strings = loaded.Strings
	local enumCache = loaded.EnumCache
	local cursor: Cursor = { Buffer = loaded.Buffer, Offset = offset }

	local groupIndex = readVarint(cursor)
	local properties = readProperties(cursor, strings, enumCache, name)
	properties.Name = name

	local effectCount = readVarint(cursor)
	local effects: { [string]: { [string]: any } } = {}

	for _ = 1, effectCount do
		local className = lookupString(strings, readVarint(cursor))
		local effectProperties = readProperties(cursor, strings, enumCache, `{name}.{className}`)
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
