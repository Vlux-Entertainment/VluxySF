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

	Warming a sound builds it once and keeps the ready-made `Sound`, effects included, in `SoundService.WarmedSounds`.
	While it is warmed, `Fetch` clones it instead of building it. Chilling it destroys the kept copy. Use this for
	sounds that matter during one part of the game, and chill them when that part is over.

	Keeping the `Sound` also makes Roblox start downloading its audio, but warming does not wait for that; to have
	audio loaded before it is needed, see `Preload`. The kept copy is silent: it never plays, and `PlayOnRemove` is off
	on it and restored on the clones `Fetch` hands out.

	Called on the server or before the library has started, every function here warns once and does nothing.
]=]
local Cache = {}

--[=[
	@within Cache

	Warms sounds by name. A name that is already warmed is skipped. A name that is not in the schema prints a warning.

	```lua
	VluxySF.Cache.Warm("BossRoar", "BossStomp")
	```

	@param ... string -- The sound names.
]=]
function Cache.Warm(...: string)
	if not SchemaStore.CheckReady("Cache.Warm") or not SchemaStore.CheckClient("Cache.Warm") then
		return
	end

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

	Chills sounds by name: their kept copies are destroyed. Sounds you already fetched are not affected. A name that is
	not warmed is ignored.

	```lua
	VluxySF.Cache.Chill("BossRoar", "BossStomp")
	```

	@param ... string -- The sound names.
]=]
function Cache.Chill(...: string)
	if not SchemaStore.CheckReady("Cache.Chill") or not SchemaStore.CheckClient("Cache.Chill") then
		return
	end

	for _, name in ipairs({ ... }) do
		Templates.Warmed.Remove(name)
	end
end

--[=[
	@within Cache

	```lua
	print(VluxySF.Cache.IsWarmed("BossRoar"))
	```

	@param name string -- The sound name.

	@return boolean -- Whether the sound is warmed.
]=]
function Cache.IsWarmed(name: string): boolean
	if not SchemaStore.CheckReady("Cache.IsWarmed") or not SchemaStore.CheckClient("Cache.IsWarmed") then
		return false
	end

	return Templates.Warmed.Get(name) ~= nil
end

--[=[
	@within Cache

	```lua
	print(VluxySF.Cache.GetNames())
	```

	@return { string } -- A new array of every warmed sound name, sorted.
]=]
function Cache.GetNames(): { string }
	if not SchemaStore.CheckReady("Cache.GetNames") or not SchemaStore.CheckClient("Cache.GetNames") then
		return {}
	end

	local names: { string } = {}
	for name in pairs(Templates.Warmed.All()) do
		table.insert(names, name)
	end
	table.sort(names)

	return names
end

return Cache
