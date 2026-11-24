--[[--------------------------------------------------------------------------
    HelloWorld.lua — минимальный рабочий аддон.
    Показывает три обязательные вещи: инициализацию по ADDON_LOADED,
    slash-команду и сохранение значения между сессиями.
----------------------------------------------------------------------------]]

-- Первая строка каждого файла аддона: движок передаёт сюда имя аддона и
-- общую таблицу-неймспейс, через которую файлы видят друг друга.
local ADDON, ns = ...

-- Значения по умолчанию. В БД их не кладём: дополним при загрузке,
-- чтобы старые сохранения не потеряли новые поля.
local DEFAULTS = {
    count = 0,
}

-- Фрейм нужен только как получатель событий: ни размера, ни родителя у него нет.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

local function ApplyDefaults(src, dst)
    dst = dst or {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = ApplyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        -- Событие приходит на каждый аддон: чужое имя пропускаем.
        if arg1 ~= ADDON then return end

        -- С этого момента SavedVariables уже заполнены клиентом.
        -- При самом первом запуске переменная равна nil — создаём таблицу.
        HelloWorldDB = ApplyDefaults(DEFAULTS, HelloWorldDB)

        -- Своё событие загрузки больше не нужно.
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        print(string.format("|cff33ff99HelloWorld|r: загружен, счётчик = %d",
            HelloWorldDB.count))
    end
end)

-- Слэш-команды: имя в SlashCmdList и алиасы SLASH_<ИМЯ><НОМЕР>.
SLASH_HELLOWORLD1 = "/hello"
SLASH_HELLOWORLD2 = "/hw"

SlashCmdList["HELLOWORLD"] = function(msg)
    -- Аргументы приходят одной строкой, поэтому режем её сами.
    local cmd, rest = tostring(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if cmd == "" or cmd == "help" then
        print("|cff33ff99HelloWorld|r: /hello help | count | reset")
    elseif cmd == "count" then
        HelloWorldDB.count = HelloWorldDB.count + 1
        print(string.format("|cff33ff99HelloWorld|r: счётчик = %d", HelloWorldDB.count))
    elseif cmd == "reset" then
        HelloWorldDB.count = 0
        print("|cff33ff99HelloWorld|r: счётчик обнулён")
    else
        -- Неизвестный аргумент не должен молчать: иначе кажется, что аддон сломан.
        print("|cff33ff99HelloWorld|r: неизвестная команда '" .. tostring(cmd) .. "'")
        _ = rest
    end
end
