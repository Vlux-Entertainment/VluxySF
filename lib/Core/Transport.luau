--!strict
--!native
--!optimize 2

--[[
	Gets the schema buffer from the server to every client.

	The server compresses the buffer (Compression, LZ4-style) and base64-encodes it into one string attribute on a
	Configuration in SoundService. It replicates to every client as part of joining, so the client normally just
	waits for it and decodes it: nothing is serialized per player and no remote round trip happens.

	A RemoteFunction under the same Configuration is the fallback. A client whose attribute is missing, cut short or
	damaged (NextGenerationReplication limits script-set string attributes) asks the server for the compressed buffer
	instead, a few times at most per player. Every client wait here is bounded by a deadline, so a server that never
	published cannot hold a client forever.

	Base64 is used because buffer attributes are refused and replicated strings are not binary safe: a raw buffer
	string is cut at its first zero byte. Text survives.
]]

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Compression = require(script.Parent.Compression)
local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local Owned = require(script.Parent.Parent.Utility.Owned)

local CONTAINER_NAME = "VluxySF_Schema"
local SCHEMA_ATTRIBUTE = "Schema"
local REQUEST_NAME = "Request"

--how many times one player may ask the server for the schema
local MAX_REQUESTS_PER_PLAYER = 3

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local PAD = string.byte("=")

local encodeTable: { number } = table.create(64)
--every byte maps to -1 (not base64) unless the alphabet says otherwise, byte 0 included
local decodeTable: { [number]: number } = {}
for byte = 0, 255 do
	decodeTable[byte] = -1
end
for index = 1, 64 do
	local byte = string.byte(ALPHABET, index)
	encodeTable[index - 1] = byte
	decodeTable[byte] = index - 1
end

local Transport = {}

------------------------------------------------------------------------------------------------------------------------
--BASE64----------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local function encode(source: buffer, start: number, length: number): string
	local fullGroups = length // 3
	local remainder = length - fullGroups * 3
	local outLength = (fullGroups + (if remainder > 0 then 1 else 0)) * 4

	local out = buffer.create(outLength)
	local inOffset = start
	local outOffset = 0

	for _ = 1, fullGroups do
		local a = buffer.readu8(source, inOffset)
		local b = buffer.readu8(source, inOffset + 1)
		local c = buffer.readu8(source, inOffset + 2)

		buffer.writeu8(out, outOffset, encodeTable[a // 4])
		buffer.writeu8(out, outOffset + 1, encodeTable[(a % 4) * 16 + b // 16])
		buffer.writeu8(out, outOffset + 2, encodeTable[(b % 16) * 4 + c // 64])
		buffer.writeu8(out, outOffset + 3, encodeTable[c % 64])

		inOffset += 3
		outOffset += 4
	end

	if remainder == 1 then
		local a = buffer.readu8(source, inOffset)

		buffer.writeu8(out, outOffset, encodeTable[a // 4])
		buffer.writeu8(out, outOffset + 1, encodeTable[(a % 4) * 16])
		buffer.writeu8(out, outOffset + 2, PAD)
		buffer.writeu8(out, outOffset + 3, PAD)
	elseif remainder == 2 then
		local a = buffer.readu8(source, inOffset)
		local b = buffer.readu8(source, inOffset + 1)

		buffer.writeu8(out, outOffset, encodeTable[a // 4])
		buffer.writeu8(out, outOffset + 1, encodeTable[(a % 4) * 16 + b // 16])
		buffer.writeu8(out, outOffset + 2, encodeTable[(b % 16) * 4])
		buffer.writeu8(out, outOffset + 3, PAD)
	end

	return buffer.tostring(out)
end

--[[
	Decodes text into the target at the given offset. Returns how many bytes were written, or nil when the text is
	not valid base64.
]]
local function decode(text: string, target: buffer, start: number): number?
	local textLength = #text
	if textLength % 4 ~= 0 then
		return nil
	end

	local source = buffer.fromstring(text)
	local written = 0
	local inOffset = 0
	local outOffset = start
	local targetLength = buffer.len(target)

	while inOffset < textLength do
		local a = decodeTable[buffer.readu8(source, inOffset)]
		local b = decodeTable[buffer.readu8(source, inOffset + 1)]
		local cByte = buffer.readu8(source, inOffset + 2)
		local dByte = buffer.readu8(source, inOffset + 3)

		if a < 0 or b < 0 then
			return nil
		end

		local groupBytes = 3
		local c = 0
		local d = 0

		if cByte == PAD then
			groupBytes = 1
		else
			c = decodeTable[cByte]
			if c < 0 then
				return nil
			end

			if dByte == PAD then
				groupBytes = 2
			else
				d = decodeTable[dByte]
				if d < 0 then
					return nil
				end
			end
		end

		if outOffset + groupBytes > targetLength then
			return nil
		end

		buffer.writeu8(target, outOffset, a * 4 + b // 16)
		if groupBytes >= 2 then
			buffer.writeu8(target, outOffset + 1, (b % 16) * 16 + c // 4)
		end
		if groupBytes == 3 then
			buffer.writeu8(target, outOffset + 2, (c % 4) * 64 + d)
		end

		inOffset += 4
		outOffset += groupBytes
		written += groupBytes

		if groupBytes < 3 and inOffset < textLength then
			return nil --padding in the middle
		end
	end

	return written
end

--[[
	@param source buffer -- The bytes to encode.

	@return string -- The bytes as base64 text.
]]
function Transport.Encode(source: buffer): string
	return encode(source, 0, buffer.len(source))
end

--[[
	@param text string -- base64 text.

	@return buffer? -- The decoded bytes, or nil when the text is not valid base64.
]]
function Transport.Decode(text: string): buffer?
	if #text % 4 ~= 0 then
		return nil
	end

	local padding = if string.sub(text, -2) == "==" then 2 elseif string.sub(text, -1) == "=" then 1 else 0
	local total = #text // 4 * 3 - padding

	local result = buffer.create(total)
	if decode(text, result, 0) ~= total then
		return nil
	end

	return result
end

------------------------------------------------------------------------------------------------------------------------
--PUBLISHING------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[[
	@param schemaBuffer buffer -- The schema to publish.

	Publishes the schema so clients can read it. Call once on the server.

	The schema goes into one string attribute, which replicates with the place. A RemoteFunction next to it hands out
	the compressed buffer to a client that could not read the attribute, for example when NextGenerationReplication limits
	string attributes, so the attribute is the fast path and never the only one.
]]
function Transport.Publish(schemaBuffer: buffer)
	local container = Instance.new("Configuration")
	container.Name = CONTAINER_NAME
	Owned.Mark(container)

	--the remote below hands out the same compressed bytes, so the fallback is as small as the attribute
	local compressed = Compression.Compress(schemaBuffer)
	local text = Transport.Encode(compressed)
	container:SetAttribute(SCHEMA_ATTRIBUTE, text)

	if container:GetAttribute(SCHEMA_ATTRIBUTE) ~= text then
		container:SetAttribute(SCHEMA_ATTRIBUTE, nil)
		FormatMessage.Warn(
			`Roblox did not store the {#text} character schema attribute, so every client will ask the server for the schema instead.`
		)
	end

	local requestCounts: { [Player]: number } = {}

	local request = Instance.new("RemoteFunction")
	request.Name = REQUEST_NAME
	Owned.Mark(request)
	request.OnServerInvoke = function(player: Player): buffer?
		--a client needs the schema once; the limit stops a client from making the server send it over and over
		local count = (requestCounts[player] or 0) + 1
		requestCounts[player] = count

		return if count <= MAX_REQUESTS_PER_PLAYER then compressed else nil
	end
	request.Parent = container

	Players.PlayerRemoving:Connect(function(player: Player)
		requestCounts[player] = nil
	end)

	--parented last so the attribute and the remote replicate with it
	container.Parent = SoundService
end

--[[
	Decodes the attribute's text, or returns nil when it is missing, cut short or damaged.
]]
local function readAttribute(container: Instance): buffer?
	local text = container:GetAttribute(SCHEMA_ATTRIBUTE)
	if type(text) ~= "string" then
		return nil
	end

	local compressed = Transport.Decode(text)
	if not compressed then
		return nil
	end

	local success, result = pcall(Compression.Decompress, compressed)

	return if success then result else nil
end

--[[
	@yields

	Asks the server for the compressed schema and decompresses it, giving up at the deadline.
]]
local function requestSchema(container: Instance, deadline: number): buffer?
	local request = Owned.WaitFor(container, REQUEST_NAME, "RemoteFunction", deadline) :: RemoteFunction?
	if not request then
		return nil
	end

	local thread = coroutine.running()
	local done = false

	local function finish(result: buffer?)
		if done then
			return
		end
		done = true

		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, result)
		end
	end

	task.spawn(function()
		local success, result = pcall(request.InvokeServer, request)
		if not success or type(result) ~= "buffer" then
			finish(nil)

			return
		end

		local decompressed, schemaBuffer = pcall(Compression.Decompress, result)
		finish(if decompressed then schemaBuffer else nil)
	end)
	local timer = task.delay(math.max(deadline - os.clock(), 0), finish, nil)

	local result = coroutine.yield()

	if coroutine.status(timer) == "suspended" then
		task.cancel(timer)
	end

	return result
end

--[[
	@yields

	@param deadline number -- The os.clock() time to give up at.

	@return buffer? -- The schema the server published, or nil when it did not arrive before the deadline.
	@return string? -- Why it did not arrive.

	Reads the published schema from its attribute, or asks the server for it when the attribute cannot be read. The
	attribute is left as it is, so a second reader on this client (another copy of the library, a tool) still finds
	it. Call once on the client.
]]
function Transport.Receive(deadline: number): (buffer?, string?)
	local container = Owned.WaitFor(SoundService, CONTAINER_NAME, "Configuration", deadline)
	if not container then
		return nil, "the server did not publish the schema in time. Check the server output for a VluxySF warning."
	end

	local schemaBuffer = readAttribute(container)
	if schemaBuffer then
		return schemaBuffer
	end

	schemaBuffer = requestSchema(container, deadline)
	if not schemaBuffer then
		return nil, "the schema attribute could not be read and the server did not answer a request for it in time."
	end

	return schemaBuffer
end

return Transport
