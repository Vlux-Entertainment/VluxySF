--!strict
--!optimize 2

local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local SchemaStore = require(script.Parent.Parent.Core.SchemaStore)
local Types = require(script.Parent.Parent.Types)

--[=[
	@class Schema

	@tag RequiresSchema

	Reads the schema: the definitions the library builds sounds from.

	Definitions are decoded out of the compiled schema the first time they are asked for. `GetDefinition` decodes one.
	`Get` and `GetDefinitions` decode every remaining one and then freeze the definitions table.
]=]
local Schema = {}

--[=[
	@within Schema

	Returns the full schema. Decodes every definition that has not been decoded yet.

	```lua
	local schema = VluxySF.Schema.Get()

	print(schema.PreloadNames)
	```

	@return SoundSchema -- The frozen schema.
]=]
function Schema.Get(): Types.SoundSchema
	SchemaStore.AssertInitialized()

	SchemaStore.GetDefinitions()

	return SchemaStore.GetSchema()
end

--[=[
	@within Schema

	Returns every definition, keyed by sound name. Decodes every definition that has not been decoded yet.

	```lua
	for name, definition in pairs(VluxySF.Schema.GetDefinitions()) do
		print(name, definition.EffectsCount)
	end
	```

	@return SoundDefinitions -- The frozen definitions.
]=]
function Schema.GetDefinitions(): Types.SoundDefinitions
	SchemaStore.AssertInitialized()

	return SchemaStore.GetDefinitions()
end

--[=[
	@within Schema

	Returns one definition. Prints a warning when the name is not in the schema.

	```lua
	local definition = VluxySF.Schema.GetDefinition("MySound")

	if definition then
		print(definition.Properties.SoundId)
	end
	```

	@param definitionName string -- The sound name.

	@return SoundDefinition? -- The frozen definition, or `nil`.
]=]
function Schema.GetDefinition(definitionName: string): Types.SoundDefinition?
	SchemaStore.AssertInitialized()

	local definition = SchemaStore.GetDefinition(definitionName)
	if not definition then
		FormatMessage.Warn(`"{definitionName}" is not in the schema.`)
	end

	return definition
end

--[=[
	@within Schema

	```lua
	print(VluxySF.Schema.GetNames())
	```

	@return { string } -- A new array of every sound name.
]=]
function Schema.GetNames(): { string }
	SchemaStore.AssertInitialized()

	return SchemaStore.GetNames()
end

return Schema
