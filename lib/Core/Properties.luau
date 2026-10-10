--!strict
--!optimize 2

--[[
	Reads and writes Instance properties in bulk.

	The set of properties a class has is learned once per class from ReflectionService, probed on a fresh instance so
	that properties which cannot be read from a script are dropped, and then cached. After that, reading an instance is
	a plain loop with no pcall per property, and only values that differ from the class default are kept.
]]

local ReflectionService = game:GetService("ReflectionService")

local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)

--selene: allow(undefined_variable)
local allCapabilities = SecurityCapabilities.new(table.unpack(Enum.SecurityCapability:GetEnumItems()))

export type ClassInfo = {
	ClassName: string,
	Names: { string },
	Defaults: { any },
	Count: number,
}

--Never stored in a definition: structural properties, runtime state, and deprecated aliases of properties that are
--already stored under their current name.
local IGNORED_PROPERTIES: { [string]: boolean } = {
	Parent = true,
	Archivable = true,
	archivable = true,
	ClassName = true,
	className = true,
	Name = true, --always stored, but set by the caller rather than compared against the default
	AudioContent = true,
	Attributes = true,
	Tags = true,
	SideChain = true, --an Instance reference that cannot travel to clients

	Pitch = true,
	MaxDistance = true,
	MinDistance = true,
	EmitterSize = true,
	isPlaying = true,

	IsLoaded = true,
	IsPaused = true,
	IsPlaying = true,
	PlaybackLoudness = true,
	TimeLength = true,
}

--Value types a definition can hold.
local STORED_TYPES: { [string]: boolean } = {
	number = true,
	string = true,
	boolean = true,
	EnumItem = true,
	NumberRange = true,
}

--Properties whose default is nil (so their type cannot be probed) that are stored anyway.
local STORED_NIL_PROPERTIES: { [string]: boolean } = {
	SoundGroup = true,
}

--Never written back to an instance, even when a hand-made definition contains them.
local SKIPPED_ON_WRITE: { [string]: boolean } = {
	ClassName = true,
	Parent = true,
}

local classInfos: { [string]: ClassInfo } = {}

local Properties = {}

------------------------------------------------------------------------------------------------------------------------

local function readProperty(instance: any, name: string): any
	return instance[name]
end

local function writeProperty(instance: any, name: string, value: any)
	instance[name] = value
end

local function readChanged(instance: any, info: ClassInfo, out: { [string]: any })
	local names, defaults = info.Names, info.Defaults

	for index = 1, info.Count do
		local name = names[index]
		local value = instance[name]

		if value ~= defaults[index] then
			out[name] = value
		end
	end
end

local function writeAll(instance: any, properties: { [string]: any })
	for name, value in pairs(properties) do
		if SKIPPED_ON_WRITE[name] then
			continue
		end

		instance[name] = value
	end
end

------------------------------------------------------------------------------------------------------------------------

--[[
	@param className string -- The class to describe.

	@return ClassInfo -- The storable properties of the class and their default values.

	Learns which properties of a class can be read and written from a script and stored in a definition.
	The result is cached, so only the first call for a class touches ReflectionService.
]]
function Properties.GetClassInfo(className: string): ClassInfo
	local info = classInfos[className]
	if info then
		return info
	end

	local descriptors = (ReflectionService :: any):GetPropertiesOfClass(className, { Security = allCapabilities })
	local probe = Instance.new(className)

	local entries: { { Name: string, Default: any } } = {}

	for _, descriptor in ipairs(descriptors) do
		local name: string = descriptor.Name

		if IGNORED_PROPERTIES[name] or not descriptor.Permits.Read or not descriptor.Permits.Write then
			continue
		end

		local success, default = pcall(readProperty, probe, name)
		if not success then
			continue
		end
		if not STORED_TYPES[typeof(default)] and not (default == nil and STORED_NIL_PROPERTIES[name]) then
			continue
		end

		table.insert(entries, { Name = name, Default = default })
	end

	probe:Destroy()

	table.sort(entries, function(a, b)
		return a.Name < b.Name
	end)

	local names: { string } = table.create(#entries)
	local defaults: { any } = table.create(#entries)

	for index, entry in ipairs(entries) do
		names[index] = entry.Name
		defaults[index] = entry.Default
	end

	local learned: ClassInfo = {
		ClassName = className,
		Names = names,
		Defaults = defaults,
		Count = #names,
	}
	classInfos[className] = learned

	return learned
end

--[[
	@param instance Instance -- The instance to read.
	@param info ClassInfo? -- The class info to read with. Looked up from the instance when not given.

	@return { [string]: any } -- Every storable property whose value differs from the class default.

	Reads an instance into a table. Reads happen without pcall; if one property on this specific instance refuses to be
	read, the instance is read again one property at a time and the unreadable ones are left out.
]]
function Properties.ReadChanged(instance: Instance, info: ClassInfo?): { [string]: any }
	local classInfo = info or Properties.GetClassInfo(instance.ClassName)
	local out: { [string]: any } = {}

	if pcall(readChanged, instance, classInfo, out) then
		return out
	end

	table.clear(out)

	for index = 1, classInfo.Count do
		local name = classInfo.Names[index]
		local success, value = pcall(readProperty, instance, name)

		if success and value ~= classInfo.Defaults[index] then
			out[name] = value
		end
	end

	return out
end

--[[
	@param instance Instance -- The instance to write to.
	@param properties { [string]: any } -- The property values to apply.

	@return boolean -- Whether every property was applied.

	Applies a property table to an instance. Writes happen without pcall; if one fails, the table is applied again one
	property at a time so every valid property still lands, and each invalid one is warned about.
]]
function Properties.Apply(instance: Instance, properties: { [string]: any }): boolean
	if pcall(writeAll, instance, properties) then
		return true
	end

	local allApplied = true

	for name, value in pairs(properties) do
		if SKIPPED_ON_WRITE[name] then
			continue
		end

		local success, reason = pcall(writeProperty :: any, instance, name, value)
		if success then
			continue
		end

		allApplied = false
		FormatMessage.Warn(`Could not set "{name}" on {instance.ClassName} "{instance.Name}": {reason}`)
	end

	return allApplied
end

return Properties
