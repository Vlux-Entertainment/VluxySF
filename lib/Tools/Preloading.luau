--!strict
--!optimize 2

local ContentProvider = game:GetService("ContentProvider")

local libarary = script.Parent.Parent

local FormatMessage = require(libarary.Utility.FormatMessage)
local Types = require(libarary.Types)

export type AllowedPreloadTypes = string | Sound | Types.SoundDefinition

local preloadHash: { [string]: Sound } = {}

--[[
    Module responsible for preloading sounds based on various identifiers such as sound locations.
]]
local Preload = {}

--[[
	@return { [string]: Sound } -- A list of sound names that have been preloaded.

	Retrieves the names of all sounds that have been preloaded.
]]
function Preload.GetNames(): { [string]: Sound }
	return preloadHash
end

--[[
	@param soundName string -- The name of the sound to retrieve.

	@return Sound? -- The preloaded Sound instance corresponding to the given name, or nil if it has not been preloaded.

	Retrieves a preloaded Sound instance by its name.
]]
function Preload.GetSound(soundName: string): Sound?
	return preloadHash[soundName]
end

--[[
	@yields

    @param ... AllowedPreloadTypes -- A variable number of sound identifiers to preload.

	Preloads sounds.
]]
function Preload.Selected(parentFolder: Configuration, ...: Sound)
	local selected: { Sound } = { ... }
	local selectedCount: number = #selected

	if selectedCount == 0 then
		return
	end

	local preloadIndex: number = 0
	local soundsToPreload: { Sound } = {}

	for _, sound in ipairs(selected) do
		local soundName: string = sound.Name

		if not preloadHash[soundName] then
			preloadHash[soundName] = sound
			preloadIndex += 1

			local newSound = Instance.new("Sound")
			newSound.Name = soundName
			newSound.SoundId = sound.SoundId
			newSound.Parent = parentFolder

			soundsToPreload[preloadIndex] = newSound
		else
			FormatMessage.Warn(`Sound named {soundName} is already preloaded!`)

			sound:Destroy()
		end
	end

	ContentProvider:PreloadAsync(soundsToPreload)
end

return Preload
