--[[--------------------------------------------------------------------------
    MyAddon / Core.lua
    Загрузка, база, настройки по умолчанию, слэш-команды, общие утилиты.
----------------------------------------------------------------------------]]

local ADDON, ns = ...

ns.name = ADDON
ns.version = "1.0.0"

-- ---------------------------------------------------------------------------
-- Настройки по умолчанию и слияние с сохранённой базой
-- ---------------------------------------------------------------------------

local DEFAULTS = {
    version = 1,
    settings = { msg = true, verbose = false },
    ui = { tab = "list", scale = 1, pos = nil, minimap = true, minimapAngle = 220 },
    items = {},      -- [itemID] = { tries = 0, wins = 0 }
}

--- Дополнить dst значениями src, не затирая уже существующие.
--- Вызов: db = ApplyDefaults(DEFAULTS, db)
local function ApplyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = ApplyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
ns.ApplyDefaults = ApplyDefaults

-- ---------------------------------------------------------------------------
-- Печать
-- ---------------------------------------------------------------------------

function ns.Print(msg, ...)
    if select("#", ...) > 0 then msg = msg:format(...) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff6ecbffMyAddon|r: " .. tostring(msg))
end

function ns.Debug(msg, ...)
    if ns.db and ns.db.settings.verbose then ns.Print(msg, ...) end
end

-- ---------------------------------------------------------------------------
-- Утилиты
-- ---------------------------------------------------------------------------

--- Значение от клиента, если оно не секретное (12.x: сравнение секрета — ошибка).
function ns.Open(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

--- Разобрать itemID из ссылки, ID или URL Wowhead.
function ns.ResolveItemID(arg)
    if not arg then return nil end
    arg = tostring(arg)
    local id = arg:match("|Hitem:(%d+)") or arg:match("[Ii]tem=(%d+)") or arg:match("(%d+)")
    return id and tonumber(id) or nil
end

--- Добавить попытку/выпадение в счётчики (персонаж + аккаунт).
function ns.AddTries(itemID, n, won)
    itemID = tonumber(itemID); if not itemID then return end
    n = n or 1

    local entry = ns.db.items[itemID]
    if not entry then
        entry = { tries = 0, wins = 0 }
        ns.db.items[itemID] = entry
    end
    entry.tries = (entry.tries or 0) + n
    if won then entry.wins = (entry.wins or 0) + 1 end

    local ch = ns.charDB.items[itemID]
    if not ch then
        ch = { tries = 0, wins = 0 }
        ns.charDB.items[itemID] = ch
    end
    ch.tries = (ch.tries or 0) + n
    if won then ch.wins = (ch.wins or 0) + 1 end

    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

-- ---------------------------------------------------------------------------
-- События клиента
-- ---------------------------------------------------------------------------

ns.eventFrame = CreateFrame("Frame")
ns.eventFrame:RegisterEvent("ADDON_LOADED")

ns.OnEvent = function(_, event, ...)
    if event == "ADDON_LOADED" then
        local which = ...
        if which ~= ADDON then return end
        ns.eventFrame:UnregisterEvent("ADDON_LOADED")
        ns.OnAddonLoaded()
    elseif event == "PLAYER_LOGIN" then
        if ns.UI and ns.UI.OnLogin then ns.UI.OnLogin() end
    elseif event == "CHAT_MSG_LOOT" then
        local text = ...
        ns.HandleLootText(text)
    elseif event == "BAG_UPDATE" then
        if ns.ClearBagsCache then ns.ClearBagsCache() end
    end
end
ns.eventFrame:SetScript("OnEvent", ns.OnEvent)

function ns.OnAddonLoaded()
    MyAddonDB = ApplyDefaults(DEFAULTS, MyAddonDB)
    MyAddonCharDB = ApplyDefaults({ items = {} }, MyAddonCharDB)
    ns.db = MyAddonDB
    ns.charDB = MyAddonCharDB

    ns:RegisterSlash()
    ns.RegisterEvents()

    if not ns.db.settings.greeted then
        ns.db.settings.greeted = true
        ns.Print(L("загружен, предметов в списке: %d"), ns.CountItems())
    end

    C_Timer.After(0, function()
        if ns.UI and ns.UI.OnLoad then ns.UI.OnLoad() end
    end)
end

function ns.CountItems()
    local n = 0
    for _ in pairs(ns.db.items or {}) do n = n + 1 end
    return n
end

-- ---------------------------------------------------------------------------
-- Регистрация событий: только то, что есть в этом клиенте
-- ---------------------------------------------------------------------------

local blocked = {}

--- Боевой лог в 12.x недоступен аддонам: pcall не спасает от ADDON_ACTION_FORBIDDEN.
function ns.CombatLogClosed()
    if ns._logClosed ~= nil then return ns._logClosed end
    local ok, toc = pcall(function() return select(4, GetBuildInfo()) end)
    local num = ok and tonumber(toc) or nil
    local closed = (C_Secrets ~= nil) or (C_CombatLog ~= nil) or num == nil or num >= 120000
    ns._logClosed = closed
    return closed
end

function ns.EventBlocked(event)
    return blocked[event] == true
end

function ns.RegisterEvent(event)
    if event:find("^COMBAT_LOG") and ns.CombatLogClosed() then
        blocked[event] = true
        return false
    end
    if C_EventUtils and type(C_EventUtils.IsEventValid) == "function" then
        local ok, valid = pcall(C_EventUtils.IsEventValid, event)
        if ok and valid == false then
            blocked[event] = true
            return false
        end
    end
    return pcall(ns.eventFrame.RegisterEvent, ns.eventFrame, event)
end

function ns.RegisterEvents()
    ns.RegisterEvent("PLAYER_LOGIN")
    ns.RegisterEvent("PLAYER_ENTERING_WORLD")
    ns.RegisterEvent("CHAT_MSG_LOOT")
    ns.RegisterEvent("BAG_UPDATE")
    if ns.db.settings.msg then
        ns.RegisterEvent("LOOT_OPENED")
    end
end

--- Разбор строки добычи: ищем ссылку на предмет, иначе название в [скобках].
function ns.HandleLootText(text)
    if type(text) ~= "string" then return end
    local id = text:match("|Hitem:(%d+)")
    if id then
        ns.AddTries(tonumber(id), 0, true)
        ns.Debug(L("добыча: %s"), id)
    end
end

-- ---------------------------------------------------------------------------
-- Слэш-команды
-- ---------------------------------------------------------------------------

--- Глобальная функция для привязки клавиши (Bindings.xml).
function MyAddon_Toggle()
    if ns.UI then ns.UI.Toggle() end
end

BINDING_HEADER_MYADDON = "My Addon"

ns.HelpText = table.concat({
    "|cffffff00/ma|r — открыть окно",
    "|cffffff00/ma add <itemID>|r — добавить предмет в список",
    "|cffffff00/ma list|r — список в чат",
    "|cffffff00/ma lang <код>|r — язык (ru, en, de, ...)",
    "|cffffff00/ma debug|r — подробный вывод",
}, "\n")

function ns:RegisterSlash()
    SLASH_MYADDON1 = "/ma"
    SLASH_MYADDON2 = "/myaddon"
    SlashCmdList["MYADDON"] = function(input)
        local cmd, rest = (input or ""):match("^(%S*)%s*(.-)$")
        cmd = (cmd or ""):lower()

        if cmd == "" then
            if ns.UI then ns.UI.Toggle() end
        elseif cmd == "help" then
            ns.Print(ns.HelpText)
        elseif cmd == "add" then
            local id = ns.ResolveItemID(rest)
            if id then
                ns.AddTries(id, 0, false)
                ns.Print(L("предмет %d добавлен"), id)
            else
                ns.Print(L("нужен itemID"))
            end
        elseif cmd == "list" then
            for id, e in pairs(ns.db.items) do
                ns.Print("%d: %s / %s", id, e.tries or 0, e.wins or 0)
            end
        elseif cmd == "lang" then
            if ns.Locale and ns.Locale.Set then ns.Locale.Set(rest) end
        elseif cmd == "debug" then
            ns.db.settings.verbose = not ns.db.settings.verbose
            ns.Print(L("отладка: %s"), tostring(ns.db.settings.verbose))
        else
            ns.Print(L("неизвестная команда: %s"), cmd)
        end
    end
end
