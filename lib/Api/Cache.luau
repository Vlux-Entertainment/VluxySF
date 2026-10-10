--!strict
--!optimize 2

local Converters = require(script.Parent.Parent.Core.Converters)
local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local SchemaStore = require(script.Parent.Parent.Core.SchemaStore)
local Templates = require(script.Parent.Parent.Core.Templates)

--[=[
	@class Cache

	@tag RequiresSchema

	@client

	A warmed sound is built once and kept in `SoundService.WarmedSounds` until you chill it. While it is warmed,
	`Fetch` clones it instead of building it. Use this for sounds that matter during one part of the game, and chill
	them when that part is over.

	Warming does not download the sound's asset. The engine loads an asset the first time a `Sound` with that id
	plays, or when `Preload` is used.
]=]
local Cache = {}

--[=[
	@within Cache

	```lua
	print(VluxySF.Cache.Get())
	```

	@return { [string]: Sound } -- Every warmed template, keyed by name. Do not modify it.
]=]
function Cache.Get(): { [string]: Sound }
	SchemaStore.AssertInitialized()
	SchemaStore.AssertClient()

	return Templates.Warmed.All()
end

--[=[
	@within Cache

	```lua
	print(VluxySF.Cache.IsWarmed("MySound"))
	```

	@param soundName string -- The sound name.

	@return boolean -- Whether the sound is warmed.
]=]
function Cache.IsWarmed(soundName: string): boolean
	SchemaStore.AssertInitialized()
	SchemaStore.AssertClient()

	return Templates.Warmed.Get(soundName) ~= nil
end

--[=[
	@within Cache

	Warms sounds by name. A name that is already warmed is skipped. A name that is not in the schema prints a warning.

	```lua
	VluxySF.Cache.Warm("BossRoar", "BossStomp")
	```

	@param ... string -- The sound names.
]=]
function Cache.Warm(...: string)
	SchemaStore.AssertInitialized()
	SchemaStore.AssertClient()

	local parent = SchemaStore.GetSchema().WarmedSounds
	local registry = Templates.Warmed

	for _, name in ipairs({ ... }) do
		if registry.Get(name) then
			continue
		end

		local definition = SchemaStore.GetDefinition(name)
		if not definition then
			FormatMessage.Warn(`"{name}" is not in the schema and cannot be warmed.`)
			continue
		end

		registry.Set(name, Converters.DefinitionToSound(definition), parent)
	end
end

--[=[
	@within Cache

	Chills sounds by name: their templates are destroyed. Sounds you already fetched are not affected. A name that
	is not warmed is ignored.

	```lua
	VluxySF.Cache.Chill("BossRoar", "BossStomp")
	```

	@param ... string -- The sound names.
]=]
function Cache.Chill(...: string)
	SchemaStore.AssertInitialized()
	SchemaStore.AssertClient()

	for _, name in ipairs({ ... }) do
		Templates.Warmed.Remove(name)
	end
end

return Cache
