--!strict

------------------------------------------------------------------------------------------------------------------------
--SCHEMA----------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[=[
	@interface SoundSchema
	@within Schema

	.SoundGroupContainer SoundGroup -- Main `SoundGroup` for all other `SoundGroups`.
	.SoundGroups SoundGroups -- Dictionary of `SoundGroups` under the Main `SoundGroup`.

	.UnattachedSounds Configuration -- `Configuration` for Un-Parented `Sounds`.
	.WarmedSounds Configuration -- `Configuration` for `Warmed` `Sounds`.
	.PreloadedSounds Configuration -- `Configuration` for `Preloaded` `Sounds`.

	.SoundDefinitions SoundDefinitions -- Dictionary of `SoundDefinitions`.
	
	.PreloadIds { string } -- List of sound names to `Preload`.

	The `Schema` for the library that is shared on client and server.
]=]
export type SoundSchema = {
	SoundGroupContainer: SoundGroup,
	SoundGroups: SoundGroups,

	PreloadedSounds: Configuration,
	WarmedSounds: Configuration,
	UnattachedSounds: Configuration,

	SoundDefinitions: SoundDefinitions,

	PreloadNames: { string },
}

------------------------------------------------------------------------------------------------------------------------
--INSTANCED-------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[=[
	@class InstancedTypes
	
	Types used for `Instances` in the `Schema` and `Conversions`.
]=]
------------------------------------------------------------------------------------------------------------------------

--[=[
	@type SoundGroups {[string]: SoundGroup}
	@within InstancedTypes

	Dictionary of `SoundGroups` from the `Schema`.
]=]
export type SoundGroups = Dictionary<SoundGroup>

------------------------------------------------------------------------------------------------------------------------

--[=[
	@type SoundDefinitionInstanced Sound & SoundChildrenInstanced
	@within InstancedTypes

	A `Sound` with `SoundEffects` parented.
]=]
export type SoundDefinitionInstanced = Sound & SoundChildrenInstanced

--[=[
	@interface SoundChildrenInstanced
	@within InstancedTypes
	
	.TremoloSoundEffect TremoloSoundEffect?
	.ReverbSoundEffect ReverbSoundEffect?
	.PitchShiftSoundEffect PitchShiftSoundEffect?
	.FlangeSoundEffect FlangeSoundEffect?
	.EqualizerSoundEffect EqualizerSoundEffect?
	.EchoSoundEffect EchoSoundEffect?
	.DistortionSoundEffect DistortionSoundEffect?
	.CompressorSoundEffect CompressorSoundEffect?
	.ChorusSoundEffect ChorusSoundEffect?
	
	All possible `SoundEffects` to find within a `Sound`.
]=]
export type SoundChildrenInstanced = {
	ChorusSoundEffect: ChorusSoundEffect?,
	CompressorSoundEffect: CompressorSoundEffect?,
	DistortionSoundEffect: DistortionSoundEffect?,
	EchoSoundEffect: EchoSoundEffect?,
	EqualizerSoundEffect: EqualizerSoundEffect?,
	FlangeSoundEffect: FlangeSoundEffect?,
	PitchShiftSoundEffect: PitchShiftSoundEffect?,
	ReverbSoundEffect: ReverbSoundEffect?,
	TremoloSoundEffect: TremoloSoundEffect?,
}

------------------------------------------------------------------------------------------------------------------------
--SERIALIZED------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[=[
	@class SerializedTypes
	
	Types used to `Serialize` sounds into the `Schema`.

	:::info
	- The library uses `ReflectionService` internally to apply and get properties so types may not be 100% accurate.
	- To save space and increase performance `SoundDefinitions` have default properties shaved off.
	- `SoundGroup` is applied directly on startup.
	:::
]=]
------------------------------------------------------------------------------------------------------------------------

--[=[
	@type SoundDefinitions {[string]: SoundDefinition}
	@within SerializedTypes

	A dictionary of sound names for fetching `SoundDefinitions`.
]=]
export type SoundDefinitions = Dictionary<SoundDefinition>

--[=[
	@interface SoundDefinition
	@within SerializedTypes

	.Properties SoundSerialized -- `Properties` of the sound.
	.Effects SoundChildrenSerialized -- Individual `SoundEffects` and their `Properties`.
	.EffectsCount number -- Amount of `SoundEffects` in the `SoundDefinition`.

	Fully Serialized `Sound`.
]=]
export type SoundDefinition = {
	Properties: SoundSerialized,
	Effects: SoundChildrenSerialized,
	EffectsCount: number,
}

------------------------------------------------------------------------------------------------------------------------

--[=[
	@interface SoundChildrenSerialized
	@within SerializedTypes

	.ChorusSoundEffect ChorusSoundEffectSerialized?
	.CompressorSoundEffect CompressorSoundEffectSerialized?
	.DistortionSoundEffect DistortionSoundEffectSerialized?
	.EchoSoundEffect EchoSoundEffectSerialized?
	.EqualizerSoundEffect EqualizerSoundEffectSerialized?
	.FlangeSoundEffect FlangeSoundEffectSerialized?
	.PitchShiftSoundEffect PitchShiftSoundEffectSerialized?
	.ReverbSoundEffect ReverbSoundEffectSerialized?
	.TremoloSoundEffect TremoloSoundEffectSerialized?

	Table of serialized `SoundEffects` for the `SoundDefinition`.
]=]
export type SoundChildrenSerialized = {
	ChorusSoundEffect: ChorusSoundEffectSerialized?,
	CompressorSoundEffect: CompressorSoundEffectSerialized?,
	DistortionSoundEffect: DistortionSoundEffectSerialized?,
	EchoSoundEffect: EchoSoundEffectSerialized?,
	EqualizerSoundEffect: EqualizerSoundEffectSerialized?,
	FlangeSoundEffect: FlangeSoundEffectSerialized?,
	PitchShiftSoundEffect: PitchShiftSoundEffectSerialized?,
	ReverbSoundEffect: ReverbSoundEffectSerialized?,
	TremoloSoundEffect: TremoloSoundEffectSerialized?,
}

------------------------------------------------------------------------------------------------------------------------

--[=[
	@interface SoundSerialized
	@within SerializedTypes

	.AcousticSimulationEnabled boolean
	.AudioContent string
	.EmitterSize number
	.IsLoaded boolean
	.IsPaused boolean
	.IsPlaying boolean
	.isPlaying boolean
	.Looped boolean
	.LoopRegion NumberRange
	.MaxDistance number
	.MinDistance number
	.Pitch number
	.PlaybackLoudness number
	.PlaybackRegion NumberRange
	.PlaybackRegionsEnabled boolean
	.PlaybackSpeed number
	.Playing boolean
	.PlayOnRemove boolean
	.RollOffMaxDistance number
	.RollOffMinDistance number
	.RollOffMode Enum.RollOffMode
	.SoundGroup string
	.SoundId string
	.TimeLength number
	.TimePosition number
	.Volume number

	.Archivable boolean
	.Name string
	.Parent Instance

	.ClassName string

	Serialized `Sound` Instance.
]=]
export type SoundSerialized = BaseInstance & SoundProperties

------------------------------------------------------------------------------------------------------------------------

--[=[
	@interface ChorusSoundEffectSerialized
	@within SerializedTypes

	.Depth number
	.Mix number
	.Rate number

	.Enabled boolean
	.Priority number

	.Archivable boolean
	.Name string
	.Parent Instance

	.ClassName string

	Serialized `ChorusSoundEffect` Instance.
]=]
export type ChorusSoundEffectSerialized = BaseEffect & ChorusSoundEffectProperties

--[=[
	@interface CompressorSoundEffectSerialized
	@within SerializedTypes

	.Attack number
	.GainMakeup number
	.Ratio number
	.Release number
	.Threshold number

	.Enabled boolean
	.Priority number

	.Archivable boolean
	.Name string
	.Parent Instance

	.ClassName string

	Serialized `CompressorSoundEffect` Instance.
]=]
export type CompressorSoundEffectSerialized = BaseEffect & CompressorSoundEffectProperties

--[=[
	@interface DistortionSoundEffectSerialized
	@within SerializedTypes

	.Level number

	.Enabled boolean
	.Priority number

	.Archivable boolean
	.Name string
	.Parent Instance

	.ClassName string

	Serialized `DistortionSoundEffect` Instance.
]=]
export type DistortionSoundEffectSerialized = BaseEffect & DistortionSoundEffectProperties

--[=[
	@interface EchoSoundEffectSerialized
	@within SerializedTypes

	.Delay number
	.Feedback number
	.WetLevel number
	.DryLevel number

	.Enabled boolean
	.Priority number

	.Archivable boolean
	.Name string
	.Parent Instance

	.ClassName string

	Serialized `EchoSoundEffect` Instance.
]=]
export type EchoSoundEffectSerialized = BaseEffect & EchoSoundEffectProperties

--[=[
	@interface EqualizerSoundEffectSerialized
	@within SerializedTypes

	.HighGain number
	.LowGain number
	.MidGain number

	.Enabled boolean
	.Priority number

	.Archivable boolean
	.Name string
	.Parent Instance

	.ClassName string

	Serialized `EqualizerSoundEffect` Instance.
]=]
export type EqualizerSoundEffectSerialized = BaseEffect & EqualizerSoundEffectProperties

--[=[
	@interface FlangeSoundEffectSerialized
	@within SerializedTypes

	.Depth number
	.Mix number
	.Rate number

	.Enabled boolean
	.Priority number

	.Archivable boolean
	.Name string
	.Parent Instance

	.ClassName string

	Serialized `FlangeSoundEffect` Instance.
]=]
export type FlangeSoundEffectSerialized = BaseEffect & FlangeSoundEffectProperties

--[=[
	@interface PitchShiftSoundEffectSerialized
	@within SerializedTypes

	.Octave number

	.Enabled boolean
	.Priority number

	.Archivable boolean
	.Name string
	.Parent Instance

	.ClassName string

	Serialized `PitchShiftSoundEffect` Instance.
]=]
export type PitchShiftSoundEffectSerialized = BaseEffect & PitchShiftSoundEffectProperties

--[=[
	@interface ReverbSoundEffectSerialized
	@within SerializedTypes

	.DecayTime number
	.Density number
	.Diffusion number
	.DryLevel number
	.WetLevel number

	.Enabled boolean
	.Priority number

	.Archivable boolean
	.Name string
	.Parent Instance

	.ClassName string

	Serialized `ReverbSoundEffect` Instance.
]=]
export type ReverbSoundEffectSerialized = BaseEffect & ReverbSoundEffectProperties

--[=[
	@interface TremoloSoundEffectSerialized
	@within SerializedTypes

	.Depth number
	.Duty number
	.Frequency number
	
	.Enabled boolean
	.Priority number

	.Archivable boolean
	.Name string
	.Parent Instance

	.ClassName string

	Serialized `TremoloSoundEffect` Instance.
]=]
export type TremoloSoundEffectSerialized = BaseEffect & TremoloSoundEffectProperties

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

type Dictionary<T> = { [string]: T }

type BaseInstance = ObjectProperties & InstanceProperties

type BaseEffect = BaseInstance & SoundEffectProperties

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

type SoundProperties = {
	AcousticSimulationEnabled: boolean,
	AudioContent: string,
	EmitterSize: number,
	IsLoaded: boolean,
	IsPaused: boolean,
	IsPlaying: boolean,
	isPlaying: boolean,
	Looped: boolean,
	LoopRegion: NumberRange,
	MaxDistance: number,
	MinDistance: number,
	Pitch: number,
	PlaybackLoudness: number,
	PlaybackRegion: NumberRange,
	PlaybackRegionsEnabled: boolean,
	PlaybackSpeed: number,
	Playing: boolean,
	PlayOnRemove: boolean,
	RollOffMaxDistance: number,
	RollOffMinDistance: number,
	RollOffMode: Enum.RollOffMode,
	SoundGroup: string,
	SoundId: string,
	TimeLength: number,
	TimePosition: number,
	Volume: number,
}

------------------------------------------------------------------------------------------------------------------------

type ChorusSoundEffectProperties = {
	Depth: number,
	Mix: number,
	Rate: number,
}

type CompressorSoundEffectProperties = {
	Attack: number,
	GainMakeup: number,
	Ratio: number,
	Release: number,
	Threshold: number,
}

type DistortionSoundEffectProperties = {
	Level: number,
}

type EchoSoundEffectProperties = {
	Delay: number,
	Feedback: number,
	WetLevel: number,
	DryLevel: number,
}

type EqualizerSoundEffectProperties = {
	HighGain: number,
	LowGain: number,
	MidGain: number,
}

type FlangeSoundEffectProperties = {
	Depth: number,
	Mix: number,
	Rate: number,
}

type PitchShiftSoundEffectProperties = {
	Octave: number,
}

type ReverbSoundEffectProperties = {
	DecayTime: number,
	Density: number,
	Diffusion: number,
	DryLevel: number,
	WetLevel: number,
}

type TremoloSoundEffectProperties = {
	Depth: number,
	Duty: number,
	Frequency: number,
}

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

type SoundEffectProperties = {
	Enabled: boolean,
	Priority: number,
}

type InstanceProperties = {
	Archivable: boolean,
	Name: string,
	Parent: Instance,
}

type ObjectProperties = {
	ClassName: string,
}

------------------------------------------------------------------------------------------------------------------------

return nil
