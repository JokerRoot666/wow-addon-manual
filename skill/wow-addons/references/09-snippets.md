# 09. Сниппеты (готово к копированию)

## 1. TOC

```toc
## Interface: 120105
## Title: My Addon
## Title-ruRU: Мой аддон
## Notes: Что делает аддон
## Notes-ruRU: Что делает аддон
## Author: me
## Version: 1.0.0
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB
## IconTexture: Interface\Icons\INV_Misc_QuestionMark
Core.lua
Locale.lua
Locale_en.lua
UI.lua
```

## 2. Core: загрузка, БД, миграция

```lua
local ADDON, ns = ...
ns.version = "1.0.0"

local DEFAULTS = {
    settings = { msg = true, verbose = false },
    ui = { tab = "list", scale = 1 },
}

-- db = ApplyDefaults(DEFAULTS, db): значения по умолчанию первым аргументом
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

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, arg1)
    if event ~= "ADDON_LOADED" or arg1 ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")

    MyAddonDB = ApplyDefaults(DEFAULTS, MyAddonDB)
    MyAddonCharDB = ApplyDefaults({ items = {} }, MyAddonCharDB)
    ns.db = MyAddonDB
    ns.charDB = MyAddonCharDB

    ns:RegisterSlash()
    C_Timer.After(0, function()
        ns.RegisterEvents()
        if ns.UI then ns.UI.OnLoad() end
    end)
end)
```

## 3. Печать и отладка

```lua
function ns.Print(msg, ...)
    if select("#", ...) > 0 then msg = msg:format(...) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff6ecbffMyAddon|r: " .. tostring(msg))
end

function ns.Debug(msg, ...)
    if ns.db and ns.db.settings.verbose then ns.Print(msg, ...) end
end
```

## 4. Локализация

```lua
-- Locale.lua
local ADDON, ns = ...
local Locale = {}
ns.Locale = Locale
Locale.current = "en"
Locale.dict = { en = {}, de = {}, fr = {}, es = {}, it = {}, pt = {},
                pl = {}, ko = {}, zh = {}, zhtw = {}, ja = {} }

function Locale.Normalize(key)
    if type(key) ~= "string" then return "en" end
    local s = key:lower():gsub("[%s%-_]", "")
    local map = { ruru = "ru", rus = "ru", russian = "ru", enus = "en", engb = "en",
                  dede = "de", german = "de", zhcn = "zh", zhtw = "zhtw", jajp = "ja" }
    return map[s] or (Locale.dict[s] and s) or "en"
end

function ns.L(s)
    local d = Locale.dict[Locale.current]
    local t = d and d[s]
    return t or s
end
```

## 5. События с проверкой клиента

```lua
local blocked = {}

function ns.CombatLogClosed()
    if ns._logClosed ~= nil then return ns._logClosed end
    local ok, toc = pcall(function() return select(4, GetBuildInfo()) end)
    local num = ok and tonumber(toc) or nil
    ns._logClosed = (C_Secrets ~= nil) or (C_CombatLog ~= nil) or num == nil or num >= 120000
    return ns._logClosed
end

function ns.RegisterEvent(frame, event)
    if event:find("^COMBAT_LOG") and ns.CombatLogClosed() then
        blocked[event] = true; return false
    end
    if C_EventUtils and type(C_EventUtils.IsEventValid) == "function" then
        local ok, valid = pcall(C_EventUtils.IsEventValid, event)
        if ok and valid == false then blocked[event] = true; return false end
    end
    return pcall(frame.RegisterEvent, frame, event)
end

function ns.RegisterEvents()
    local f = ns.eventFrame or CreateFrame("Frame")
    ns.eventFrame = f
    ns.RegisterEvent(f, "PLAYER_LOGIN")
    ns.RegisterEvent(f, "PLAYER_ENTERING_WORLD")
    ns.RegisterEvent(f, "CHAT_MSG_LOOT")
    ns.RegisterEvent(f, "LOOT_OPENED")
    ns.RegisterEvent(f, "LOOT_READY")
    ns.RegisterEvent(f, "BAG_UPDATE")
    ns.RegisterEvent(f, "GET_ITEM_INFO_RECEIVED")
    f:SetScript("OnEvent", ns.OnEvent)
end

function ns.OnEvent(self, event, ...)
    if event == "CHAT_MSG_LOOT" then
        local text = ...
        ns.HandleLootText(text)
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.OnEnterWorld()
    end
end
```

## 6. Слэш-команды

```lua
function ns:RegisterSlash()
    SLASH_MYADDON1 = "/ma"
    SLASH_MYADDON2 = "/myaddon"
    SlashCmdList["MYADDON"] = function(input)
        local cmd, rest = (input or ""):gmatch("^(%S*)%s*(.-)$")()
        cmd = (cmd or ""):lower()
        if cmd == "" then ns.UI.Toggle()
        elseif cmd == "help" then ns.Print(ns.HelpText)
        elseif cmd == "lang" then ns.Locale.Set(rest)
        elseif cmd == "debug" then
            ns.db.settings.verbose = not ns.db.settings.verbose
            ns.Print("отладка: " .. tostring(ns.db.settings.verbose))
        else ns.Print("неизвестная команда: " .. cmd) end
    end
end
```

## 7. Окно: позиция, Esc, масштаб

```lua
function ns.UI.Build()
    local f = CreateFrame("Frame", "MyAddonFrame", UIParent, "BackdropTemplate")
    f:SetSize(780, 540)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.ui.pos = { point = p, relPoint = rp, x = x, y = y }
    end)
    f:SetScript("OnShow", function() ns.UI.Refresh() end)

    local pos = ns.db.ui.pos
    if pos then f:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 0)
    else f:SetPoint("CENTER") end
    f:SetScale(ns.db.ui.scale or 1)

    local known = false
    for _, v in ipairs(UISpecialFrames) do if v == "MyAddonFrame" then known = true end end
    if not known then tinsert(UISpecialFrames, "MyAddonFrame") end

    ns.UI.frame = f
    return f
end

function ns.UI.Toggle()
    local f = ns.UI.frame or ns.UI.Build()
    if f:IsShown() then f:Hide() else f:Show() end
end
```

## 8. Кэш метаданных предмета

```lua
local meta = {}

function ns.ItemMeta(id)
    id = tonumber(id); if not id then return nil end
    local m = meta[id]
    if m then return m end
    local info = C_Item.GetItemInfo(id)
    if not info then
        C_Item.RequestLoadItemDataByID(id)
        return nil
    end
    m = {
        name = info.name, quality = info.itemQuality, icon = info.itemIcon,
        classID = info.itemClassID, equipLoc = info.itemEquipLoc,
    }
    meta[id] = m
    return m
end

ns.eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
-- в OnEvent:
--   local id = ...
--   meta[id] = nil
--   if ns.UI then ns.UI.RefreshItem(id) end
```

## 9. Порционный скан

```lua
function ns.ScanStart(ids, onDone)
    local queue, step, done = {}, 250, 0
    for _, id in ipairs(ids) do queue[#queue + 1] = id end
    local function Tick()
        local n = 0
        while #queue > 0 and n < step do
            local id = table.remove(queue)
            if ns.ScanOne(id) then done = done + 1 end
            n = n + 1
        end
        if ns.UI then ns.UI.ScanProgress(done, #queue) end
        if #queue > 0 then C_Timer.After(0, Tick) else onDone(done) end
    end
    Tick()
end
```

## 10. Кнопка у миникарты (сокращённо)

```lua
function ns.UI.BuildMinimap()
    if ns.UI.minimap or not Minimap then return end
    local b = CreateFrame("Button", "MyAddonMinimapButton", Minimap)
    b:SetSize(32, 32); b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    b:RegisterForDrag("LeftButton")

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(20, 20); b.icon:SetPoint("CENTER", 0, 1)
    b.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    local angle = ns.db.ui.minimapAngle or 220
    local function Place(a)
        local w = (Minimap.GetWidth and Minimap:GetWidth()) or 140
        if not w or w < 40 then w = 140 end
        local r = w / 2 + 5
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(math.rad(a)), r * math.sin(math.rad(a)))
    end
    Place(angle)

    local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
    b:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then ns.UI.MinimapMenu(b) else ns.UI.Toggle() end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local s = Minimap:GetEffectiveScale() or 1
            local cx, cy = GetCursorPosition(); cx, cy = cx / s, cy / s
            angle = math.deg(atan2(cy - my, cx - mx))
            ns.db.ui.minimapAngle = angle; Place(angle)
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    ns.UI.minimap = b
end
```

## 11. Страница настроек

```lua
function ns.UI.RegisterOptions()
    if ns.UI.optCategory then return end
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame"); panel:SetSize(560, 420)
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 0, 0); fs:SetText("MyAddon " .. ns.version)
    local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, panel, "MyAddon")
    if ok and cat then pcall(Settings.RegisterAddOnCategory, cat); ns.UI.optCategory = cat end
end
```

## 12. Тултип на строке

```lua
row:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemID) end
    GameTooltip:AddLine(("шанс %s • попытки %d"):format(ns.Pct(chance), tries), 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
row:SetScript("OnLeave", function() GameTooltip:Hide() end)
```

## 13. Математика дропа

```lua
function ns.PNoDrop(p, n) return (1 - (p or 0)) ^ (n or 0) end
function ns.Expected(p) return (p and p > 0) and (1 / p) or nil end
function ns.TriesFor(p, confidence)
    if not p or p <= 0 then return nil end
    if p >= 1 then return 1 end
    return math.ceil(math.log(1 - confidence) / math.log(1 - p))
end
function ns.Pct(p) return p and ("%.2f%%"):format(p * 100) or "—" end
```

## 14. Таймеры и отложенный старт

```lua
C_Timer.After(0, function() ns.DetectStart() end)
local ticker = C_Timer.NewTicker(2, function() ns.UI.PerfTick() end)
-- при выключении: if ticker then ticker:Cancel() end
```

## 15. Чтение SavedVariables вне игры (Python)

```python
import re, pathlib
src = pathlib.Path(r"E:/Games/World of Warcraft/_retail_/WTF/Account/ACC/SavedVariables/MyAddon.lua").read_text("utf-8")
# файл — Lua-код; безопаснее не exec-ать его, а извлекать нужное
chunks = re.findall(r"\[(\d+)\]\s*=\s*\{([^}]*)\}", src)
```

Для полноценного разбора — отдельная песочница Lua (`loadfile` + пустое окружение),
как в `sync/dl_sync.py` (слияние счётчиков между ПК).

## 16. Сборщик архивов (Python, минимум)

```python
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ADDON = Path("MyAddon")
files = [p for p in ADDON.rglob("*")
         if p.is_file() and p.suffix in {".lua", ".toc", ".xml"}
         and "tools" not in p.parts]
assert (ADDON / f"{ADDON.name}.toc").exists(), "нет TOC"

out = Path("MyAddon-CurseForge.zip")
with ZipFile(out, "w", ZIP_DEFLATED) as z:
    for p in files:
        z.write(p, f"{ADDON.name}/{p.relative_to(ADDON)}")
    names = z.namelist()
    assert all(n.startswith(f"{ADDON.name}/") for n in names), "не та корневая папка"
    assert not any(n.startswith(f"{ADDON.name}/{ADDON.name}/") for n in names), "вложенность"
print("собрано:", out, len(names), "файлов")
```

## 17. Генератор Lua-данных (скелет)

```python
def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

with open("DataLoot.lua", "w", encoding="utf-8") as f:
    f.write("-- Сгенерировано gen_loot.py, не править руками\n")
    f.write("local ADDON, ns = ...\n")
    f.write('ns.LootBuild = "%s"\n' % BUILD_ID)
    f.write("ns.LootBoss = {\n")
    for enc, (name, inst, items) in sorted(bosses.items()):
        f.write("    [%d] = { %s, %d, %s },\n" % (enc, lua_str(name), inst, lua_str(items)))
    f.write("}\n")
```

## 18. Проверка синтаксиса (Node + luaparse)

```js
const fs = require('fs'), path = require('path'), luaparse = require('luaparse');
const dir = process.argv[2];
let bad = 0;
for (const f of fs.readdirSync(dir).filter(x => x.endsWith('.lua'))) {
  const src = fs.readFileSync(path.join(dir, f), 'utf8');
  try {
    luaparse.parse(src, { luaVersion: '5.1', locations: true });
    console.log('OK   ' + f);
  } catch (e) { bad++; console.log('FAIL ' + f + ': ' + e.message); }
}
process.exit(bad ? 1 : 0);
```
