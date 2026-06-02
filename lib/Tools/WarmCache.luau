--!strict
--!optimize 2

local warmedSounds: { [string]: Sound } = {}

--[[
    Module responsible for managing warmed Sound instances.
]]
local WarmCache = {}

--[[
	@return { [string]: Sound } -- A table of warmed Sound instances, indexed by their names.

	Returns the current WarmCache of warmed Sound instances.
]]
function WarmCache.GetSounds(): { [string]: Sound }
	return warmedSounds
end

--[[
	@param soundName string -- The name of the Sound to retrieve.

	@return Sound? -- The warmed Sound instance corresponding to the given name, or nil if it is not currently warmed.

	Retrieves a warmed Sound instance by its name.
]]
function WarmCache.GetSound(soundName: string): Sound?
	return warmedSounds[soundName]
end

--[[
	@param soundName string -- The name of the Sound to check.

	@return boolean -- Whether the specified Sound is currently warmed.

	Creates a Sound instance from a SoundDefinition and adds it to the warmed sounds cache under the specified parent folder.
]]
function WarmCache.IsWarmed(soundName: string): boolean
	return warmedSounds[soundName] and true or false
end

--[[
	@param sound Sound -- The Sound instance to warm.

	Adds a Sound instance to the WarmCache for future use.
]]
function WarmCache.SetSound(parent: Configuration, sound: Sound)
	local soundName: string = sound.Name

	if warmedSounds[soundName] then
		return
	end
	warmedSounds[soundName] = sound

	sound.Parent = parent
end

--[[
	@param soundName string -- The name of the Sound to chill.

	Removes a Sound instance from the WarmCache.
]]
function WarmCache.RemoveSound(soundName: string)
	if not warmedSounds[soundName] then
		return
	end

	local sound = warmedSounds[soundName]

	sound:Destroy()
	warmedSounds[soundName] = nil

	return
end

return WarmCache
