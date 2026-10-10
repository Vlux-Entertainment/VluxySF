--!strict
--!optimize 2

--[[
	Builds template Sounds for a list of names, stores them as preloaded, and asks ContentProvider to load them.
]]

local ContentProvider = game:GetService("ContentProvider")

local Converters = require(script.Parent.Converters)
local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local SchemaStore = require(script.Parent.SchemaStore)
local Templates = require(script.Parent.Templates)

local Preloading = {}

--[[
	@param names { string } -- The sound names to preload.
	@param warnOnRepeat boolean -- Whether to warn about names that are already preloaded.

	@return { Sound } -- The new templates, parented in PreloadedSounds and ready to be loaded.

	Builds one template per name and stores it in the Preloaded registry. Unknown and repeated names are skipped.
]]
function Preloading.Register(names: { string }, warnOnRepeat: boolean): { Sound }
	local parent = SchemaStore.GetSchema().PreloadedSounds
	local registry = Templates.Preloaded
	local sounds: { Sound } = {}

	for _, name in ipairs(names) do
		if registry.Get(name) then
			if warnOnRepeat then
				FormatMessage.Warn(`"{name}" is already preloaded.`)
			end

			continue
		end

		local definition = SchemaStore.GetDefinition(name)
		if not definition then
			FormatMessage.Warn(`"{name}" is not in the schema and cannot be preloaded.`)

			continue
		end

		local sound = Converters.DefinitionToSound(definition)
		registry.Set(name, sound, parent)

		table.insert(sounds, sound)
	end

	return sounds
end

--[[
	@yields

	@param sounds { Sound } -- The sounds to load.

	Loads the sounds' assets. Returns when they are loaded or ContentProvider gives up on them.
]]
function Preloading.Load(sounds: { Sound })
	if #sounds == 0 then
		return
	end

	ContentProvider:PreloadAsync(sounds)
end

return Preloading
