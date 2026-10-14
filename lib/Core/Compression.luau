--!strict
--!native
--!optimize 2

--[[
	LZ4-style block compression, built for speed over ratio.

	There is no entropy coding: the output is runs of literal bytes and back references to bytes already written, so
	decompressing is mostly buffer.copy. Layout:

		u32 uncompressed length
		sequences, each: token byte, extra literal length bytes, literals, u16 match offset, extra match length bytes

	The token's high 4 bits are the literal length and its low 4 bits the match length minus 4. A nibble of 15 means
	the length continues in the following bytes, each adding up to 255, ending at the first byte under 255. The last
	sequence has literals only.
]]

local MIN_MATCH = 4
local MAX_OFFSET = 0xFFFF

--The last bytes are always literals, so a match never has to be checked past the end.
local END_LITERALS = 5

--2^16 slots of u32 positions.
local HASH_BITS = 16
local HASH_SIZE = 2 ^ HASH_BITS
local HASH_SHIFT = 2 ^ (32 - HASH_BITS)

local Compression = {}

------------------------------------------------------------------------------------------------------------------------

local function writeLength(target: buffer, offset: number, length: number): number
	while length >= 255 do
		buffer.writeu8(target, offset, 255)
		offset += 1
		length -= 255
	end

	buffer.writeu8(target, offset, length)

	return offset + 1
end

local function readLength(source: buffer, offset: number, length: number): (number, number)
	while true do
		local byte = buffer.readu8(source, offset)
		offset += 1
		length += byte

		if byte ~= 255 then
			return length, offset
		end
	end
end

--[[
	Writes one sequence: the literals from source[literalStart, literalStart + literalLength), then a match of
	matchLength bytes at matchOffset back, or no match when matchLength is 0. Returns the new output offset.
]]
local function writeSequence(
	out: buffer,
	at: number,
	source: buffer,
	literalStart: number,
	literalLength: number,
	matchOffset: number,
	matchLength: number
): number
	local literalNibble = if literalLength >= 15 then 15 else literalLength
	local matchNibble = 0
	if matchLength > 0 then
		matchNibble = if matchLength - MIN_MATCH >= 15 then 15 else matchLength - MIN_MATCH
	end

	buffer.writeu8(out, at, literalNibble * 16 + matchNibble)
	at += 1

	if literalNibble == 15 then
		at = writeLength(out, at, literalLength - 15)
	end

	buffer.copy(out, at, source, literalStart, literalLength)
	at += literalLength

	if matchLength > 0 then
		buffer.writeu16(out, at, matchOffset)
		at += 2

		if matchNibble == 15 then
			at = writeLength(out, at, matchLength - MIN_MATCH - 15)
		end
	end

	return at
end

------------------------------------------------------------------------------------------------------------------------

--[[
	@param source buffer -- The bytes to compress.

	@return buffer -- The compressed bytes.
]]
function Compression.Compress(source: buffer): buffer
	local length = buffer.len(source)

	--worst case: everything is literals, plus the length bytes and the header
	local out = buffer.create(4 + length + length // 255 + 16)
	buffer.writeu32(out, 0, length)
	local at = 4

	--positions + 1, so 0 means empty
	local hashTable = buffer.create(HASH_SIZE * 4)

	local anchor = 0
	local position = 0
	local matchLimit = length - END_LITERALS
	local searchLimit = matchLimit - MIN_MATCH

	while position <= searchLimit do
		local sequence = buffer.readu32(source, position)
		local slot = (sequence * 2654435761 % 4294967296) // HASH_SHIFT * 4

		local candidate = buffer.readu32(hashTable, slot) - 1
		buffer.writeu32(hashTable, slot, position + 1)

		if candidate >= 0 and position - candidate <= MAX_OFFSET and buffer.readu32(source, candidate) == sequence then
			local matchLength = MIN_MATCH
			local maxLength = matchLimit - position

			while
				matchLength + 4 <= maxLength
				and buffer.readu32(source, candidate + matchLength)
					== buffer.readu32(source, position + matchLength)
			do
				matchLength += 4
			end
			while
				matchLength < maxLength
				and buffer.readu8(source, candidate + matchLength) == buffer.readu8(source, position + matchLength)
			do
				matchLength += 1
			end

			at = writeSequence(out, at, source, anchor, position - anchor, position - candidate, matchLength)

			position += matchLength
			anchor = position
		else
			position += 1
		end
	end

	at = writeSequence(out, at, source, anchor, length - anchor, 0, 0)

	local result = buffer.create(at)
	buffer.copy(result, 0, out, 0, at)

	return result
end

--[[
	@param source buffer -- Bytes made by Compress.

	@return buffer -- The original bytes. Errors when the bytes are damaged.
]]
function Compression.Decompress(source: buffer): buffer
	local sourceLength = buffer.len(source)
	local out = buffer.create(buffer.readu32(source, 0))

	local position = 4
	local at = 0

	while position < sourceLength do
		local token = buffer.readu8(source, position)
		position += 1

		local literalLength = token // 16
		if literalLength == 15 then
			literalLength, position = readLength(source, position, 15)
		end

		buffer.copy(out, at, source, position, literalLength)
		position += literalLength
		at += literalLength

		if position >= sourceLength then
			break
		end

		local matchOffset = buffer.readu16(source, position)
		position += 2

		local matchLength = token % 16
		if matchLength == 15 then
			matchLength, position = readLength(source, position, 15)
		end
		matchLength += MIN_MATCH

		local from = at - matchOffset
		if matchOffset == 0 or from < 0 then
			error("The compressed bytes are damaged: a match points before the start.")
		end

		--a match can overlap what it is writing (a repeating pattern), so copy in chunks no longer than the gap; the
		--gap doubles with every chunk
		local remaining = matchLength
		while remaining > 0 do
			local chunk = math.min(at - from, remaining)
			buffer.copy(out, at, out, from, chunk)
			at += chunk
			remaining -= chunk
		end
	end

	if at ~= buffer.len(out) then
		error("The compressed bytes are damaged: the length does not match.")
	end

	return out
end

return Compression
