string_utf8 = {}

dofile(core.get_modpath(core.get_current_modname()).."/utf8data.lua")

local byte    = string.byte
local char    = string.char
local len     = string.len
local sub     = string.sub

-- Ensure API
if Ensure ~= nil then
	arg_type = Ensure.argType
else
	arg_type = function(arg, expectedType, n, function_name) end
end

local utf8charpattern = '[%z\1-\127\194-\244][\128-\191]*'

--- Determines the length of a character in bytes encoded in UTF-8, based on the first byte of the character.
--- @param byte  number  First byte of a character.
--- @return      number
local function utf8symbollen(byte)
	arg_type(byte, "number", 1, "utf8symbollen")

	return not byte and 0 or (byte < 0x80 and 1) or (byte >= 0xF0 and 4) or (byte >= 0xE0 and 3) or (byte >= 0xC0 and 2) or 1
end

local head_table = {}

for i = 0, 255 do
	head_table[i] = utf8symbollen(i)
end
head_table[256] = 0

--- Returns the length of the character in bytes starting at position `pos` in the string `str` using the table `head_table`.
--- @param str  string  Input string.
--- @param bs   number  Position of character in line.
--- @return     number
local function utf8charbytes(str, bs)
	arg_type(str, "string", 1, "utf8charbytes")
	arg_type(bs, "number", 2, "utf8charbytes")

	assert(#str ~= 0, 'bad argument #1 to \'utf8charbytes\' (string cannot be empty)')

	return head_table[byte(str, bs) or 256]
end

--- Returns the new position in the string `str`, skipping the current character.
--- @param str  string  Input string.
--- @param bs   number  Position of character in line.
--- @return     number
local function utf8next(str, bs)
	arg_type(str, "string", 1, "utf8next")
	arg_type(bs, "number", 2, "utf8next")

	assert(#str ~= 0, 'bad argument #1 to \'utf8next\' (string cannot be empty)')

	return bs + utf8charbytes(str, bs)
end

--- Returns the number of characters in a UTF-8 string
--- @param str  string  Input string.
--- @return     number
function string_utf8.len(str)
	arg_type(str, "string", 1, "string_utf8.len")

	assert(#str ~= 0, 'bad argument #1 to \'string_utf8.len\' (string cannot be empty)')

	local bs = 1
	local bytes = len(str)
	local length = 0

	while bs <= bytes do
		length = length + 1
		bs = utf8next(str, bs)
	end

	return length
end


--- Functions identically to `string.sub` except that `i` and `j` are UTF-8 characters instead of bytes.
--- @param str  string  Input string.
--- @param i    number  The starting character index (default: 1). Negative values count from the end.
--- @param j    number  The ending character index (default: i). Negative values count from the end.
--- @overload   fun(s: string, i: number)
--- @return     string
function string_utf8.sub(str, i, j)
	j = j or -1

	arg_type(str, "string", 1, "string_utf8.sub")
	arg_type(i, "number", 2, "string_utf8.sub")
	arg_type(j, "number", 3, "string_utf8.sub")

	assert(#str ~= 0, 'bad argument #1 to \'string_utf8.sub\' (string cannot be empty)')

	local bs = 1
	local bytes = len(str)
	local length = 0

	local l = (i >= 0 and j >= 0) or string_utf8.len(str)
	i = (i >= 0) and i or l + i + 1
	j = (j >= 0) and j or l + j + 1

	if i > j then
		return ""
	end

	local start, finish = 1, bytes

	while bs <= bytes do
		length = length + 1

		if length == i then
			start = bs
		end

		bs = utf8next(str, bs)

		if length == j then
			finish = bs - 1
			break
		end
	end

	if i > length then start = bytes + 1 end
	if j < 1 then finish = 0 end

	return sub(str, start, finish)
end

--- Returns a UTF-8 string from the given Unicode codes.
--- @param ...  number  List of Unicode codes.
--- @return     string
function string_utf8.char(...)
	local codes = {...}

	assert(codes ~= {}, 'bad argument #1 to \'string_utf8.char\' (key cannot be nil)')

	--- @type int[]
	local result = {}

	for _, unicode in ipairs(codes) do

		if unicode <= 0x7F then
			result[#result + 1] = unicode
		elseif unicode <= 0x7FF then
			local b0 = 0xC0 + math.floor(unicode / 0x40);
			local b1 = 0x80 + (unicode % 0x40);
			result[#result + 1] = b0
			result[#result + 1] = b1
		elseif unicode <= 0xFFFF then
			local b0 = 0xE0 +	math.floor(unicode / 0x1000);
			local b1 = 0x80 + (math.floor(unicode / 0x40) % 0x40);
			local b2 = 0x80 + (unicode % 0x40);
			result[#result + 1] = b0
			result[#result + 1] = b1
			result[#result + 1] = b2
		elseif unicode <= 0x10FFFF then
			local code = unicode
			local b3 = 0x80 + (code % 0x40);
			code = math.floor(code / 0x40)
			local b2 = 0x80 + (code % 0x40);
			code = math.floor(code / 0x40)
			local b1 = 0x80 + (code % 0x40);
			code = math.floor(code / 0x40)
			local b0 = 0xF0 + code;

			result[#result + 1] = b0
			result[#result + 1] = b1
			result[#result + 1] = b2
			result[#result + 1] = b3
		else
			error 'Unicode cannot be greater than U+10FFFF!'
		end

	end

	return char(unpack(result, 1, #result))
end

local shift_6  = 16      -- 2^6
local shift_12 = 4096    -- 2^12
local shift_18 = 262144  -- 2^18

--- Converts UTF-8 encoded characters in a string to their corresponding Unicode code points.
--- @param str  string  The input string containing UTF-8 encoded characters.
--- @param ibs  number  The starting byte position in the string (inclusive).
--- @param jbs  number  The ending byte position in the string (inclusive).
--- @return     number | number...
function string_utf8.unicode(str, ibs, jbs)
	arg_type(str, "string", 1, "string_utf8.unicode")
	arg_type(ibs, "number", 2, "string_utf8.unicode")
	arg_type(jbs, "number", 3, "string_utf8.unicode")

	assert(ibs < jbs, 'bad arguments #2 & #3 to \'string_utf8.unicode\' (#2 cannot be more #3)')
	assert(#str ~= 0, 'bad argument #1 to \'string_utf8.unicode\' (string cannot be empty)')

	local bytes

	bytes = utf8charbytes(str, ibs)
	if bytes == 0 then return end

	local unicode

	if bytes == 1 then unicode = byte(str, ibs, ibs) end
	if bytes == 2 then
		local byte0,byte1 = byte(str, ibs, ibs + 1)
		if byte0 and byte1 then
			local code0,code1 = byte0-0xC0,byte1-0x80
			unicode = code0*shift_6 + code1
		else
			unicode = byte0
		end
	end
	if bytes == 3 then
		local byte0,byte1,byte2 = byte(str, ibs, ibs + 2)
		if byte0 and byte1 and byte2 then
			local code0,code1,code2 = byte0-0xE0,byte1-0x80,byte2-0x80
			unicode = code0*shift_12 + code1*shift_6 + code2
		else
			unicode = byte0
		end
	end
	if bytes == 4 then
		local byte0,byte1,byte2,byte3 = byte(str, ibs, ibs + 3)
		if byte0 and byte1 and byte2 and byte3 then
			local code0,code1,code2,code3 = byte0-0xF0,byte1-0x80,byte2-0x80,byte3-0x80
			unicode = code0*shift_18 + code1*shift_12 + code2*shift_6 + code3
		else
			unicode = byte0
		end
	end

	if ibs == jbs then
		return unicode
	else
		return unicode, string_utf8.unicode(str, ibs+bytes, jbs)
	end
end

--- Returns Unicode code points for characters in a UTF-8 string within the specified range.
--- @param str  string  The input UTF-8 encoded string.
--- @param i    number  The starting character index (default: 1). Negative values count from the end.
--- @param j    number  The ending character index (default: i). Negative values count from the end.
--- @overload   fun(str: string)
--- @overload   fun(str: string, i: number)
--- @return     number | number...
function string_utf8.byte(str, i, j)
	arg_type(str, "string", 1, "string_utf8.byte")
	arg_type(i, "number", 2, "string_utf8.byte")
	arg_type(j, "number", 3, "string_utf8.byte")

	assert(#str ~= 0, 'bad argument #1 to \'string_utf8.byte\' (string cannot be empty)')

	local ibs, jbs

	if i or j then
		i = i or 1
		j = j or i

		local str_len = string_utf8.len(str)
		i = i < 0 and str_len + i + 1 or i
		j = j < 0 and str_len + j + 1 or j
		j = j > str_len and str_len or j

		if i > j then return end

		for p = 1, i - 1 do
			ibs = utf8next(str, ibs or 1)
		end

		if i == j then
			jbs = ibs
		else
			for p = 1, j - 1 do
				jbs = utf8next(str, jbs or 1)
			end
		end

		if not ibs or not jbs then
			return nil
		end
	else
		ibs, jbs = 1, 1
	end

	return string_utf8.unicode(str, ibs, jbs)
end

--- Creates an iterator to generate UTF-8 substrings of a specified length.
--- @param str       string  The input UTF-8 encoded string.
--- @param sub_len?  number  The length of each substring in characters (default: 1).
--- @return          fun(skip_ptr: table | nil, bs: number | nil)
function string_utf8.gensub(str, sub_len)
	sub_len = sub_len or 1

	arg_type(str, "string", 1, "string_utf8.gensub")
	arg_type(sub_len, "number", 2, "string_utf8.gensub")

	assert(#str ~= 0, 'bad argument #1 to \'string_utf8.gensub\' (string cannot be empty)')

	local max_len = #str

	return function(skip_ptr, bs)
		bs = (bs and bs or 1) + (skip_ptr and (skip_ptr[1] or 0) or 0)

		local nbs = bs
		if bs > max_len then return nil end
		for i = 1, sub_len do
			nbs = utf8next(str, nbs)
		end

		return nbs, sub(str, bs, nbs - 1), bs
	end
end

--- Reverses a UTF-8 encoded string while preserving multi-byte characters.
--- @param str  string  The input UTF-8 encoded string.
--- @return     string
function string_utf8.reverse(str)
	arg_type(str, "string", 1, "string_utf8.reverse")

	local result = ''

	for _, w in string_utf8.gensub(str) do
		result = w .. result
	end

	return result
end

--- Validates UTF-8 encoded characters in a string starting from a given byte position.
--- @param str  string  The input UTF-8 encoded string to validate.
--- @param bs   number  The starting byte position for validation (default: 1).
--- @overload   fun(str: string)
--- @return     number?
local function utf8validator(str, bs)
	bs = bs or 1

	arg_type(str, "string", 1, "utf8validator")
	arg_type(bs, "number", 2, "utf8validator")

	assert(#str ~= 0, 'bad argument #1 to \'utf8validator\' (string cannot be empty)')

	local c = byte(str, bs)

	if not c then return end

	-- determine bytes needed for character, based ons RFC 3629

	-- UTF8-1
	if c >= 0 and c <= 127 then
		return bs + 1
	elseif c >= 128 and c <= 193 then
		return bs + 1, bs, 1, c
			-- UTF8-2
	elseif c >= 194 and c <= 223 then
		local c2 = byte(str, bs + 1)
		if not c2 or c2 < 128 or c2 > 191 then
			return bs + 2, bs, 2, c2
		end

		return bs + 2
			-- UTF8-3
	elseif c >= 224 and c <= 239 then
		local c2 = byte(str, bs + 1)

		if not c2 then
			return bs + 2, bs, 2, c2
		end

		-- validate byte 2
		if c == 224 and (c2 < 160 or c2 > 191) then
			return bs + 2, bs, 2, c2
		elseif c == 237 and (c2 < 128 or c2 > 159) then
			return bs + 2, bs, 2, c2
		elseif c2 < 128 or c2 > 191 then
			return bs + 2, bs, 2, c2
		end

		local c3 = byte(str, bs + 2)
		if not c3 or c3 < 128 or c3 > 191 then
			return bs + 3, bs, 3, c3
		end

		return bs + 3
			-- UTF8-4
	elseif c >= 240 and c <= 244 then
		local c2 = byte(str, bs + 1)

		if not c2 then
			return bs + 2, bs, 2, c2
		end

		-- validate byte 2
		if c == 240 and (c2 < 144 or c2 > 191) then
			return bs + 2, bs, 2, c2
		elseif c == 244 and (c2 < 128 or c2 > 143) then
			return bs + 2, bs, 2, c2
		elseif c2 < 128 or c2 > 191 then
			return bs + 2, bs, 2, c2
		end

		local c3 = byte(str, bs + 2)
		if not c3 or c3 < 128 or c3 > 191 then
			return bs + 3, bs, 3, c3
		end

		local c4 = byte(str, bs + 3)
		if not c4 or c4 < 128 or c4 > 191 then
			return bs + 4, bs, 4, c4
		end

		return bs + 4
	else -- c > 245
		return bs + 1, bs, 1, c
	end
end

--- Validates a UTF-8 encoded string for correctness.
--- @param str        string  The input UTF-8 encoded string to validate.
--- @param byte_pos?  number  The starting byte position for validation (default: 1).
--- @return           boolean | table
function string_utf8.validate(str, byte_pos)
	byte_pos = byte_pos or 1

	arg_type(str, "string", 1, "string_utf8.validate")
	arg_type(byte_pos, "number", 2, "string_utf8.validate")

	assert(#str ~= 0, 'bad argument #1 to \'string_utf8.validate\' (string cannot be empty)')

	local result = {}

	for nbs, bs, part, code in utf8validator, str, byte_pos do
		if bs then
			result[#result + 1] = { pos = bs, part = part, code = code }
		end
	end
	return #result == 0, result
end

--- Creates an iterator to traverse UTF-8 encoded characters in a string.
--- @param str  string  The input UTF-8 encoded string.
--- @return     fun(skip_ptr: table|nil)
function string_utf8.codes(str)

	arg_type(str, "string", 1, "string_utf8.codes")

	assert(#str ~= 0, 'bad argument #1 to \'string_utf8.codes\' (string cannot be empty)')

	local max_len = #str
	local bs = 1
	return function(skip_ptr)
		if bs > max_len then return nil end
		local pbs = bs
		bs = utf8next(str, pbs)

		return pbs, string_utf8.unicode(str, pbs, pbs), pbs
	end
end


--[[
differs from Lua 5.3 utf8.offset in accepting any byte positions (not only head byte) for all n values

h - head, c - continuation, t - tail
hhhccthccthccthcthhh
        ^ start byte pos
searching current charracter head by moving backwards
hhhccthccthccthcthhh
      ^ head

n == 0: current position
n > 0: n jumps forward
n < 0: n more scans backwards
--]]

--- Finds the byte position of the `n`-th UTF-8 character in a string, starting from a given byte position.
--- @param str  string  The input UTF-8 encoded string.
--- @param n    number  The character index to find. If `n` is negative, counts from the end.
--- @param bs   number  The starting byte position (default: 1 for positive `n`, end of string for negative `n`).
--- @overload   fun(str: string, n: number)
--- @return     number | nil
function string_utf8.offset(str, n, bs)
	local l = #str
	if not bs then
		if n < 0 then
			bs = l + 1
		else
			bs = 1
		end
	end

	arg_type(str, "string", 1, "string_utf8.offset")
	arg_type(n, "number", 2, "string_utf8.offset")
	arg_type(bs, "number", 3, "string_utf8.offset")

	assert(#str ~= 0, 'bad argument #1 to \'string_utf8.offset\' (string cannot be empty)')

	if bs <= 0 or bs > l + 1 then
		error("bad argument #3 to 'string_utf8.offset' (position out of range)")
	end

	if n == 0 then
		if bs == l + 1 then
			return bs
		end
		while true do
			local b = byte(str, bs)
			if (0 < b and b < 127)
			or (194 < b and b < 244) then
				return bs
			end
			bs = bs - 1
			if bs < 1 then
				return
			end
		end
	elseif n < 0 then
		bs = bs - 1
		repeat
			if bs < 1 then
				return
			end

			local b = byte(str, bs)
			if (0 < b and b < 127)
			or (194 < b and b < 244) then
				n = n + 1
			end
			bs = bs - 1
		until n == 0
		return bs + 1
	else
		while true do
			if bs > l then
				return
			end

			local b = byte(str, bs)
			if (0 < b and b < 127)
			or (194 < b and b < 244) then
				n = n - 1
				for i = 1, n do
					if bs > l then
						return
					end
					bs = utf8next(str, bs)
				end
				return bs
			end
			bs = bs - 1
		end
	end

end

--- Replaces UTF-8 characters in a string according to a mapping table.
--- @param str      string  The input UTF-8 encoded string.
--- @param mapping  table   A table where keys are UTF-8 characters (or patterns) and values are their replacements.
--- @return         string
function string_utf8.replace(str, mapping)
	arg_type(str, "string", 1, "string_utf8.replace")
	arg_type(mapping, "table", 2, "string_utf8.replace")

	assert(#str ~= 0, 'bad argument #1 to \'string_utf8.offset\' (string cannot be empty)')

	local result = string.gsub( str, utf8charpattern, mapping )
	return result
end

--- Converts all UTF-8 characters in a string to uppercase.
--- @param str  string  The input UTF-8 encoded string.
--- @return     string
function string_utf8.upper(str)
	arg_type(str, "string", 1, "string_utf8.upper")

	assert(#str ~= 0, 'bad argument #1 to \'string_utf8.upper\' (string cannot be empty)')

	return string_utf8.replace(str, string_utf8.lc_uc)
end

--- Converts all UTF-8 characters in a string to lowercase.
--- @param str  string  The input UTF-8 encoded string.
--- @return     string
function string_utf8.lower(str)
	arg_type(str, "string", 1, "string_utf8.lower")

	assert(#str ~= 0, 'bad argument #1 to \'string_utf8.lower\' (string cannot be empty)')

	return string_utf8.replace(str, string_utf8.uc_lc)
end
