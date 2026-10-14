--!strict
--!optimize 2

local Converters = require(script.Parent.Parent.Core.Converters)
local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local SchemaStore = require(script.Parent.Parent.Core.SchemaStore)
local Templates = require(script.Parent.Parent.Core.Templates)
local Types = require(script.Parent.Parent.Types)

type SoundDefinitionInstanced = Types.SoundDefinitionInstanced
type Preset = (Sound) -> ()

--Seconds OneShot gives an asset to load before it gives up and destroys the sound.
local ONE_SHOT_LOAD_TIMEOUT = 10

local blankDefinition: Types.SoundDefinition = table.freeze(Converters.NewBlankDefinition())

local Fetch = {}

------------------------------------------------------------------------------------------------------------------------

--[[
	Clones a warmed template when there is one, otherwise builds the sound from its definition. Returns nil when the
	name is not in the schema.
]]
local function resolve(name: string): Sound?
	local definition = SchemaStore.GetDefinition(name)
	if not definition then
		return nil
	end

	local sound = Templates.Clone(name)
	if sound then
		--templates have PlayOnRemove forced off so they stay silent in SoundService; the clone gets the real value back
		if definition.Properties.PlayOnRemove then
			sound.PlayOnRemove = true
		end

		return sound
	end

	return Converters.DefinitionToSound(definition)
end

--[[
	Returns the parent when it is usable, otherwise warns and returns nil so the sound goes where an unparented one
	would. Setting Parent to a non-Instance throws, and that must never reach game code.
]]
local function checkParent(parent: any, functionName: string): Instance?
	if parent == nil or typeof(parent) == "Instance" then
		return parent
	end

	FormatMessage.Warn(
		`{functionName} was given {typeof(parent)} as the parent instead of an Instance. It was ignored.`
	)

	return nil
end

--[[
	Returns the preset when it is a function, otherwise warns and returns nil so no preset is applied.
]]
local function checkPreset(preset: any, functionName: string): Preset?
	if preset == nil or type(preset) == "function" then
		return preset
	end

	FormatMessage.Warn(`{functionName} was given {typeof(preset)} as the preset instead of a function. It was ignored.`)

	return nil
end

local function setParent(sound: Sound, parent: Instance)
	sound.Parent = parent
end

--[[
	Parents the sound, warning and returning false when the parent refuses it (locked, destroyed or not allowed to
	hold a Sound) so the caller can fall back.
]]
local function tryParent(sound: Sound, parent: Instance, functionName: string): boolean
	local success, reason = pcall(setParent :: any, sound, parent)
	if success then
		return true
	end

	FormatMessage.Warn(`{functionName} could not parent "{sound.Name}" to "{parent:GetFullName()}": {reason}`)

	return false
end

--[[
	Applies the preset, then parents the sound. An explicit parent wins; otherwise a sound the preset left unparented
	goes to UnattachedSounds, as does one whose parent refused it.

	The preset is the developer's own code, so an error in it propagates to them; the half-built sound is destroyed
	first so nothing is left behind.
]]
local function place(sound: Sound, parent: Instance?, preset: Preset?, functionName: string)
	if preset then
		local success, reason = pcall(preset :: any, sound)
		if not success then
			sound:Destroy()
			error(reason, 0)
		end
	end

	if parent and tryParent(sound, parent, functionName) then
		return
	end

	--pcalled too: a preset that destroyed the sound leaves it with a locked Parent
	if sound.Parent == nil then
		tryParent(sound, SchemaStore.GetSchema().UnattachedSounds, functionName)
	end
end

local function blankSound(): Sound
	return Converters.DefinitionToSound(blankDefinition)
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within VluxySF

	@tag RequiresSchema

	Creates the `Sound` with that name. If the name is not in the schema, a warning is printed and a silent blank
	`Sound` named `VluxySF_Blank_Sound` is returned instead, so calling code never has to nil-check.

	:::info
	- A warmed sound (see `Cache`) is cloned from its template.
	- A sound fetched without a parent is placed in `SoundService.UnattachedSounds`. So is one whose parent refused
	it (a locked or destroyed Instance), with a warning. A parent that is not an Instance, or a preset that is not a
	function, is warned about and ignored.
	- Called before the library has started, it warns once and returns a blank `Sound` instead of erroring, so early
	game code keeps running. The blank is parented to `parent` when one was given and stays unparented otherwise;
	the preset is not applied to it.
	- An error thrown by the preset is yours and propagates; the sound it was applied to is destroyed first.
	:::

	```lua
	local mySound = VluxySF.Fetch("MySound")
	mySound.Volume = 0.3

	local echo = mySound:FindFirstChild("EchoSoundEffect")
	if echo then
		echo.WetLevel = 1.3
	end

	mySound:Play()
	```

	@param name string -- The name of the `Sound`.
	@param parent Instance? -- Parent of the `Sound`.
	@param preset ((Sound) -> ())? -- `Preset` to apply before parenting.

	@return Sound -- The new `Sound`.
]=]
function Fetch.Fetch(name: string, parent: Instance?, preset: ((Sound) -> ())?): SoundDefinitionInstanced
	local checkedParent = checkParent(parent, "Fetch")

	if not SchemaStore.CheckReady("Fetch") then
		local blank = blankSound()

		--there is no UnattachedSounds to fall back to yet, so a refused parent leaves the blank unparented
		if checkedParent then
			tryParent(blank, checkedParent, "Fetch")
		end

		return blank :: SoundDefinitionInstanced
	end

	local sound = resolve(name)
	if not sound then
		FormatMessage.Warn(`"{name}" is not in the schema. A blank sound was returned instead.`)
		sound = blankSound()
	end

	place(sound :: Sound, checkedParent, checkPreset(preset, "Fetch"), "Fetch")

	return sound :: SoundDefinitionInstanced
end

--[=[
	@within VluxySF

	@tag RequiresSchema

	The same as `Fetch`, but returns `nil` instead of a blank sound when the name is not in the schema, or when the
	library has not started yet. Use it for names built at runtime or sounds that may not exist.

	```lua
	local voiceLine = VluxySF.TryFetch(`VO_{npcName}`, head)

	if voiceLine then
		voiceLine:Play()
	end
	```

	@param name string -- The name of the `Sound`.
	@param parent Instance? -- Parent of the `Sound`.
	@param preset ((Sound) -> ())? -- `Preset` to apply before parenting.

	@return Sound? -- The new `Sound`, or `nil`.
]=]
function Fetch.TryFetch(name: string, parent: Instance?, preset: ((Sound) -> ())?): SoundDefinitionInstanced?
	if not SchemaStore.CheckReady("TryFetch") then
		return nil
	end

	local sound = resolve(name)
	if not sound then
		FormatMessage.Warn(`"{name}" is not in the schema.`)

		return nil
	end

	place(sound, checkParent(parent, "TryFetch"), checkPreset(preset, "TryFetch"), "TryFetch")

	return sound :: SoundDefinitionInstanced
end

--[=[
	@within VluxySF

	@tag RequiresSchema

	Plays a sound once and cleans it up: builds it, turns looping off, plays it and destroys it when it ends. Returns a
	function that stops and destroys it early.

	Nothing has to wait for the audio to load: Roblox holds a played sound until its audio arrives and starts it from
	the beginning. If the audio has not loaded within 10 seconds (deleted, moderated or private audio never does), a
	warning is printed and the sound is destroyed. With a name that is not in the schema, or before the library has
	started, a warning is printed and nothing plays. Destroying the parent while the sound plays is fine: the sound
	goes with it and nothing is reported.

	```lua
	VluxySF.OneShot("Hit", character.HumanoidRootPart)

	local stop = VluxySF.OneShot("Charge")
	-- later, if it has to end early:
	stop()
	```

	:::info
	`Sound.Played` fires and `IsPlaying` turns true as soon as the sound is played, before its audio has loaded. Code
	that needs the sound to be audible should wait for `Sound.Loaded`.
	:::

	@param name string -- The name of the `Sound`.
	@param parent Instance? -- Parent of the `Sound`.
	@param preset ((Sound) -> ())? -- `Preset` to apply before parenting.

	@return () -> () -- Stops and destroys the `Sound` early.
]=]
function Fetch.OneShot(name: string, parent: Instance?, preset: ((Sound) -> ())?): () -> ()
	if not SchemaStore.CheckReady("OneShot") then
		return function() end
	end

	local sound = Fetch.Fetch(name, parent, preset)
	sound.Looped = false

	--a sound with no asset never fires Ended or Loaded, so it would sit there forever
	if sound.SoundId == "" then
		sound:Destroy()

		return function() end
	end

	--a destroyed sound reads IsLoaded as false and Destroy drops the Ended connection, so the watchdog has to be told
	--when the sound is finished by any route: Ended, the stop function, or game code destroying it or an ancestor
	--(Destroying fires for both)
	local finished = false
	local watchdog: thread? = nil

	local function finish()
		finished = true

		if watchdog and coroutine.status(watchdog) == "suspended" then
			task.cancel(watchdog)
		end
	end

	sound.Destroying:Once(finish)

	sound.Ended:Once(function()
		finish()
		sound:Destroy()
	end)

	sound:Play()

	--an asset that never loads never fires Ended either, so without this the sound would stay forever
	watchdog = task.delay(ONE_SHOT_LOAD_TIMEOUT, function()
		if finished or sound.IsLoaded then
			return
		end

		FormatMessage.Warn(
			`"{name}" did not load within {ONE_SHOT_LOAD_TIMEOUT} seconds and was destroyed. Check that its asset is available.`
		)
		sound:Destroy()
	end)

	return function()
		finish()
		sound:Destroy()
	end
end

return Fetch
