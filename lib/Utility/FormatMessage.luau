--!strict
--!optimize 2

--[[
	Formats every user-facing warning and error so they are easy to spot in the output.
]]
local FormatMessage = {}

local PREFIX = "[VluxySF]: "

--[[
	@param message any -- The message to prefix.

	@return string -- The message with the library prefix.

	Prefixes a message with the library name.
]]
function FormatMessage.NewMessage(message: any): string
	return PREFIX .. tostring(message)
end

--[[
	@param message any -- The message to throw.
	@param level number? -- The stack level the error points at. Default is 2, the caller of the function that errored.

	Throws a prefixed error.
]]
function FormatMessage.Error(message: any, level: number?)
	error(FormatMessage.NewMessage(message), level or 2)
end

--[[
	@param message any -- The message to warn with.

	Prints a prefixed warning.
]]
function FormatMessage.Warn(message: any)
	warn(FormatMessage.NewMessage(message))
end

return FormatMessage
