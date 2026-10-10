--!strict

--[[
	Round-trip check for a real SOUNDS Configuration.

	Drop a Configuration named SOUNDS into ServerStorage next to TEST_SOUNDS and press Play. This script compiles it
	the same way InitServer does, rebuilds every sound from the schema, and compares the rebuilt sound and its
	effects against the original. It never touches the library's state, so the normal tests still run on
	TEST_SOUNDS. It prints one summary and up to MAX_REPORTED mismatches.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local library = ReplicatedStorage.VluxySF
local Codec = require(library.Core.Codec)
local Compile = require(library.Core.Compile)
local Converters = require(library.Core.Converters)
local Properties = require(library.Core.Properties)

local CONFIG_NAME = "SOUNDS"
local MAX_REPORTED = 20
local TOLERANCE = 0.0001

--Never compared: SoundGroup is assigned from the group index at runtime, not stored on the definition.
local SKIPPED_KEYS: { [string]: boolean } = {
	SoundGroup = true,
}

local config = ServerStorage:FindFirstChild(CONFIG_NAME)
if not config then
	return
end

local mismatches: { string } = {}

local function report(message: string)
	table.insert(mismatches, message)
end

local function same(a: any, b: any): boolean
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) <= TOLERANCE
	end

	return a == b
end

local function compareTables(label: string, original: { [string]: any }, rebuilt: { [string]: any })
	for key, value in pairs(original) do
		if SKIPPED_KEYS[key] then
			continue
		end

		if not same(value, rebuilt[key]) then
			report(`{label}.{key}: original {tostring(value)}, rebuilt {tostring(rebuilt[key])}`)
		end
	end

	for key, value in pairs(rebuilt) do
		if SKIPPED_KEYS[key] or original[key] ~= nil then
			continue
		end

		report(`{label}.{key}: rebuilt has {tostring(value)}, original has nothing`)
	end
end

------------------------------------------------------------------------------------------------------------------------

local sounds: { Sound } = {}
for _, descendant in ipairs(config:GetDescendants()) do
	if descendant:IsA("Sound") then
		table.insert(sounds, descendant)
	end
end

local groupCount = #config:GetChildren()

local clock = os.clock()
local schemaBuffer, compiledCount = Compile.Build(config)
local compileSeconds = os.clock() - clock

local loaded = Codec.Load(schemaBuffer)

local effectCount = 0
local seenNames: { [string]: boolean } = {}

clock = os.clock()
for _, sound in ipairs(sounds) do
	local name = sound.Name

	if seenNames[name] then
		continue --Compile keeps the first one; the warning already said so
	end
	seenNames[name] = true

	local offset = loaded.Offsets[name]
	if not offset then
		report(`{name}: missing from the schema`)
		continue
	end

	local definition = Codec.ReadDefinition(loaded, offset)
	local rebuilt = Converters.DefinitionToSound(definition)

	compareTables(name, Properties.ReadChanged(sound), Properties.ReadChanged(rebuilt))

	if rebuilt.Name ~= name then
		report(`{name}: rebuilt Name is "{rebuilt.Name}"`)
	end

	local originalEffects: { [string]: Instance } = {}
	for _, child in ipairs(sound:GetChildren()) do
		if child:IsA("SoundEffect") and not originalEffects[child.ClassName] then
			originalEffects[child.ClassName] = child
			effectCount += 1
		end
	end

	local rebuiltEffects: { [string]: Instance } = {}
	for _, child in ipairs(rebuilt:GetChildren()) do
		rebuiltEffects[child.ClassName] = child
	end

	for className, original in pairs(originalEffects) do
		local copy = rebuiltEffects[className]
		if not copy then
			report(`{name}.{className}: effect missing after rebuild`)
			continue
		end

		compareTables(`{name}.{className}`, Properties.ReadChanged(original), Properties.ReadChanged(copy))
	end

	for className in pairs(rebuiltEffects) do
		if not originalEffects[className] then
			report(`{name}.{className}: effect appeared after rebuild`)
		end
	end

	rebuilt:Destroy()
end
local rebuildSeconds = os.clock() - clock

------------------------------------------------------------------------------------------------------------------------

print(
	`[VluxySF Tests] {CONFIG_NAME}: {#sounds} sounds in {groupCount} groups with {effectCount} effects, {#loaded.PreloadNames} tagged to preload.`
)
print(
	`[VluxySF Tests] {CONFIG_NAME}: compiled {compiledCount} in {math.round(compileSeconds * 1000)} ms into {buffer.len(
		schemaBuffer
	)} bytes; rebuilt and compared in {math.round(rebuildSeconds * 1000)} ms.`
)

if #mismatches == 0 then
	print(`[VluxySF Tests] {CONFIG_NAME}: every sound and effect round-tripped exactly.`)
else
	warn(`[VluxySF Tests] {CONFIG_NAME}: {#mismatches} mismatches!`)
	for index = 1, math.min(#mismatches, MAX_REPORTED) do
		warn(`\t{mismatches[index]}`)
	end
	if #mismatches > MAX_REPORTED then
		warn(`\t... and {#mismatches - MAX_REPORTED} more`)
	end
end
