--!strict
--!native
--!optimize 2

--[[
	Gets the schema buffer from the server to every client without a request.

	The server compresses the buffer (Compression, LZ4-style) and base64-encodes it into one string attribute on a Configuration in SoundService. It replicates
	to every client as part of joining, so the client just waits for it and decodes it. Nothing is serialized per
	player and no remote round trip happens.

	Base64 is used because buffer attributes are refused and replicated strings are not binary safe: a raw buffer
	string is cut at its first zero byte. Text survives.
]]

local SoundService = game:GetService("SoundService")

local Compression = require(script.Parent.Compression)
local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)

local CONTAINER_NAME = "VluxySF_Schema"
local SCHEMA_ATTRIBUTE = "Schema"

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local PAD = string.byte("=")

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
]]
function Transport.Publish(schemaBuffer: buffer)
	if SoundService:FindFirstChild(CONTAINER_NAME) then
		FormatMessage.Error("The schema was already published! Startup.InitServer should only run once.", 4)
	end

	local text = Transport.Encode(Compression.Compress(schemaBuffer))

	local container = Instance.new("Configuration")
	container.Name = CONTAINER_NAME
	container:SetAttribute(SCHEMA_ATTRIBUTE, text)

	--a refused or shortened attribute would leave every client without a schema, so fail here where it is visible
	if container:GetAttribute(SCHEMA_ATTRIBUTE) ~= text then
		container:Destroy()
		FormatMessage.Error(
			`Roblox did not store the {#text} character schema attribute. Attribute limits may have changed; VluxySF needs an update.`,
			4
		)
	end

	--parented last so the attribute replicates with it
	container.Parent = SoundService
end

--[[
	@yields

	@return buffer -- The schema the server published.

	Waits for the published schema to replicate and decodes it. The attribute is then cleared on this client so the
	text does not stay in memory. Call once on the client.
]]
function Transport.Receive(): buffer
	local container = SoundService:WaitForChild(CONTAINER_NAME)

	local text = container:GetAttribute(SCHEMA_ATTRIBUTE)
	while text == nil do
		container:GetAttributeChangedSignal(SCHEMA_ATTRIBUTE):Wait()
		text = container:GetAttribute(SCHEMA_ATTRIBUTE)
	end

	local compressed = if type(text) == "string" then Transport.Decode(text) else nil
	if not compressed then
		FormatMessage.Error("The schema arrived damaged: it is not valid base64.")
	end

	local success, result = pcall(Compression.Decompress, compressed :: buffer)
	if not success then
		FormatMessage.Error(`The schema arrived damaged: {result}`)
	end

	--a local change only; the server keeps its copy for players who join later
	container:SetAttribute(SCHEMA_ATTRIBUTE, nil)

	return result :: buffer
end

return Transport
