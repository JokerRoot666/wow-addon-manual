--[[--------------------------------------------------------------------------
    mock.lua — крошечная заглушка клиента WoW для проверки аддона без игры.
    Реализовано только то, что реально нужно Hello World: фрейм,
    события, print и SlashCmdList. Всё остальное — в настоящем клиенте.
----------------------------------------------------------------------------]]

local MOCK = {
    out = {},      -- весь вывод print, строками
    frames = {},   -- созданные фреймы
    slash = {},    -- SlashCmdList
}

function MOCK.say(line)
    MOCK.out[#MOCK.out + 1] = tostring(line)
end

-- print в клиенте пишет в чат; здесь — в MOCK.out, чтобы тест мог сравнить.
function print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    MOCK.say(table.concat(parts, " "))
end

UIParent = {}

local frameMeta = {}
frameMeta.__index = frameMeta

function frameMeta:RegisterEvent(event)
    self.events = self.events or {}
    self.events[event] = true
end

function frameMeta:UnregisterEvent(event)
    if self.events then self.events[event] = nil end
end

function frameMeta:SetScript(handler, fn)
    self.scripts[handler] = fn
end

function frameMeta:GetScript(handler)
    return self.scripts[handler]
end

function frameMeta:GetName()
    return self.name
end

function CreateFrame(kind, name, parent, template)
    local f = setmetatable({
        kind = kind,
        name = name,
        parent = parent,
        template = template,
        scripts = {},
        events = {},
    }, frameMeta)
    MOCK.frames[#MOCK.frames + 1] = f
    if name then _G[name] = f end
    return f
end

SlashCmdList = setmetatable({}, {
    __newindex = function(t, key, fn)
        MOCK.slash[key] = fn
        rawset(t, key, fn)
    end,
})

--- Вызвать событие у всех фреймов, которые на него подписаны.
function MOCK.dispatch(event, ...)
    for _, f in ipairs(MOCK.frames) do
        if f.events[event] and f.scripts.OnEvent then
            f.scripts.OnEvent(f, event, ...)
        end
    end
end

--- Выполнить слэш-команду так, как это сделал бы клиент.
function MOCK.slashcmd(line)
    local text = tostring(line):gsub("^/", "")
    local cmd, rest = text:match("^(%S+)%s*(.*)$")
    cmd = (cmd or ""):lower()
    -- ищем ключ SlashCmdList, у которого есть алиас с таким именем
    for key, fn in pairs(MOCK.slash) do
        for i = 1, 20 do
            local alias = _G["SLASH_" .. key .. i]
            if not alias then break end
            if alias:gsub("^/", ""):lower() == cmd then
                fn(rest, nil)
                return true
            end
        end
    end
    return false
end

_G.MOCK = MOCK
