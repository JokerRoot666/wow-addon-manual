-- test_smoke.lua — smoke-тест шаблона MyAddon на mock-клиенте.

local MOCK = MOCK
local print = MOCK.print

local fails = 0
local function check(cond, msg)
    if cond then print("  ok    " .. msg)
    else fails = fails + 1; print("  FAIL  " .. msg) end
end

local ADDON = "MyAddon"

-- порядок как в TOC
local FILES_ORDER = { "Locale.lua", "Locale_en.lua", "Core.lua", "UI.lua" }

local function loadAddon()
    local ns = {}
    for _, f in ipairs(FILES_ORDER) do
        local src = FILES[f]
        if not src then error("нет файла " .. f) end
        local chunk, err = load(src, "@" .. f, "t", MOCK)
        if not chunk then error("не загрузился " .. f .. ": " .. tostring(err)) end
        chunk(ADDON, ns)
    end
    return ns
end

local ok, ns = pcall(loadAddon)
check(ok, "аддон загрузился без ошибок" .. (ok and "" or (": " .. tostring(ns))))
if not ok then return end

-- аддон грузится с env = MOCK, поэтому его глобал L() живёт в MOCK
local L = MOCK.L

print("-- загрузка")
MOCK.event("ADDON_LOADED", ADDON)
MOCK.flush()                       -- отложенный C_Timer.After(0, ...)
check(ns.db ~= nil, "база создана")
check(ns.db.settings.msg == true, "настройки по умолчанию на месте")
check(#MOCK.chat > 0 and MOCK.chat[1]:find("MyAddon") ~= nil, "приветствие в чат")
check(ns.CombatLogClosed() == true, "боевой лог в 12.x считается закрытым")
check(ns.RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") == false, "регистрация боевого лога отклонена")
check(ns.EventBlocked("COMBAT_LOG_EVENT_UNFILTERED") == true, "боевой лог помечен заблокированным")
check(#MOCK.forbiddenAttempts == 0, "запрещённые события не дошли до клиента")

print("-- окно")
ns.UI.Toggle()
check(ns.UI.frame ~= nil and ns.UI.frame:IsShown(), "окно открылось")
check(ns.UI.frame.title:GetText():find("My Addon") ~= nil, "заголовок на месте")
ns.UI.Toggle()
check(not ns.UI.frame:IsShown(), "повторный тумблер закрывает окно")
ns.UI.Toggle()

print("-- данные и список")
ns.AddTries(50818, 2, false)
ns.AddTries(50818, 0, true)
check(ns.db.items[50818] ~= nil, "предмет в базе")
check(ns.db.items[50818].tries == 2, "попытки: 2")
check(ns.db.items[50818].wins == 1, "выпадения: 1")
check(ns.charDB.items[50818].tries == 2, "счётчик персонажа синхронен")
ns.UI.ShowTab("list")
check(#ns.UI.frame.pages.list.rows >= 1, "строка списка создана")
check(ns.UI.frame.footer:GetText():find("предметов: 1") ~= nil, "футер посчитал предметы")

print("-- вкладки")
ns.UI.ShowTab("set")
check(ns.UI.frame.pages.set:IsShown(), "страница настроек показана")
check(not ns.UI.frame.pages.list:IsShown(), "список скрыт")
ns.UI.ShowTab("list")

print("-- слэш-команды")
check(type(SlashCmdList["MYADDON"]) == "function", "слэш-команда зарегистрирована")
SlashCmdList["MYADDON"]("add 19019")
check(ns.db.items[19019] ~= nil, "/ma add добавил предмет")
SlashCmdList["MYADDON"]("list")
SlashCmdList["MYADDON"]("нет такой команды")
check(#MOCK.chat > 0, "чат отвечает на команды")

print("-- локализация")
check(L("Список") == "List", "английский словарь работает")
ns.Locale.Set("ru")
check(L("Список") == "Список", "русский возвращает исходник")
check(ns.db.ui.locale == "ru", "выбор языка сохранён в базе")
check(ns.Locale.Supported("ja") == false, "японский скрыт на enUS-клиенте")

print("-- миникарта")
ns.UI.BuildMinimap()
check(ns.UI.minimap ~= nil, "кнопка у миникарты создана")
check(ns.UI.minimap.icon ~= nil, "иконка на месте")

print("-- события")
MOCK.event("PLAYER_LOGIN")
MOCK.event("CHAT_MSG_LOOT", "Получен предмет: |Hitem:50818::::::::|h[Клык]|h")
check(ns.db.items[50818].wins == 2, "добыча из строки чата засчитана")
MOCK.event("BAG_UPDATE")

if fails == 0 then print("-- все проверки пройдены") end
