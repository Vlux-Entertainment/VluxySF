--!strict

--[[
    A utility module for formatting error and warning messages consistently across the Vluxy Sound Factory.
]]
local FormatMessage = {}

--[[
    @param errorMessage any -- The specific error message to be formatted.

    @return any -- The formatted error message with the module prefix.

    Creates a standardized error message by prefixing it with the module name.
]]
function FormatMessage.NewMessage(errorMessage: any): any
	return "[VluxySF Plugin]: " .. errorMessage
end

------------------------------------------------------------------------------------------------------------------------

--[[
    @param errorMessage any -- The specific error message to be thrown.
    @param level number? -- Optional parameter to specify the stack level for the error (default is 1).

    Throws an error with a formatted message.
]]
function FormatMessage.Error(errorMessage: any, level: number?)
	error(FormatMessage.NewMessage(errorMessage), level or 2)
end

--[[
    @param errorMessage any -- The specific error message to be thrown when the thunk is called.
    @param level number? -- Optional parameter to specify the stack level for the error (default is 1).

    @return (number?) -> () - A function that, when called, will throw an error with the formatted message. The caller can optionally provide a different stack level when invoking the thunk.

    Creates a thunk (a function that can be called later) for throwing an error with a formatted message.
]]
function FormatMessage.ErrorThunk(errorMessage: any, level: number?): (number?) -> ()
	return function(levelOverride: number?)
		FormatMessage.Error(errorMessage, levelOverride or level or 3)
	end
end

------------------------------------------------------------------------------------------------------------------------

--[[
    @param warningMessage any -- The specific warning message to be issued.

    Issues a warning with a formatted message.
]]
function FormatMessage.Warn(warningMessage: any)
	warn(FormatMessage.NewMessage(warningMessage))
end

--[[
    @param warningMessage any -- The specific warning message to be issued when the thunk is called.

    @return () -> () -- A function that, when called, will issue a warning with the formatted message.

    Creates a thunk (a function that can be called later) for issuing a warning with a formatted message.
]]
function FormatMessage.WarnThunk(warningMessage: any): () -> ()
	return function()
		FormatMessage.Warn(warningMessage)
	end
end

------------------------------------------------------------------------------------------------------------------------

--[[
    @param message any -- The specific message to be printed.

    Prints a formatted message to the console.
]]
function FormatMessage.Print(message: any)
	print(FormatMessage.NewMessage(message))
end

--[[
    @param message any -- The specific message to be printed when the thunk is called.

    @return () -> () -- A function that, when called, will print a message with the formatted format.

    Creates a thunk (a function that can be called later) for printing a formatted message.
]]
function FormatMessage.PrintThunk(message: any): () -> ()
	return function()
		FormatMessage.Print(message)
	end
end

return FormatMessage
