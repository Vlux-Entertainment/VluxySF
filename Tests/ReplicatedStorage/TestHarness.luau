--!strict

--[[
	A small test harness for the test place.
	There is no test runner in this repo, so the test scripts use this to run their cases and print one summary.
]]
local TestHarness = {}

export type Suite = {
	Test: (name: string, case: () -> ()) -> (),
	Finish: () -> (),
}

local TOLERANCE = 0.0001

------------------------------------------------------------------------------------------------------------------------
--EXPECTATIONS----------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[[
	@param condition any -- The value that should be truthy.
	@param message string -- What was expected.

	Fails the current case when the condition is falsy.
]]
function TestHarness.Expect(condition: any, message: string)
	if not condition then
		error(message, 2)
	end
end

--[[
	@param actual any -- The value the library gave.
	@param expected any -- The value it should be.
	@param label string -- What is being compared.

	Fails the current case when the two values are not equal.
]]
function TestHarness.ExpectEqual(actual: any, expected: any, label: string)
	if actual ~= expected then
		error(`{label}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

--[[
	@param actual number -- The number the library gave.
	@param expected number -- The number it should be close to.
	@param label string -- What is being compared.

	Fails the current case when the numbers differ by more than a rounding error.
	Instance properties are stored as 32 bit floats, so they rarely equal the authored number exactly.
]]
function TestHarness.ExpectNear(actual: number, expected: number, label: string)
	if math.abs(actual - expected) > TOLERANCE then
		error(`{label}: expected about {expected}, got {actual}`, 2)
	end
end

--[[
	@param callback () -> () -- The function that should throw.
	@param label string -- What should have thrown.

	Fails the current case when the callback does not throw.
]]
function TestHarness.ExpectError(callback: () -> (), label: string)
	local success = pcall(callback)

	if success then
		error(`{label}: expected an error, but it did not throw`, 2)
	end
end

--[[
	@param list { string } -- The list to search.
	@param expected { string } -- The values that should all be in the list.
	@param label string -- What is being compared.

	Fails the current case when any expected value is missing from the list.
]]
function TestHarness.ExpectContains(list: { string }, expected: { string }, label: string)
	for _, value in ipairs(expected) do
		if not table.find(list, value) then
			error(`{label}: "{value}" is missing`, 2)
		end
	end
end

------------------------------------------------------------------------------------------------------------------------
--SUITES----------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[[
	@param suiteName string -- The name printed in the summary.

	@return Suite -- The suite to add cases to.

	Creates a suite. Each case runs right away, and Finish prints the summary.
]]
function TestHarness.new(suiteName: string): Suite
	local passed: number = 0
	local failures: { string } = {}

	local suite = {}

	function suite.Test(name: string, case: () -> ())
		local success, reason = pcall(case :: () -> any)

		if success then
			passed += 1
		else
			table.insert(failures, `{name}\n\t\t{tostring(reason)}`)
		end
	end

	function suite.Finish()
		local prefix = `[VluxySF Tests] {suiteName}:`

		if #failures == 0 then
			print(`{prefix} all {passed} cases passed.`)

			return
		end

		warn(`{prefix} {#failures} of {passed + #failures} cases failed!`)
		for _, failure in ipairs(failures) do
			warn(`\tFAILED: {failure}`)
		end
	end

	return suite
end

return TestHarness
