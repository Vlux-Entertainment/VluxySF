--!strict

------------------------------------------------------------------------------------------------------------------------
--SCHEMA----------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[=[
	@interface SoundSchema
	@within Schema

	.UnattachedSounds Configuration -- A folder for storing unattached sounds.
	.SoundGroupContainer Configuration -- A folder for storing sound groups.
	.SoundGroups SoundGroups -- A dictionary of sound group instances, organized by name.
	.SoundDefinitions SoundDefinitions -- A dictionary of sound definitions, organized by sound name.
	.DefinitionsGroupHash Dictionary<Dictionary<string>> -- Set of hashmaps for fast searching.
	.PreloadIds { string } -- A list of sound asset IDs to preload.

	Defines the overall schema for the sound system, containing all necessary data for sound creation and management.
]=]
export type SoundSchema = {
	UnattachedSounds: Configuration,
	SoundGroupContainer: Configuration,

	SoundGroups: SoundGroups,
	SoundDefinitions: SoundDefinitions,

	PreloadIds: { string },
}

------------------------------------------------------------------------------------------------------------------------
--INSTANCED-------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[=[
	@class InstancedTypes
	
	A base type for serialized instances and effects, containing common properties and structure for serialization.
]=]
------------------------------------------------------------------------------------------------------------------------

--[=[
	@type SoundGroups {[string]: SoundGroup}
	@within InstancedTypes

	Defines the type of a sound group instance.
]=]
export type SoundGroups = Dictionary<SoundGroup>

------------------------------------------------------------------------------------------------------------------------

--[=[
	@type SoundDefinitionInstanced Sound & SoundChildrenInstanced
	@within InstancedTypes

	Defines a sound group, which is a collection of sounds that can be managed together, allowing for collective volume control and organization.
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
	
	Defines the possible child sound effects that can be attached to a sound instance, allowing for enhanced audio manipulation and variation.
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
	
	Types for serialized instances and effects, containing common properties and structure for serialization.
]=]
------------------------------------------------------------------------------------------------------------------------

--[=[
	@type SoundDefinitions {[string]: SoundDefinition}
	@within SerializedTypes

	Defines the sound definitions of the system as a dictionary of sound names to their corresponding sound data.
]=]
export type SoundDefinitions = Dictionary<SoundDefinition>

--[=[
	@interface SoundDefinition
	@within SerializedTypes

	.Properties SoundSerialized -- The properties of the sound itself, such as SoundId, Volume, etc.
	.Effects SoundChildrenSerialized -- The sound effects of the sound, organized by class name.

	Defines the properties and sound effects of a sound.
]=]
export type SoundDefinition = {
	Properties: SoundSerialized,
	Effects: SoundChildrenSerialized,
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

	Defines the sound effects of a sound as a dictionary of class names to their corresponding properties.
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
	@type SoundSerialized {[string]: any}
	@within SerializedTypes

	Defines the properties of a sound as a dictionary of property names and values.
]=]
export type SoundSerialized = BaseInstance & SoundProperties

------------------------------------------------------------------------------------------------------------------------

--[=[
	@type ChorusSoundEffectSerialized {[string]: any}
	@within SerializedTypes

	Defines the properties of a ChorusSoundEffect as a dictionary of property names and values.
]=]
export type ChorusSoundEffectSerialized = BaseEffect & ChorusSoundEffectProperties

--[=[
	@type CompressorSoundEffectSerialized {[string]: any}
	@within SerializedTypes

	Defines the properties of a CompressorSoundEffect as a dictionary of property names and values.
]=]
export type CompressorSoundEffectSerialized = BaseEffect & CompressorSoundEffectProperties

--[=[
	@type DistortionSoundEffectSerialized {[string]: any}
	@within SerializedTypes
	
	Defines the properties of a DistortionSoundEffect as a dictionary of property names and values.
]=]
export type DistortionSoundEffectSerialized = BaseEffect & DistortionSoundEffectProperties

--[=[
	@type EchoSoundEffectSerialized {[string]: any}
	@within SerializedTypes

	Defines the properties of an EchoSoundEffect as a dictionary of property names and values.
]=]
export type EchoSoundEffectSerialized = BaseEffect & EchoSoundEffectProperties

--[=[
	@type EqualizerSoundEffectSerialized {[string]: any}
	@within SerializedTypes

	Defines the properties of an EqualizerSoundEffect as a dictionary of property names and values.
]=]
export type EqualizerSoundEffectSerialized = BaseEffect & EqualizerSoundEffectProperties

--[=[
	@type FlangeSoundEffectSerialized {[string]: any}
	@within SerializedTypes

	Defines the properties of a FlangeSoundEffect as a dictionary of property names and values.
]=]
export type FlangeSoundEffectSerialized = BaseEffect & FlangeSoundEffectProperties

--[=[
	@type PitchShiftSoundEffectSerialized {[string]: any}
	@within SerializedTypes

	Defines the properties of a PitchShiftSoundEffect as a dictionary of property names and values.
]=]
export type PitchShiftSoundEffectSerialized = BaseEffect & PitchShiftSoundEffectProperties

--[=[
	@type ReverbSoundEffectSerialized {[string]: any}
	@within SerializedTypes

	Defines the properties of a ReverbSoundEffect as a dictionary of property names and values.
]=]
export type ReverbSoundEffectSerialized = BaseEffect & ReverbSoundEffectProperties

--[=[
	@type TremoloSoundEffectSerialized {[string]: any}
	@within SerializedTypes

	Defines the properties of a TremoloSoundEffect as a dictionary of property names and values.
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
	Priority: number,
}

type CompressorSoundEffectProperties = {
	Attack: number,
	GainMakeup: number,
	Ratio: number,
	Release: number,
	Threshold: number,
	Priority: number,
}

type DistortionSoundEffectProperties = {
	Level: number,
	Priority: number,
}

type EchoSoundEffectProperties = {
	Delay: number,
	Feedback: number,
	WetLevel: number,
	DryLevel: number,
	Priority: number,
}

type EqualizerSoundEffectProperties = {
	HighGain: number,
	LowGain: number,
	MidGain: number,
	Priority: number,
}

type FlangeSoundEffectProperties = {
	Depth: number,
	Mix: number,
	Rate: number,
	Priority: number,
}

type PitchShiftSoundEffectProperties = {
	Octave: number,
	Priority: number,
}

type ReverbSoundEffectProperties = {
	DecayTime: number,
	Density: number,
	Diffusion: number,
	DryLevel: number,
	WetLevel: number,
	Priority: number,
}

type TremoloSoundEffectProperties = {
	Depth: number,
	Duty: number,
	Frequency: number,
	Priority: number,
}

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

type SoundEffectProperties = {
	Enabled: boolean,
	Priority: number,
}

type InstanceProperties = {
	Archivable: boolean,
	archivable: boolean,
	Capabilities: SecurityCapabilities,
	Name: string,
	Parent: Instance,
	PredictionMode: Enum.PredictionMode,
	RobloxLocked: boolean,
	Sandboxed: boolean,
}

type ObjectProperties = {
	ClassName: string,
}

------------------------------------------------------------------------------------------------------------------------

return nil
