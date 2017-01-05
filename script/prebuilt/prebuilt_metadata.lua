local w3xparser = require 'w3xparser'
local slk = w3xparser.slk

local type = type
local string_char = string.char
local pairs = pairs
local ipairs = ipairs

local misc_names

local typedefine
local function get_typedefine(w2l, type)
    if not typedefine then
        typedefine = w2l:parse_lni(io.load(w2l.defined / 'typedefine.ini'))
    end
    return typedefine[type:lower()] or 3
end

local function sortpairs(t)
    local sort = {}
    for k, v in pairs(t) do
        sort[#sort+1] = {k, v}
    end
    table.sort(sort, function (a, b)
        return a[1] < b[1]
    end)
    local n = 1
    return function()
        local v = sort[n]
        if not v then
            return
        end
        n = n + 1
        return v[1], v[2]
    end
end

local function fmtstring(s)
    if s:find '[^%w_]' then
        return ('%q'):format(s)
    end
    return s
end

local function stringify2(inf, outf)
    for name, obj in sortpairs(inf) do
        outf[#outf+1] = ('[.%s]'):format(fmtstring(name))
        for k, v in sortpairs(obj) do
            outf[#outf+1] = ('%s = %s'):format(fmtstring(k), v)
        end
    end
end

local function stringify(inf, outf)
    for name, obj in sortpairs(inf) do
        if next(obj) then
            outf[#outf+1] = ('[%s]'):format(fmtstring(name))
            stringify2(obj, outf)
            outf[#outf+1] = ''
        end
    end
end

local function string_misc(outf)
    outf[#outf+1] = '[misc_names]'
    for k, v in sortpairs(misc_names) do
        outf[#outf+1] = ('%s = %s'):format(k, v)
    end
end

local function stringify_ex(inf)
    local f = {}
    for _, type in ipairs {'ability', 'buff', 'unit', 'item', 'upgrade', 'doodad', 'destructable', 'misc'} do
        stringify({[type]=inf[type]}, f)
        inf[type] = nil
    end
    stringify(inf, f)
    string_misc(f)
    return table.concat(f, '\r\n')
end

local function is_enable(meta, type)
    if type == 'unit' then
        if meta.usehero == 1 or meta.useunit == 1 or meta.usebuilding == 1 or meta.usecreep == 1 then
            return true
        else
            return false
        end
    end
    if type == 'item' then
        if meta['useitem'] == 1 then
            return true
        else
            return false
        end
    end
    return true
end

local function parse_id(w2l, tmeta, id, meta, type, has_level)
    local key = meta.field
    local num  = meta.data
    local objs = meta.usespecific or meta.section
    if num and num ~= 0 then
        key = key .. string_char(('A'):byte() + num - 1)
    end
    if meta._has_index then
        key = key .. ':' .. (meta.index + 1)
    end
    local data = {
        ['id'] = id,
        ['key'] = meta.field:lower(),
        ['type'] = get_typedefine(w2l, meta.type),
        ['field'] = key,
        ['repeat'] = has_level and meta['repeat'] > 0 and meta['repeat'] or nil,
        ['appendindex'] = meta.appendindex == 1 and true or nil,
        ['displayname'] = meta.displayname,
    }
    if meta.type:sub(-4) == 'List' or meta.type:sub(-5) == 'Table' then
        data.concat = true
    end
    if meta.index == -1 and data.type == 3 and not data.concat then
        data.splite = true
    end
    if meta._has_index then
        data.index = meta.index + 1
    end
    local lkey = key:lower()
    if objs then
        for name in objs:gmatch '%w+' do
            if not tmeta[name] then
                tmeta[name] = {}
            end
            tmeta[name][lkey] = data
            if type == 'misc' then
                misc_names[name] = true
            end
        end
    else
        tmeta[type][lkey] = data
    end
end

local function create_meta(w2l, type, tmeta)
    tmeta[type] = {}
    local has_level = w2l.info.key.max_level[type]
    local filepath = w2l.mpq / w2l.info['metadata'][type]
    local tbl = slk(io.load(filepath))
    local has_index = {}
    for k, v in pairs(tbl) do
        -- 进行部分预处理
        local name  = v['field']
        local index = v['index']
        if index and index >= 1 then
            has_index[name] = true
        end
    end
    for k, v in pairs(tbl) do
        local name = v['field']
        if has_index[name] then
            v._has_index = true
        end
    end
    for id, meta in pairs(tbl) do
        if is_enable(meta, type) then
            parse_id(w2l, tmeta, id, meta, type, has_level)
        end
    end
end

local function copy_code(t, template)
    for name, d in pairs(template) do
        local code = d.code
        local data = t[name]
        if data then
            t[name] = nil
            if t[code] then
                for k, v in pairs(data) do
                    local dest = t[code][k]
                    if dest then
                        if v.id ~= dest.id then
                            message('id不同:', k, 'skill:', name, v.id, 'code:', code, dest.id)
                        end
                    else
                        t[code][k] = v
                    end
                end
            else
                t[code] = {}
                for k, v in pairs(data) do
                    t[code][k] = v
                end
            end
        end
    end
end

return function(w2l)
    misc_names = {}
    local tmeta = {}
    for _, type in ipairs {'ability', 'buff', 'unit', 'item', 'upgrade', 'doodad', 'destructable', 'misc'} do
        create_meta(w2l, type, tmeta)
    end
    local template = w2l:parse_slk(io.load(w2l.mpq / w2l.info.slk.ability[1]))
    copy_code(tmeta, template)
    io.save(w2l.defined / 'metadata.ini', stringify_ex(tmeta))
end