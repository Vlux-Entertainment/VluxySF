--!strict
--!optimize 2

local Preloading = require(script.Parent.Parent.Core.Preloading)
local SchemaStore = require(script.Parent.Parent.Core.SchemaStore)
local Templates = require(script.Parent.Parent.Core.Templates)

--[=[
	@class Preload

	@tag RequiresSchema

	@client

	Preloading downloads a sound's audio ahead of time and keeps it loaded for the whole session, so the sound plays
	without a delay the first time it is needed.

	Sounds tagged `VluxySF_Preload` in Studio are preloaded by `Startup.InitClient`. Use `AddAsync` to preload more at
	runtime. This is about the network; to keep built `Sound` instances ready instead, see `Cache`.

	Called on the server or before the library has started, every function here warns once and does nothing.
]=]
local Preload = {}

--[=[
	@within Preload

	@yields

	Preloads more sounds by name and yields until their audio has loaded. A name that is already preloaded is skipped,
	and a name that is not in the schema prints a warning.

	```lua
	VluxySF.Preload.AddAsync("BossRoar", "BossStomp")
	```

	@param ... string -- The sound names.
]=]
function Preload.AddAsync(...: string)
	if not SchemaStore.CheckReady("Preload.AddAsync") or not SchemaStore.CheckClient("Preload.AddAsync") then
		return
	end

	local sounds = Preloading.Register({ ... }, false)
	Preloading.Load(sounds)
end

--[=[
	@within Preload

	```lua
	print(VluxySF.Preload.Has("BossRoar"))
	```

	@param name string -- The sound name.

	@return boolean -- Whether the sound is preloaded, or being preloaded.
]=]
function Preload.Has(name: string): boolean
	if not SchemaStore.CheckReady("Preload.Has") or not SchemaStore.CheckClient("Preload.Has") then
		return false
	end

	return Templates.Preloaded.Get(name) ~= nil
end

--[=[
	@within Preload

	```lua
	print(VluxySF.Preload.GetNames())
	```

	@return { string } -- A new array of every preloaded sound name, sorted.
]=]
function Preload.GetNames(): { string }
	if not SchemaStore.CheckReady("Preload.GetNames") or not SchemaStore.CheckClient("Preload.GetNames") then
		return {}
	end

	local names: { string } = {}
	for name in pairs(Templates.Preloaded.All()) do
		table.insert(names, name)
	end
	table.sort(names)

	return names
end

return Preload
