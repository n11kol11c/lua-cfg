local cfg = {}
cfg.__index = cfg

local function newCfg()
    return setmetatable({
        sets        = {},
        resources   = {},
        exec        = {},
        aces        = {},
        principals  = {},
        lines       = {},
        raw         = {},
    }, cfg)
end

function cfg.open(path)
    if type(path) ~= "string" then
        return nil, "Path must be a string"
    end
    local f, err = io.open(path, "r")
    if not f then return nil, err end
    return f
end

function cfg.parse(path)
    local _cfg = newCfg()

    for line in io.lines(path) do
        table.insert(_cfg.lines, line)

        local stripped = line:match("^%s*(.-)%s*$")
        if stripped ~= "" and not stripped:match("^#") then

            local set_type, key, value = stripped:match("^(set[rab]?)%s+([%w_%.]+)%s+(.+)$")
            if set_type then
                _cfg.sets[key] = { type = set_type, value = value:gsub('"', "") }
                goto continue
            end

            local res_cmd, res = stripped:match("^(ensure|start|stop)%s+([%w_%-]+)$")
            if res_cmd then
                table.insert(_cfg.resources, { cmd = res_cmd, name = res })
                goto continue
            end

            local exec_file = stripped:match("^exec%s+(.+)$")
            if exec_file then
                table.insert(_cfg.exec, exec_file)
                goto continue
            end

            local ace = stripped:match("^add_ace%s+(.+)$")
            if ace then
                table.insert(_cfg.aces, ace)
                goto continue
            end

            local principal = stripped:match("^add_principal%s+(.+)$")
            if principal then
                table.insert(_cfg.principals, principal)
                goto continue
            end

            table.insert(_cfg.raw, stripped)
        end
        ::continue::
    end

    return _cfg
end

function cfg.write(path, cfgObj)
    local f = assert(io.open(path, "w"))

    for key, entry in pairs(cfgObj.sets) do
        f:write(string.format('%s %s "%s"\n', entry.type, key, entry.value))
    end

    for _, r in ipairs(cfgObj.resources) do
        f:write(string.format("%s %s\n", r.cmd, r.name))
    end

    for _, e in ipairs(cfgObj.exec) do
        f:write("exec " .. e .. "\n")
    end

    for _, a in ipairs(cfgObj.aces) do
        f:write("add_ace " .. a .. "\n")
    end

    for _, p in ipairs(cfgObj.principals) do
        f:write("add_principal " .. p .. "\n")
    end

    for _, r in ipairs(cfgObj.raw) do
        f:write(r .. "\n")
    end

    f:close()
end

function cfg:set(key, value)
    if not self.sets[key] then
        self.sets[key] = { type = "set", value = value }
    else
        self.sets[key].value = value
    end
end

function cfg:get(key)
    return self.sets[key] and self.sets[key].value
end

return cfg
