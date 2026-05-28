--!strict

local library = script.Parent.Parent

local FormatMessage = require(library.Utility.FormatMessage)
local Types = require(library.Types)

------------------------------------------------------------------------------------------------------------

local schemaFailCheck: () -> () = function()
	FormatMessage.Error(`SchemaFailCheck was not inject for the Schema Section!`)
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
	@class Schema

	@tag RequiresSchema

	Functions for accessing the sound schema and its data.
]=]
local Schema = {}

--[=[
	@within Schema

	@return SoundSchema -- The internal sound schema used by the system.

	Provides access to the internal sound schema.
]=]
function Schema.Get(): Types.SoundSchema
	schemaFailCheck()

	return soundSchema
end

--[=[
	@within Schema

	@return SoundDefinitions -- All converted sound data

	Returns all serialized sound data.
]=]
function Schema.GetDefinitions(): Types.SoundDefinitions
	schemaFailCheck()

	return soundSchema.SoundDefinitions
end

--[=[
	@within Schema

	@return { string } -- All registered sound locations

	Returns all sound locations.
]=]
function Schema.GetLocations(): { string }
	schemaFailCheck()

	local locations = {}

	for location, _ in pairs(soundSchema.SoundDefinitions) do
		table.insert(locations, location)
	end

	return locations
end

Core.Schema = Schema

return Core
