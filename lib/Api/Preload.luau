--!strict
--!optimize 2

local Preloading = require(script.Parent.Parent.Core.Preloading)
local SchemaStore = require(script.Parent.Parent.Core.SchemaStore)
local Templates = require(script.Parent.Parent.Core.Templates)

--[=[
	@class Preload

	@tag RequiresSchema

	@client

	Preloaded sounds are built once, kept in `SoundService.PreloadedSounds` for the whole session, and loaded by
	`ContentProvider`. `Fetch` clones them instead of building them, so they play without a delay.

	Sounds tagged `VluxySF_Preload` in Studio are preloaded by `Startup.InitClient`. Use `Selected` to preload more at
	runtime.
]=]
local Preload = {}

--[=[
	@within Preload

	```lua
	print(VluxySF.Preload.Get())
	```

	@return { [string]: Sound } -- Every preloaded template, keyed by name. Do not modify it.
]=]
function Preload.Get(): { [string]: Sound }
	SchemaStore.AssertInitialized()
	SchemaStore.AssertClient()

	return Templates.Preloaded.All()
end

--[=[
	@within Preload

	@yields

	Preloads more sounds by name. Yields until they are loaded. A name that is already preloaded prints a warning.

	```lua
	VluxySF.Preload.Selected("Footstep", "Jump")
	```

	@param ... string -- The sound names.
]=]
function Preload.Selected(...: string)
	SchemaStore.AssertInitialized()
	SchemaStore.AssertClient()

	local sounds = Preloading.Register({ ... }, true)
	Preloading.Load(sounds)
end

return Preload
