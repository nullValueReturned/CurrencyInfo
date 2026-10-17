-- CurrencyInfo.lua
-- Core display logic

local ADDON_NAME, ns = ...
local VERSION = "1.1.0"

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
    { id = "custom",       label = "Custom",            template = nil, accent = true },
}

ns.CAP_ACTIONS = {
    { id = "none",  label = "Do nothing" },
    { id = "color", label = "Change color" },
    { id = "hide",  label = "Hide currency" },
}

-- Template tokens: used for validation and for the help tooltips.
ns.TOKEN_HELP = {
    { "{label}",     "currency name" },
    { "{current}",   "current quantity" },
    { "{max}",       "maximum quantity" },
    { "{earned}",    "total earned" },
    { "{left}",      "left to earn (max - earned)" },
    { "{weekly}",    "earned this week" },
    { "{weeklycap}", "weekly cap" },
    { "{pct}",       "percentage current / max" },
}
ns.TOKENS = {}
for _, t in ipairs(ns.TOKEN_HELP) do ns.TOKENS[t[1]:sub(2, -2)] = true end

ns.FONT_OPTIONS = {
    { id = "Fonts\\FRIZQT__.TTF", label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { id = "Fonts\\MORPHEUS.TTF", label = "Morpheus",       path = "Fonts\\MORPHEUS.TTF" },
    { id = "Fonts\\ARIALN.TTF",   label = "Arial Narrow",   path = "Fonts\\ARIALN.TTF" },
    { id = "Fonts\\skurri.TTF",   label = "Skurri",         path = "Fonts\\skurri.TTF" },
}

ns.DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

-- Sets a font on a FontString, falling back to the default font if the given
-- path is invalid (e.g. it belonged to an addon like LibSharedMedia/ElvUI that
-- has since been removed).
function ns.SafeSetFont(fontString, path, size, flags)
    if not (path and fontString:SetFont(path, size, flags)) then
        fontString:SetFont(ns.DEFAULT_FONT, size, flags)
    end
end

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
        direction      = "column",
        align          = "left",
        spacing        = 6,
        iconSize       = 16,
        fontSize       = 12,
        fontFace       = "Fonts\\FRIZQT__.TTF",
        padding        = 8,
        showBackground = true,
        bgAlpha        = 0.75,
        scale          = 1,
    },
    visibility = {
        hideInCombat      = false,
        hideOnCurrencyTab = false,
        fadeIdle          = false,
    },
    position  = { point = "CENTER", x = 0, y = 0 },
    locked    = false,
    hidden    = false,
    showGains = true,
}
ns.DB_DEFAULTS = DB_DEFAULTS

ns.CURRENCY_DEFAULTS = {
    id             = 0,
    showIcon       = true,
    formatPreset   = "current_max",
    customTemplate = "{label}: {current} / {max}",
    capAction      = "none",
    capColor       = { 0.30, 1.00, 0.50 },
    capThreshold   = 100,
    -- textColor is optional: nil means the default (white)
}

local FADE_ALPHA = 0.25
local FLASH_TIME = 2.5

-- ============================================================
-- Utility
-- ============================================================

local function Say(msg)
    print("|cFF00FFFFCurrencyInfo|r: " .. msg)
end

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
    if not data.label or data.label == "" then
        r = r:gsub("{label}:%s*", "")
    end
    r = r:gsub("{label}",     function() return data.label or "" end)
    r = r:gsub("{current}",   function() return FNum(data.current) end)
    r = r:gsub("{max}",       function() return FNum(data.max) end)
    r = r:gsub("{earned}",    function() return FNum(data.earned) end)
    r = r:gsub("{left}",      function() return FNum(data.left) end)
    r = r:gsub("{weekly}",    function() return FNum(data.weekly) end)
    r = r:gsub("{weeklycap}", function() return FNum(data.weeklycap) end)
    r = r:gsub("{pct}",       function() return (data.pct and tostring(data.pct) or "0") .. "%" end)
    return r
end
ns.ApplyTemplate = ApplyTemplate

local function GetCurrencyData(currencyId)
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyId)
    if not info or not info.name or info.name == "" then return nil end
    local max     = info.maxQuantity or 0
    local earned  = info.totalEarned or 0
    local current = info.quantity or 0
    return {
        name       = info.name,
        current    = current,
        max        = max,
        earned     = earned,
        left       = max > 0 and math.max(0, max - earned) or 0,
        weekly     = info.quantityEarnedThisWeek or 0,
        weeklycap  = info.maxWeeklyQuantity or 0,
        useEarned  = info.useTotalEarnedForMaxQty and true or false,
        iconFileID = info.iconFileID,
        pct        = max > 0 and math.floor((current / max) * 100) or 0,
    }
end
ns.GetCurrencyData = GetCurrencyData

function ns.GetPresetTemplate(id)
    for _, p in ipairs(ns.FORMAT_PRESETS) do
        if p.id == id then return p.template end
    end
end

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

-- The text shown for one currency (used by the display and the settings preview).
function ns.FormatCurrency(currSettings, data)
    return ApplyTemplate(GetTemplate(currSettings), setmetatable({ label = data.name }, { __index = data }))
end

-- How close the currency is to its cap, 0-100+: the highest of current/max
-- (or total earned/max for seasonal caps) and weekly earned/weekly cap.
local function CapProgress(data)
    local p = 0
    if data.max > 0 then
        p = (data.useEarned and data.earned or data.current) / data.max * 100
    end
    if data.weeklycap > 0 then
        p = math.max(p, data.weekly / data.weeklycap * 100)
    end
    return p
end

function ns.IsCapped(currSettings, data)
    if data.max <= 0 and data.weeklycap <= 0 then return false end
    return CapProgress(data) >= (currSettings.capThreshold or 100)
end

-- Every currency the character knows about: { id, name, icon, maxQuantity, isHeader, depth }.
-- Collapsed headers in the Currency tab are expanded for the scan, then collapsed again.
function ns.GetCurrencyList()
    local collapsed = {}
    repeat
        local expanded = false
        for i = C_CurrencyInfo.GetCurrencyListSize(), 1, -1 do
            local info = C_CurrencyInfo.GetCurrencyListInfo(i)
            if info and info.isHeader and not info.isHeaderExpanded then
                collapsed[info.name] = true
                C_CurrencyInfo.ExpandCurrencyList(i, true)
                expanded = true
            end
        end
    until not expanded

    local list = {}
    local size = C_CurrencyInfo.GetCurrencyListSize()
    for i = 1, size do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info then
            if info.isHeader then
                list[#list + 1] = { isHeader = true, name = info.name, depth = info.currencyListDepth or 0 }
            else
                local link = C_CurrencyInfo.GetCurrencyListLink(i)
                local id = link and tonumber(link:match("currency:(%d+)"))
                if id then
                    list[#list + 1] = {
                        id          = id,
                        name        = info.name,
                        icon        = info.iconFileID,
                        maxQuantity = info.maxQuantity or 0,
                        depth       = info.currencyListDepth or 0,
                    }
                end
            end
        end
    end

    for i = size, 1, -1 do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.isHeader and collapsed[info.name] then
            C_CurrencyInfo.ExpandCurrencyList(i, false)
        end
    end
    return list
end

-- ============================================================
-- Addon Object
-- ============================================================

CurrencyInfoAddon = CurrencyInfoAddon or {}
local CI = CurrencyInfoAddon
ns.CI = CI

CI.entries  = {}   -- entries currently on screen
CI.pool     = {}   -- hidden entries waiting for reuse
CI.flashes  = {}   -- currency id -> { delta, t0 } for the +/- gain text
CI.inCombat = false

-- ---- Tracked currency list ----

function CI:FindTracked(id)
    for i, c in ipairs(self.db.currencies) do
        if c.id == id then return i end
    end
end

-- Returns ok, message.
function CI:AddCurrency(id, quiet)
    if self:FindTracked(id) then return false, "Already tracked!" end
    local data = GetCurrencyData(id)
    if not data then return false, "Invalid currency ID" end
    local c = {}
    DeepMerge(c, ns.CURRENCY_DEFAULTS)
    c.id = id
    table.insert(self.db.currencies, c)
    if not quiet then self:OnTrackedChanged() end
    return true, data.name
end

function CI:RemoveCurrency(id)
    local i = self:FindTracked(id)
    if not i then return false end
    table.remove(self.db.currencies, i)
    self:OnTrackedChanged()
    return true
end

-- Adds every currency that has a cap. Returns how many were added.
function CI:AddAllCapped()
    local added = 0
    for _, e in ipairs(ns.GetCurrencyList()) do
        if not e.isHeader and e.maxQuantity > 0 and self:AddCurrency(e.id, true) then
            added = added + 1
        end
    end
    if added > 0 then self:OnTrackedChanged() end
    return added
end

-- Older versions had a per-currency custom label and a "no label" switch. Fold them into a
-- custom template so nothing is lost.
function CI:MigrateLegacyLabels()
    for _, c in ipairs(self.db.currencies) do
        if (c.customLabel and c.customLabel ~= "") or c.noLabel then
            local template = GetTemplate(c)
            if c.noLabel then
                template = template:gsub("{label}:%s*", ""):gsub("{label}", "")
            else
                template = template:gsub("{label}", function() return c.customLabel end)
            end
            c.formatPreset   = "custom"
            c.customTemplate = template
            c.customEdited   = true
        end
        c.customLabel, c.noLabel = nil, nil
    end
end

function CI:OnTrackedChanged()
    self:RefreshDisplay()
    if self.RefreshConfigCurrencyList then self:RefreshConfigCurrencyList() end
    if self.RefreshPicker then self:RefreshPicker() end
end

-- Accepts an ID, a currency link, or (part of) a currency name.
function CI:ResolveCurrency(text)
    local id = tonumber(text) or tonumber(text:match("currency:(%d+)"))
    if id then return id end
    local lower = text:lower()
    local partial
    for _, e in ipairs(ns.GetCurrencyList()) do
        if not e.isHeader then
            local n = e.name:lower()
            if n == lower then return e.id end
            if not partial and n:find(lower, 1, true) then partial = e.id end
        end
    end
    return partial
end

-- ============================================================
-- Main Display Frame
-- ============================================================

function CI:BeginMove()
    if not self.db.locked then self.mainFrame:StartMoving() end
end

function CI:EndMove()
    local f = self.mainFrame
    f:StopMovingOrSizing()
    local point, _, _, x, y = f:GetPoint()
    self.db.position.point = point
    self.db.position.x     = math.floor(x)
    self.db.position.y     = math.floor(y)
end

function CI:CreateMainFrame()
    local f = CreateFrame("Frame", "CurrencyInfoMainFrame", UIParent, "BackdropTemplate")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() CI:BeginMove() end)
    f:SetScript("OnDragStop",  function() CI:EndMove() end)
    f:SetScript("OnMouseUp", function(_, btn)
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

    -- Hint text shown when there is nothing to display
    local hint = f:CreateFontString(nil, "OVERLAY")
    hint:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    hint:SetPoint("CENTER", f, "CENTER", 0, 0)
    hint:Hide()
    self.hintText = hint

    -- Content frame (entries are anchored inside here)
    local content = CreateFrame("Frame", nil, f)
    self.contentFrame = content
end

function CI:UpdateBackdrop()
    local layout, f, UI = self.db.layout, self.mainFrame, ns.UI

    -- Same flat look as the settings window: solid fill, hairline border, accent bar on the left.
    if not f.bg then
        UI.Surface(f, UI.Colors.window, { 1, 1, 1, 0.12 })
        f.bg = f.arBg
        f.edge = f.arBorder
        local bar = f:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(2)
        UI.OnAccent(function(r, g, b) bar:SetColorTexture(r, g, b, 1) end)
        f.accentBar = bar
    end

    local show = layout.showBackground
    f.bg:SetShown(show)
    f.accentBar:SetShown(show)
    for _, t in ipairs(f.edge) do t:SetShown(show) end
    if show then
        local c = UI.Colors.window
        f.bg:SetColorTexture(c[1], c[2], c[3], layout.bgAlpha)
        f.edge:SetColor(1, 1, 1, 0.12 * math.min(1, layout.bgAlpha + 0.25))
        f.accentBar:SetAlpha(math.max(0.35, layout.bgAlpha))
    end
end

-- ============================================================
-- Visibility (hidden / combat / Currency tab / idle fade)
-- ============================================================

function CI:ShouldShow()
    local db, v = self.db, self.db.visibility
    if db.hidden then return false end
    if v.hideInCombat and self.inCombat then return false end
    if v.hideOnCurrencyTab then
        local tab = TokenFrame or CurrencyFrame
        if tab and tab:IsVisible() then return false end
    end
    return true
end

function CI:UpdateVisibility()
    if self.mainFrame then self.mainFrame:SetShown(self:ShouldShow()) end
end

local function FadeOnUpdate(self, dt)
    local cfg = CI.configFrame
    local target = (self:IsMouseOver() or (cfg and cfg:IsShown())) and 1 or FADE_ALPHA
    local a = self:GetAlpha()
    if math.abs(a - target) < 0.01 then
        if a ~= target then self:SetAlpha(target) end
        return
    end
    self:SetAlpha(a + (target - a) * math.min(1, dt * 10))
end

-- Call after any visibility option changes.
function CI:ApplyVisibilityRules()
    local v = self.db.visibility

    -- The Currency tab has no reliable show/hide hook across versions, so poll while it matters.
    if v.hideOnCurrencyTab then
        if not self.tabTicker then
            self.tabTicker = C_Timer.NewTicker(0.5, function() CI:UpdateVisibility() end)
        end
    elseif self.tabTicker then
        self.tabTicker:Cancel()
        self.tabTicker = nil
    end

    if v.fadeIdle then
        self.mainFrame:SetScript("OnUpdate", FadeOnUpdate)
    else
        self.mainFrame:SetScript("OnUpdate", nil)
        self.mainFrame:SetAlpha(1)
    end

    self:UpdateVisibility()
end

-- ============================================================
-- Entry Frames (pooled)
-- ============================================================

function CI:ClearEntries()
    for _, e in ipairs(self.entries) do
        e.frame:Hide()
        e.frame:ClearAllPoints()
        e.frame:SetScript("OnUpdate", nil)
        e.gain:Hide()
        self.pool[#self.pool + 1] = e
    end
    wipe(self.entries)
end

function CI:AcquireEntry()
    local e = table.remove(self.pool) or self:BuildEntryFrame()
    e.frame:Show()
    return e
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
    ns.SafeSetFont(text, layout.fontFace, layout.fontSize, "OUTLINE")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)

    -- "+150" / "-20" flash after the value changes
    local gain = f:CreateFontString(nil, "OVERLAY")
    ns.SafeSetFont(gain, layout.fontFace, layout.fontSize, "OUTLINE")
    gain:SetPoint("LEFT", text, "RIGHT", 4, 0)
    gain:Hide()

    -- Entries swallow mouse input for the tooltip, so forward moving and the settings click.
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() CI:BeginMove() end)
    f:SetScript("OnDragStop",  function() CI:EndMove() end)
    f:SetScript("OnMouseUp", function(_, btn)
        if btn == "RightButton" then CI:ToggleConfig() end
    end)
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
        if d.capped then
            GameTooltip:AddLine("Cap reached", d.capColor[1], d.capColor[2], d.capColor[3])
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Right-click: settings   Drag: move", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return { frame = f, icon = icon, text = text, gain = gain }
end

function CI:StartFlash(id, delta)
    local fl = self.flashes[id]
    local now = GetTime()
    if fl and now - fl.t0 < FLASH_TIME then
        fl.delta = fl.delta + delta
        fl.t0 = now
    else
        self.flashes[id] = { delta = delta, t0 = now }
    end
end

function CI:ApplyFlash(entry, id)
    local fl = self.flashes[id]
    local gain = entry.gain
    if not (fl and self.db.showGains and fl.delta ~= 0 and GetTime() - fl.t0 < FLASH_TIME) then
        gain:Hide()
        return
    end
    gain:SetText((fl.delta > 0 and "|cFF55FF55+" or "|cFFFF5555-") .. FNum(math.abs(fl.delta)) .. "|r")
    gain:SetAlpha(1)
    gain:Show()
    entry.frame:SetScript("OnUpdate", function(f)
        local age = GetTime() - fl.t0
        if age >= FLASH_TIME then
            gain:Hide()
            f:SetScript("OnUpdate", nil)
        elseif age > FLASH_TIME * 0.5 then
            gain:SetAlpha((FLASH_TIME - age) / (FLASH_TIME * 0.5))
        end
    end)
end

function CI:PopulateEntry(entry, currSettings, data, capped)
    local layout = self.db.layout
    local alignRight = layout.direction == "column" and layout.align == "right"

    entry.text:ClearAllPoints()
    entry.icon:SetSize(layout.iconSize, layout.iconSize)
    local hasIcon = currSettings.showIcon and data.iconFileID
    if hasIcon then
        entry.icon:SetTexture(data.iconFileID)
        entry.icon:Show()
    else
        entry.icon:Hide()
    end

    if alignRight then
        entry.text:SetPoint("RIGHT", entry.frame, "RIGHT", 0, 0)
        entry.text:SetJustifyH("RIGHT")
    else
        if hasIcon then
            entry.text:SetPoint("LEFT", entry.icon, "RIGHT", 4, 0)
        else
            entry.text:SetPoint("LEFT", entry.frame, "LEFT", 0, 0)
        end
        entry.text:SetJustifyH("LEFT")
    end

    ns.SafeSetFont(entry.text, layout.fontFace, layout.fontSize, "OUTLINE")
    ns.SafeSetFont(entry.gain, layout.fontFace, layout.fontSize, "OUTLINE")
    entry.text:SetText(ns.FormatCurrency(currSettings, data))

    local r, g, b = 1, 1, 1
    if currSettings.textColor then r, g, b = unpack(currSettings.textColor) end
    if capped and currSettings.capAction == "color" then r, g, b = unpack(currSettings.capColor) end
    entry.text:SetTextColor(r, g, b, 1)

    entry.frame:SetHeight(math.max(layout.iconSize, layout.fontSize + 2))

    entry.frame.ttData = {
        name      = data.name,
        current   = data.current,
        max       = data.max,
        earned    = data.earned,
        left      = data.left,
        weekly    = data.weekly,
        weeklycap = data.weeklycap,
        pct       = data.pct,
        capped    = capped,
        capColor  = currSettings.capColor,
    }

    self:ApplyFlash(entry, currSettings.id)
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

    local widths, maxW = {}, 0
    for i, e in ipairs(self.entries) do
        local iconW = e.icon:IsShown() and (layout.iconSize + 4) or 0
        widths[i] = math.max(iconW + e.text:GetStringWidth() + 2, 30)
        if widths[i] > maxW then maxW = widths[i] end
    end

    local totalW, totalH = 0, 0
    local xOff = 0
    for i, e in ipairs(self.entries) do
        e.frame:ClearAllPoints()
        if isCol then
            e.frame:SetPoint("TOPLEFT", self.contentFrame, "TOPLEFT",
                0, -((entryH + spacing) * (i - 1)))
            -- Equal widths in a column so right-aligned values line up.
            e.frame:SetWidth(layout.align == "right" and maxW or widths[i])
            totalH = totalH + entryH + (i > 1 and spacing or 0)
        else
            e.frame:SetPoint("TOPLEFT", self.contentFrame, "TOPLEFT", xOff, 0)
            e.frame:SetWidth(widths[i])
            xOff = xOff + widths[i] + spacing
            totalW = totalW + widths[i] + (i > 1 and spacing or 0)
            totalH = entryH
        end
        e.frame:Show()
    end
    if isCol then totalW = maxW end

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

function CI:ShowHint(text)
    self.mainFrame:SetSize(220, 36)
    ns.SafeSetFont(self.hintText, self.db.layout.fontFace, self.db.layout.fontSize, "")
    self.hintText:SetText("|cFF888888" .. text .. "|r")
    self.hintText:Show()
end

function CI:RefreshDisplay()
    if not self.mainFrame then return end

    self.mainFrame:SetScale(self.db.layout.scale)
    self:ClearEntries()
    self:UpdateBackdrop()
    self:UpdateVisibility()

    if #self.db.currencies == 0 then
        self:ShowHint("Right-click to add currencies")
        return
    end

    for _, currSettings in ipairs(self.db.currencies) do
        DeepMerge(currSettings, ns.CURRENCY_DEFAULTS)
        local data = GetCurrencyData(currSettings.id)
        if data then
            local capped = ns.IsCapped(currSettings, data)
            if not (capped and currSettings.capAction == "hide") then
                local entry = self:AcquireEntry()
                self:PopulateEntry(entry, currSettings, data, capped)
                table.insert(self.entries, entry)
            end
        end
    end

    if #self.entries == 0 then
        self:ShowHint("All currencies hidden")
        return
    end

    self.hintText:Hide()
    self:LayoutEntries()
end

-- CURRENCY_DISPLAY_UPDATE can fire many times in one frame; rebuild once.
function CI:QueueRefresh()
    if self.refreshQueued then return end
    self.refreshQueued = true
    C_Timer.After(0, function()
        self.refreshQueued = false
        self:RefreshDisplay()
    end)
end

-- ============================================================
-- Init & Events
-- ============================================================

function CI:Load()
    if not CurrencyInfoDB then CurrencyInfoDB = {} end
    DeepMerge(CurrencyInfoDB, DB_DEFAULTS)
    self.db = CurrencyInfoDB

    if self.db.accent then ns.UI.SetAccent(unpack(self.db.accent)) end

    -- Saved font may point at a path from an addon (e.g. LibSharedMedia/ElvUI)
    -- that is no longer installed. Correct it permanently so the settings UI
    -- doesn't keep pointing at a missing font.
    local probe = UIParent:CreateFontString(nil, "OVERLAY")
    if not (self.db.layout.fontFace and probe:SetFont(self.db.layout.fontFace, 12, "")) then
        self.db.layout.fontFace = ns.DEFAULT_FONT
    end

    self:MigrateLegacyLabels()
    self.inCombat = InCombatLockdown() and true or false
    self:CreateMainFrame()

    local pos = self.db.position
    self.mainFrame:ClearAllPoints()
    self.mainFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

    self:RefreshDisplay()
    self:ApplyVisibilityRules()
    if self.RegisterSettingsPanel then self:RegisterSettingsPanel() end

    SLASH_CURRENCYINFO1 = "/ci"
    SLASH_CURRENCYINFO2 = "/currencyinfo"
    SlashCmdList["CURRENCYINFO"] = function(msg) CI:HandleSlash(msg) end

    print("|cFF00FFFFCurrencyInfo|r v" .. VERSION .. " loaded. Right-click display or |cFFFFFF00/ci|r to open settings.")
end

function CI:HandleSlash(msg)
    local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()

    if cmd == "" or cmd == "config" then
        self:ToggleConfig()
    elseif cmd == "browse" then
        self:OpenPicker()
    elseif cmd == "lock" then
        self.db.locked = not self.db.locked
        Say("Frame " .. (self.db.locked and "|cFFFF4444locked|r" or "|cFF44FF44unlocked|r"))
    elseif cmd == "show" or cmd == "hide" or cmd == "toggle" then
        if cmd == "toggle" then self.db.hidden = not self.db.hidden else self.db.hidden = (cmd == "hide") end
        self:UpdateVisibility()
        Say("Display " .. (self.db.hidden and "|cFFFF4444hidden|r" or "|cFF44FF44shown|r"))
    elseif cmd == "add" then
        local id = arg ~= "" and self:ResolveCurrency(arg)
        if not id then Say("No currency found for '" .. arg .. "'. Try |cFFFFFF00/ci browse|r.") return end
        local ok, result = self:AddCurrency(id)
        Say(ok and ("Added " .. result) or result)
    elseif cmd == "remove" then
        local id = arg ~= "" and self:ResolveCurrency(arg)
        if not (id and self:RemoveCurrency(id)) then Say("'" .. arg .. "' isn't tracked.") return end
        Say("Removed currency " .. id)
    elseif cmd == "list" then
        if #self.db.currencies == 0 then Say("No currencies tracked.") return end
        for _, c in ipairs(self.db.currencies) do
            local data = GetCurrencyData(c.id)
            print(string.format("  |cFFFFFF00%d|r  %s", c.id, data and data.name or "|cFFFF6666unknown|r"))
        end
    elseif cmd == "reset" then
        self.mainFrame:ClearAllPoints()
        self.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        self.db.position = { point = "CENTER", x = 0, y = 0 }
        Say("Position reset.")
    else
        print("|cFF00FFFFCurrencyInfo|r commands:")
        print("  |cFFFFFF00/ci|r                  — open settings")
        print("  |cFFFFFF00/ci browse|r           — pick currencies from a list")
        print("  |cFFFFFF00/ci add <id|name>|r    — track a currency")
        print("  |cFFFFFF00/ci remove <id|name>|r — stop tracking a currency")
        print("  |cFFFFFF00/ci list|r             — list tracked currencies")
        print("  |cFFFFFF00/ci show|hide|toggle|r — show or hide the display")
        print("  |cFFFFFF00/ci lock|r             — toggle frame lock")
        print("  |cFFFFFF00/ci reset|r            — reset frame position")
    end

    if self.RefreshDisplaySettingsUI then self:RefreshDisplaySettingsUI() end
end

-- Addon Compartment (the button next to the minimap) - see the .toc
function CurrencyInfo_OnAddonCompartmentClick(_, mouseButton)
    if mouseButton == "RightButton" then
        CI.db.hidden = not CI.db.hidden
        CI:UpdateVisibility()
        if CI.RefreshDisplaySettingsUI then CI:RefreshDisplaySettingsUI() end
    else
        CI:ToggleConfig()
    end
end

function CurrencyInfo_OnAddonCompartmentEnter(_, frame)
    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
    GameTooltip:SetText("CurrencyInfo")
    GameTooltip:AddLine("Left-click: open settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click: show / hide display", 1, 1, 1)
    GameTooltip:Show()
end

function CurrencyInfo_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON_NAME then CI:Load() end
        return
    end
    if not CI.db then return end

    if event == "CURRENCY_DISPLAY_UPDATE" then
        local id, _, change, _, lostSource = ...
        if id and change and change ~= 0 and CI:FindTracked(id) then
            if lostSource and change > 0 then change = -change end
            CI:StartFlash(id, change)
        end
        CI:QueueRefresh()
    elseif event == "PLAYER_REGEN_DISABLED" then
        CI.inCombat = true
        CI:UpdateVisibility()
    elseif event == "PLAYER_REGEN_ENABLED" then
        CI.inCombat = false
        CI:UpdateVisibility()
    elseif event == "PLAYER_ENTERING_WORLD" then
        CI:QueueRefresh()
    end
end)
