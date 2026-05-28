--!strict
--!native
--!optimize 2

local Random = Random.new()

------------------------------------------------------------------------------------------------------------------------

--[=[
	@class Jitter
	
	A collection of functions to generate random jitter values for sound properties, allowing for dynamic and natural variations in sound playback.
]=]
local Jitter = {}

--[=[
	@within Jitter

	@param center number -- The central value around which the jitter will occur.
	@param spread number -- The maximum deviation from the center value.

	@return () -> number -- A function that generates a random jitter value when called.

	Jitter function for sound properties.
]=]
function Jitter.Default(center: number, spread: number): () -> number
	return function()
		local j = (Random:NextNumber() * 2 - 1) * spread

		return math.clamp(center + j, 0, 10)
	end
end

--[=[
	@within Jitter

	@param min number -- The minimum value for the jitter range.
	@param max number -- The maximum value for the jitter range.

	@return () -> number -- A function that generates a random jitter value within the specified range when called.

	Jitter function that generates a random value within a specified range.
]=]
function Jitter.Range(min: number, max: number): () -> number
	return function()
		local j = Random:NextNumber(min, max)

		return math.clamp(j, 0, 10)
	end
end

--[=[
	@within Jitter

	@param spread number -- The maximum percentage deviation from the base value (e.g., 0.1 for ±10% jitter).

	@return () -> number -- A function that generates a random jitter multiplier when called.

	Jitter function that generates a random multiplier around 1, allowing for percentage-based variation.
]=]
function Jitter.Scale(spread: number): () -> number
	return function()
		local j = (Random:NextNumber() * 2 - 1) * spread

		return math.clamp(1 + j, 0, 10)
	end
end

--[=[
	@within Jitter

	@param center number -- The central value around which the jitter will occur.
	@param spread number -- The maximum deviation from the center value.

	@return () -> number -- A function that generates a random jitter value with a shaped distribution when called.

	Jitter function that produces values with a shaped distribution, creating more natural variations around the center value.
]=]
function Jitter.UnitLog(center: number, spread: number): () -> number
	return function()
		local r = (Random:NextNumber() * 2 - 1) * spread
		local shaped = r / (1 + math.abs(r) * 3)

		return math.clamp(center + shaped, 0, 10)
	end
end

return Jitter
