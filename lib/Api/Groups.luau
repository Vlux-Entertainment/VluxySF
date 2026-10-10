--!strict

local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local SchemaStore = require(script.Parent.Parent.Core.SchemaStore)
local Types = require(script.Parent.Parent.Types)

--[=[
	@class SoundGroups

	@tag RequiresSchema

	Reads and adjusts the `SoundGroups` the library made from your `SOUNDS` Configuration.

	Every group sits under one main `SoundGroup` named `SOUNDS` in `SoundService`, so the main volume scales all of
	them.
]=]
local Groups = {}

--[=[
	@within SoundGroups

	```lua
	print(VluxySF.Groups.Get())
	```

	@return SoundGroups -- Every `SoundGroup`, keyed by name.
]=]
function Groups.Get(): Types.SoundGroups
	SchemaStore.AssertInitialized()

	return SchemaStore.GetSchema().SoundGroups
end

--[=[
	@within SoundGroups

	```lua
	local music = VluxySF.Groups.GetByName("MUSIC")

	if music then
		music.Volume = 0.3
	end
	```

	@param name string -- The group name.

	@return SoundGroup? -- The `SoundGroup`, or `nil`.
]=]
function Groups.GetByName(name: string): SoundGroup?
	SchemaStore.AssertInitialized()

	return SchemaStore.GetSchema().SoundGroups[name]
end

--[=[
	@within SoundGroups

	```lua
	print(VluxySF.Groups.GetNames())
	```

	@return { string } -- A new array of every group name.
]=]
function Groups.GetNames(): { string }
	SchemaStore.AssertInitialized()

	local names: { string } = {}

	for name in pairs(SchemaStore.GetSchema().SoundGroups) do
		table.insert(names, name)
	end

	return names
end

--[=[
	@within SoundGroups

	Sets the volume of the main `SoundGroup` that every other group sits under.

	```lua
	VluxySF.Groups.SetMainVolume(0.3)
	```

	@param mainVolume number -- The volume.
]=]
function Groups.SetMainVolume(mainVolume: number)
	SchemaStore.AssertInitialized()

	SchemaStore.GetSchema().SoundGroupContainer.Volume = mainVolume
end

--[=[
	@within SoundGroups

	Sets several volumes at once. A group name that does not exist prints a warning and is skipped.

	```lua
	VluxySF.Groups.SetVolumes(1, {
		MUSIC = 0.7,
		SFX = 0.5,
	})

	VluxySF.Groups.SetVolumes(nil, { MUSIC = 0.2 }) -- Leaves the main volume alone.
	```

	@param mainVolume number? -- The main volume, or `nil` to leave it as it is.
	@param volumes { [string]: number } -- Group volumes, keyed by group name.
]=]
function Groups.SetVolumes(mainVolume: number?, volumes: { [string]: number })
	SchemaStore.AssertInitialized()

	local schema = SchemaStore.GetSchema()

	if mainVolume then
		schema.SoundGroupContainer.Volume = mainVolume
	end

	for groupName, volume in pairs(volumes) do
		local group = schema.SoundGroups[groupName]

		if not group then
			FormatMessage.Warn(`There is no SoundGroup named "{groupName}" to set the volume of.`)
			continue
		end

		group.Volume = volume
	end
end

return Groups
