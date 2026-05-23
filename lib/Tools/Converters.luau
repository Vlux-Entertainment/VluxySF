--!strict

local libarary = script.Parent.Parent

local FormatMessage = require(libarary.Utility.FormatMessage)
local Properties = require(libarary.Utility.Properties)

local Types = require(libarary.Types)

local ALLOWED_SOUND_CHILDREN = {
	"ChorusSoundEffect",
	"CompressorSoundEffect",
	"DistortionSoundEffect",
	"EchoSoundEffect",
	"EqualizerSoundEffect",
	"FlangeSoundEffect",
	"PitchShiftSoundEffect",
	"ReverbSoundEffect",
	"TremoloSoundEffect",
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

	--properties
	for property, value in pairs(Properties.InstanceToProperties(sound)) do
		definition.Properties[property] = value
	end

	--effects
	if #sound:GetDescendants() > #ALLOWED_SOUND_CHILDREN then
		FormatMessage.Warn(`{sound.Name} has more children than allowed!`)
	end

	local function getEffect(effectName: string): SoundEffect?
		local child = sound:FindFirstChildOfClass(effectName)
		if not child then
			return nil
		end

		if not child:IsA("SoundEffect") then
			FormatMessage.Warn(
				`VluxySF: {child.Name} is not a SoundEffect and will be skipped when converting {sound.Name} to a definition!`
			)
			return nil
		end

		return child
	end

	local function registerEffect(effectName: string, childEffect: SoundEffect)
		definition.Effects[effectName] = {}
		for property, value in pairs(Properties.InstanceToProperties(childEffect)) do
			definition.Effects[effectName][property] = value
		end
	end

	for _, effectName in ipairs(ALLOWED_SOUND_CHILDREN) do
		local childEffect = getEffect(effectName)

		if childEffect then
			registerEffect(effectName, childEffect)
		end
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
