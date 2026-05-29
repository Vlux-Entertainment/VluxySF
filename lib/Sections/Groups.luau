--!strict
--!optimize 2

local library = script.Parent.Parent

local FormatMessage = require(library.Utility.FormatMessage)

local Types = require(library.Types)

------------------------------------------------------------------------------------------------------------

local schemaFailCheck: () -> () = function()
	FormatMessage.Error(`SchemaFailCheck was not inject for the Groups Section!`)
end

local soundSchema: Types.SoundSchema = nil

------------------------------------------------------------------------------------------------------------

--[[
    Internals for this liberary.
]]
local Core = {}

--[[
    @param func () -> () -- The function to be injected as the schema fail check.

    Injects a function to be used as a check for when the schhema exists.
]]
function Core._injectSchemaFailCheck(func: () -> ())
	schemaFailCheck = func
end

--[[
    @param schema Types.SoundSchema -- The sound schema to be injected for use in the Groups section.

    Injects the sound schema for use in the Groups section.
]]
function Core._injectSoundSchema(schema: Types.SoundSchema)
	soundSchema = schema
end

------------------------------------------------------------------------------------------------------------

--[=[
	@class SoundGroups

	@tag RequiresSchema

	Functions for getting and setting the created sound groups.
]=]
local Groups = {}

--[=[
	@within SoundGroups

	@return SoundGroups -- All sound groups defined in the schema.

	Returns all sound groups defined in the schema.
]=]
function Groups.Get(): Types.SoundGroups
	schemaFailCheck()

	return soundSchema.SoundGroups
end

--[=[
	@within SoundGroups

	@param name string -- The name of the sound group to retrieve.

	@return SoundGroup? -- The sound group instance if found, otherwise nil.

	Retrieves a sound group instance by its name.
]=]
function Groups.GetByName(name: string): SoundGroup?
	schemaFailCheck()

	return soundSchema.SoundGroups[name]
end

--[=[
	@within SoundGroups

	@return { string } -- A list of all sound group names defined in the schema.

	Returns a list of all sound group names defined in the schema.
]=]
function Groups.GetNames(): { string }
	schemaFailCheck()

	local names = {}

	for name, _ in pairs(soundSchema.SoundGroups) do
		table.insert(names, name)
	end

	return names
end

------------------------------------------------------------------------------------------------------------

--[[
    @within SoundGroups

    @param mainVolume number -- The desired main volume level to set for the "SOUNDS" group.

    Sets the main volume level for the "SOUNDS" group, which can be used as a master volume control for all sounds in that group.
]]
function Groups.SetMainVolume(mainVolume: number)
	local soundsGroup = soundSchema.SoundGroupContainer

	if soundsGroup then
		soundsGroup.Volume = mainVolume
	end
end

--[=[
	@within SoundGroups

	@param mainVolume number? -- An optional main volume level to set.
	@param volumes { [string]: number } -- A dictionary mapping sound group names to their desired volume levels.

	Sets the volume levels for multiple sound groups at once based on the provided dictionary of group names and volume values.
]=]
function Groups.SetVolumes(mainVolume: number?, volumes: { [string]: number })
	schemaFailCheck()

	if mainVolume then
		Groups.SetMainVolume(mainVolume)
	end

	for groupName, volume in pairs(volumes) do
		local group = Groups.GetByName(groupName)

		if not group then
			warn(`VluxySF: Attempted to set volume for sound group '{groupName}', but it does not exist in schema!`)
			continue
		end

		group.Volume = volume
	end
end

Core.Groups = Groups

return Core
