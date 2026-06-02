--!strict
--!optimize 2

local libarary = script.Parent.Parent

local FormatMessage = require(libarary.Utility.FormatMessage)
local Properties = require(libarary.Utility.Properties)

local Types = require(libarary.Types)

local ALLOWED_SOUND_CHILDREN = {
	ChorusSoundEffect = true,
	CompressorSoundEffect = true,
	DistortionSoundEffect = true,
	EchoSoundEffect = true,
	EqualizerSoundEffect = true,
	FlangeSoundEffect = true,
	PitchShiftSoundEffect = true,
	ReverbSoundEffect = true,
	TremoloSoundEffect = true,
}

local function fastSetProperties(instance: Instance, properties: { [string]: any })
	local soundInst = instance :: any --fix type error

	for property, value in pairs(properties) do
		soundInst[property] = value
	end
end

--[[
    Module responsible for converting Sound instances to SoundDefinitions and vice versa.
]]
local Converters = {}

------------------------------------------------------------------------------------------------------------------------

--[[
    @param sound Sound -- The Sound instance to convert.

    @return SoundDefinition -- The created Definition

	Converts a Sound instance to a SoundDefinition.
]]
function Converters.SoundToDefinition(sound: Sound, soundGroup: SoundGroup?): Types.SoundDefinition
	local definition = {
		Properties = {},
		Effects = {},
		EffectsCount = 0,
	} :: Types.SoundDefinition

	--[[
		properties
	]]
	local properties: { [string]: any } = Properties.InstanceToProperties(sound)

	Properties.RemoveDefaultProperties(properties)
	properties.AudioContent = nil
	properties.Parent = nil

	if soundGroup then
		properties.SoundGroup = soundGroup
	end

	definition.Properties = properties

	--[[
		effects
	]]
	local effects: { Instance } = sound:GetChildren()
	local childEffectCount: number = #effects

	if childEffectCount == 0 then
		return definition
	end

	local effectsHash: { [string]: boolean } = {}
	local effectsDefinition = definition.Effects :: { [string]: { [string]: any } }

	for _, effect in ipairs(effects) do
		local effectClassName: string = effect.ClassName

		--check for allowed children
		if not ALLOWED_SOUND_CHILDREN[effectClassName] then
			FormatMessage.Warn(`Invalid child Instance found in "{sound.Name}, Location: {effect:GetFullName()}"`)
			continue
		end

		--check for repeats
		if effectsHash[effectClassName] then
			FormatMessage.Warn(
				`Sound has more than one SoundEffect of the same Class! Location: {effect:GetFullName()}`
			)
			continue
		end
		effectsHash[effectClassName] = true

		--check for any sub children
		if effect:FindFirstChildWhichIsA("Instance") then
			FormatMessage.Warn(`Child Instances of a Sound cannot have children! Location: {effect:GetFullName()}`)
		end

		--set effect
		local effectProperties: { [string]: any } = Properties.InstanceToProperties(effect)
		Properties.RemoveDefaultProperties(effectProperties)

		effectsDefinition[effectClassName] = effectProperties

		definition.EffectsCount += 1
	end

	return definition
end

--[[
    @param SoundDefinition -- The SoundDefinition to convert.

    @return Sound -- The created Sound

	Converts a SoundDefinition to a Sound instance.
]]
function Converters.DefinitionToSound(definition: Types.SoundDefinition): Types.SoundDefinitionInstanced
	local sound = Instance.new("Sound")
	sound:AddTag("_VLUXY_SOUND_FACTORY_INSTANCE") --lets the system know what sound was created by VluxySF

	--properties
	pcall(fastSetProperties, sound, definition.Properties)

	if definition.EffectsCount == 0 then
		return sound :: Types.SoundDefinitionInstanced
	end

	for effectName, effectProperties in pairs(definition.Effects) do
		local effect = Instance.new(effectName)

		pcall(fastSetProperties, effect, effectProperties)

		effect.Parent = sound
	end

	return sound :: Types.SoundDefinitionInstanced
end

return Converters
