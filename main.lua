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
	DeclAssign = {},
	DeclEmptyLine = {},
	DeclBadAlign = {},
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

local function build_error(enum, line, col, dbg, xtr)
	return {
		type = enum,
		line = line,
		col = col,
		dbg = dbg,
		xtr = xtr,
	}	
end

local function parse_error(line)
	local cursor = string.len("Error ")
	local err_string = line:sub(line:find(':') + 2)
	local extra = {}
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
	elseif err_string:match(".+ is instanciated during declaration") then
		local var_name = err_string:match("(.+) is")
		err_type = EnumError.DeclAssign
		extra.var_name = var_name
	elseif err_string:match("declarations in .+ are bad aligned") then
		local fn_name = err_string:match("declarations in (.+) are bad aligned")
		err_type = EnumError.DeclBadAlign
		extra.fn_nme = fn_name
	end
	if line:match("Error %(line %d+, col %d+%)") then
		local linepos, curpos = line:find("%d+")
		linepos = tonumber(line:match("%d+"))
		curpos = tonumber(line:sub(curpos):match("%d+"))
		return build_error(err_type, linepos, colpos, err_string, extra)
	elseif line:match("Error %(line %d+%)") then
		local linepos = tonumber(line:match("%d+"))
		return build_error(err_type, linepos, nil, err_string, extra)
	elseif err_type then
		return build_error(err_type, nil, nil, err_string, extra)
	end
	return nil
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
				--error("bad error: " .. line, 2)
			end
		else
			print("Unknown line type: ", line)
		end
	end

	local newout = {}
	local postproc = {}
	while true do
		local f = file:read("*l")
		if not f then
			break
		end
		table.insert(newout, f)
	end
	-- local errors
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
			-- lmao idc
		elseif type == EnumError.DeclAssign then
			local expression = newout[line]:match(".-%s*=%s*(.*);$")
			local offset = 1
			while (newout[line + offset]:match(".-%s*=.*;") or newout[line + offset]:match(".-%s+.-;")) do
				offset = offset + 1
			end
			local leading = newout[line]:match("%s*")
			newout[line] = newout[line]:gsub("(.-)%s*=.*;", "%1;") -- unfuck the declaration
			table.insert(postproc, {
				line = line + offset,
				text = leading .. err.xtr.var_name .. " = " .. expression .. ";"
			}) -- create seperate assignment
		--	table.insert(newout, line + offset, leading .. err.xtr.var_name .. " = " .. expression .. ";") -- create the seperate assignment
		else
			newout[line] = newout[line] .. string.format(" /* uNhAndLEd: %s */", err.dbg)
		end
	end
	for _, pp in pairs(postproc) do
		newout[pp.line] = newout[pp.line] .. '\n' .. pp.text
	end
	-- global errors
	for _, err in pairs(errors) do
		local type = err.type
		local line = err.line
		if type == EnumError.DeclBadAlign then
			newout[line] = newout[line] .. "/* UnhAndLeD */"
		end
	end
	local source = table.concat(newout, "\n")
	source = source:gsub("%s*$", "")
	return source
end

print(process_norminette(file_name))