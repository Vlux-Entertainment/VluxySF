--!strict
--!optimize 2

--[[
	Converts Sound instances to SoundDefinitions and back.
]]

local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local Properties = require(script.Parent.Properties)
local Types = require(script.Parent.Parent.Types)

local INSTANCE_TAG = "_VLUXY_SOUND_FACTORY_INSTANCE"

--Name of the silent Sound handed out in place of one that could not be built or found.
local BLANK_SOUND_NAME = "VluxySF_Blank_Sound"

local ALLOWED_SOUND_CHILDREN: { [string]: boolean } = {
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

local Converters = {}

------------------------------------------------------------------------------------------------------------------------

--[[
	@return SoundDefinition -- A new definition of a silent Sound with no asset and no effects, named BLANK_SOUND_NAME.
]]
function Converters.NewBlankDefinition(): Types.SoundDefinition
	return {
		Properties = { Name = BLANK_SOUND_NAME } :: any,
		Effects = {} :: any,
		EffectsCount = 0,
	}
end

--[[
	@param sound Sound -- The Sound to convert.
	@param soundGroup SoundGroup? -- A SoundGroup to store on the definition instead of the one the Sound has.

	@return SoundDefinition -- The definition.

	Converts a Sound and its SoundEffect children into a SoundDefinition. Only properties that differ from the class
	defaults are stored, plus Name, so a definition stays small.
]]
function Converters.SoundToDefinition(sound: Sound, soundGroup: SoundGroup?): Types.SoundDefinition
	local properties = Properties.ReadChanged(sound)
	properties.Name = sound.Name

	if soundGroup then
		properties.SoundGroup = soundGroup
	end

	local effects: { [string]: { [string]: any } } = {}
	local effectsCount = 0

	for _, child in ipairs(sound:GetChildren()) do
		local className = child.ClassName

		if not ALLOWED_SOUND_CHILDREN[className] then
			FormatMessage.Warn(`"{child:GetFullName()}" is not a SoundEffect and was skipped.`)
			continue
		end

		if effects[className] then
			FormatMessage.Warn(`"{sound:GetFullName()}" has more than one {className}. Only the first one was kept.`)
			continue
		end

		if #child:GetChildren() > 0 then
			FormatMessage.Warn(`"{child:GetFullName()}" has children. SoundEffects cannot have children.`)
		end

		local effectProperties = Properties.ReadChanged(child)
		effectProperties.Name = className --effects are fetched by class name, so that is their name

		effects[className] = effectProperties
		effectsCount += 1
	end

	return {
		Properties = properties :: any,
		Effects = effects :: any,
		EffectsCount = effectsCount,
	}
end

--[[
	@param definition SoundDefinition -- The definition to build.

	@return Sound -- A new Sound with its SoundEffects parented under their class names.

	Builds a new Sound from a SoundDefinition. The Sound is not parented. A definition with no Properties or no Effects
	builds what it has; an effect entry that is not a table is warned about and skipped.
]]
function Converters.DefinitionToSound(definition: Types.SoundDefinition): Types.SoundDefinitionInstanced
	local sound = Instance.new("Sound")
	sound:AddTag(INSTANCE_TAG)

	local properties = (definition :: any).Properties
	if type(properties) == "table" then
		Properties.Apply(sound, properties)
	end

	local effects = (definition :: any).Effects
	if type(effects) == "table" then
		for className, effectProperties in pairs(effects) do
			if type(className) ~= "string" or not ALLOWED_SOUND_CHILDREN[className] then
				FormatMessage.Warn(`"{className}" is not a SoundEffect class and was skipped on "{sound.Name}".`)
				continue
			end

			if type(effectProperties) ~= "table" then
				FormatMessage.Warn(
					`{className} on "{sound.Name}" is {typeof(effectProperties)} instead of a property table and was skipped.`
				)
				continue
			end

			local effect = Instance.new(className)
			Properties.Apply(effect, effectProperties)
			effect.Parent = sound
		end
	end

	return sound :: Types.SoundDefinitionInstanced
end

return Converters
