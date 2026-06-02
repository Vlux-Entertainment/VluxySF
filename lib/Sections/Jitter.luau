--!strict
--!native
--!optimize 2

local Random = Random.new()

------------------------------------------------------------------------------------------------------------------------

--[=[
	@class Jitter
	
	Jitter functions meant for Volume and Pitch properties of sounds. Can be used in other contexts as well.

	:::info
	All jitter functions are clamped from 0 to 10.
	:::
]=]
local Jitter = {}

--[=[
	@within Jitter

	@param center number -- The central value around which the jitter will occur.
	@param spread number -- The maximum deviation from the center value.

	@return () -> number -- Generates the jitter value when called.

	Standard Jitter function that randomly varies from the center value +- the spread.

	```lua
	local myJitter = Jitter.Default(1, 0.15)
	
	local sound1 = ...
	sound1.PlaybackSpeed = myJitter() -- Sets a random value.

	local sound2 = ...
	sound2.PlaybackSpeed = myJitter() -- Sets another random value.
	```
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

	@return () -> number -- Generates the jitter value when called.

	Essentially just a random number that requires a specified range.

	```lua
	local myJitter = Jitter.Range(0.85, 1.15)
	
	local sound1 = ...
	sound1.PlaybackSpeed = myJitter() -- Sets a random value.

	local sound2 = ...
	sound2.PlaybackSpeed = myJitter() -- Sets another random value.
	```
]=]
function Jitter.Range(min: number, max: number): () -> number
	return function()
		local j = Random:NextNumber(min, max)

		return math.clamp(j, 0, 10)
	end
end

--[=[
	@within Jitter

	@param spread number -- The maximum deviation from the center value.

	@return () -> number -- Generates the jitter value when called.

	Very similar to `Jitter.Default` but the center value is 1.

	```lua
	local myJitter = Jitter.Scale(0.15)
	
	local sound1 = ...
	sound1.PlaybackSpeed = myJitter() -- Sets a random value.

	local sound2 = ...
	sound2.PlaybackSpeed = myJitter() -- Sets another random value.
	```
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

	@return () -> number -- Generates the jitter value when called.

	Produces jitter values with a shaped distribution that favors the center value.

	```lua
	local myJitter = Jitter.UnitLog(1, 0.15)
	
	local sound1 = ...
	sound1.PlaybackSpeed = myJitter() -- Sets a random shaped value.

	local sound2 = ...
	sound2.PlaybackSpeed = myJitter() -- Sets another random shaped value.
	```

	:::tip
		This can be used to make more natural repetitious sounds like footsteps.
	:::
]=]
function Jitter.UnitLog(center: number, spread: number): () -> number
	return function()
		local r = (Random:NextNumber() * 2 - 1) * spread
		local shaped = r / (1 + math.abs(r) * 3)

		return math.clamp(center + shaped, 0, 10)
	end
end

return Jitter
