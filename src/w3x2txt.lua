local mt = {}

function mt:convert_wts(str, only_short, read_only)
	return str:gsub('TRIGSTR_(%d+)', function(i)
		local str_data = w3x2txt.wts_strings[i]
		if not str_data then
			return
		end
		local text = ('%q'):format(str_data.text):sub(2, -2)
		if only_short and #text > 256 then
			return
		end
		str_data.converted = not read_only
		return text
	end)
end

mt.meta_list = setmetatable({}, { __index = function(self, id)
	local value = 'string'
	if id:sub(-1) == '\0' then
		value = self[('z'):unpack(id)]
	end
	self[id] = value
	return value
end})

local value_type = {
	['int']          = 0,
	['bool']         = 0,
	['deathType']    = 0,
	['attackBits']   = 0,
	['teamColor']    = 0,
	['fullFlags']    = 0,
	['channelType']  = 0,
	['channelFlags'] = 0,
	['stackFlags']   = 0,
	['silenceFlags'] = 0,
	['spellDetail']  = 0,
	['real']         = 1,
	['unreal']       = 2,
}

local function main()
	-- 加载脚本
	local convertors = {
		'read_wts', 'fresh_wts',
		'obj2lni', 'lni2obj',
		'read_metadata',
	}
	
	for _, name in ipairs(convertors) do
		local func = require('impl.' .. name)
		mt[name] = function (self, ...)
			print(('正在执行:') .. name)
			return func(self, ...)
		end
	end

	mt.wts_strings = {}
end

main()

return mt
