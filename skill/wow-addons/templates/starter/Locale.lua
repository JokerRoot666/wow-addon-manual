--[[--------------------------------------------------------------------------
    MyAddon / Locale.lua
    Русский текст — исходник, остальные языки — словари «русская строка → перевод».
    Язык выбирается по клиенту; переключается /ma lang <код>.
----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Locale = {}
ns.Locale = Locale

Locale.fallback = "en"
Locale.default = "en"
Locale.current = "en"

-- Названия языков не переводятся: игрок ищет свой язык на своём языке.
Locale.available = {
    { key = "ru", name = "Русский" },
    { key = "en", name = "English" },
    { key = "de", name = "Deutsch" },
    { key = "fr", name = "Français" },
    { key = "es", name = "Español" },
    { key = "it", name = "Italiano" },
    { key = "pt", name = "Português" },
    { key = "pl", name = "Polski" },
    -- азиатские языки: показывать только на родном клиенте, иначе «квадратики»
    { key = "ko", name = "한국어", script = "koKR" },
    { key = "zh", name = "中文", script = "zhCN" },
    { key = "zhtw", name = "繁體中文", script = "zhTW" },
    { key = "ja", name = "日本語", script = "jaJP" },
}

Locale.dict = { en = {}, de = {}, fr = {}, es = {}, it = {}, pt = {},
                pl = {}, ko = {}, zh = {}, zhtw = {}, ja = {} }

local aliases = {
    ru = "ru", ruru = "ru", rus = "ru", russian = "ru",
    en = "en", enus = "en", engb = "en", english = "en",
    de = "de", dede = "de", german = "de",
    fr = "fr", frfr = "fr", french = "fr",
    es = "es", eses = "es", esmx = "es", spanish = "es",
    it = "it", itit = "it", italian = "it",
    pt = "pt", ptbr = "pt", ptpt = "pt", portuguese = "pt",
    pl = "pl", plpl = "pl", polish = "pl",
    ko = "ko", kokr = "ko", korean = "ko",
    zh = "zh", zhcn = "zh", chinese = "zh",
    zhtw = "zhtw", traditional = "zhtw",
    ja = "ja", jajp = "ja", japanese = "ja",
}

function Locale.Normalize(key)
    if type(key) ~= "string" then return Locale.default end
    key = key:lower():gsub("[%s%-_]", "")
    return aliases[key] or Locale.default
end

--- Может ли этот клиент нарисовать язык (шрифт азиатских сборок).
function Locale.Supported(key)
    for _, l in ipairs(Locale.available) do
        if l.key == key then
            if not l.script then return true end
            return tostring(GetLocale and GetLocale() or "") == l.script
        end
    end
    return false
end

function Locale.Set(key, skipRebuild)
    key = Locale.Normalize(key)
    if not Locale.Supported(key) then return nil end
    Locale.current = key
    if ns.db and ns.db.ui then ns.db.ui.locale = key end
    if not skipRebuild and Locale.OnChange then Locale.OnChange(key) end
    return key
end

--- Язык по клиенту (ruRU → ru, zhTW → zhtw, незнакомый → en).
function Locale.FromClient()
    return Locale.Normalize(GetLocale and GetLocale() or "enUS")
end

-- ---------------------------------------------------------------------------
-- L(): ключ — русская строка целиком; непереведённая остаётся русской
-- ---------------------------------------------------------------------------

function L(s)
    local d = Locale.dict[Locale.current]
    if d then
        local t = d[s]
        if t then return t end
    end
    return s
end
ns.L = L
