--!strict
--!optimize 2

--[[
	Walks the SOUNDS Configuration once and writes every Sound into a schema buffer.

	Every direct child of SOUNDS must be a Configuration and becomes a SoundGroup. Folders and Configurations below
	that are organization only. A Sound tagged VluxySF_Preload, or inside a container tagged with it, is preloaded on
	the client.
]]

local Codec = require(script.Parent.Codec)
local Converters = require(script.Parent.Converters)
local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)

local PRELOAD_TAG = "VluxySF_Preload"

local Compile = {}

type State = {
	Writer: Codec.Writer,
	GroupIndex: number,

	Seen: { [string]: boolean },
	PreloadSeen: { [string]: boolean },
	PreloadNames: { string },
}

local function writeSound(state: State, sound: Sound, preload: boolean)
	local name = sound.Name

	if state.Seen[name] then
		FormatMessage.Warn(`Duplicate sound name "{name}" at {sound:GetFullName()}. Only the first one was kept.`)

		return
	end
	state.Seen[name] = true

	local definition = Converters.SoundToDefinition(sound)
	Codec.WriteDefinition(state.Writer, name, state.GroupIndex, definition)

	if preload and not state.PreloadSeen[name] then
		state.PreloadSeen[name] = true
		table.insert(state.PreloadNames, name)
	end
end

--Any non-Sound instance is a container, so a Sound is found wherever it is placed under its group.
local function walk(state: State, container: Instance, preload: boolean)
	for _, child in ipairs(container:GetChildren()) do
		local childPreload = preload or child:HasTag(PRELOAD_TAG)

		if child:IsA("Sound") then
			writeSound(state, child, childPreload)
		else
			walk(state, child, childPreload)
		end
	end
end

--[[
	@param soundsFolder Configuration -- The SOUNDS Configuration.

	@return buffer -- The schema buffer.
	@return number -- How many sounds were written.

	Compiles a SOUNDS Configuration into a schema buffer. Errors when a direct child is not a Configuration.
]]
function Compile.Build(soundsFolder: Instance): (buffer, number)
	local state: State = {
		Writer = Codec.NewWriter(),
		GroupIndex = 0,

		Seen = {},
		PreloadSeen = {},
		PreloadNames = {},
	}

	local groupNames: { string } = {}
	local groupSeen: { [string]: boolean } = {}

	for _, child in ipairs(soundsFolder:GetChildren()) do
		if not child:IsA("Configuration") then
			FormatMessage.Error(
				`"{child:GetFullName()}" is a {child.ClassName}. Every direct child of {soundsFolder.Name} must be a Configuration, one per SoundGroup.`,
				4
			)
		end

		local groupName = child.Name
		if groupSeen[groupName] then
			FormatMessage.Error(
				`There are two SoundGroups named "{groupName}" under {soundsFolder.Name}. SoundGroup names must be unique.`,
				4
			)
		end
		groupSeen[groupName] = true

		table.insert(groupNames, groupName)
		state.GroupIndex = #groupNames

		walk(state, child, child:HasTag(PRELOAD_TAG))
	end

	return Codec.Finish(state.Writer, groupNames, state.PreloadNames), state.Writer.Count
end

return Compile
