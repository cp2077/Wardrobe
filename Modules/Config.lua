local Config = {
    ["data"] = {
        ["window"] = {
            ["winX"] = nil,
            ["winY"] = nil,
        },
        ["outfits"] = {}
    }
}

function RaiseError(msg)
    msg = ('[MUI] ' .. msg)
    print(msg)
    error(msg, 2)
end

local CONFIG_FILE_NAME = "config.lua"

function Config.InitConfig()
    local config = ReadConfig()
    if config == nil then
        WriteConfig()
    else
        Config.data = config
    end
end

function Config.SaveConfig()
    WriteConfig()
end

function WriteConfig()
    local sessionPath = CONFIG_FILE_NAME
    local sessionFile = io.open(sessionPath, 'w')

    if not sessionFile then
        RaiseError(('Cannot write session file %q.'):format(sessionPath))
    end

    sessionFile:write('return ')
    sessionFile:write(TableToString(Config.data))
    sessionFile:close()
end

function ReadConfig()
    local configPath = CONFIG_FILE_NAME
    local configChunk = loadfile(configPath)

    if type(configChunk) ~= 'function' then
        return nil
    end

    return configChunk()
end

function TableToString(t, max, depth)
	if type(t) ~= 'table' then
		return ''
	end

	max = max or 63
	depth = depth or 8

	local dumpStr = '{\n'
	local indent = string.rep('\t', depth)

	for k, v in pairs(t) do
		local ktype = type(k)
		local vtype = type(v)

		local kstr = ''
		if ktype == 'string' then
			kstr = string.format('[%q] = ', k)
		end

		local vstr = ''
		if vtype == 'string' then
			vstr = string.format('%q', v)
		elseif vtype == 'table' then
			if depth < max then
				vstr = TableToString(v, max, depth + 1)
			end
		elseif vtype == 'userdata' then
			vstr = tostring(v)
			if vstr:find('^userdata:') or vstr:find('^sol%.') then
                vstr = ''
			end
		elseif vtype == 'function' or vtype == 'thread' then
            --
		else
			vstr = tostring(v)
		end

		if vstr ~= '' then
			dumpStr = string.format('%s\t%s%s%s,\n', dumpStr, indent, kstr, vstr)
		end
	end

	return string.format('%s%s}', dumpStr, indent)
end	
return Config
