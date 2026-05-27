--!strict
--!native
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

--[[
    Module responsible for converting Sound instances to SoundDefinitions and vice versa.
]]
local Converters = {}

--[[
    Converts a Sound instance to a SoundDefinition.

    @param sound Sound -- The Sound instance to convert.

    @return SoundDefinition -- The created Definition
]]
function Converters.SoundToDefinition(sound: Sound): Types.SoundDefinition
	local definition = {
		Properties = {},
		Effects = {},
	} :: Types.SoundDefinition

	--[[
		properties
	]]
	local properties: { [string]: any } = Properties.InstanceToProperties(sound)

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

	for i = 1, childEffectCount do
		local effect: Instance = effects[i]
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

		effectsDefinition[effectClassName] = effectProperties
	end

	return definition
end

--[[
    Converts a SoundDefinition to a Sound instance.

    @param SoundDefinition -- The SoundDefinition to convert.

    @return Sound -- The created Sound
]]
function Converters.DefinitionToSound(definition: Types.SoundDefinition): Types.SoundDefinitionInstanced
	local sound = Instance.new("Sound")
	sound:AddTag("_VLUXY_SOUND_FACTORY_INSTANCE") --lets the system know what sound was created by VluxySF

	--properties
	for property, value in pairs(definition.Properties) do
		Properties.ApplyPropertyValueToInstance(sound, property, value)
	end

	--effects
	local function addEffect(effectName: string, effectProperties: { [string]: any })
		local effect = Instance.new(effectName)

		for property, value in pairs(effectProperties) do
			Properties.ApplyPropertyValueToInstance(effect, property, value)
		end

		effect.Parent = sound
	end

	for effectName, effectProperties in pairs(definition.Effects) do
		if not effectProperties then
			continue
		end

		addEffect(effectName, effectProperties)
	end

	return sound :: Types.SoundDefinitionInstanced
end

return Converters
