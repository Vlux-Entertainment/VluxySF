--!strict
--!native
--!optimize 2

--[[
	Gets the schema buffer from the server to every client without a request.

	The server base64-encodes the buffer in chunks and stores each chunk in a StringValue under the library module.
	Those replicate to every client as part of joining, so the client just waits for them and decodes them back into
	one buffer. Nothing is serialized per player and no remote round trip happens.

	Base64 is used because replicated string properties are not binary safe: a raw buffer string is cut at its first
	zero byte. Text survives.
]]

local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)

local FOLDER_NAME = "VluxySF_Schema"
local FORMAT = "base64"

--raw bytes per chunk, a multiple of 3 so every chunk encodes without padding except the last
local CHUNK_SIZE = 48 * 1024

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local PAD = string.byte("=")

local library = script.Parent.Parent

local encodeTable: { number } = table.create(64)
local decodeTable: { number } = table.create(256, -1)
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

------------------------------------------------------------------------------------------------------------------------
--PUBLISHING------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

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

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	for index = 1, chunkCount do
		local start = (index - 1) * CHUNK_SIZE
		local length = math.min(CHUNK_SIZE, total - start)

		local chunk = Instance.new("StringValue")
		chunk.Name = tostring(index)
		chunk.Value = encode(schemaBuffer, start, length)
		chunk.Parent = folder
	end

	folder:SetAttribute("Size", total)
	folder:SetAttribute("Chunks", chunkCount)
	folder:SetAttribute("Format", FORMAT)

	folder.Parent = library
end

--[[
	@yields

	@return buffer -- The schema the server published.

	Waits for the published schema to replicate and decodes its chunks back into one buffer. Call once on the client.
]]
function Transport.Receive(): buffer
	local folder = library:WaitForChild(FOLDER_NAME)

	while folder:GetAttribute("Chunks") == nil do
		folder.AttributeChanged:Wait()
	end

	local total = folder:GetAttribute("Size") :: number
	local chunkCount = folder:GetAttribute("Chunks") :: number
	local format = folder:GetAttribute("Format")

	if format ~= FORMAT then
		FormatMessage.Error(
			`The schema was published in format "{tostring(format)}" but this client reads "{FORMAT}". The server and client are running different versions of VluxySF.`
		)
	end

	local result = buffer.create(total)
	local cursor = 0

	for index = 1, chunkCount do
		local chunk = folder:WaitForChild(tostring(index)) :: StringValue

		local written = decode(chunk.Value, result, cursor)
		if not written then
			FormatMessage.Error(`The schema arrived damaged: chunk {index} of {chunkCount} is not valid base64.`)
		end

		cursor += written :: number
	end

	if cursor ~= total then
		FormatMessage.Error(`The schema arrived damaged: expected {total} bytes but got {cursor}.`)
	end

	return result
end

return Transport
