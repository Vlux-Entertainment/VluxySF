--!strict

local Tables = {}

--[[
    @param tbl { [any]: any } -- The table to deep freeze.

    Deep freezes a table and all of its nested tables, making them immutable.
]]
function Tables.DeepFreeze(tbl: { [any]: any })
	table.freeze(tbl)

	for _, v in pairs(tbl) do
		if type(v) ~= "table" then
			continue
		end

		Tables.DeepFreeze(v)
	end
end

--[[
    @param tbl T -- The table to deep clone

    @return T -- A deep clone of the provided table, with all nested tables also cloned.

    Deep clones a table and all of its nested tables, creating a new table with the same structure and values.
]]
function Tables.DeepClone<T>(tbl: T): T
	local seen: { [any]: any } = {}

	local function cloneRecursive(v: any): any
		if type(v) ~= "table" then
			return v
		end

		local existing = seen[v]
		if existing then
			return existing
		end

		local copy = {} :: any
		seen[v] = copy

		for k, inner in pairs(v) do
			local clonedKey = cloneRecursive(k)
			local clonedValue = cloneRecursive(inner)
			copy[clonedKey] = clonedValue
		end

		return copy
	end

	return cloneRecursive(tbl)
end

return Tables
