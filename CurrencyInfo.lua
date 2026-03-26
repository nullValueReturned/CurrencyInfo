-- CurrencyInfo.lua
-- Core display logic

local ADDON_NAME, ns = ...
local VERSION = "1.0.0"

-- ============================================================
-- Shared Constants (used by Config too)
-- ============================================================

ns.FORMAT_PRESETS = {
    { id = "current",      label = "Current",           template = "{label}: {current}" },
    { id = "current_max",  label = "Current / Max",     template = "{label}: {current} / {max}" },
    { id = "current_left", label = "Current (Left)",    template = "{label}: {current} ({left} left)" },
    { id = "earned",       label = "Total Earned",      template = "{label}: {earned}" },
    { id = "earned_max",   label = "Earned / Max",      template = "{label}: {earned} / {max}" },
    { id = "weekly",       label = "Weekly Progress",   template = "{label}: {weekly} / {weeklycap}" },
    { id = "pct",          label = "Percentage",        template = "{label}: {pct}" },
    { id = "custom",       label = "Custom",            template = nil },
}

ns.FONT_OPTIONS = {
    { id = "Fonts\\FRIZQT__.TTF", label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { id = "Fonts\\MORPHEUS.TTF", label = "Morpheus",       path = "Fonts\\MORPHEUS.TTF" },
    { id = "Fonts\\ARIALN.TTF",   label = "Arial Narrow",   path = "Fonts\\ARIALN.TTF" },
    { id = "Fonts\\skurri.TTF",   label = "Skurri",         path = "Fonts\\skurri.TTF" },
}

-- Returns font options from LibSharedMedia-3.0 if loaded, otherwise the built-in list.
-- Each entry: { id = path, label = name, path = path }
function ns.GetFontOptions()
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm then
        local opts = {}
        for _, name in ipairs(lsm:List("font")) do
            local path = lsm:Fetch("font", name)
            opts[#opts + 1] = { id = path, label = name, path = path }
        end
        table.sort(opts, function(a, b) return a.label < b.label end)
        return opts
    end
    return ns.FONT_OPTIONS
end

local DB_DEFAULTS = {
    currencies = {},
    layout = {
        direction     = "column",
        spacing       = 6,
        iconSize      = 16,
        fontSize      = 12,
        fontFace      = "Fonts\\FRIZQT__.TTF",
        padding       = 8,
        showBackground = true,
    },
    position = { point = "CENTER", x = 0, y = 0 },
    locked   = false,
}

ns.CURRENCY_DEFAULTS = {
    id             = 0,
    customLabel    = "",
    showIcon       = true,
    formatPreset   = "current_max",
    customTemplate = "{label}: {current} / {max}",
}

-- ============================================================
-- Utility
-- ============================================================

local function DeepMerge(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            DeepMerge(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end
ns.DeepMerge = DeepMerge

local function FNum(n)
    if not n or n == 0 then return "0" end
    return BreakUpLargeNumbers(math.floor(n))
end
ns.FNum = FNum

local function ApplyTemplate(template, data)
    local r = template
    r = r:gsub("{label}",     function() return data.label or "" end)
    r = r:gsub("{current}",   function() return FNum(data.current) end)
    r = r:gsub("{max}",       function() return FNum(data.max) end)
    r = r:gsub("{earned}",    function() return FNum(data.earned) end)
    r = r:gsub("{left}",      function() return FNum(data.left) end)
    r = r:gsub("{weekly}",    function() return FNum(data.weekly) end)
    r = r:gsub("{weeklycap}", function() return FNum(data.weeklycap) end)
    r = r:gsub("{pct}",       function() return (data.pct and tostring(data.pct) or "0") .. "%%" end)
    return r
end
ns.ApplyTemplate = ApplyTemplate

local function GetCurrencyData(currencyId)
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyId)
    if not info then return nil end
    local max     = info.maxQuantity or 0
    local earned  = info.totalEarned or 0
    local current = info.quantity or 0
    return {
        name       = info.name or ("Currency " .. currencyId),
        current    = current,
        max        = max,
        earned     = earned,
        left       = max > 0 and math.max(0, max - earned) or 0,
        weekly     = info.quantityEarnedThisWeek or 0,
        weeklycap  = info.maxWeeklyQuantity or 0,
        iconFileID = info.iconFileID,
        pct        = max > 0 and math.floor((current / max) * 100) or 0,
    }
end
ns.GetCurrencyData = GetCurrencyData

local function GetTemplate(currSettings)
    if currSettings.formatPreset == "custom" then
        return currSettings.customTemplate or "{label}: {current}"
    end
    for _, p in ipairs(ns.FORMAT_PRESETS) do
        if p.id == currSettings.formatPreset then
            return p.template
        end
    end
    return "{label}: {current}"
end
ns.GetTemplate = GetTemplate

-- ============================================================
-- Addon Object
-- ============================================================

CurrencyInfoAddon = CurrencyInfoAddon or {}
local CI = CurrencyInfoAddon
ns.CI = CI

CI.entries = {}

-- ============================================================
-- Main Display Frame
-- ============================================================

function CI:CreateMainFrame()
    local f = CreateFrame("Frame", "CurrencyInfoMainFrame", UIParent, "BackdropTemplate")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not CI.db.locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        CI.db.position.point = point
        CI.db.position.x     = math.floor(x)
        CI.db.position.y     = math.floor(y)
    end)
    f:SetScript("OnMouseUp", function(self, btn)
        if btn == "RightButton" then CI:ToggleConfig() end
    end)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(10)
    self.mainFrame = f

    -- Gear button (top-right corner)
    local gear = CreateFrame("Button", nil, f)
    gear:SetSize(14, 14)
    gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton", "ADD")
    gear:SetAlpha(0.4)
    gear:SetScript("OnEnter",    function(s) s:SetAlpha(1) end)
    gear:SetScript("OnLeave",    function(s) s:SetAlpha(0.4) end)
    gear:SetScript("OnMouseUp",  function(_, btn) if btn == "LeftButton" then CI:ToggleConfig() end end)
    self.gearBtn = gear

    -- Hint text shown when no currencies are tracked
    local hint = f:CreateFontString(nil, "OVERLAY")
    hint:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    hint:SetText("|cFF888888Right-click to add currencies|r")
    hint:SetPoint("CENTER", f, "CENTER", 0, 0)
    hint:Hide()
    self.hintText = hint

    -- Content frame (entries are anchored inside here)
    local content = CreateFrame("Frame", nil, f)
    self.contentFrame = content
end

function CI:UpdateBackdrop()
    if self.db.layout.showBackground then
        self.mainFrame:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        self.mainFrame:SetBackdropColor(0, 0, 0, 0.75)
        self.mainFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
    else
        self.mainFrame:SetBackdrop(nil)
    end
end

-- ============================================================
-- Entry Frames
-- ============================================================

function CI:ClearEntries()
    for _, e in ipairs(self.entries) do
        e.frame:Hide()
        e.frame:SetParent(nil)
    end
    self.entries = {}
end

function CI:BuildEntryFrame()
    local layout = self.db.layout
    local f = CreateFrame("Frame", nil, self.contentFrame)
    f:SetHeight(layout.iconSize)

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(layout.iconSize, layout.iconSize)
    icon:SetPoint("LEFT", f, "LEFT", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFont(layout.fontFace, layout.fontSize, "OUTLINE")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")

    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        local d = self.ttData
        if not d then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(d.name, 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Current:",      FNum(d.current),  1,1,1, 1,1,0)
        if d.max > 0 then
            GameTooltip:AddDoubleLine("Max:",      FNum(d.max),      1,1,1, 1,1,0)
            GameTooltip:AddDoubleLine("Left:",     FNum(d.left),     1,1,1, 1,1,0)
            GameTooltip:AddDoubleLine("Progress:", d.pct .. "%",     1,1,1, 1,1,0)
        end
        if d.earned > 0 then
            GameTooltip:AddDoubleLine("Total Earned:", FNum(d.earned), 1,1,1, 1,1,0)
        end
        if d.weeklycap > 0 then
            GameTooltip:AddDoubleLine("Weekly:", FNum(d.weekly) .. " / " .. FNum(d.weeklycap), 1,1,1, 1,1,0)
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return { frame = f, icon = icon, text = text }
end

function CI:PopulateEntry(entry, currSettings, data)
    local layout = self.db.layout

    -- Icon
    if currSettings.showIcon and data.iconFileID then
        entry.icon:SetTexture(data.iconFileID)
        entry.icon:SetSize(layout.iconSize, layout.iconSize)
        entry.icon:Show()
        entry.text:SetPoint("LEFT", entry.icon, "RIGHT", 4, 0)
    else
        entry.icon:Hide()
        entry.text:SetPoint("LEFT", entry.frame, "LEFT", 0, 0)
    end

    local label = (currSettings.customLabel ~= "" and currSettings.customLabel) or data.name
    local template = GetTemplate(currSettings)
    local displayText = ApplyTemplate(template, {
        label     = label,
        current   = data.current,
        max       = data.max,
        earned    = data.earned,
        left      = data.left,
        weekly    = data.weekly,
        weeklycap = data.weeklycap,
        pct       = data.pct,
    })

    entry.text:SetFont(layout.fontFace, layout.fontSize, "OUTLINE")
    entry.text:SetText(displayText)

    local entryH = math.max(layout.iconSize, layout.fontSize + 2)
    entry.frame:SetHeight(entryH)

    entry.frame.ttData = {
        name      = data.name,
        current   = data.current,
        max       = data.max,
        earned    = data.earned,
        left      = data.left,
        weekly    = data.weekly,
        weeklycap = data.weeklycap,
        pct       = data.pct,
    }
end

-- ============================================================
-- Layout
-- ============================================================

function CI:LayoutEntries()
    local layout  = self.db.layout
    local padding = layout.padding
    local spacing = layout.spacing
    local isCol   = layout.direction == "column"
    local entryH  = math.max(layout.iconSize, layout.fontSize + 2)

    local totalW, totalH = 0, 0

    for i, e in ipairs(self.entries) do
        e.frame:ClearAllPoints()
        if isCol then
            e.frame:SetPoint("TOPLEFT", self.contentFrame, "TOPLEFT",
                0, -((entryH + spacing) * (i - 1)))
        else
            local xOff = 0
            for j = 1, i - 1 do
                xOff = xOff + self.entries[j].frame:GetWidth() + spacing
            end
            e.frame:SetPoint("TOPLEFT", self.contentFrame, "TOPLEFT", xOff, 0)
        end
        e.frame:Show()

        local iconW = e.icon:IsShown() and (layout.iconSize + 4) or 0
        local w     = iconW + e.text:GetStringWidth() + 2
        e.frame:SetWidth(math.max(w, 30))

        if isCol then
            if w > totalW then totalW = w end
            totalH = totalH + entryH + (i > 1 and spacing or 0)
        else
            totalW = totalW + e.frame:GetWidth() + (i > 1 and spacing or 0)
            if entryH > totalH then totalH = entryH end
        end
    end

    local gearPad = 20
    self.mainFrame:SetSize(
        math.max(totalW + padding * 2 + gearPad, 80),
        math.max(totalH + padding * 2 + 4,        30)
    )

    self.contentFrame:ClearAllPoints()
    self.contentFrame:SetPoint("TOPLEFT",     self.mainFrame, "TOPLEFT",     padding, -(padding + 4))
    self.contentFrame:SetPoint("BOTTOMRIGHT", self.mainFrame, "BOTTOMRIGHT", -(padding + gearPad), padding)
end

-- ============================================================
-- Refresh
-- ============================================================

function CI:RefreshDisplay()
    if not self.mainFrame then return end

    self:ClearEntries()
    self:UpdateBackdrop()

    if #self.db.currencies == 0 then
        self.mainFrame:SetSize(220, 36)
        self.hintText:SetFont(self.db.layout.fontFace, self.db.layout.fontSize, "")
        self.hintText:Show()
        return
    end

    self.hintText:Hide()

    for _, currSettings in ipairs(self.db.currencies) do
        DeepMerge(currSettings, ns.CURRENCY_DEFAULTS)
        local data = GetCurrencyData(currSettings.id)
        if data then
            local entry = self:BuildEntryFrame()
            self:PopulateEntry(entry, currSettings, data)
            table.insert(self.entries, entry)
        end
    end

    self:LayoutEntries()
end

-- ============================================================
-- Init & Events
-- ============================================================

function CI:Load()
    if not CurrencyInfoDB then CurrencyInfoDB = {} end
    DeepMerge(CurrencyInfoDB, DB_DEFAULTS)
    self.db = CurrencyInfoDB

    self:CreateMainFrame()

    local pos = self.db.position
    self.mainFrame:ClearAllPoints()
    self.mainFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

    self:RefreshDisplay()

    SLASH_CURRENCYINFO1 = "/ci"
    SLASH_CURRENCYINFO2 = "/currencyinfo"
    SlashCmdList["CURRENCYINFO"] = function(msg) CI:HandleSlash(msg) end

    print("|cFF00FFFFCurrencyInfo|r v" .. VERSION .. " loaded. Right-click display or |cFFFFFF00/ci|r to open settings.")
end

function CI:HandleSlash(msg)
    local cmd = strtrim(msg:lower())
    if cmd == "" or cmd == "config" then
        CI:ToggleConfig()
    elseif cmd == "lock" then
        self.db.locked = not self.db.locked
        print("|cFF00FFFFCurrencyInfo|r: Frame " .. (self.db.locked and "|cFFFF4444locked|r" or "|cFF44FF44unlocked|r"))
    elseif cmd == "reset" then
        self.mainFrame:ClearAllPoints()
        self.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        self.db.position = { point = "CENTER", x = 0, y = 0 }
        print("|cFF00FFFFCurrencyInfo|r: Position reset.")
    else
        print("|cFF00FFFFCurrencyInfo|r commands:")
        print("  |cFFFFFF00/ci|r          — open settings")
        print("  |cFFFFFF00/ci lock|r     — toggle frame lock")
        print("  |cFFFFFF00/ci reset|r    — reset frame position")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        CI:Load()
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        CI:RefreshDisplay()
    end
end)
