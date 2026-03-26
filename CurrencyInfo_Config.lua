-- CurrencyInfo_Config.lua
-- Settings UI

local ADDON_NAME, ns = ...

local CI              = CurrencyInfoAddon
local FORMAT_PRESETS  = ns.FORMAT_PRESETS
local FONT_OPTIONS    = ns.FONT_OPTIONS
local DeepMerge       = ns.DeepMerge
local FNum            = ns.FNum

local CFG_W = 680
local CFG_H = 560

-- Row layout in the currency list
local ROW_H     = 28
local ROW_PAD   = 4
local COL_ICON  = 0
local COL_NAME  = 26
local COL_LABEL = 102
local COL_FMT   = 250
local COL_ICON_CB = 408
local COL_UP    = 438
local COL_DOWN  = 460
local COL_DEL   = 482

-- ============================================================
-- Widget helpers
-- ============================================================

local function Label(parent, text, size)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if size then fs:SetFont("Fonts\\FRIZQT__.TTF", size, "") end
    fs:SetText(text)
    return fs
end

local function Button(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 80, h or 22)
    b:SetText(text)
    return b
end

-- Minimal styled edit box
local function EditBox(parent, w, h)
    local wrap = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    wrap:SetSize(w or 120, h or 22)
    wrap:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    wrap:SetBackdropColor(0, 0, 0, 0.6)
    wrap:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)

    local eb = CreateFrame("EditBox", nil, wrap)
    eb:SetPoint("TOPLEFT",     wrap, "TOPLEFT",     4, -2)
    eb:SetPoint("BOTTOMRIGHT", wrap, "BOTTOMRIGHT", -4, 2)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    wrap.editBox = eb
    return wrap
end

-- Cycle button: left-click → forward, right-click → backward
-- options: array of { id, label, ... }
-- currentId: id of initial selection
-- onChange: function(option) called on change
local function CycleButton(parent, options, currentId, onChange)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(150, 22)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local idx = 1
    for i, opt in ipairs(options) do
        if opt.id == currentId then idx = i; break end
    end

    local function Refresh()
        btn:SetText(options[idx].label .. " \xE2\x96\xB8")  -- ▸ suffix
    end
    Refresh()

    btn:SetScript("OnClick", function(self, mouseBtn)
        if mouseBtn == "RightButton" then
            idx = idx == 1 and #options or idx - 1
        else
            idx = idx == #options and 1 or idx + 1
        end
        Refresh()
        if onChange then onChange(options[idx]) end
    end)

    function btn:SetById(id)
        for i, opt in ipairs(options) do
            if opt.id == id then idx = i; break end
        end
        Refresh()
    end

    function btn:GetCurrentId() return options[idx].id end

    return btn
end

-- Simple checkbox (WoW's UICheckButtonTemplate, with optional label to the right)
local function Checkbox(parent, checked, label, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetChecked(checked)
    if label and cb.text then cb.text:SetText(label) end
    cb:SetScript("OnClick", function(self)
        if onChange then onChange(self:GetChecked()) end
    end)
    return cb
end

-- Horizontal separator line
local function Separator(parent, yAnchor)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",  parent, "TOPLEFT",  16, yAnchor)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yAnchor)
    line:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    return line
end

-- ============================================================
-- Config Frame creation
-- ============================================================

function CI:CreateConfigFrame()
    local f = CreateFrame("Frame", "CurrencyInfoConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(CFG_W, CFG_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 20,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    f:SetFrameStrata("HIGH")
    f:Hide()
    self.configFrame = f

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("CurrencyInfo Settings")
    title:SetTextColor(1, 0.82, 0)

    -- Close
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    Separator(f, -34)

    -- ---- Add Currency ----
    local addLabel = Label(f, "Add Currency:", 11)
    addLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -46)
    addLabel:SetTextColor(0.85, 0.85, 0.85)

    local idBox = EditBox(f, 100, 24)
    idBox:SetPoint("TOPLEFT", f, "TOPLEFT", 108, -44)
    idBox.editBox:SetNumeric(true)
    idBox.editBox:SetMaxLetters(10)

    -- Placeholder
    local idPlaceholder = f:CreateFontString(nil, "OVERLAY")
    idPlaceholder:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    idPlaceholder:SetPoint("LEFT", idBox, "LEFT", 6, 0)
    idPlaceholder:SetText("Currency ID")
    idPlaceholder:SetTextColor(0.45, 0.45, 0.45)
    idBox.editBox:SetScript("OnEditFocusGained", function() idPlaceholder:Hide() end)
    idBox.editBox:SetScript("OnEditFocusLost",   function(self)
        if self:GetText() == "" then idPlaceholder:Show() end
    end)

    local addBtn = Button(f, "Add", 60, 24)
    addBtn:SetPoint("LEFT", idBox, "RIGHT", 6, 0)

    -- Preview / feedback label
    local feedback = f:CreateFontString(nil, "OVERLAY")
    feedback:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    feedback:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
    feedback:SetText("")

    idBox.editBox:SetScript("OnTextChanged", function(self)
        local id = tonumber(self:GetText())
        if id then
            local data = ns.GetCurrencyData(id)
            if data then
                feedback:SetText(data.name)
                feedback:SetTextColor(0.5, 1, 0.5)
            else
                feedback:SetText("Unknown ID")
                feedback:SetTextColor(1, 0.4, 0.4)
            end
        else
            feedback:SetText("")
        end
    end)

    local function DoAdd()
        local id = tonumber(idBox.editBox:GetText())
        if not id then return end
        for _, c in ipairs(CI.db.currencies) do
            if c.id == id then
                feedback:SetText("Already tracked!")
                feedback:SetTextColor(1, 0.8, 0)
                return
            end
        end
        local data = ns.GetCurrencyData(id)
        if not data then
            feedback:SetText("Invalid currency ID")
            feedback:SetTextColor(1, 0.4, 0.4)
            return
        end
        local newCurr = {}
        DeepMerge(newCurr, ns.CURRENCY_DEFAULTS)
        newCurr.id = id
        table.insert(CI.db.currencies, newCurr)
        idBox.editBox:SetText("")
        idPlaceholder:Show()
        feedback:SetText("Added: " .. data.name)
        feedback:SetTextColor(0.5, 1, 0.5)
        CI:RefreshDisplay()
        CI:RefreshConfigCurrencyList()
    end

    addBtn:SetScript("OnClick", DoAdd)
    idBox.editBox:SetScript("OnEnterPressed", function(self)
        DoAdd()
        self:ClearFocus()
    end)

    Separator(f, -78)

    -- ---- Currency List header ----
    local listLabel = Label(f, "Tracked Currencies:", 11)
    listLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -88)
    listLabel:SetTextColor(0.85, 0.85, 0.85)

    -- Token reference tooltip on the label
    listLabel:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Custom Template Tokens", 1, 0.82, 0)
        GameTooltip:AddLine("{label}    — custom label or currency name", 1, 1, 1)
        GameTooltip:AddLine("{current}  — current quantity",              1, 1, 1)
        GameTooltip:AddLine("{max}      — maximum quantity",              1, 1, 1)
        GameTooltip:AddLine("{earned}   — total earned",                  1, 1, 1)
        GameTooltip:AddLine("{left}     — left to earn (max − earned)",   1, 1, 1)
        GameTooltip:AddLine("{weekly}   — earned this week",              1, 1, 1)
        GameTooltip:AddLine("{weeklycap}— weekly cap",                    1, 1, 1)
        GameTooltip:AddLine("{pct}      — percentage current/max",        1, 1, 1)
        GameTooltip:Show()
    end)
    listLabel:SetScript("OnLeave", function() GameTooltip:Hide() end)
    listLabel:EnableMouse(true)

    -- Column headers
    local hdrY = -104
    local function ColHdr(text, x)
        local lbl = f:CreateFontString(nil, "OVERLAY")
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
        lbl:SetPoint("TOPLEFT", f, "TOPLEFT", 16 + x, hdrY)
        lbl:SetText(text)
        lbl:SetTextColor(0.6, 0.6, 0.6)
    end
    ColHdr("",             COL_ICON)
    ColHdr("Name",         COL_NAME)
    ColHdr("Custom Label", COL_LABEL)
    ColHdr("Format",       COL_FMT)
    ColHdr("Icon",         COL_ICON_CB)

    -- Scroll frame for currency rows
    local scrollFrame = CreateFrame("ScrollFrame", "CIConfigScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     f, "TOPLEFT",     16, -120)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -36, 112)
    self.cfgScroll = scrollFrame

    local scrollContent = CreateFrame("Frame", "CIConfigScrollContent", scrollFrame)
    scrollContent:SetWidth(scrollFrame:GetWidth() - 4)
    scrollContent:SetHeight(60)
    scrollFrame:SetScrollChild(scrollContent)
    self.cfgContent = scrollContent

    Separator(f, -448)

    -- ---- Display Settings ----
    local dsLabel = Label(f, "Display Settings:", 11)
    dsLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 95)
    dsLabel:SetTextColor(0.85, 0.85, 0.85)

    local dsFrame = CreateFrame("Frame", nil, f)
    dsFrame:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  16, 14)
    dsFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    dsFrame:SetHeight(80)
    self:BuildDisplaySettings(dsFrame)
end

-- ============================================================
-- Display Settings panel (inside config frame)
-- ============================================================

function CI:BuildDisplaySettings(p)
    local layout = self.db.layout
    local db     = self.db

    -- Row 1: Layout direction, Font face, Font size
    local dirLbl = Label(p, "Layout:", 11); dirLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0); dirLbl:SetTextColor(0.85,0.85,0.85)

    local colBtn = Button(p, "Column", 70, 22); colBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 56, 2)
    local rowBtn = Button(p, "Row",    70, 22); rowBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 130, 2)

    local function UpdateDirBtns()
        if layout.direction == "column" then
            colBtn:SetNormalFontObject(GameFontHighlight)
            rowBtn:SetNormalFontObject(GameFontNormal)
        else
            colBtn:SetNormalFontObject(GameFontNormal)
            rowBtn:SetNormalFontObject(GameFontHighlight)
        end
    end
    UpdateDirBtns()
    colBtn:SetScript("OnClick", function() layout.direction = "column"; UpdateDirBtns(); CI:RefreshDisplay() end)
    rowBtn:SetScript("OnClick", function() layout.direction = "row";    UpdateDirBtns(); CI:RefreshDisplay() end)

    local fontLbl = Label(p, "Font:", 11); fontLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 218, 0); fontLbl:SetTextColor(0.85,0.85,0.85)
    local fontBtn = CycleButton(p, FONT_OPTIONS, nil, function(opt)
        layout.fontFace = opt.path
        CI:RefreshDisplay()
    end)
    fontBtn:SetSize(156, 22)
    fontBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 252, 2)
    -- Set initial font selection
    for _, opt in ipairs(FONT_OPTIONS) do
        if opt.path == layout.fontFace then fontBtn:SetById(opt.id); break end
    end

    local fsLbl = Label(p, "Font Size:", 11); fsLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 422, 0); fsLbl:SetTextColor(0.85,0.85,0.85)
    local fsBox = EditBox(p, 44, 22); fsBox:SetPoint("TOPLEFT", p, "TOPLEFT", 494, 2)
    fsBox.editBox:SetNumeric(true)
    fsBox.editBox:SetText(tostring(layout.fontSize))
    fsBox.editBox:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v and v >= 6 and v <= 48 then layout.fontSize = v; CI:RefreshDisplay() end
        self:ClearFocus()
    end)

    -- Row 2: Icon size, Spacing, Background, Lock
    local iconLbl = Label(p, "Icon Size:", 11); iconLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -30); iconLbl:SetTextColor(0.85,0.85,0.85)
    local iconBox = EditBox(p, 44, 22); iconBox:SetPoint("TOPLEFT", p, "TOPLEFT", 70, -28)
    iconBox.editBox:SetNumeric(true)
    iconBox.editBox:SetText(tostring(layout.iconSize))
    iconBox.editBox:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v and v >= 8 and v <= 64 then layout.iconSize = v; CI:RefreshDisplay() end
        self:ClearFocus()
    end)

    local spcLbl = Label(p, "Spacing:", 11); spcLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 124, -30); spcLbl:SetTextColor(0.85,0.85,0.85)
    local spcBox = EditBox(p, 44, 22); spcBox:SetPoint("TOPLEFT", p, "TOPLEFT", 186, -28)
    spcBox.editBox:SetNumeric(true)
    spcBox.editBox:SetText(tostring(layout.spacing))
    spcBox.editBox:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v and v >= 0 and v <= 60 then layout.spacing = v; CI:RefreshDisplay() end
        self:ClearFocus()
    end)

    local bgCb = Checkbox(p, layout.showBackground, "Background", function(checked)
        layout.showBackground = checked
        CI:UpdateBackdrop()
    end)
    bgCb:SetPoint("TOPLEFT", p, "TOPLEFT", 244, -28)

    local lockCb = Checkbox(p, db.locked, "Lock Position", function(checked)
        db.locked = checked
    end)
    lockCb:SetPoint("TOPLEFT", p, "TOPLEFT", 380, -28)
end

-- ============================================================
-- Currency list rows
-- ============================================================

function CI:BuildCurrencyRow(parent, index, currSettings)
    local data = ns.GetCurrencyData(currSettings.id)
    if not data then return end

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(parent:GetWidth(), ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * (ROW_H + ROW_PAD)))

    -- Alternating row bg
    if index % 2 == 0 then
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(1, 1, 1, 0.04)
    end

    -- Icon
    if data.iconFileID then
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", row, "LEFT", COL_ICON, 0)
        icon:SetTexture(data.iconFileID)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    -- Name
    local nameLbl = row:CreateFontString(nil, "OVERLAY")
    nameLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    nameLbl:SetPoint("LEFT", row, "LEFT", COL_NAME, 0)
    nameLbl:SetWidth(COL_LABEL - COL_NAME - 4)
    nameLbl:SetText(data.name)
    nameLbl:SetTextColor(0.9, 0.9, 0.9)
    nameLbl:SetJustifyH("LEFT")
    nameLbl:SetWordWrap(false)

    -- Custom label input
    local labelBox = EditBox(row, COL_FMT - COL_LABEL - 6, 22)
    labelBox:SetPoint("LEFT", row, "LEFT", COL_LABEL, 0)
    labelBox.editBox:SetText(currSettings.customLabel or "")
    local function SaveLabel(self)
        currSettings.customLabel = self:GetText()
        CI:RefreshDisplay()
    end
    labelBox.editBox:SetScript("OnEnterPressed", function(self) SaveLabel(self); self:ClearFocus() end)
    labelBox.editBox:SetScript("OnEditFocusLost", SaveLabel)

    -- Format cycle button + custom template box below it (if custom selected)
    local fmtBtn = CycleButton(row, FORMAT_PRESETS, currSettings.formatPreset, function(opt)
        currSettings.formatPreset = opt.id
        row.ctBox:SetShown(opt.id == "custom")
        CI:RefreshDisplay()
    end)
    fmtBtn:SetSize(COL_ICON_CB - COL_FMT - 6, 22)
    fmtBtn:SetPoint("LEFT", row, "LEFT", COL_FMT, 0)
    fmtBtn:SetById(currSettings.formatPreset)

    -- Custom template edit box (shown only when "custom" preset is active)
    local ctBox = EditBox(row, COL_ICON_CB - COL_FMT - 6, 20)
    ctBox:SetPoint("TOPLEFT", row, "TOPLEFT", COL_FMT, -(ROW_H / 2))
    ctBox:SetShown(currSettings.formatPreset == "custom")
    ctBox.editBox:SetText(currSettings.customTemplate or "")
    ctBox.editBox:SetFontObject(ChatFontNormal)
    local function SaveTemplate(self)
        currSettings.customTemplate = self:GetText()
        CI:RefreshDisplay()
    end
    ctBox.editBox:SetScript("OnEnterPressed", function(self) SaveTemplate(self); self:ClearFocus() end)
    ctBox.editBox:SetScript("OnEditFocusLost", SaveTemplate)
    row.ctBox = ctBox

    -- Show Icon checkbox
    local iconCb = Checkbox(row, currSettings.showIcon, nil, function(checked)
        currSettings.showIcon = checked
        CI:RefreshDisplay()
    end)
    iconCb:SetPoint("LEFT", row, "LEFT", COL_ICON_CB, 0)

    -- Up / Down / Remove buttons
    local function SmallBtn(x, normalTex, highlightTex, tooltip, onClick)
        local b = CreateFrame("Button", nil, row)
        b:SetSize(18, 18)
        b:SetPoint("LEFT", row, "LEFT", x, 0)
        b:SetNormalTexture(normalTex)
        b:SetHighlightTexture(highlightTex, "ADD")
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end

    SmallBtn(COL_UP,   "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up",
                       "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up",   "Move Up", function()
        local t = CI.db.currencies
        if index > 1 then t[index], t[index-1] = t[index-1], t[index]; CI:RefreshDisplay(); CI:RefreshConfigCurrencyList() end
    end)

    SmallBtn(COL_DOWN, "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up",
                       "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up", "Move Down", function()
        local t = CI.db.currencies
        if index < #t then t[index], t[index+1] = t[index+1], t[index]; CI:RefreshDisplay(); CI:RefreshConfigCurrencyList() end
    end)

    SmallBtn(COL_DEL,  "Interface\\Buttons\\UI-StopButton",
                       "Interface\\Buttons\\UI-StopButton",               "Remove", function()
        table.remove(CI.db.currencies, index)
        CI:RefreshDisplay()
        CI:RefreshConfigCurrencyList()
    end)
end

function CI:RefreshConfigCurrencyList()
    if not self.cfgContent then return end

    -- Clear old rows
    local children = { self.cfgContent:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
    -- Also clear any font strings (hint text)
    self.cfgContent.hintText = nil

    local currencies = self.db.currencies
    if #currencies == 0 then
        if not self.cfgContent.hintText then
            local hint = self.cfgContent:CreateFontString(nil, "OVERLAY")
            hint:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
            hint:SetText("No currencies tracked yet. Enter a currency ID above and click Add.")
            hint:SetTextColor(0.5, 0.5, 0.5)
            hint:SetPoint("CENTER", self.cfgContent, "CENTER", 0, 0)
            self.cfgContent.hintText = hint
        end
        self.cfgContent:SetHeight(60)
        return
    end

    for i, currSettings in ipairs(currencies) do
        self:BuildCurrencyRow(self.cfgContent, i, currSettings)
    end
    self.cfgContent:SetHeight(math.max(#currencies * (ROW_H + ROW_PAD) + ROW_PAD, 60))
end

-- ============================================================
-- Toggle config visibility
-- ============================================================

function CI:ToggleConfig()
    if not self.configFrame then
        self:CreateConfigFrame()
    end
    if self.configFrame:IsShown() then
        self.configFrame:Hide()
    else
        self:RefreshConfigCurrencyList()
        self.configFrame:Show()
    end
end
