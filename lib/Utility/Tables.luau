--!strict
--!optimize 2

local Tables = {}

--[[
	@param tbl { [any]: any } -- The table to deep freeze.

	Freezes a table and every table nested inside it.
]]
function Tables.DeepFreeze(tbl: { [any]: any })
	if not table.isfrozen(tbl) then
		table.freeze(tbl)
	end

	for _, value in pairs(tbl) do
		if type(value) == "table" then
			Tables.DeepFreeze(value)
		end
	end
end

return Tables
