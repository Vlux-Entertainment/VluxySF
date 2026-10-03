--!strict

--[[
	Times how long it takes to fetch every sound in the schema.

	Run this from the command bar while playing, on the client or the server:
		require(game:GetService("ReplicatedStorage").FetchBenchmark).Run()

	Use ServerScriptService.StressFixture before pressing Play to get a large schema to measure.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.VluxySF)

local FetchBenchmark = {}

--[[
	@param iterations number? -- How many times to fetch every sound. Default is 50.

	@return number -- The average seconds one pass over every sound took.

	Fetches every sound in the schema, destroys the fetched sounds, and prints the average time of a pass.
]]
function FetchBenchmark.Run(iterations: number?): number
	VluxySF.Startup.WaitForSchema()

	local iterationCount: number = iterations or 50
	local names = VluxySF.Schema.GetNames()

	local total = 0

	for _ = 1, iterationCount do
		local fetched: { Sound } = table.create(#names)

		local start = os.clock()
		for index, name in ipairs(names) do
			fetched[index] = VluxySF.Fetch(name)
		end
		total += os.clock() - start

		for _, sound in ipairs(fetched) do
			sound:Destroy()
		end

		task.wait()
	end

	local average = total / iterationCount
	print(`[VluxySF Tests] Fetched {#names} sounds {iterationCount} times. Average pass: {average * 1000} ms.`)

	return average
end

return FetchBenchmark
