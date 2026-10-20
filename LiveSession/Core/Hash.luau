local Constants = require(script.Parent.Constants)

local Hash = {}

local HASH = Constants.HASH
local PRIME_SHIFT = HASH.PRIME_SHIFT
local PRIME_REMAINDER = HASH.PRIME_REMAINDER
local MODULO = HASH.MODULO
local BATCH_BYTES = HASH.WORDS_PER_BATCH * HASH.WORD_BYTES
local BATCH_FORMAT = string.rep(HASH.WORD_FORMAT, HASH.WORDS_PER_BATCH)

local function padToBatch(text)
	local remainder = #text % BATCH_BYTES
	if remainder == 0 then
		return text
	end
	return text .. string.rep(HASH.PADDING, BATCH_BYTES - remainder)
end

function Hash.text(text)
	local hash = bit32.bxor(HASH.OFFSET_BASIS, #text)
	local padded = padToBatch(text)
	local position = 1
	while position <= #padded do
		local words = { string.unpack(BATCH_FORMAT, padded, position) }
		position = table.remove(words)
		for _, word in ipairs(words) do
			local mixed = bit32.bxor(hash, word)
			hash = (bit32.lshift(mixed, PRIME_SHIFT) + mixed * PRIME_REMAINDER) % MODULO
		end
	end
	return string.format(HASH.FORMAT, hash)
end

return Hash
