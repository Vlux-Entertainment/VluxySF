--!strict
--!optimize 2

local Cache = require(script.Parent.Cache)
local Conversions = require(script.Parent.Conversions)
local Fetch = require(script.Parent.Fetch)
local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local Groups = require(script.Parent.Groups)
local Jitter = require(script.Parent.Jitter)
local Preload = require(script.Parent.Preload)
local Presets = require(script.Parent.Presets)
local Schema = require(script.Parent.Schema)
local SchemaStore = require(script.Parent.Parent.Core.SchemaStore)
local Startup = require(script.Parent.Startup)
local Types = require(script.Parent.Parent.Types)

type Preset = ((Sound) -> ())?

--[=[
	@type Wrapped<T> VluxySF
	@within VluxySF

	The library returned by `WithWrapper`. The same as `VluxySF`, except that `Fetch` and `FetchStrict` return the
	wrapper instead of the `Sound`.
]=]
export type Wrapped<T> = {
	Fetch: (name: string, parent: Instance?, preset: Preset) -> T,
	FetchStrict: (name: string, parent: Instance?, preset: Preset) -> T?,
	FetchPlayOnce: typeof(Fetch.FetchPlayOnce),

	Startup: typeof(Startup),
	Schema: typeof(Schema),
	Groups: typeof(Groups),

	Preload: typeof(Preload),
	Cache: typeof(Cache),

	Conversions: typeof(Conversions),
	Presets: typeof(Presets),
	Jitter: typeof(Jitter),
}

local Wrapping = {}

--[[
	Wraps the sound. If the wrapper errors, the sound is destroyed so it does not stay in UnattachedSounds forever,
	and the error is raised again for the caller to see.
]]
local function wrapOrClean<T>(wrap: (sound: Types.SoundDefinitionInstanced) -> T, sound: Types.SoundDefinitionInstanced): T
	local success, result = pcall(wrap, sound)
	if not success then
		sound:Destroy()
		error(result, 0)
	end

	return result
end

--[=[
	@within VluxySF

	Returns a copy of the library whose `Fetch` and `FetchStrict` pass every fetched `Sound` through `wrap` and return
	what it returns. Use it to get your own sound class, with methods like fades, out of every fetch.

	The copy is fully typed: whatever type `wrap` returns is what `Fetch` returns. `VluxySF` itself is not changed, so
	other scripts and packages that require it still get plain `Sound`s.

	:::tip
	Call this once in a module of your own and require that module everywhere. The Wrapping Sounds guide shows the
	setup.
	:::

	```lua
	local Sounds = VluxySF.WithWrapper(function(sound)
		return MySoundClass.new(sound)
	end)

	Sounds.Fetch("MySound"):FadeIn(1)
	```

	:::info
	- Presets still receive the `Sound` before it is wrapped.
	- `Fetch` wraps the blank sound it returns for an unknown name. `FetchStrict` returns `nil` without calling `wrap`.
	- `FetchPlayOnce` is unchanged, since it returns a cleanup function, not a sound.
	:::

	@param wrap (Sound) -> T -- Turns a fetched `Sound` into your wrapper.

	@return Wrapped<T> -- The library with wrapping fetch functions.
]=]
function Wrapping.WithWrapper<T>(wrap: (sound: Types.SoundDefinitionInstanced) -> T): Wrapped<T>
	if type(wrap) ~= "function" then
		FormatMessage.Error(`WithWrapper needs a function, got {typeof(wrap)}.`, 3)
	end

	local wrapped: Wrapped<T> = {
		--each one asserts first so an early call errors at the caller, not in here
		Fetch = function(name: string, parent: Instance?, preset: Preset): T
			SchemaStore.AssertInitialized()

			return wrapOrClean(wrap, Fetch.Fetch(name, parent, preset))
		end,

		FetchStrict = function(name: string, parent: Instance?, preset: Preset): T?
			SchemaStore.AssertInitialized()

			local sound = Fetch.FetchStrict(name, parent, preset)
			if sound == nil then
				return nil
			end

			return wrapOrClean(wrap, sound)
		end,

		FetchPlayOnce = Fetch.FetchPlayOnce,

		Startup = Startup,
		Schema = Schema,
		Groups = Groups,

		Preload = Preload,
		Cache = Cache,

		Conversions = Conversions,
		Presets = Presets,
		Jitter = Jitter,
	}

	return table.freeze(wrapped)
end

return Wrapping
