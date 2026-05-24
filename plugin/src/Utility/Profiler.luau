--!strict

local TestService = game:GetService("TestService")

--[[
    Debugging and performance info.
]]
local Profiler = {}

--[[
    @param canRun: () -> boolean -- A function that determines whether the profile should print out.
    @param name: string -- The name of the process being profiled.

    @return string? -- An optional name override for the next profile.
    @return Instance? -- An optional context for the message.
    @return number? -- An optional line number for the message.

    Starts a new Diagnostics profile.
]]
function Profiler.NewDiagnostic(
	canRun: () -> boolean,
	name: string,
	restOnCall: boolean?
): (string?, Instance?, number?) -> ()
	local t = os.clock()

	return function(nameOverride: string?, context: Instance?, line: number?)
		if not canRun() then
			return
		end

		TestService:Message(
			`[VluxySF Plugin Diagnostic]: {nameOverride or name} took {os.clock() - t} seconds to execute.`,
			context,
			line
		)

		if restOnCall then
			t = os.clock()
		end
	end
end

--[[
    @param name: string -- The name of the process being profiled.

    @return () -> () -- A function that ends the profile when called.

    Starts a new debug profile.
]]
function Profiler.NewDebugProfile(name: string): () -> ()
	debug.profilebegin("[VluxySF Plugin Debug]: " .. name)

	return function()
		debug.profileend()
	end
end

return Profiler
