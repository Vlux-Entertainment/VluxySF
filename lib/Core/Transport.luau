--!strict
--!optimize 2

--[[
	Gets the schema buffer from the server to every client without a request.

	The server splits the buffer into chunks and stores them on instances under the library module. Those replicate to
	every client as part of joining, so the client just waits for them and joins them back together. Nothing is
	serialized per player and no remote round trip happens.

	Chunks are stored as buffer attributes when the engine allows it, and as StringValue contents otherwise.
]]

local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)

local FOLDER_NAME = "VluxySF_Schema"
local CHUNK_SIZE = 64 * 1024
local DATA_ATTRIBUTE = "Data"

local MODE_BUFFER = "buffer"
local MODE_STRING = "string"

local library = script.Parent.Parent

local Transport = {}

------------------------------------------------------------------------------------------------------------------------

local function setBufferAttribute(instance: Instance, data: buffer)
	instance:SetAttribute(DATA_ATTRIBUTE, data)
end

--[[
	@param schemaBuffer buffer -- The schema to publish.

	Publishes the schema so clients can read it. Call once on the server.
]]
function Transport.Publish(schemaBuffer: buffer)
	if library:FindFirstChild(FOLDER_NAME) then
		FormatMessage.Error("The schema was already published! Startup.InitServer should only run once.", 4)
	end

	local total = buffer.len(schemaBuffer)
	local chunkCount = math.max(1, math.ceil(total / CHUNK_SIZE))
	local mode = MODE_BUFFER

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	for index = 1, chunkCount do
		local start = (index - 1) * CHUNK_SIZE
		local length = math.min(CHUNK_SIZE, total - start)

		local chunk = Instance.new("StringValue")
		chunk.Name = tostring(index)

		if mode == MODE_BUFFER then
			local slice = buffer.create(length)
			buffer.copy(slice, 0, schemaBuffer, start, length)

			if not pcall(setBufferAttribute, chunk, slice) then
				mode = MODE_STRING
			end
		end

		if mode == MODE_STRING then
			chunk.Value = buffer.readstring(schemaBuffer, start, length)
		end

		chunk.Parent = folder
	end

	folder:SetAttribute("Size", total)
	folder:SetAttribute("Chunks", chunkCount)
	folder:SetAttribute("Mode", mode)

	folder.Parent = library
end

--[[
	@yields

	@return buffer -- The schema the server published.

	Waits for the published schema to replicate and joins its chunks back into one buffer. Call once on the client.
]]
function Transport.Receive(): buffer
	local folder = library:WaitForChild(FOLDER_NAME)

	while folder:GetAttribute("Chunks") == nil do
		folder.AttributeChanged:Wait()
	end

	local total = folder:GetAttribute("Size") :: number
	local chunkCount = folder:GetAttribute("Chunks") :: number
	local mode = folder:GetAttribute("Mode") :: string

	local result = buffer.create(total)
	local cursor = 0

	for index = 1, chunkCount do
		local chunk = folder:WaitForChild(tostring(index)) :: StringValue

		if mode == MODE_BUFFER then
			local data = chunk:GetAttribute(DATA_ATTRIBUTE)
			while data == nil do
				chunk.AttributeChanged:Wait()
				data = chunk:GetAttribute(DATA_ATTRIBUTE)
			end

			local slice = data :: buffer
			buffer.copy(result, cursor, slice)
			cursor += buffer.len(slice)
		else
			local text = chunk.Value
			buffer.writestring(result, cursor, text)
			cursor += #text
		end
	end

	if cursor ~= total then
		FormatMessage.Error(`The schema arrived damaged: expected {total} bytes but got {cursor}.`)
	end

	return result
end

return Transport
