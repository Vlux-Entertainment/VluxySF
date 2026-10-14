--!strict
--!optimize 2

--[[
	Keeps template Sounds by name so Fetch can clone them instead of building them.

	There are two registries. Preloaded holds the sounds Preload keeps for the whole session; those templates exist to
	keep their audio loaded and are never cloned. Warmed holds the sounds the game warms and chills at runtime; Fetch
	clones those instead of building them.
]]

export type Registry = {
	Get: (name: string) -> Sound?,
	Set: (name: string, sound: Sound, parent: Instance) -> boolean,
	Remove: (name: string) -> boolean,
	All: () -> { [string]: Sound },
}

local Templates = {}

local function newRegistry(): Registry
	local sounds: { [string]: Sound } = {}

	local registry = {} :: Registry

	--[[
		@param name string -- The sound name.

		@return Sound? -- The stored template, if there is one.
	]]
	function registry.Get(name: string): Sound?
		return sounds[name]
	end

	--[[
		@param name string -- The sound name.
		@param sound Sound -- The template to store. It is parented to the given parent.
		@param parent Instance -- Where the template lives.

		@return boolean -- false when a template with that name already exists. The sound is left untouched then.
	]]
	function registry.Set(name: string, sound: Sound, parent: Instance): boolean
		if sounds[name] then
			return false
		end

		sounds[name] = sound
		sound.Parent = parent

		return true
	end

	--[[
		@param name string -- The sound name.

		@return boolean -- Whether a template was removed. The template is destroyed.
	]]
	function registry.Remove(name: string): boolean
		local sound = sounds[name]
		if not sound then
			return false
		end

		sounds[name] = nil
		sound:Destroy()

		return true
	end

	--[[
		@return { [string]: Sound } -- The live table of templates. Do not modify it.
	]]
	function registry.All(): { [string]: Sound }
		return sounds
	end

	return registry
end

Templates.Preloaded = newRegistry()
Templates.Warmed = newRegistry()

--[[
	@param name string -- The sound name.

	@return Sound? -- A fresh, unparented clone of the warmed template, or nil when there is none.
]]
function Templates.Clone(name: string): Sound?
	local template = Templates.Warmed.Get(name)
	if not template then
		return nil
	end

	return template:Clone()
end

return Templates
