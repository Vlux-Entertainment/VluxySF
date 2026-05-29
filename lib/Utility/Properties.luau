--!strict
--!optimize 2

local ReflectionService = game:GetService("ReflectionService")

--selene: allow(undefined_variable)
local allCapabilities = SecurityCapabilities.new(table.unpack(Enum.SecurityCapability:GetEnumItems()))

------------------------------------------------------------------------------------------------------------------------

local savedDefaultClassProperties: { [string]: { [string]: any } } = {}
local savedClassProperties: { [string]: { [string]: boolean } } = {}

--[[
	For setting and fetching Instance properties by table and attributes.
]]
local Class = {}

--[[
	@param properties { [string]: any } -- The properties table to remove default values from.

	Removes properties from a properties table that are the same as the default value for that class.
]]
function Class.RemoveDefaultProperties(properties: { [string]: any })
	local className: string = properties.ClassName

	local defaultProperties = savedDefaultClassProperties[className]

	if not defaultProperties then
		local defaultInstance = Instance.new(className)

		defaultProperties = Class.InstanceToProperties(defaultInstance)
		savedDefaultClassProperties[className] = defaultProperties

		defaultInstance:Destroy()
	end

	for property, value in pairs(defaultProperties) do
		if properties[property] ~= value then
			continue
		end

		properties[property] = nil
	end
end

--[[
	@param instance Instance -- The instance to pull its properties from.

	@return { [string]: any } -- Table of all pulled properties.

	Reads an Instance and converts its properties to a table.
]]
function Class.InstanceToProperties(instance: Instance): { [string]: any }
	local className: string = instance.ClassName

	local hashedProperties: { [string]: boolean } = savedClassProperties[className]
	local properties: { [string]: any } = {}

	if not hashedProperties then
		local newProperties = ReflectionService:GetPropertiesOfClass(className, { Security = allCapabilities })

		local tblProperties: { [string]: boolean } = {}

		for _, v in ipairs(newProperties) do
			local name: string = v.Name

			if not v.Permits.Write or not v.Permits.Read then
				continue
			end

			tblProperties[name] = true
		end

		savedClassProperties[instance.ClassName] = tblProperties
		hashedProperties = tblProperties
	end

	--we know we can trust this since the data is comming from reflection service.
	local inst = instance :: any --fix type error
	for property, _ in pairs(hashedProperties) do
		pcall(function()
			properties[property] = inst[property]
		end)
	end
	properties["ClassName"] = className

	return properties
end

--[[
	@param instance Instance -- The instance to pull its attributes from.

	@return { [string]: any } -- Table of all pulled attributes.

	Reads attributes from an instance and converts it to a table.
]]
function Class.AttributesToProperties(instance: Instance): { [string]: any }
	return instance:GetAttributes()
end

--[[
	@param instance Instance -- The instance to pull its properties from.
	@param property string -- The name of the property you want to change.
	@param value any -- The value you want to change the property too.

	@return boolean -- was applying successful.
	@return any -- error message.

	Applies a value to a property of the instance if one exists.
]]
function Class.ApplyPropertyValueToInstance(instance: Instance, property: string, value: any): (boolean, any)
	return pcall(function()
		local inst = instance :: any --fix type error
		inst[property] = value
	end)
end

--[[
	@param instance Instance -- The instance to pull its properties from.
	@param property string -- The name of the property you want to fetch.

	@return any -- value of the property, nil if it doesn't exist.

	Fetches a value from a property of the instance if one exists.
]]
function Class.GetPropertyValueFromInstance(instance: Instance, property: string): any?
	local _, result = pcall(function()
		local inst = instance :: any --fix type error
		return inst[property]
	end)

	return result
end

return Class
