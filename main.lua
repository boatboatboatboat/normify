local file_name = arg[1];

local EnumWarning = {
	InvalidFile = {},
}

local EnumError = {
	ReturnNoParens = {},
	SpaceBeforeFunction = {},
	BadSpacing = {},
	EOLSpace = {},
	NoNewlineBeforeBlock = {},
	NoNewlineAfterBlock = {},
	SingleEmptyLine = {};
}

--[[

]]

function string.at(self, n)
	return self:sub(n, n)
end

local function is_error(line)
	return line:sub(1, 5) == "Error"
end

local function is_warning(line)
	return line:sub(1, 7) == "Warning"
end

local function is_file_id(line)
	return line:sub(1, 6) == "Norme:"
end

local function parse_file_id(line)
	return line:sub(8)
end

local function parse_warning(line)

end

local function build_error(enum, line, col, dbg)
	return {
		type = enum,
		line = line,
		col = col,
		dbg = dbg,
	}	
end

local function parse_error(line)
	local cursor = string.len("Error ")
	local err_string = line:sub(line:find(':') + 2)
	local err_type
	if err_string == "Space before function name" then
		err_type = EnumError.SpaceBeforeFunction
	elseif err_string == "bad spacing" then
		err_type = EnumError.BadSpacing
	elseif err_string == "missing parentheses in return statement" then
		err_type = EnumError.ReturnNoParens
	elseif err_string == "no newline before block" then
		err_type = EnumError.NoNewlineBeforeBlock
	elseif err_string == "spaces at the end of line" then
		err_type = EnumError.EOLSpace
	elseif err_string == "no newline after block" then
		err_type = EnumError.NoNewlineAfterBlock
	elseif err_string == "file must end with a single empty line" then
		err_type = EnumError.SingleEmptyLine
	end
	if line:match("Error %(line %d+, col %d+%)") then
		local linepos, curpos = line:find("%d+")
		linepos = tonumber(line:match("%d+"))
		curpos = tonumber(line:sub(curpos):match("%d+"))
		return build_error(err_type, linepos, colpos, err_string)
	elseif line:match("Error %(line %d+%)") then
		local linepos = tonumber(line:match("%d+"))
		return build_error(err_type, linepos, nil, err_string)
	elseif err_type then
		return build_error(err_type, nil, nil, err_string)
	end
	return nil
end

local function fix_error(err)

end

local function process_norminette(filename)
	local norm = io.popen("norminette " .. filename)
	local file, errors

	for	line in norm:lines() do
		--print("norminator: ", line)
		if is_file_id(line) then
			file = io.open(parse_file_id(line), "r")
			errors = {}
		elseif is_warning(line) then
			if line:match("Not a valid file") then
				print("file doesn't exist, very rude >:(")
				break
			end
		elseif is_error(line) then
			local err = parse_error(line)
			if err then
				table.insert(errors, err)
			else
				error("bad error: " .. line, 2)
			end
		else
			print("Unknown line type: ", line)
		end
	end

	local newout = {}
	while true do
		local f = file:read("*l")
		if not f then
			break
		end
		table.insert(newout, f)
	end
	local SEL = false;
	for _, err in pairs(errors) do
		local type = err.type
		local line = err.line
		if type == EnumError.SpaceBeforeFunction then
			newout[line] = newout[line]:gsub("%s+", "\t")
		elseif type == EnumError.NoNewlineBeforeBlock then
			newout[line] = newout[line]:gsub("%s*{", "\n{")
		elseif type == EnumError.ReturnNoParens then
			newout[line] = newout[line]:gsub("return (.);", "return %(%1%);")
		elseif type == EnumError.EOLSpace then
			newout[line] = newout[line]:gsub("%s*$", "")
		elseif type == EnumError.BadSpacing then
			-- lmao idc
		elseif type == EnumError.NoNewlineAfterBlock then
			newout[line] = newout[line]:gsub("%s*", "") .. '\n'
		elseif type == EnumError.SingleEmptyLine then
			SEL = true
		end
	end
	repeat
		local a = file:read("*l")
		if a then
			table.insert(newout, a)
		end
	until not a
	local source = table.concat(newout, "\n")
	source = source:gsub("%s*$", "")
	return source
end

print(process_norminette(file_name))