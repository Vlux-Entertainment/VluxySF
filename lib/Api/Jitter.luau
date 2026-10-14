--!strict
--!optimize 2

local random = Random.new()

------------------------------------------------------------------------------------------------------------------------

--[=[
	@class Jitter

	Builders for small random variations, meant for the `Volume` and `PlaybackSpeed` of sounds so repeated sounds do not
	sound identical. Each builder returns a function that gives a new value every time it is called.

	:::info
	Values never go below 0, since a negative volume or speed means nothing. There is no upper clamp; Roblox clamps the
	property itself.
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

	@param center number -- The value the jitter varies around.
	@param spread number -- The largest distance from the center.

	@return () -> number -- Gives a new value when called.
]=]
function Jitter.Uniform(center: number, spread: number): () -> number
	return function()
		return math.max(center + (random:NextNumber() * 2 - 1) * spread, 0)
	end
end

--[=[
	@within Jitter

	Spreads values evenly between `min` and `max`.

	```lua
	local speed = VluxySF.Jitter.Range(0.85, 1.15)

	sound.PlaybackSpeed = speed()
	```

	@param min number -- The smallest value.
	@param max number -- The largest value.

	@return () -> number -- Gives a new value when called.
]=]
function Jitter.Range(min: number, max: number): () -> number
	return function()
		return math.max(random:NextNumber(min, max), 0)
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

	@param center number -- The value the jitter varies around.
	@param spread number -- The largest distance from the center.

	@return () -> number -- Gives a new value when called.
]=]
function Jitter.Natural(center: number, spread: number): () -> number
	return function()
		local offset = (random:NextNumber() * 2 - 1) * spread
		local shaped = offset / (1 + math.abs(offset) * 3)

		return math.max(center + shaped, 0)
	end
end

return Jitter
