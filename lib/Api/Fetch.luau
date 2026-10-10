--!strict
--!optimize 2

local Converters = require(script.Parent.Parent.Core.Converters)
local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local SchemaStore = require(script.Parent.Parent.Core.SchemaStore)
local Templates = require(script.Parent.Parent.Core.Templates)
local Types = require(script.Parent.Parent.Types)

type SoundDefinitionInstanced = Types.SoundDefinitionInstanced

local BLANK_SOUND_NAME = "VluxySF_Blank_Sound"

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
	Clones a preloaded or warmed template when there is one, otherwise builds the sound from its definition.
	Returns nil when the name is not in the schema.
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

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within VluxySF

	@tag RequiresSchema

	Creates the `Sound` with that name. If the name is not in the schema, a warning is printed and a blank `Sound`
	named `VluxySF_Blank_Sound` is returned instead, so calling code never has to nil-check.

	:::info
	- A preloaded or warmed sound is cloned from its template, which is faster than building it.
	- A sound fetched without a parent is placed in `SoundService.UnattachedSounds`.
	:::

	```lua
	local mySound = VluxySF.Fetch("MySound")
	mySound.Volume = 0.3

	local echo = mySound.EchoSoundEffect
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
	SchemaStore.AssertInitialized()

	local sound = resolve(name)
	if not sound then
		FormatMessage.Warn(`"{name}" is not in the schema. A blank sound was returned instead.`)
		sound = Converters.DefinitionToSound(blankDefinition)
	end

	place(sound :: Sound, parent, preset)

	return sound :: SoundDefinitionInstanced
end

--[=[
	@within VluxySF

	@tag RequiresSchema

	The same as `Fetch`, but returns `nil` instead of a blank sound when the name is not in the schema.

	```lua
	local mySound = VluxySF.FetchStrict("MySound")

	if mySound then
		mySound:Play()
	end
	```

	@param name string -- The name of the `Sound`.
	@param parent Instance? -- Parent of the `Sound`.
	@param preset ((Sound) -> ())? -- `Preset` to apply before parenting.

	@return Sound? -- The new `Sound`, or `nil`.
]=]
function Fetch.FetchStrict(name: string, parent: Instance?, preset: ((Sound) -> ())?): SoundDefinitionInstanced?
	SchemaStore.AssertInitialized()

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

	Fetches a `Sound`, plays it once, and destroys it when it ends. Looping is turned off.

	```lua
	VluxySF.FetchPlayOnce("MySound")
	```

	@param name string -- The name of the `Sound`.
	@param parent Instance? -- Parent of the `Sound`.
	@param preset ((Sound) -> ())? -- `Preset` to apply before parenting.
	@param waitOnLoad boolean? -- Wait for the `Sound` to load before playing. The wait never blocks the caller.

	@return () -> () -- Stops and destroys the `Sound` early.
]=]
function Fetch.FetchPlayOnce(name: string, parent: Instance?, preset: ((Sound) -> ())?, waitOnLoad: boolean?): () -> ()
	SchemaStore.AssertInitialized()

	local sound = Fetch.Fetch(name, parent, preset)
	sound.Looped = false

	--a sound with no asset never fires Ended or Loaded, so it would sit there forever
	if sound.SoundId == "" then
		sound:Destroy()

		return function() end
	end

	local playThread = task.spawn(function()
		if waitOnLoad and not sound.IsLoaded then
			sound.Loaded:Wait()
		end

		sound.Ended:Once(function()
			sound:Destroy()
		end)

		sound:Play()
	end)

	return function()
		if coroutine.status(playThread) == "suspended" then
			task.cancel(playThread)
		end

		sound:Destroy()
	end
end

return Fetch
