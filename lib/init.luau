--!strict
--!optimize 2

local api = script.Api

local Cache = require(api.Cache)
local Conversions = require(api.Conversions)
local Fetch = require(api.Fetch)
local Groups = require(api.Groups)
local Jitter = require(api.Jitter)
local Preload = require(api.Preload)
local Presets = require(api.Presets)
local Schema = require(api.Schema)
local Startup = require(api.Startup)
local Wrapping = require(api.Wrapping)

local Types = require(script.Types)

------------------------------------------------------------------------------------------------------------------------
--TYPES-----------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--Kept for code that annotated sound names with it. Sound names are plain strings.
export type GeneratedSoundNames = string

export type SoundSchema = Types.SoundSchema

export type SoundGroups = Types.SoundGroups

export type SoundDefinitionInstanced = Types.SoundDefinitionInstanced
export type SoundChildrenInstanced = Types.SoundChildrenInstanced

export type SoundDefinitions = Types.SoundDefinitions
export type SoundDefinition = Types.SoundDefinition

export type SoundChildrenSerialized = Types.SoundChildrenSerialized
export type SoundSerialized = Types.SoundSerialized

export type ChorusSoundEffectSerialized = Types.ChorusSoundEffectSerialized
export type CompressorSoundEffectSerialized = Types.CompressorSoundEffectSerialized
export type DistortionSoundEffectSerialized = Types.DistortionSoundEffectSerialized
export type EchoSoundEffectSerialized = Types.EchoSoundEffectSerialized
export type EqualizerSoundEffectSerialized = Types.EqualizerSoundEffectSerialized
export type FlangeSoundEffectSerialized = Types.FlangeSoundEffectSerialized
export type PitchShiftSoundEffectSerialized = Types.PitchShiftSoundEffectSerialized
export type ReverbSoundEffectSerialized = Types.ReverbSoundEffectSerialized
export type TremoloSoundEffectSerialized = Types.TremoloSoundEffectSerialized

export type Wrapped<T> = Wrapping.Wrapped<T>

------------------------------------------------------------------------------------------------------------------------
--LIBRARY---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[=[
	@class VluxySF

	@client
	@server

	Vluxy Sound Factory. Build your sounds in Studio once, then fetch any of them by name from the server or the
	client.

	```lua
	local sound = VluxySF.Fetch("MySound")
	sound:Play()
	```
]=]
local VluxySF = {
	Fetch = Fetch.Fetch,
	FetchStrict = Fetch.FetchStrict,
	FetchPlayOnce = Fetch.FetchPlayOnce,
	WithWrapper = Wrapping.WithWrapper,

	Startup = Startup,
	Schema = Schema,
	Groups = Groups,

	Preload = Preload,
	Cache = Cache,

	Conversions = Conversions,
	Presets = Presets,
	Jitter = Jitter,
}

export type VluxySF = typeof(VluxySF)

return table.freeze(VluxySF)
