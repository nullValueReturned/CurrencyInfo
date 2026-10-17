-- CurrencyInfo_Config.lua
-- Settings UI

local ADDON_NAME, ns = ...

local CI             = CurrencyInfoAddon
local FORMAT_PRESETS = ns.FORMAT_PRESETS
local DeepMerge      = ns.DeepMerge

local UI = ns.UI

local CFG_W      = 860
local CFG_H      = 700
local DS_H       = 168   -- height of the display settings block
local BOTTOM_PAD = 16

-- Row layout in the currency list
local ROW_H        = 30
local ROW_PAD      = 2
local COL_GRIP     = 2
local COL_ICON     = 22
local COL_NAME     = 48
local COL_FMT      = 204
local COL_CUSTOM   = 360
local COL_PREVIEW  = 556
local COL_ICON_CB  = 690
local COL_HIDENAME = 734
local COL_OPTS     = 778
local COL_DEL      = 796

-- ============================================================
-- Widget helpers (thin wrappers over ns.UI)
-- ============================================================

local function Label(parent, text)
    return UI.Text(parent, "body", text)
end

-- Muted small-caps style caption for headings, column headers and hints.
local function Caption(parent, text)
    return UI.Text(parent, "small", text and text:upper())
end

local Button = UI.Button

-- Flat input; returns the EditBox.
local function EditBox(parent, w, h)
    return UI.Input(parent, w, h)
end

local function DropDown(parent, width, options, currentId, onChange, maxScrollHeight, up)
    return UI.Dropdown(parent, width, options, currentId, onChange, maxScrollHeight, up)
end

-- Pill toggle with an optional label to its right.
local function Checkbox(parent, checked, label, onChange)
    local cb = UI.Toggle(parent, checked, onChange)
    if label then
        local fs = Label(parent, label)
        fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb.text = fs
    end
    return cb
end

local function Separator(parent, yAnchor)
    return UI.Divider(parent, yAnchor, 16)
end

local function ShowTokenTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("Template tokens", UI.accent.r, UI.accent.g, UI.accent.b)
    for _, t in ipairs(ns.TOKEN_HELP) do
        GameTooltip:AddDoubleLine(t[1], t[2], 1, 1, 1, 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

local function HideTooltip() GameTooltip:Hide() end

-- True if the template contains a {token} that doesn't exist.
local function HasUnknownToken(template)
    for name in (template or ""):gmatch("{(%w+)}") do
        if not ns.TOKENS[name] then return true end
    end
    return false
end

function CI:SetFeedback(text, r, g, b)
    if not self.cfgFeedback then return end
    self.cfgFeedback:SetText(text)
    self.cfgFeedback:SetTextColor(r or 1, g or 1, b or 1)
end

-- ============================================================
-- Config Frame creation
-- ============================================================

function CI:CreateConfigFrame()
    local f = CreateFrame("Frame", "CurrencyInfoConfigFrame", UIParent)
    f:SetSize(CFG_W, CFG_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    UI.Surface(f, UI.Colors.window, { 1, 1, 1, 0.09 })
    UI.FadeInOnShow(f)
    f:Hide()
    self.configFrame = f
    tinsert(UISpecialFrames, "CurrencyInfoConfigFrame")

    -- Header bar: accent title, accent picker, close
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    header:SetHeight(44)
    local hbg = header:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(unpack(UI.Colors.header))
    -- Accent wash fading down from the top edge
    local wash = header:CreateTexture(nil, "BACKGROUND", nil, 1)
    wash:SetAllPoints()
    UI.OnAccent(function(r, g, b)
        wash:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.14))
    end)
    local bar = header:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(3)
    UI.OnAccent(function(r, g, b) bar:SetColorTexture(r, g, b, 1) end)

    local title = UI.Text(header, "title", "CurrencyInfo")
    title:SetPoint("LEFT", header, "LEFT", 16, 0)
    UI.AccentText(title)
    local sub = Caption(header, "Settings")
    sub:SetPoint("LEFT", title, "RIGHT", 10, -1)

    local closeBtn = UI.CloseButton(header, 28)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local swatch = UI.ColorSwatch(header,
        function() return UI.accent.r, UI.accent.g, UI.accent.b end,
        function(r, g, b)
            UI.SetAccent(r, g, b)
            CI.db.accent = { r, g, b }
        end, 20)
    swatch:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
    self.accentSwatch = swatch
    local swLbl = Caption(header, "Accent")
    swLbl:SetPoint("RIGHT", swatch, "LEFT", -8, 0)

    UI.Divider(f, -45, 1)

    -- ---- Add Currency ----
    local addLabel = Caption(f, "Add currency")
    addLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -62)

    local browseBtn = Button(f, "Browse list...", 130, 26)
    browseBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 112, -57)
    browseBtn:SetScript("OnClick", function() CI:OpenPicker() end)

    local orLbl = Caption(f, "or ID")
    orLbl:SetPoint("LEFT", browseBtn, "RIGHT", 12, 0)

    local idBox = EditBox(f, 90, 26)
    idBox:SetPoint("LEFT", orLbl, "RIGHT", 8, 0)
    idBox:SetNumeric(true)
    idBox:SetMaxLetters(10)

    -- Placeholder
    local idPlaceholder = UI.Text(idBox, "small", "Currency ID")
    idPlaceholder:SetPoint("LEFT", idBox, "LEFT", 8, 0)
    idPlaceholder:SetAlpha(0.7)
    idBox:HookScript("OnEditFocusGained", function() idPlaceholder:Hide() end)
    idBox:HookScript("OnEditFocusLost",   function(self)
        if self:GetText() == "" then idPlaceholder:Show() end
    end)

    local addBtn = Button(f, "Add", 56, 26)
    addBtn:SetPoint("LEFT", idBox, "RIGHT", 6, 0)

    -- Preview / feedback label
    local feedback = UI.Text(f, "body")
    feedback:SetPoint("LEFT", addBtn, "RIGHT", 12, 0)
    feedback:SetText("")
    self.cfgFeedback = feedback

    idBox:SetScript("OnTextChanged", function(self)
        local id = tonumber(self:GetText())
        if id then
            local data = ns.GetCurrencyData(id)
            if data then
                CI:SetFeedback(data.name, 0.5, 1, 0.5)
            else
                CI:SetFeedback("Unknown ID", 1, 0.4, 0.4)
            end
        else
            CI:SetFeedback("")
        end
    end)

    local function DoAdd()
        local id = tonumber(idBox:GetText())
        if not id then return end
        local ok, msg = CI:AddCurrency(id)
        if ok then
            idBox:SetText("")
            idPlaceholder:Show()
            CI:SetFeedback("Added: " .. msg, 0.5, 1, 0.5)
        elseif msg == "Already tracked!" then
            CI:SetFeedback(msg, 1, 0.8, 0)
        else
            CI:SetFeedback(msg, 1, 0.4, 0.4)
        end
    end

    addBtn:SetScript("OnClick", DoAdd)
    idBox:SetScript("OnEnterPressed", function(self)
        DoAdd()
        self:ClearFocus()
    end)

    Separator(f, -96)

    -- ---- Currency List header ----
    local listLabel = Caption(f, "Tracked currencies  (drag to reorder, hover for template tokens)")
    listLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -108)
    listLabel:SetScript("OnEnter", ShowTokenTooltip)
    listLabel:SetScript("OnLeave", HideTooltip)
    listLabel:EnableMouse(true)

    -- Column headers
    local hdrY = -130
    local function ColHdr(text, x)
        local lbl = Caption(f, text)
        lbl:SetPoint("TOPLEFT", f, "TOPLEFT", 16 + x, hdrY)
    end
    ColHdr("Name",     COL_NAME)
    ColHdr("Format",   COL_FMT)
    ColHdr("Custom",   COL_CUSTOM)
    ColHdr("Preview",  COL_PREVIEW)
    ColHdr("Icon",     COL_ICON_CB)
    ColHdr("Hide name", COL_HIDENAME)

    -- Scroll frame for currency rows
    local dsTop = BOTTOM_PAD + DS_H
    local scrollFrame = UI.ScrollFrame(f)
    scrollFrame:SetPoint("TOPLEFT",     f, "TOPLEFT",     16, -148)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, dsTop + 38)
    self.cfgScroll = scrollFrame

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(CFG_W - 46)
    scrollContent:SetHeight(60)
    scrollFrame:SetScrollChild(scrollContent)
    self.cfgContent = scrollContent

    -- Empty state: shown inside the list while nothing is tracked
    local empty = CreateFrame("Frame", nil, scrollContent)
    empty:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  0, 0)
    empty:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, 0)
    empty:SetHeight(140)
    local emptyText = UI.Text(empty, "body", "No currencies tracked yet.")
    emptyText:SetPoint("TOP", empty, "TOP", 0, -28)
    local emptySub = UI.Text(empty, "small", "Pick from a list, add an ID above, or start with every currency that has a cap.")
    emptySub:SetPoint("TOP", emptyText, "BOTTOM", 0, -8)
    local emptyBrowse = Button(empty, "Browse currencies", 170, 28)
    emptyBrowse:SetPoint("TOP", empty, "TOP", -95, -80)
    emptyBrowse:SetScript("OnClick", function() CI:OpenPicker() end)
    local emptyCapped = Button(empty, "Add all capped currencies", 190, 28)
    emptyCapped:SetPoint("LEFT", emptyBrowse, "RIGHT", 10, 0)
    emptyCapped:SetScript("OnClick", function()
        local n = CI:AddAllCapped()
        CI:SetFeedback(n > 0 and ("Added " .. n .. " capped currencies") or "No capped currencies found", 0.5, 1, 0.5)
    end)
    empty:Hide()
    self.cfgEmpty = empty

    Separator(f, -(CFG_H - (dsTop + 30)))

    -- ---- Display Settings ----
    local dsLabel = Caption(f, "Display settings")
    dsLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, dsTop + 8)

    local dsFrame = CreateFrame("Frame", nil, f)
    dsFrame:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  16, BOTTOM_PAD)
    dsFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, BOTTOM_PAD)
    dsFrame:SetHeight(DS_H)
    self:BuildDisplaySettings(dsFrame)
end

-- ============================================================
-- Display Settings panel (inside config frame)
-- ============================================================

function CI:BuildDisplaySettings(p)
    local db     = self.db
    local layout = db.layout
    local vis    = db.visibility

    -- Each control registers a function that re-reads its value (used after a reset).
    local refreshers = {}
    self.dsRefreshers = refreshers

    -- Row 1: layout direction, alignment, font, reset
    local dirLbl = Caption(p, "Layout"); dirLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -7)
    local colBtn = Button(p, "Column", 70, 24); colBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 56, 0)
    local rowBtn = Button(p, "Row",    70, 24); rowBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 132, 0)
    local function UpdateDir()
        colBtn:SetSelected(layout.direction == "column")
        rowBtn:SetSelected(layout.direction ~= "column")
    end
    UpdateDir()
    refreshers[#refreshers + 1] = UpdateDir
    colBtn:SetScript("OnClick", function() layout.direction = "column"; UpdateDir(); CI:RefreshDisplay() end)
    rowBtn:SetScript("OnClick", function() layout.direction = "row";    UpdateDir(); CI:RefreshDisplay() end)

    local alignLbl = Caption(p, "Align"); alignLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 222, -7)
    local leftBtn  = Button(p, "Left",  56, 24); leftBtn:SetPoint("TOPLEFT",  p, "TOPLEFT", 266, 0)
    local rightBtn = Button(p, "Right", 56, 24); rightBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 328, 0)
    local function UpdateAlign()
        leftBtn:SetSelected(layout.align ~= "right")
        rightBtn:SetSelected(layout.align == "right")
    end
    UpdateAlign()
    refreshers[#refreshers + 1] = UpdateAlign
    leftBtn:SetScript("OnClick",  function() layout.align = "left";  UpdateAlign(); CI:RefreshDisplay() end)
    rightBtn:SetScript("OnClick", function() layout.align = "right"; UpdateAlign(); CI:RefreshDisplay() end)
    local function AlignTip(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Text alignment (column layout)", 1, 1, 1)
        GameTooltip:AddLine("Right-align lines up the values.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end
    for _, b in ipairs({ leftBtn, rightBtn }) do
        b:HookScript("OnEnter", AlignTip)
        b:HookScript("OnLeave", HideTooltip)
    end

    local fontLbl = Caption(p, "Font"); fontLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 420, -7)
    local fontDD = DropDown(p, 190, ns.GetFontOptions(), layout.fontFace, function(opt)
        layout.fontFace = opt.id
        CI:RefreshDisplay()
    end, 300, true)
    fontDD:SetPoint("TOPLEFT", p, "TOPLEFT", 458, 0)
    refreshers[#refreshers + 1] = function() fontDD:SetCurrentId(layout.fontFace) end

    local resetBtn = Button(p, "Reset to defaults", 140, 24)
    resetBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
    resetBtn:SetScript("OnClick", function()
        wipe(layout); DeepMerge(layout, ns.DB_DEFAULTS.layout)
        wipe(vis);    DeepMerge(vis,    ns.DB_DEFAULTS.visibility)
        db.showGains = true
        db.accent = nil
        UI.SetAccent(unpack(UI.DEFAULT_ACCENT))
        CI:RefreshDisplaySettingsUI()
        CI:ApplyVisibilityRules()
        CI:RefreshDisplay()
    end)
    resetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Resets layout, visibility rules and accent color.", 1, 1, 1)
        GameTooltip:AddLine("Tracked currencies and position are kept.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", HideTooltip)

    -- Rows 2-3: sliders
    local function SliderCell(x, y, text, minV, maxV, step, key, fmt)
        local cap = Caption(p, text); cap:SetPoint("TOPLEFT", p, "TOPLEFT", x, y - 4)
        local s = UI.Slider(p, 120, minV, maxV, step, layout[key], function(v)
            layout[key] = v
            CI:RefreshDisplay()
        end, fmt)
        s:SetPoint("TOPLEFT", p, "TOPLEFT", x + 84, y - 4)
        refreshers[#refreshers + 1] = function() s:SetValueSilent(layout[key]) end
    end
    local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

    SliderCell(0,   -34, "Font size", 6,   48, 1,    "fontSize")
    SliderCell(276, -34, "Icon size", 8,   64, 1,    "iconSize")
    SliderCell(552, -34, "Spacing",   0,   60, 1,    "spacing")
    SliderCell(0,   -68, "Scale",     0.5, 2,  0.05, "scale",   function(v) return string.format("%.2fx", v) end)
    SliderCell(276, -68, "Bg opacity", 0,  1,  0.05, "bgAlpha", pct)
    SliderCell(552, -68, "Padding",   0,   30, 1,    "padding")

    -- Rows 4-5: toggles
    local function Toggle(x, y, text, get, set)
        local cb = Checkbox(p, get(), text, set)
        cb:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
        refreshers[#refreshers + 1] = function() cb:SetState(get()) end
    end

    Toggle(0,   -102, "Background",    function() return layout.showBackground end,
        function(v) layout.showBackground = v; CI:RefreshDisplay() end)
    Toggle(200, -102, "Lock position", function() return db.locked end,
        function(v) db.locked = v end)
    Toggle(400, -102, "Show display",  function() return not db.hidden end,
        function(v) db.hidden = not v; CI:UpdateVisibility() end)
    Toggle(600, -102, "Gain / loss text", function() return db.showGains end,
        function(v) db.showGains = v; CI:RefreshDisplay() end)

    Toggle(0,   -134, "Hide in combat", function() return vis.hideInCombat end,
        function(v) vis.hideInCombat = v; CI:ApplyVisibilityRules() end)
    Toggle(200, -134, "Hide on Currency tab", function() return vis.hideOnCurrencyTab end,
        function(v) vis.hideOnCurrencyTab = v; CI:ApplyVisibilityRules() end)
    Toggle(400, -134, "Fade when not hovered", function() return vis.fadeIdle end,
        function(v) vis.fadeIdle = v; CI:ApplyVisibilityRules() end)
    Toggle(600, -134, "Minimap icon", function() return not db.minimap.hide end,
        function(v) db.minimap.hide = not v; CI:UpdateMinimapButton() end)
end

function CI:RefreshDisplaySettingsUI()
    for _, fn in ipairs(self.dsRefreshers or {}) do fn() end
    if self.accentSwatch then self.accentSwatch.Refresh() end
end

-- ============================================================
-- Per-currency options popup (text color, cap behaviour)
-- ============================================================

local function BuildOptionsPopup()
    local cfg = CI.configFrame
    local p = CreateFrame("Frame", nil, cfg)
    p:SetSize(400, 280)
    p:SetPoint("CENTER", cfg, "CENTER", 0, 0)
    p:SetFrameLevel(cfg:GetFrameLevel() + 60)
    p:EnableMouse(true)
    UI.Surface(p, UI.Colors.popup, { 1, 1, 1, 0.18 })
    UI.FadeInOnShow(p)
    p:Hide()
    cfg:HookScript("OnHide", function() p:Hide() end)

    local title = UI.Text(p, "title", "")
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -14)
    title:SetWidth(330)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    UI.AccentText(title)
    local closeBtn = UI.CloseButton(p, 26)
    closeBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -10)
    closeBtn:SetScript("OnClick", function() p:Hide() end)

    local function Changed()
        if p.row then p.row:UpdatePreview(); p.row:UpdateMarker() end
        CI:RefreshDisplay()
    end

    local function RowLabel(text, y)
        local c = Caption(p, text)
        c:SetPoint("TOPLEFT", p, "TOPLEFT", 16, y - 5)
        return c
    end

    -- Text color
    RowLabel("Text color", -56)
    local textSwatch = UI.ColorSwatch(p,
        function()
            local c = p.cur and p.cur.textColor
            if c then return c[1], c[2], c[3] end
            return 1, 1, 1
        end,
        function(r, g, b) p.cur.textColor = { r, g, b }; Changed() end, 22)
    textSwatch:SetPoint("TOPLEFT", p, "TOPLEFT", 150, -56)
    local textReset = Button(p, "Reset", 60, 22)
    textReset:SetPoint("LEFT", textSwatch, "RIGHT", 10, 0)
    textReset:SetScript("OnClick", function()
        p.cur.textColor = nil
        textSwatch.Refresh()
        Changed()
    end)

    -- When capped
    RowLabel("When capped", -94)
    local capDD = DropDown(p, 170, ns.CAP_ACTIONS, "none", function(opt)
        p.cur.capAction = opt.id
        p:UpdateEnabled()
        Changed()
    end)
    capDD:SetPoint("TOPLEFT", p, "TOPLEFT", 150, -94)

    -- Cap color
    local capColorLbl = RowLabel("Cap color", -132)
    local capSwatch = UI.ColorSwatch(p,
        function()
            local c = p.cur and p.cur.capColor or { 0.3, 1, 0.5 }
            return c[1], c[2], c[3]
        end,
        function(r, g, b) p.cur.capColor = { r, g, b }; Changed() end, 22)
    capSwatch:SetPoint("TOPLEFT", p, "TOPLEFT", 150, -132)

    -- Threshold
    local thrLbl = RowLabel("Capped at", -170)
    local thr = UI.Slider(p, 150, 50, 100, 5, 100, function(v)
        p.cur.capThreshold = v
        Changed()
    end, function(v) return v .. "%" end)
    thr:SetPoint("TOPLEFT", p, "TOPLEFT", 150, -170)

    local hint = UI.Text(p, "small",
        "Capped means current / max (or total earned / max, or weekly earned / weekly cap, whichever is highest) has reached this percentage.")
    hint:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -212)
    hint:SetWidth(368)
    hint:SetJustifyH("LEFT")

    function p:UpdateEnabled()
        local action = self.cur.capAction
        local colorOn = action == "color"
        capColorLbl:SetAlpha(colorOn and 1 or 0.35)
        capSwatch:SetAlpha(colorOn and 1 or 0.35)
        capSwatch:EnableMouse(colorOn)
        local anyOn = action ~= "none"
        thrLbl:SetAlpha(anyOn and 1 or 0.35)
        thr:SetAlpha(anyOn and 1 or 0.35)
        thr:EnableMouse(anyOn)
    end

    function p:Load(row)
        self.row, self.cur = row, row.cur
        title:SetText(row.data and row.data.name or ("Currency " .. row.cur.id))
        textSwatch.Refresh()
        capSwatch.Refresh()
        capDD:SetCurrentId(row.cur.capAction)
        thr:SetValueSilent(row.cur.capThreshold)
        self:UpdateEnabled()
    end

    return p
end

function CI:OpenRowOptions(row)
    if not self.optionsPopup then self.optionsPopup = BuildOptionsPopup() end
    local p = self.optionsPopup
    if p:IsShown() and p.row == row then p:Hide() return end
    p:Load(row)
    p:Show()
end

-- ============================================================
-- Currency list rows (pooled; SetData rebinds a row to a currency)
-- ============================================================

local function SmallBtn(row, x, tex, tooltip, onClick)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(18, 18)
    b:SetPoint("LEFT", row, "LEFT", x, 0)
    b:SetNormalTexture(tex)
    b:GetNormalTexture():SetVertexColor(1, 1, 1, 0.55)
    b:SetHighlightTexture(tex, "ADD")
    UI.OnAccent(function(r, g, bl) b:GetHighlightTexture():SetVertexColor(r, g, bl, 0.9) end)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", HideTooltip)
    return b
end

local function BuildRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(parent:GetWidth(), ROW_H)
    row.baseLevel = row:GetFrameLevel()
    UI.RowStripe(row, index)

    -- Drag handle
    local grip = CreateFrame("Button", nil, row)
    grip:SetSize(16, ROW_H)
    grip:SetPoint("LEFT", row, "LEFT", COL_GRIP, 0)
    local bars = {}
    for k = -1, 1 do
        local bar = grip:CreateTexture(nil, "ARTWORK")
        bar:SetSize(10, 2)
        bar:SetPoint("CENTER", grip, "CENTER", 0, k * 4)
        bar:SetColorTexture(1, 1, 1, 0.3)
        bars[#bars + 1] = bar
    end
    local function GripAlpha(a) for _, b in ipairs(bars) do b:SetAlpha(a) end end
    grip:SetScript("OnEnter", function(self)
        GripAlpha(2.5)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Drag to reorder", 1, 1, 1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GripAlpha(1); GameTooltip:Hide() end)

    local function DragUpdate()
        local content = row:GetParent()
        local offset = content:GetTop() - select(2, GetCursorPosition()) / content:GetEffectiveScale()
        local n = #CI.db.currencies
        local y = math.max(0, math.min((n - 1) * (ROW_H + ROW_PAD), offset - ROW_H / 2))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        row.dropIndex = math.max(1, math.min(n, math.floor(offset / (ROW_H + ROW_PAD)) + 1))
    end
    local function EndDrag()
        if not row.dragging then return end
        row.dragging = false
        row:SetScript("OnUpdate", nil)
        row:SetAlpha(1)
        row:SetFrameLevel(row.baseLevel)
        local from, to = row.index, row.dropIndex
        if to and to ~= from then
            local t = CI.db.currencies
            table.insert(t, to, table.remove(t, from))
            CI:RefreshDisplay()
        end
        CI:RefreshConfigCurrencyList()
    end
    grip:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        row.dragging, row.dropIndex = true, row.index
        row:SetFrameLevel(row.baseLevel + 20)
        row:SetAlpha(0.85)
        row:SetScript("OnUpdate", DragUpdate)
    end)
    grip:SetScript("OnMouseUp", EndDrag)
    grip:SetScript("OnHide", EndDrag)

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", row, "LEFT", COL_ICON, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Name
    local nameLbl = UI.Text(row, "body")
    nameLbl:SetPoint("LEFT", row, "LEFT", COL_NAME, 0)
    nameLbl:SetWidth(COL_FMT - COL_NAME - 6)
    nameLbl:SetJustifyH("LEFT")
    nameLbl:SetWordWrap(false)

    -- Format dropdown
    local fmtDD = DropDown(row, COL_CUSTOM - COL_FMT - 6, FORMAT_PRESETS, "current_max", function(opt)
        local cur, prev = row.cur, row.cur.formatPreset
        cur.formatPreset = opt.id
        -- Start "Custom" from the preset that was in use, unless the user wrote their own before.
        if opt.id == "custom" and not cur.customEdited then
            cur.customTemplate = ns.GetPresetTemplate(prev) or cur.customTemplate
        end
        row:SyncTemplate()
        row:UpdatePreview()
        CI:RefreshDisplay()
    end)
    fmtDD:SetPoint("LEFT", row, "LEFT", COL_FMT, 0)

    -- Template: shows the preset's template greyed out, editable once "Custom" is chosen
    -- (turns red on an unknown {token})
    local ctBox = EditBox(row, COL_PREVIEW - COL_CUSTOM - 6, 24)
    ctBox:SetPoint("LEFT", row, "LEFT", COL_CUSTOM, 0)
    ctBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    ctBox:SetScript("OnTextChanged", function(self, user)
        local bad = HasUnknownToken(self:GetText())
        if bad then self:SetTextColor(1, 0.45, 0.45) else self:SetTextColor(1, 1, 1) end
        if not user then return end
        row.cur.customTemplate = self:GetText()
        row.cur.customEdited = true
        row:UpdatePreview()
        CI:RefreshDisplay()
    end)
    ctBox:SetScript("OnEnter", ShowTokenTooltip)
    ctBox:SetScript("OnLeave", HideTooltip)
    row.ctBox = ctBox

    -- Live preview of what the display will show
    local preview = UI.Text(row, "body")
    preview:SetPoint("LEFT", row, "LEFT", COL_PREVIEW, 0)
    preview:SetWidth(COL_ICON_CB - COL_PREVIEW - 8)
    preview:SetJustifyH("LEFT")
    preview:SetWordWrap(false)

    -- Show icon
    local iconCb = Checkbox(row, true, nil, function(checked)
        row.cur.showIcon = checked
        CI:RefreshDisplay()
    end)
    iconCb:SetPoint("LEFT", row, "LEFT", COL_ICON_CB, 0)

    -- Hide name: presets only (a Custom template decides for itself)
    local hideCb = Checkbox(row, false, nil, function(checked)
        row.cur.hideName = checked
        row:UpdatePreview()
        CI:RefreshDisplay()
    end)
    hideCb:SetPoint("LEFT", row, "LEFT", COL_HIDENAME, 0)

    -- Options (color / cap behaviour) and remove
    local optsBtn = SmallBtn(row, COL_OPTS, "Interface\\Buttons\\UI-OptionsButton",
        "Color and cap options", function() CI:OpenRowOptions(row) end)
    SmallBtn(row, COL_DEL, "Interface\\Buttons\\UI-StopButton", "Remove", function()
        CI:RemoveCurrency(row.cur.id)
    end)

    function row:SyncTemplate()
        local cur = self.cur
        local custom = cur.formatPreset == "custom"
        ctBox:SetText(custom and (cur.customTemplate or "") or ns.GetPresetTemplate(cur.formatPreset) or "")
        ctBox:SetActive(custom)
        hideCb:SetEnabled(not custom)
    end

    function row:UpdatePreview()
        local cur = self.cur
        if not self.data then
            preview:SetText("-")
            preview:SetTextColor(1, 1, 1, 0.5)
            return
        end
        preview:SetText(ns.FormatCurrency(cur, self.data))
        local c = cur.textColor
        if c then preview:SetTextColor(c[1], c[2], c[3], 1) else preview:SetTextColor(1, 1, 1, 0.9) end
    end

    -- Tint the options button when this currency has non-default color / cap settings.
    function row:UpdateMarker()
        local cur = self.cur
        local tex = optsBtn:GetNormalTexture()
        if cur.textColor or cur.capAction ~= "none" then
            tex:SetVertexColor(UI.accent.r, UI.accent.g, UI.accent.b, 1)
        else
            tex:SetVertexColor(1, 1, 1, 0.55)
        end
    end

    function row:SetData(i, cur)
        DeepMerge(cur, ns.CURRENCY_DEFAULTS)
        local data = ns.GetCurrencyData(cur.id)
        self.index, self.cur, self.data = i, cur, data

        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((i - 1) * (ROW_H + ROW_PAD)))

        if data and data.iconFileID then
            icon:SetTexture(data.iconFileID)
            icon:Show()
        else
            icon:Hide()
        end
        if data then
            nameLbl:SetText(data.name)
            nameLbl:SetTextColor(1, 1, 1, 0.9)
        else
            nameLbl:SetText("Unknown (ID " .. cur.id .. ")")
            nameLbl:SetTextColor(1, 0.4, 0.4, 1)
        end

        fmtDD:SetCurrentId(cur.formatPreset)
        hideCb:SetState(cur.hideName)
        self:SyncTemplate()
        iconCb:SetState(cur.showIcon)

        self:UpdatePreview()
        self:UpdateMarker()
    end

    return row
end

function CI:RefreshConfigCurrencyList()
    if not self.cfgContent then return end
    self.cfgRows = self.cfgRows or {}

    local currencies = self.db.currencies
    for i, cur in ipairs(currencies) do
        local row = self.cfgRows[i]
        if not row then
            row = BuildRow(self.cfgContent, i)
            self.cfgRows[i] = row
        end
        row:SetData(i, cur)
        row:Show()
    end
    for i = #currencies + 1, #self.cfgRows do
        self.cfgRows[i]:Hide()
    end

    -- The options popup may point at a row that moved or was removed.
    if self.optionsPopup and self.optionsPopup:IsShown() then self.optionsPopup:Hide() end

    if #currencies == 0 then
        self.cfgEmpty:Show()
        self.cfgContent:SetHeight(140)
    else
        self.cfgEmpty:Hide()
        self.cfgContent:SetHeight(#currencies * (ROW_H + ROW_PAD) + ROW_PAD)
    end
end

-- ============================================================
-- Open / toggle config visibility
-- ============================================================

function CI:OpenConfig()
    if not self.configFrame then
        self:CreateConfigFrame()
    end
    if not self.configFrame:IsShown() then
        self:RefreshConfigCurrencyList()
        self.configFrame:Show()
    end
end

function CI:ToggleConfig()
    if self.configFrame and self.configFrame:IsShown() then
        self.configFrame:Hide()
    else
        self:OpenConfig()
    end
end

-- ============================================================
-- Blizzard options entry (Esc > Options > AddOns)
-- ============================================================

function CI:RegisterSettingsPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end

    local panel = CreateFrame("Frame")
    panel.name = "CurrencyInfo"

    local title = UI.Text(panel, "title", "CurrencyInfo")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    UI.AccentText(title)
    local desc = UI.Text(panel, "body", "Track and display currencies with custom formatting.\nYou can also type /ci or right-click the display.")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetJustifyH("LEFT")
    local btn = Button(panel, "Open settings", 160, 28)
    btn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    btn:SetScript("OnClick", function()
        if SettingsPanel and not InCombatLockdown() then HideUIPanel(SettingsPanel) end
        CI:OpenConfig()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "CurrencyInfo")
    Settings.RegisterAddOnCategory(category)
end

-- ============================================================
-- Shift-click a currency (Currency tab) while settings are open to track it
-- ============================================================

local function OnInsertLink(text)
    if type(text) ~= "string" or not CI.db then return end
    if not (CI.configFrame and CI.configFrame:IsShown()) then return end
    -- If a chat box was active the link went there, not to us.
    local getActive = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow) or ChatEdit_GetActiveWindow
    if getActive and getActive() then return end
    local id = tonumber(text:match("currency:(%d+)"))
    if not id then return end
    local ok, msg = CI:AddCurrency(id)
    if ok then
        CI:SetFeedback("Added: " .. msg, 0.5, 1, 0.5)
    else
        CI:SetFeedback(msg, 1, 0.8, 0)
    end
end

if ChatFrameUtil and ChatFrameUtil.InsertLink then
    hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink)
elseif ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", OnInsertLink)
end
