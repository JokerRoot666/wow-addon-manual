--[[--------------------------------------------------------------------------
    MyAddon / UI.lua
    Окно с вкладками, список строк, кнопка у миникарты, страница настроек.
    Минимально, но по правилам: слои, пул строк, сохранение позиции, Esc.
----------------------------------------------------------------------------]]

local ADDON, ns = ...

local UI = {}
ns.UI = UI

local C = {
    bg = 0.06, panel = 0.10, border = 0.30, accent = 0.42, text = 0.95, dim = 0.62,
}

local function MakeFS(parent, size, r, g, b, point, relPoint, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if fs.SetFont then fs:SetFont(GameFontNormal:GetFont(), size or 12, "OUTLINE") end
    if fs.SetTextColor then fs:SetTextColor(r or C.text, g or C.text, b or C.text) end
    fs:SetPoint(point or "TOPLEFT", parent, relPoint or "TOPLEFT", x or 0, y or 0)
    fs:SetJustifyH("LEFT")
    return fs
end

local function NewButton(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 100, h or 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

--- Высота перенесённого текста: у клиента может быть nil до отрисовки.
local function TextHeight(fs, width, fallback)
    local h = fs.GetStringHeight and fs:GetStringHeight()
    if h and h > 0 then return h end
    local len = #(fs:GetText() or "")
    return fallback + math.floor(len / math.max(1, width / 6)) * fallback
end

-- ---------------------------------------------------------------------------
-- Окно
-- ---------------------------------------------------------------------------

function UI.Build()
    if UI.frame then return UI.frame end

    local f = CreateFrame("Frame", "MyAddonFrame", UIParent, "BackdropTemplate")
    f:SetSize(640, 460)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                        tile = true, tileSize = 16, edgeSize = 16,
                        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    end
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ns.db.ui.pos = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    -- позиция и масштаб из базы
    local pos = ns.db.ui.pos
    if pos then
        f:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER")
    end
    f:SetScale(ns.db.ui.scale or 1)

    -- Esc закрывает
    local known = false
    for _, v in ipairs(UISpecialFrames) do
        if v == "MyAddonFrame" then known = true end
    end
    if not known then tinsert(UISpecialFrames, "MyAddonFrame") end

    local title = MakeFS(f, 14, C.accent, C.accent, C.accent, "TOPLEFT", "TOPLEFT", 16, -14)
    title:SetText("My Addon " .. ns.version)
    f.title = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

    -- вкладки
    f.tabs = {}
    local tabs = { { key = "list", text = L("Список") }, { key = "set", text = L("Настройки") } }
    local tx = 16
    for _, t in ipairs(tabs) do
        local b = NewButton(f, t.text, 110, 22, function() UI.ShowTab(t.key) end)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", tx, -38)
        f.tabs[t.key] = b
        tx = tx + 116
    end

    -- страницы
    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -70)
    f.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 40)

    f.pages = {}

    -- страница «Список»
    local list = CreateFrame("Frame", nil, f.content)
    list:SetAllPoints(f.content)
    list.rows = {}
    list.child = CreateFrame("Frame", nil, list)
    list.child:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
    list.child:SetSize(560, 10)
    f.pages.list = list

    -- строка списка (пул)
    function UI.Row(i)
        local r = list.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, list.child)
        r:SetHeight(22)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
        r:SetPoint("RIGHT", list.child, "RIGHT", 0, 0)
        r.id = MakeFS(r, 12, nil, nil, nil, "LEFT", "LEFT", 4, 0)
        r.tries = MakeFS(r, 12, C.dim, C.dim, C.dim, "RIGHT", "RIGHT", -120, 0)
        r.wins = MakeFS(r, 12, C.dim, C.dim, C.dim, "RIGHT", "RIGHT", -40, 0)
        r:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L("Попытки") .. ": " .. tostring(self.triesCount or 0))
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        list.rows[i] = r
        return r
    end

    -- страница «Настройки»
    local set = CreateFrame("Frame", nil, f.content)
    set:SetAllPoints(f.content)
    set:Hide()
    f.pages.set = set

    set.msgLabel = MakeFS(set, 12, nil, nil, nil, "TOPLEFT", "TOPLEFT", 0, -8)
    set.msgLabel:SetText(L("Сообщение в чат при выпадении"))

    local cb = CreateFrame("CheckButton", nil, set, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", set, "TOPLEFT", 250, -2)
    cb:SetScript("OnClick", function(self)
        ns.db.settings.msg = not ns.db.settings.msg
        if self.SetChecked then self:SetChecked(ns.db.settings.msg) end
        ns.Print(L("Сообщение в чат при выпадении") .. ": " .. tostring(ns.db.settings.msg))
    end)
    set.msgCheck = cb

    -- подвал
    local footer = MakeFS(f, 11, C.dim, C.dim, C.dim, "BOTTOMLEFT", "BOTTOMLEFT", 16, 14)
    f.footer = footer

    UI.frame = f
    return f
end

function UI.ShowTab(key)
    local f = UI.frame
    if not f then return end
    ns.db.ui.tab = key
    for k, page in pairs(f.pages) do page:SetShown(k == key) end
    UI.Refresh()
end

--- Пересобрать видимые строки (только пул, не по фрейму на запись).
function UI.Refresh()
    local f = UI.frame
    if not f or not f:IsShown() then return end

    local ids = {}
    for id in pairs(ns.db.items or {}) do ids[#ids + 1] = id end
    table.sort(ids)

    local list = f.pages.list
    for i, id in ipairs(ids) do
        local r = UI.Row(i)
        local e = ns.db.items[id]
        r.id:SetText(("%s (%d)"):format(ns.ItemLabel(id), id))
        r.tries:SetText(tostring(e.tries or 0))
        r.wins:SetText(tostring(e.wins or 0))
        r.triesCount = e.tries or 0
        r.id.itemID = id
        r:Show()
    end
    for i = #ids + 1, #list.rows do list.rows[i]:Hide() end
    list.child:SetHeight(math.max(10, #ids * 22))

    local total = 0
    for _, e in pairs(ns.db.items or {}) do total = total + (e.tries or 0) end
    f.footer:SetText(("предметов: %d • попыток: %d"):format(#ids, total))

    if f.pages.set.msgCheck and f.pages.set.msgCheck.SetChecked then
        f.pages.set.msgCheck:SetChecked(ns.db.settings.msg and true or false)
    end
end

function UI.RefreshItem(itemID)
    if not UI.frame or not UI.frame:IsShown() then return end
    UI.Refresh()
end

function UI.Toggle()
    local f = UI.Build()
    if f:IsShown() then f:Hide() else f:Show() end
end

-- ---------------------------------------------------------------------------
-- Кнопка у миникарты
-- ---------------------------------------------------------------------------

function UI.UpdateMinimap()
    local b = UI.minimap
    if not b then return end
    if ns.db.ui.minimap ~= false then b:Show() else b:Hide() end
end

function UI.MinimapMenu(anchor)
    local function Open(tab)
        local f = UI.Build()
        f:Show()
        if tab then UI.ShowTab(tab) end
    end

    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, root)
            root:CreateTitle("My Addon")
            root:CreateButton(L("Список"), function() Open("list") end)
            root:CreateButton(L("Настройки"), function() Open("set") end)
        end)
        return
    end
    Open(nil)
end

function UI.BuildMinimap()
    if UI.minimap or not Minimap then return end

    local b = CreateFrame("Button", "MyAddonMinimapButton", Minimap)
    b:SetSize(32, 32)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    b:RegisterForDrag("LeftButton")

    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetSize(54, 54)
    b.border:SetPoint("CENTER")
    b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(20, 20)
    b.icon:SetPoint("CENTER", 0, 1)
    b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local angle = ns.db.ui.minimapAngle or 220
    local function Place(a)
        local w = (Minimap.GetWidth and Minimap:GetWidth()) or 140
        if not w or w < 40 then w = 140 end
        local radius = w / 2 + 5
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER",
            radius * math.cos(math.rad(a)), radius * math.sin(math.rad(a)))
    end
    Place(angle)

    local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            UI.MinimapMenu(b)
        else
            UI.Toggle()
        end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale() or 1
            local cx, cy = GetCursorPosition()
            cx, cy = cx / scale, cy / scale
            local a = math.deg(atan2(cy - my, cx - mx))
            angle = a
            ns.db.ui.minimapAngle = a
            Place(a)
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    UI.minimap = b
end

-- ---------------------------------------------------------------------------
-- Страница в «Настройки → Аддоны»
-- ---------------------------------------------------------------------------

function UI.RegisterOptions()
    if UI.optCategory then return end
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return
    end

    local panel = CreateFrame("Frame")
    panel:SetSize(560, 420)

    local head = MakeFS(panel, 14, C.accent, C.accent, C.accent, "TOPLEFT", "TOPLEFT", 0, 0)
    head:SetText("My Addon " .. ns.version)

    local open = NewButton(panel, "My Addon", 200, 24, function()
        UI.Build():Show()
        UI.ShowTab("list")
    end)
    open:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -26)

    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "My Addon")
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        UI.optCategory = category
    end
end

-- ---------------------------------------------------------------------------
-- Жизненный цикл
-- ---------------------------------------------------------------------------

function UI.OnLogin()
    UI.RegisterOptions()
    UI.BuildMinimap()
    UI.UpdateMinimap()
end

function UI.OnLoad()
    -- язык: сохранённый выбор, иначе по клиенту
    local want = (ns.db and ns.db.ui and ns.db.ui.locale) or (ns.Locale.FromClient and ns.Locale.FromClient()) or "en"
    ns.Locale.Set(want, true)

    UI.Build()
    if ns.db.ui.tab then UI.ShowTab(ns.db.ui.tab) end
end

--- Пересборка после смены языка.
function ns.Locale.OnChange()
    if UI.frame then
        UI.frame:Hide()
        UI.frame = nil
        UI.pages = nil
    end
    if UI.minimap then
        UI.minimap:Hide()
        UI.minimap = nil
    end
    UI.optCategory = nil
    if ns.db then
        UI.OnLoad()
        UI.OnLogin()
    end
end

--- Русское имя предмета из клиента или номер.
function ns.ItemLabel(itemID)
    local info = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(itemID)
    if type(info) == "table" and info.name then return info.name end
    return "#" .. tostring(itemID)
end
