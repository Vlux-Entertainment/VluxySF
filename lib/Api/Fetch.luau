--!strict
--!optimize 2

local Converters = require(script.Parent.Parent.Core.Converters)
local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local SchemaStore = require(script.Parent.Parent.Core.SchemaStore)
local Templates = require(script.Parent.Parent.Core.Templates)
local Types = require(script.Parent.Parent.Types)

type SoundDefinitionInstanced = Types.SoundDefinitionInstanced

local BLANK_SOUND_NAME = "VluxySF_Blank_Sound"

--Seconds OneShot gives an asset to load before it gives up and destroys the sound.
local ONE_SHOT_LOAD_TIMEOUT = 10

local blankDefinition: Types.SoundDefinition = table.freeze({
	Properties = table.freeze({
		Name = BLANK_SOUND_NAME,
	}) :: any,
	Effects = table.freeze({}) :: any,
	EffectsCount = 0,
})

local Fetch = {}

------------------------------------------------------------------------------------------------------------------------

--[[
	Clones a warmed template when there is one, otherwise builds the sound from its definition. Returns nil when the
	name is not in the schema.
]]
local function resolve(name: string): Sound?
	local sound = Templates.Clone(name)
	if sound then
		return sound
	end

	local definition = SchemaStore.GetDefinition(name)
	if not definition then
		return nil
	end

	return Converters.DefinitionToSound(definition)
end

--[[
	Applies the preset, then parents the sound. An explicit parent wins; otherwise a sound the preset left unparented
	goes to UnattachedSounds.
]]
local function place(sound: Sound, parent: Instance?, preset: ((Sound) -> ())?)
	if preset then
		preset(sound)
	end

	if parent then
		sound.Parent = parent
	elseif sound.Parent == nil then
		sound.Parent = SchemaStore.GetSchema().UnattachedSounds
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
	- A sound fetched without a parent is placed in `SoundService.UnattachedSounds`.
	- Called before the library has started, it warns once and returns an unparented blank `Sound` instead of
	erroring, so early game code keeps running.
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
	if not SchemaStore.CheckReady("Fetch") then
		local blank = blankSound()
		blank.Parent = parent

		return blank :: SoundDefinitionInstanced
	end

	local sound = resolve(name)
	if not sound then
		FormatMessage.Warn(`"{name}" is not in the schema. A blank sound was returned instead.`)
		sound = blankSound()
	end

	place(sound :: Sound, parent, preset)

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

	place(sound, parent, preset)

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
	started, a warning is printed and nothing plays.

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

	--a destroyed sound reads IsLoaded as false, so the watchdog needs to know the sound already finished
	local ended = false

	sound.Ended:Once(function()
		ended = true
		sound:Destroy()
	end)

	sound:Play()

	--an asset that never loads never fires Ended either, so without this the sound would stay forever
	local watchdog = task.delay(ONE_SHOT_LOAD_TIMEOUT, function()
		if ended or sound.IsLoaded then
			return
		end

		FormatMessage.Warn(
			`"{name}" did not load within {ONE_SHOT_LOAD_TIMEOUT} seconds and was destroyed. Check that its asset is available.`
		)
		sound:Destroy()
	end)

	return function()
		if coroutine.status(watchdog) == "suspended" then
			task.cancel(watchdog)
		end

		sound:Destroy()
	end
end

return Fetch
