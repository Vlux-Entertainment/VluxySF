--!strict
--!optimize 2

local ContentProvider = game:GetService("ContentProvider")

local libarary = script.Parent.Parent

local FormatMessage = require(libarary.Utility.FormatMessage)

local Types = require(libarary.Types)

export type AllowedPreloadTypes = number | string | Sound | Types.SoundDefinition

local function getPreloadId(preloadObject: AllowedPreloadTypes): string?
	local soundId: string? = nil
	if typeof(preloadObject) == "Instance" and preloadObject:IsA("Sound") then
		soundId = preloadObject.SoundId
	elseif typeof(preloadObject) == "table" and preloadObject.Properties then
		soundId = preloadObject.Properties.SoundId
	elseif typeof(preloadObject) == "number" then
		soundId = "rbxassetid://" .. preloadObject
	elseif typeof(preloadObject) == "string" then
		soundId = preloadObject
	end

	if not soundId then
		FormatMessage.Warn(`Invalid preload object, {preloadObject}`)
		return nil
	end

	return soundId
end

--[[
    Module responsible for preloading sounds based on various identifiers such as sound locations, Sound instances, or SoundDefinitions. Utilizes ContentProvider for efficient preloading.
]]
local Preload = {}

--[[
	@yields

    @param ... number | string | Sound | SoundDefinition -- A variable number of sound identifiers to preload.

	Preloads sounds.
]]
function Preload.Selected(...: AllowedPreloadTypes)
	local selected: { AllowedPreloadTypes } = { ... }
	local selectedCount: number = #selected

	if selectedCount == 0 then
		return
	end

	local preloadHash: { [string]: boolean } = {}

	local preloadIndex: number = 0
	local soundsToPreload: { Sound } = {}

	for _, preloadObject in ipairs(selected) do
		local soundId: string? = getPreloadId(preloadObject)
		if not soundId then
			continue
		end

		if not preloadHash[soundId] then
			preloadHash[soundId] = true
			preloadIndex += 1

			local newSound = Instance.new("Sound")
			newSound.Name = "PreloadSound" .. preloadIndex
			newSound.SoundId = soundId
			newSound.Parent = script

			soundsToPreload[preloadIndex] = newSound
		end
	end

	local t = os.clock()

	ContentProvider:PreloadAsync(soundsToPreload)

	FormatMessage.Print(`Preloaded {selectedCount} sounds in {os.clock() - t} seconds!`)

	--may not be able to clear children for preload givin the more recent updates.
	script:ClearAllChildren()
end

return Preload
