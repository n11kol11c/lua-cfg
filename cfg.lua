local cfg = {}
cfg.__index = cfg

local function newCfg()
    return setmetatable({
        sets = {},
        resources = {},
        exec = {},
        aces = {},
        principals = {},
        lines = {},
        raw = {},
        _path = nil
    }, cfg)
end

function cfg.parse(path)
    local obj = newCfg()
    obj._path = path

    for line in io.lines(path) do
        table.insert(obj.lines, line)

        local stripped = line:match("^%s*(.-)%s*$")
        if stripped ~= "" and not stripped:match("^#") then

            local t, k, v = stripped:match("^(set[rab]?)%s+([%w_%.]+)%s+(.+)$")
            if t then
                local q = v:match('^".*"$') ~= nil
                local clean = v:gsub('^"(.*)"$', "%1")
                obj.sets[k] = { type = t, value = clean, quoted = q }
                goto continue
            end

            local rc, rn = stripped:match("^(ensure|start|stop)%s+([%w_%-]+)$")
            if rc then
                table.insert(obj.resources, { cmd = rc, name = rn })
                goto continue
            end

            local ef = stripped:match("^exec%s+(.+)$")
            if ef then
                table.insert(obj.exec, ef)
                goto continue
            end

            local ace = stripped:match("^add_ace%s+(.+)$")
            if ace then
                table.insert(obj.aces, ace)
                goto continue
            end

            local pr = stripped:match("^add_principal%s+(.+)$")
            if pr then
                table.insert(obj.principals, pr)
                goto continue
            end

            table.insert(obj.raw, stripped)
        end
        ::continue::
    end

    return obj
end

function cfg:set(key, value)
    value = tostring(value)

    if not self.sets[key] then
        self.sets[key] = { type = "set", value = value, quoted = false }
    else
        self.sets[key].value = value
    end

    local entry = self.sets[key]
    local out = entry.type .. " " .. key .. " " .. (entry.quoted and '"' .. entry.value .. '"' or entry.value)

    for i, line in ipairs(self.lines) do
        if line:match("^set[rab]?%s+" .. key) then
            self.lines[i] = out
            break
        end
    end
end

function cfg:get(key)
    return self.sets[key] and self.sets[key].value
end

function cfg:addResource(cmd, name)
    table.insert(self.resources, { cmd = cmd, name = name })
    table.insert(self.lines, cmd .. " " .. name)
end

function cfg:removeResource(name)
    for i = #self.resources, 1, -1 do
        if self.resources[i].name == name then
            table.remove(self.resources, i)
            break
        end
    end

    for i = #self.lines, 1, -1 do
        if self.lines[i]:match("%s" .. name .. "$") then
            table.remove(self.lines, i)
            break
        end
    end
end

function cfg:addExec(word, file)
    table.insert(self.exec, file)
    table.insert(self.lines, word .. " " .. file)
end

function cfg:removeExec(file)
    for i = #self.exec, 1, -1 do
        if self.exec[i] == file then
            table.remove(self.exec, i)
            break
        end
    end

    for i = #self.lines, 1, -1 do
        if self.lines[i] == "exec " .. file then
            table.remove(self.lines, i)
            break
        end
    end
end

function cfg:addAce(str)
    table.insert(self.aces, str)
    table.insert(self.lines, "add_ace " .. str)
end

function cfg:addPrincipal(str)
    table.insert(self.principals, str)
    table.insert(self.lines, "add_principal " .. str)
end

function cfg:save(path)
    local p = path or self._path
    local f = assert(io.open(p, "w"))

    for _, line in ipairs(self.lines) do
        f:write(line .. "\n")
    end

    f:close()
end

function cfg:ensure(name)
    self:addResource("ensure", name)
end

function cfg:start(name)
    self:addResource("start", name)
end

function cfg:stop(name)
    self:addResource("stop", name)
end

function cfg:sortResources()
    table.sort(self.resources, function(a, b)
        return a.name < b.name
    end)

    local new = {}
    for _, r in ipairs(self.resources) do
        table.insert(new, r.cmd .. " " .. r.name)
    end

    for i = #self.lines, 1, -1 do
        if self.lines[i]:match("^(ensure|start|stop)%s+") then
            table.remove(self.lines, i)
        end
    end

    for _, l in ipairs(new) do
        table.insert(self.lines, l)
    end
end

function cfg:removeAce(str)
    for i = #self.aces, 1, -1 do
        if self.aces[i] == str then
            table.remove(self.aces, i)
            break
        end
    end
    for i = #self.lines, 1, -1 do
        if self.lines[i] == "add_ace " .. str then
            table.remove(self.lines, i)
            break
        end
    end
end

function cfg:removePrincipal(str)
    for i = #self.principals, 1, -1 do
        if self.principals[i] == str then
            table.remove(self.principals, i)
            break
        end
    end
    for i = #self.lines, 1, -1 do
        if self.lines[i] == "add_principal " .. str then
            table.remove(self.lines, i)
            break
        end
    end
end

function cfg:findResource(name)
    for _, r in ipairs(self.resources) do
        if r.name == name then
            return r
        end
    end
    return nil
end

function cfg:findSet(name)
    return self.sets[name]
end

function cfg:getResourceCommands(cmd)
    local out = {}
    for _, r in ipairs(self.resources) do
        if r.cmd == cmd then
            table.insert(out, r.name)
        end
    end
    return out
end

function cfg:getUnknownLines()
    return self.raw
end

function cfg:hasResource(name)
    for _, r in ipairs(self.resources) do
        if r.name == name then
            return true
        end
    end
    return false
end

return cfg
