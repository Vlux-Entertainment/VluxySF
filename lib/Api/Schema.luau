--!strict
--!optimize 2

local SchemaStore = require(script.Parent.Parent.Core.SchemaStore)
local Types = require(script.Parent.Parent.Types)

--[=[
	@class Schema

	@tag RequiresSchema

	Reads the schema: the definitions the library builds sounds from.

	Definitions are decoded out of the compiled schema the first time they are asked for. `GetDefinition` decodes one.
	`Get` and `GetDefinitions` decode every remaining one and then freeze the definitions table.

	Called before the library has started, every function here warns once and returns an empty result.

	:::caution
	With a large schema, `Get` and `GetDefinitions` cost time and keep every definition in memory. Use them for
	tooling and debugging, not on hot paths; use `GetDefinition` or `Has` for one sound.
	:::
]=]
local Schema = {}

local emptyDefinitions: Types.SoundDefinitions = table.freeze({})

--[=[
	@within Schema

	Returns the full schema. Decodes every definition that has not been decoded yet.

	```lua
	local schema = VluxySF.Schema.Get()

	if schema then
		print(schema.PreloadNames)
	end
	```

	@return SoundSchema? -- The frozen schema, or `nil` before the library has started.
]=]
function Schema.Get(): Types.SoundSchema?
	if not SchemaStore.CheckReady("Schema.Get") then
		return nil
	end

	SchemaStore.GetDefinitions()

	return SchemaStore.GetSchema()
end

--[=[
	@within Schema

	Returns every definition, keyed by sound name. Decodes every definition that has not been decoded yet.

	```lua
	for name, definition in VluxySF.Schema.GetDefinitions() do
		print(name, definition.EffectsCount)
	end
	```

	@return SoundDefinitions -- The frozen definitions. Empty before the library has started.
]=]
function Schema.GetDefinitions(): Types.SoundDefinitions
	if not SchemaStore.CheckReady("Schema.GetDefinitions") then
		return emptyDefinitions
	end

	return SchemaStore.GetDefinitions()
end

--[=[
	@within Schema

	Returns one definition, decoding it the first time. Prints nothing for a name that is not in the schema; use `Has`
	to check first if that matters.

	```lua
	local definition = VluxySF.Schema.GetDefinition("MySound")

	if definition then
		print(definition.Properties.SoundId)
	end
	```

	@param name string -- The sound name.

	@return SoundDefinition? -- The frozen definition, or `nil`.
]=]
function Schema.GetDefinition(name: string): Types.SoundDefinition?
	if not SchemaStore.CheckReady("Schema.GetDefinition") then
		return nil
	end

	return SchemaStore.GetDefinition(name)
end

--[=[
	@within Schema

	Checks whether a sound is in the schema, without decoding it and without a warning.

	```lua
	if VluxySF.Schema.Has(`VO_{npcName}`) then
		VluxySF.OneShot(`VO_{npcName}`)
	end
	```

	@param name string -- The sound name.

	@return boolean -- Whether a sound has that name. `false` before the library has started.
]=]
function Schema.Has(name: string): boolean
	if not SchemaStore.CheckReady("Schema.Has") then
		return false
	end

	local loaded = SchemaStore.GetLoaded()

	return loaded ~= nil and loaded.Offsets[name] ~= nil
end

--[=[
	@within Schema

	```lua
	print(VluxySF.Schema.GetNames())
	```

	@return { string } -- A new array of every sound name, in the order they were compiled. Empty before the library
	has started.
]=]
function Schema.GetNames(): { string }
	if not SchemaStore.CheckReady("Schema.GetNames") then
		return {}
	end

	return SchemaStore.GetNames()
end

return Schema
