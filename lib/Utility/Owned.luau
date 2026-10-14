--!strict
--!optimize 2

--[[
	Marks the instances the library creates, and finds them again on the client by name, class and mark, so a game's
	own instance with the same name in the same place is never mistaken for the library's. Waits are bounded by a
	deadline so a server that never published cannot hold a client forever.
]]

local OWNER_ATTRIBUTE = "VluxySF"

local Owned = {}

--[[
	@param instance Instance -- An instance the library created. Mark it before parenting it, so the mark replicates
	with it.
]]
function Owned.Mark(instance: Instance)
	instance:SetAttribute(OWNER_ATTRIBUTE, true)
end

local function matches(child: Instance, name: string, className: string): boolean
	return child.Name == name and child:IsA(className) and child:GetAttribute(OWNER_ATTRIBUTE) == true
end

--[[
	@yields

	@param parent Instance -- Where to look.
	@param name string -- The child's name.
	@param className string -- The class the child has to be.
	@param deadline number -- The os.clock() time to give up at.

	@return Instance? -- The library's child, or nil when it did not appear before the deadline.
]]
function Owned.WaitFor(parent: Instance, name: string, className: string, deadline: number): Instance?
	for _, child in ipairs(parent:GetChildren()) do
		if matches(child, name, className) then
			return child
		end
	end

	local thread = coroutine.running()
	local done = false

	local function finish(result: Instance?)
		if done then
			return
		end
		done = true

		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, result)
		end
	end

	local connection = parent.ChildAdded:Connect(function(child: Instance)
		if matches(child, name, className) then
			finish(child)
		end
	end)
	local timer = task.delay(math.max(deadline - os.clock(), 0), finish, nil)

	local result = coroutine.yield()

	connection:Disconnect()
	if coroutine.status(timer) == "suspended" then
		task.cancel(timer)
	end

	return result
end

return Owned
