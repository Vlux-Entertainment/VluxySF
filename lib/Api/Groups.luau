--!strict
--!optimize 2

local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local SchemaStore = require(script.Parent.Parent.Core.SchemaStore)
local Types = require(script.Parent.Parent.Types)

--Roblox caps SoundGroup.Volume here.
local MAX_VOLUME = 10

--[=[
	@class Groups

	@tag RequiresSchema

	Reads and adjusts the `SoundGroups` the library made from your `SOUNDS` Configuration.

	Every group sits under one main `SoundGroup` named `SOUNDS` in `SoundService`, so the main volume scales all of
	them.

	:::info
	The groups are made on the server and replicate. Setting a volume on a client changes it for that player only,
	which is what a settings menu wants. Setting it on the server changes it for every player.
	:::

	Called before the library has started, every function here warns once and returns an empty result or does nothing.
	A volume that is not a number from 0 to 10 prints a warning and is ignored.
]=]
local Groups = {}

local emptyGroups: Types.SoundGroups = table.freeze({})

--[[
	Returns the volume when it can be set, otherwise warns and returns nil.
]]
local function checkVolume(volume: any, target: string): number?
	if type(volume) ~= "number" or volume ~= volume then
		FormatMessage.Warn(`The volume for {target} has to be a number, got {tostring(volume)}. It was not changed.`)

		return nil
	end

	if volume < 0 or volume > MAX_VOLUME then
		FormatMessage.Warn(
			`The volume for {target} has to be from 0 to {MAX_VOLUME}, got {volume}. It was not changed.`
		)

		return nil
	end

	return volume
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within Groups

	```lua
	local music = VluxySF.Groups.Get("MUSIC")

	if music then
		print(music.Volume)
	end
	```

	@param name string -- The group name.

	@return SoundGroup? -- The `SoundGroup`, or `nil`.
]=]
function Groups.Get(name: string): SoundGroup?
	if not SchemaStore.CheckReady("Groups.Get") then
		return nil
	end

	return SchemaStore.GetSchema().SoundGroups[name]
end

--[=[
	@within Groups

	```lua
	for name, group in VluxySF.Groups.GetAll() do
		print(name, group.Volume)
	end
	```

	@return SoundGroups -- Every `SoundGroup`, keyed by name. Empty before the library has started.
]=]
function Groups.GetAll(): Types.SoundGroups
	if not SchemaStore.CheckReady("Groups.GetAll") then
		return emptyGroups
	end

	return SchemaStore.GetSchema().SoundGroups
end

--[=[
	@within Groups

	```lua
	print(VluxySF.Groups.GetMain())
	```

	@return SoundGroup? -- The main `SoundGroup` every group sits under, or `nil` before the library has started.
]=]
function Groups.GetMain(): SoundGroup?
	if not SchemaStore.CheckReady("Groups.GetMain") then
		return nil
	end

	return SchemaStore.GetSchema().SoundGroupContainer
end

--[=[
	@within Groups

	```lua
	print(VluxySF.Groups.GetNames())
	```

	@return { string } -- A new array of every group name, in the order the groups appear under `SOUNDS`.
]=]
function Groups.GetNames(): { string }
	if not SchemaStore.CheckReady("Groups.GetNames") then
		return {}
	end

	return SchemaStore.GetGroupNames()
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within Groups

	Sets the volume of one group. A group name that does not exist prints a warning.

	```lua
	VluxySF.Groups.SetVolume("MUSIC", 0.4)
	```

	@param name string -- The group name.
	@param volume number -- The volume, from 0 to 10.
]=]
function Groups.SetVolume(name: string, volume: number)
	if not SchemaStore.CheckReady("Groups.SetVolume") then
		return
	end

	local group = SchemaStore.GetSchema().SoundGroups[name]
	if not group then
		FormatMessage.Warn(`There is no SoundGroup named "{name}" to set the volume of.`)

		return
	end

	local checked = checkVolume(volume, `"{name}"`)
	if checked then
		group.Volume = checked
	end
end

--[=[
	@within Groups

	Sets several group volumes at once. A group name that does not exist prints a warning and is skipped.

	```lua
	VluxySF.Groups.SetVolumes({
		MUSIC = 0.7,
		SFX = 0.5,
	})
	```

	@param volumes { [string]: number } -- Group volumes, keyed by group name.
]=]
function Groups.SetVolumes(volumes: { [string]: number })
	if not SchemaStore.CheckReady("Groups.SetVolumes") then
		return
	end

	if type(volumes) ~= "table" then
		FormatMessage.Warn(`Groups.SetVolumes needs a table of volumes, got {typeof(volumes)}.`)

		return
	end

	for name, volume in pairs(volumes) do
		Groups.SetVolume(name, volume)
	end
end

--[=[
	@within Groups

	Sets the volume of the main `SoundGroup` that every other group sits under.

	```lua
	VluxySF.Groups.SetMainVolume(0.3)
	```

	@param volume number -- The volume, from 0 to 10.
]=]
function Groups.SetMainVolume(volume: number)
	if not SchemaStore.CheckReady("Groups.SetMainVolume") then
		return
	end

	local checked = checkVolume(volume, "the main SoundGroup")
	if checked then
		SchemaStore.GetSchema().SoundGroupContainer.Volume = checked
	end
end

--[=[
	@within Groups

	Returns every group volume, keyed by group name. Pairs with `SetVolumes` for saving and loading settings.

	```lua
	local saved = VluxySF.Groups.GetVolumes()
	-- later:
	VluxySF.Groups.SetVolumes(saved)
	```

	@return { [string]: number } -- Group volumes, keyed by group name. Empty before the library has started.
]=]
function Groups.GetVolumes(): { [string]: number }
	if not SchemaStore.CheckReady("Groups.GetVolumes") then
		return {}
	end

	local volumes: { [string]: number } = {}

	for name, group in pairs(SchemaStore.GetSchema().SoundGroups) do
		volumes[name] = group.Volume
	end

	return volumes
end

--[=[
	@within Groups

	```lua
	print(VluxySF.Groups.GetMainVolume())
	```

	@return number -- The main volume. `1` before the library has started.
]=]
function Groups.GetMainVolume(): number
	if not SchemaStore.CheckReady("Groups.GetMainVolume") then
		return 1
	end

	return SchemaStore.GetSchema().SoundGroupContainer.Volume
end

return Groups
