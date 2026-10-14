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
local Startup = require(script.Parent.Startup)
local Types = require(script.Parent.Parent.Types)

type Preset = ((Sound) -> ())?

--[=[
	@type Wrapped<T> VluxySF
	@within VluxySF

	The library returned by `WithWrapper`. The same as `VluxySF`, except that `Fetch` and `TryFetch` return the
	wrapper instead of the `Sound`.
]=]
export type Wrapped<T> = {
	Fetch: (name: string, parent: Instance?, preset: Preset) -> T,
	TryFetch: (name: string, parent: Instance?, preset: Preset) -> T?,
	OneShot: typeof(Fetch.OneShot),

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

	Returns a copy of the library whose `Fetch` and `TryFetch` pass every fetched `Sound` through `wrap` and return
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
	- `Fetch` wraps the blank sound it returns for an unknown name. `TryFetch` returns `nil` without calling `wrap`.
	- `OneShot` is unchanged, since a one-shot cleans itself up.
	- If `wrap` errors, the fetched `Sound` is destroyed and the error is passed on, since it comes from your code.
	:::

	@param wrap (Sound) -> T -- Turns a fetched `Sound` into your wrapper.

	@return Wrapped<T> -- The library with wrapping fetch functions.
]=]
function Wrapping.WithWrapper<T>(wrap: (sound: Types.SoundDefinitionInstanced) -> T): Wrapped<T>
	if type(wrap) ~= "function" then
		FormatMessage.Error(`WithWrapper needs a function, got {typeof(wrap)}.`, 3)
	end

	local wrapped: Wrapped<T> = {
		Fetch = function(name: string, parent: Instance?, preset: Preset): T
			return wrapOrClean(wrap, Fetch.Fetch(name, parent, preset))
		end,

		TryFetch = function(name: string, parent: Instance?, preset: Preset): T?
			local sound = Fetch.TryFetch(name, parent, preset)
			if sound == nil then
				return nil
			end

			return wrapOrClean(wrap, sound)
		end,

		OneShot = Fetch.OneShot,

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
