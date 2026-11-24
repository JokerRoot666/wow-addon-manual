--[[--------------------------------------------------------------------------
    mock.lua — заглушка WoW API для прогона аддона в обычном Lua (fengari).
    Ничего не рисует: повторяет сигнатуры и хранит состояние, поэтому ловит
    nil-глобалы, опечатки в методах и ошибки вызовов.
----------------------------------------------------------------------------]]

local MOCK = {}
_G.MOCK = MOCK

-- ВАЖНО: тесты грузят файлы аддона с env = MOCK, поэтому стандартные
-- библиотеки и базовые функции тоже должны быть видны из этого окружения,
-- иначе первый же `table.concat` падает "attempt to index a nil value".
MOCK.table  = table
MOCK.string = string
MOCK.math   = math
MOCK.os     = os
MOCK.coroutine = coroutine
MOCK.utf8   = utf8
MOCK.tostring, MOCK.tonumber, MOCK.type = tostring, tonumber, type
MOCK.pairs, MOCK.ipairs, MOCK.next = pairs, ipairs, next
MOCK.select, MOCK.rawget, MOCK.rawset = select, rawget, rawset
MOCK.setmetatable, MOCK.getmetatable = setmetatable, getmetatable
MOCK.pcall, MOCK.xpcall, MOCK.error = pcall, xpcall, error
MOCK.assert, MOCK.unpack = assert, unpack or table.unpack
MOCK.format = string.format
MOCK.floor, MOCK.ceil, MOCK.max, MOCK.min = math.floor, math.ceil, math.max, math.min

local noop = function() end

MOCK.out = {}
MOCK.chat = {}
MOCK.timers = {}
MOCK.forbiddenAttempts = {}
MOCK.forbiddenEvents = { COMBAT_LOG_EVENT_UNFILTERED = true, COMBAT_LOG_EVENT = true }

function MOCK.print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    MOCK.out[#MOCK.out + 1] = table.concat(parts, " ")
end

-- ---------------------------------------------------------------------------
-- Объекты интерфейса
-- ---------------------------------------------------------------------------

local methods = {}
local objMT

local function newobj(kind, name)
    local o = {
        __kind = kind, __name = name,
        __scripts = {}, __events = {},
        __text = "", __shown = false, __w = 100, __h = 100,
    }
    setmetatable(o, objMT)
    return o
end

objMT = {
    __index = function(_, k)
        local m = methods[k]
        if m then return m end
        -- клиент имеет сотни методов; для теста неизвестный метод — noop
        if type(k) == "string" and k:match("^%u") then return noop end
        return nil
    end,
}

methods.SetSize = function(self, w, h) self.__w, self.__h = w, h end
methods.SetWidth = function(self, w) self.__w = w end
methods.SetHeight = function(self, h) self.__h = h end
methods.GetWidth = function(self) return self.__w end
methods.GetHeight = function(self) return self.__h end
methods.SetAllPoints = noop
methods.SetPoint = function(self, point, relTo, relPoint, x, y)
    self.__point = { point = point, relTo = relTo, relPoint = relPoint, x = x, y = y }
end
methods.ClearAllPoints = function(self) self.__point = nil end
methods.GetPoint = function(self)
    local p = self.__point
    if p then return p.point, p.relTo, p.relPoint, p.x or 0, p.y or 0 end
    return "CENTER", UIParent, "CENTER", 0, 0
end
methods.GetCenter = function() return 0, 0 end
methods.GetScale = function() return 1 end
methods.GetEffectiveScale = function() return 1 end
methods.GetFrameLevel = function(self) return self.__level or 1 end
methods.GetFrameStrata = function(self) return self.__strata or "MEDIUM" end
methods.GetName = function(self) return self.__name end
methods.SetScript = function(self, name, fn) self.__scripts[name] = fn end
methods.GetScript = function(self, name) return self.__scripts[name] end
methods.HookScript = function(self, name, fn) self.__scripts[name] = fn end
methods.SetText = function(self, t) self.__text = t end
methods.GetText = function(self) return self.__text end
methods.SetFont = noop
methods.SetJustifyH = noop
methods.GetStringHeight = function(self)
    if MOCK.__stringHeight then return MOCK.__stringHeight(self) end
    return nil
end
methods.SetTexture = function(self, t) self.__texture = t end
methods.GetTexture = function(self) return self.__texture end

-- цвета клиент принимает только числами — здесь та же строгость
local function checkNumbers(fname, minArgs, ...)
    local n = select("#", ...)
    if n < minArgs then error(fname .. ": слишком мало аргументов", 2) end
    for i = 1, n do
        if type((select(i, ...))) ~= "number" then
            error(fname .. ": аргумент #" .. i .. " должен быть number", 2)
        end
    end
end

methods.SetTextColor = function(self, ...) checkNumbers("SetTextColor", 1, ...) end
methods.SetColorTexture = function(self, ...) checkNumbers("SetColorTexture", 3, ...) end
methods.SetBackdropColor = function(self, ...) checkNumbers("SetBackdropColor", 3, ...) end
methods.SetBackdropBorderColor = function(self, ...) checkNumbers("SetBackdropBorderColor", 3, ...) end

methods.Show = function(self) self.__shown = true end
methods.Hide = function(self) self.__shown = false end
methods.SetShown = function(self, v) self.__shown = v and true or false end
methods.IsShown = function(self) return self.__shown end
methods.IsVisible = function(self) return self.__shown end
methods.SetChecked = function(self, v) self.__checked = v and true or false end
methods.GetChecked = function(self) return self.__checked end
methods.CreateTexture = function() return newobj("Texture") end
methods.CreateFontString = function() return newobj("FontString") end
methods.SetBackdrop = function(self, b) self.__backdrop = b end

methods.RegisterEvent = function(self, e)
    if MOCK.forbiddenEvents[e] then
        MOCK.forbiddenAttempts[#MOCK.forbiddenAttempts + 1] = e
        error("ADDON_ACTION_FORBIDDEN: " .. tostring(e), 2)
    end
    self.__events[e] = true
end
methods.UnregisterEvent = function(self, e) self.__events[e] = nil end
methods.UnregisterAllEvents = function(self) self.__events = {} end
methods.IsEventRegistered = function(self, e) return self.__events[e] and true or false end

-- ---------------------------------------------------------------------------
-- Рендеринг фреймов
-- ---------------------------------------------------------------------------

MOCK.objects = {}

function MOCK.CreateFrame(kind, name, parent, template)
    local o = newobj(kind or "Frame", name)
    o.__parent, o.__template = parent, template
    MOCK.objects[#MOCK.objects + 1] = o
    return o
end

UIParent = newobj("Frame", "UIParent")
Minimap = newobj("Frame", "Minimap")
Minimap.GetWidth = function() return 140 end
Minimap.GetFrameLevel = function() return 1 end
Minimap.GetCenter = function() return 0, 0 end

-- шрифты-шаблоны клиента: GameFontNormal:GetFont() -> путь, размер, флаги
local function newFontHandle() return newobj("Font") end
GameFontNormal = newFontHandle()
GameFontNormal.GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end
GameFontNormalSmall = newFontHandle()
GameFontNormalSmall.GetFont = function() return "Fonts\\FRIZQT__.TTF", 10, "" end
GameFontNormalLarge = newFontHandle()
GameFontNormalLarge.GetFont = function() return "Fonts\\FRIZQT__.TTF", 16, "" end
GameFontHighlight = newFontHandle()
GameFontHighlight.GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end
GameFontDisable = newFontHandle()
GameFontDisable.GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end
ChatFontNormal = newFontHandle()

UISpecialFrames = {}
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end end
GetCursorPosition = function() return 0, 0 end
InCombatLockdown = function() return false end

-- ---------------------------------------------------------------------------
-- Клиентские API
-- ---------------------------------------------------------------------------

MOCK.__items = {}      -- [id] = { name = ..., itemQuality = ... }

C_Item = {
    GetItemInfo = function(id)
        local it = MOCK.__items[id]
        if not it then return nil end
        return { name = it.name, itemQuality = it.itemQuality or 2, itemIcon = 134400 }
    end,
    GetItemInfoInstant = function(id) return id, "Прочее", "", "", 134400, 15, 5 end,
    RequestLoadItemDataByID = function() end,
}

C_Timer = {
    After = function(delay, fn) MOCK.timers[#MOCK.timers + 1] = fn end,
    NewTimer = function() return { Cancel = noop } end,
    NewTicker = function() return { Cancel = noop } end,
}

C_EventUtils = { IsEventValid = function() return true end }

C_Spell = {
    GetSpellName = function(id) return "Spell " .. tostring(id) end,
    GetSpellInfo = function(id) return { name = "Spell " .. tostring(id), iconID = 134400 } end,
}

C_Map = {
    GetBestMapForUnit = function() return 1 end,
    GetMapInfo = function() return { name = "Карта", parentMapID = 0, mapType = 3 } end,
}

MOCK.StaticPopupDialogs = {}
MOCK.StaticPopup_Show = function(which) MOCK.popupShown = which end

DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, text) MOCK.chat[#MOCK.chat + 1] = text end,
}

GameTooltip = {
    SetOwner = noop, SetText = noop, AddLine = noop, Show = noop, Hide = noop,
    SetItemByID = noop, ClearLines = noop,
}

SlashCmdList = {}
MOCK.visibility = {}
-- порядок как у клиента: version, build, date, tocversion
GetBuildInfo = function() return "12.1.5", "70961", "Nov 24 2026", 120105 end
GetLocale = function() return "enUS" end
GetTime = function() return os.time() end
issecretvalue = function() return false end

-- ---------------------------------------------------------------------------
-- Доставка событий и вызовов
-- ---------------------------------------------------------------------------

function MOCK.flush()
    local guard = 0
    while #MOCK.timers > 0 and guard < 1000 do
        guard = guard + 1
        local fn = table.remove(MOCK.timers, 1)
        local ok, err = pcall(fn)
        if not ok then error("таймер упал: " .. tostring(err), 0) end
    end
end

function MOCK.event(name, ...)
    for _, o in ipairs(MOCK.objects) do
        if o.__events[name] and o.__scripts.OnEvent then
            o.__scripts.OnEvent(o, name, ...)
        end
    end
end

function MOCK.fire(obj, script, ...)
    local fn = obj and obj.__scripts and obj.__scripts[script]
    if not fn then return false end
    fn(obj, ...)
    return true
end

function MOCK.find(text)
    for _, o in ipairs(MOCK.objects) do
        if o.__text == text then return o end
    end
    return nil
end

--- Скопировать все глобалы стенда в MOCK: файлы аддона грузятся с env = MOCK,
--- поэтому UIParent, SlashCmdList, Minimap и прочее должны быть видны оттуда.
for k, v in pairs(_G) do
    if MOCK[k] == nil then MOCK[k] = v end
end

return MOCK
