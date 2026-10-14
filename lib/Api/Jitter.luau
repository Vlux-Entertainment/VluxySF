--!strict
--!optimize 2

local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)

local random = Random.new()

--Arguments are checked once when the jitter is built, so the returned function never has to and never throws.
local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

--Returns the value when it is usable, otherwise warns and returns the fallback.
local function checkNumber(functionName: string, argumentName: string, value: any, fallback: number): number
	if isFinite(value) then
		return value
	end

	FormatMessage.Warn(
		`Jitter.{functionName} {argumentName} must be a finite number, got {tostring(value)}. Using {fallback}.`
	)

	return fallback
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@class Jitter

	Builders for small random variations, meant for the `Volume` and `PlaybackSpeed` of sounds so repeated sounds do not
	sound identical. Each builder returns a function that gives a new value every time it is called.

	:::info
	Values never go below 0, since a negative volume or speed means nothing. There is no upper clamp; Roblox clamps the
	property itself.

	A builder never throws. An argument that is not a number warns when the builder is called and falls back to a value
	that gives no variation, so the mistake shows up where it was made and the sounds keep playing.
	:::
]=]
local Jitter = {}

--[=[
	@within Jitter

	Spreads values evenly between `center - spread` and `center + spread`.

	```lua
	local speed = VluxySF.Jitter.Uniform(1, 0.15)

	sound1.PlaybackSpeed = speed() -- a random value from 0.85 to 1.15
	sound2.PlaybackSpeed = speed() -- another one
	```

	@param center number -- The value the jitter varies around. Falls back to 1 when it is not a number.
	@param spread number -- The largest distance from the center. Falls back to 0 when it is not a number.

	@return () -> number -- Gives a new value when called.
]=]
function Jitter.Uniform(center: number, spread: number): () -> number
	local realCenter = checkNumber("Uniform", "center", center, 1)
	local realSpread = checkNumber("Uniform", "spread", spread, 0)

	return function()
		return math.max(realCenter + (random:NextNumber() * 2 - 1) * realSpread, 0)
	end
end

--[=[
	@within Jitter

	Spreads values evenly between `min` and `max`. When `min` is above `max` the two are swapped.

	```lua
	local speed = VluxySF.Jitter.Range(0.85, 1.15)

	sound.PlaybackSpeed = speed()
	```

	@param min number -- The smallest value. Falls back to `max` when it is not a number.
	@param max number -- The largest value. Falls back to `min` when it is not a number.

	@return () -> number -- Gives a new value when called.
]=]
function Jitter.Range(min: number, max: number): () -> number
	--a bad bound falls back to the other one, so the result is a constant rather than something made up
	local realMin = checkNumber("Range", "min", min, if isFinite(max) then max else 1)
	local realMax = checkNumber("Range", "max", max, if isFinite(min) then min else 1)

	if realMin > realMax then
		FormatMessage.Warn(`Jitter.Range min {realMin} is above max {realMax}. They were swapped.`)
		realMin, realMax = realMax, realMin
	end

	return function()
		return math.max(random:NextNumber(realMin, realMax), 0)
	end
end

--[=[
	@within Jitter

	Like `Uniform`, but values cluster near the center and rarely reach the edges, which sounds more natural for
	repeated sounds like footsteps.

	```lua
	local volume = VluxySF.Jitter.Natural(0.8, 0.1)

	footstep.Volume = volume()
	```

	@param center number -- The value the jitter varies around. Falls back to 1 when it is not a number.
	@param spread number -- The largest distance from the center. Falls back to 0 when it is not a number.

	@return () -> number -- Gives a new value when called.
]=]
function Jitter.Natural(center: number, spread: number): () -> number
	local realCenter = checkNumber("Natural", "center", center, 1)
	local realSpread = checkNumber("Natural", "spread", spread, 0)

	return function()
		local offset = (random:NextNumber() * 2 - 1) * realSpread
		local shaped = offset / (1 + math.abs(offset) * 3)

		return math.max(realCenter + shaped, 0)
	end
end

return Jitter
