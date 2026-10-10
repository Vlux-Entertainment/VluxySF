--!strict
--!optimize 2

--[[
	A tiny signal whose listeners run right when it fires, in their own threads, whatever the place's SignalBehavior
	setting is. BindableEvents defer their listeners under the default setting, which breaks "connect, init, check"
	code that expects the callback to have run by the time the init call returns.
]]

export type Signal = {
	Connect: (self: Signal, callback: () -> ()) -> () -> (),
	Once: (self: Signal, callback: () -> ()) -> () -> (),
	Wait: (self: Signal) -> (),
	Fire: (self: Signal) -> (),
}

local Signal = {}
Signal.__index = Signal

--[[
	@return Signal -- A new signal.
]]
function Signal.new(): Signal
	local self = setmetatable({
		_callbacks = {} :: { [() -> ()]: boolean },
	}, Signal)

	return self :: any
end

--[[
	@param callback () -> () -- Runs in a new thread every time the signal fires.

	@return () -> () -- Disconnects the callback.
]]
function Signal.Connect(self: any, callback: () -> ()): () -> ()
	self._callbacks[callback] = true

	return function()
		self._callbacks[callback] = nil
	end
end

--[[
	@param callback () -> () -- Runs in a new thread the next time the signal fires, then disconnects.

	@return () -> () -- Disconnects the callback early.
]]
function Signal.Once(self: any, callback: () -> ()): () -> ()
	local disconnect: () -> ()

	disconnect = self:Connect(function()
		disconnect()
		callback()
	end)

	return disconnect
end

--[[
	@yields

	Yields the current thread until the signal fires.
]]
function Signal.Wait(self: any)
	local thread = coroutine.running()

	self:Once(function()
		task.spawn(thread)
	end)

	coroutine.yield()
end

--[[
	Runs every connected callback in its own thread.
]]
function Signal.Fire(self: any)
	for callback in pairs(table.clone(self._callbacks)) do
		task.spawn(callback)
	end
end

return Signal
