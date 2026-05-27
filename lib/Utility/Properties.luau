--!strict
--!native
--!optimize 2

local ReflectionService = game:GetService("ReflectionService")

--selene: allow(undefined_variable)
local allCapabilities = SecurityCapabilities.new(table.unpack(Enum.SecurityCapability:GetEnumItems()))

------------------------------------------------------------------------------------------------------------------------

local savedClassProperties: { [string]: { [string]: boolean } } = {}

--[[
	For setting and fetching Instance properties by table and attributes
]]
local Class = {}

--[[
	Reads an Instance and converts its properties to a table

	@param instance Instance -- The instance to pull its properties from

	@return { [string]: any } -- Table of all pulled properties
]]
function Class.InstanceToProperties(instance: Instance): { [string]: any }
	local className: string = instance.ClassName

	local hashedProperties: { [string]: boolean } = savedClassProperties[className]
	local properties: { [string]: any } = {}

	if not hashedProperties then
		local newProperties = ReflectionService:GetPropertiesOfClass(className, { Security = allCapabilities })
		local newPropertiesCount: number = #newProperties

		local tblProperties: { [string]: boolean } = {}

		for i = 1, newPropertiesCount do
			local v: { [string]: any } = newProperties[i]
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
	for property, _ in hashedProperties do
		pcall(function()
			properties[property] = inst[property]
		end)
	end

	return properties
end

--[[
	Reads attributes from an instance and converts it to a table
	
	@param instance Instance -- The instance to pull its attributes from

	@return { [string]: any } -- Table of all pulled attributes
]]
function Class.AttributesToProperties(instance: Instance): { [string]: any }
	return instance:GetAttributes()
end

--[[
	Applies a value to a property of the instance if one exists
	
	@param instance Instance -- The instance to pull its properties from
	@param property string -- The name of the property you want to change
	@param value any -- The value you want to change the property too

	@return boolean -- was applying successful
	@return any -- error message
]]
function Class.ApplyPropertyValueToInstance(instance: Instance, property: string, value: any): (boolean, any)
	return pcall(function()
		local inst = instance :: any --fix type error
		inst[property] = value
	end)
end

--[[
	Fetches a value from a property of the instance if one exists

	@param instance Instance -- The instance to pull its properties from
	@param property string -- The name of the property you want to fetch

	@return any -- value of the property, nil if it doesn't exist
]]
function Class.GetPropertyValueFromInstance(instance: Instance, property: string): any?
	local _, result = pcall(function()
		local inst = instance :: any --fix type error
		return inst[property]
	end)

	return result
end

return Class
