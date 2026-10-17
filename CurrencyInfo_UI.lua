-- CurrencyInfo_UI.lua
-- Flat dark theme + widgets for the settings window: solid surfaces, hairline borders, one
-- accent colour, eased hover / toggle states.

local ADDON_NAME, ns = ...

local UI = {}
ns.UI = UI

-- ---------------------------------------------------------------------------
-- Palette and accent
-- ---------------------------------------------------------------------------

local C = {
    window      = { 0.055, 0.059, 0.070, 0.985 },
    header      = { 0.039, 0.042, 0.051, 1 },
    btn         = { 0.108, 0.114, 0.134, 1 },
    btnHover    = { 0.150, 0.158, 0.184, 1 },
    input       = { 0.028, 0.030, 0.038, 0.9 },
    off         = { 0.215, 0.225, 0.265, 1 },
    popup       = { 0.070, 0.075, 0.090, 0.99 },
}
UI.Colors = C

UI.DEFAULT_ACCENT = { 0x81 / 255, 0x60 / 255, 1.00 } -- #8160FF
local accent = { r = UI.DEFAULT_ACCENT[1], g = UI.DEFAULT_ACCENT[2], b = UI.DEFAULT_ACCENT[3] }
UI.accent = accent
local listeners = {}

-- fn(r, g, b) runs now and again whenever the accent changes.
function UI.OnAccent(fn)
    listeners[#listeners + 1] = fn
    fn(accent.r, accent.g, accent.b)
end

function UI.SetAccent(r, g, b)
    accent.r, accent.g, accent.b = r, g, b
    for _, fn in ipairs(listeners) do fn(r, g, b) end
end

function UI.AccentText(fs)
    UI.OnAccent(function(r, g, b) fs:SetTextColor(r, g, b, 1) end)
end

-- ---------------------------------------------------------------------------
-- Animation: one shared OnUpdate drives every eased value
-- ---------------------------------------------------------------------------

local active = {}
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self, dt)
    for a in pairs(active) do
        local diff = a.target - a.value
        if math.abs(diff) < 0.004 then
            a.value = a.target
            active[a] = nil
        else
            a.value = a.value + diff * math.min(1, dt * a.speed)
        end
        a.apply(a.value)
    end
    if not next(active) then self:Hide() end
end)

local function NewAnim(apply, speed)
    local a = { value = 0, target = 0, apply = apply, speed = speed or 16 }
    function a:To(target, instant)
        self.target = target
        if instant then
            self.value = target
            active[self] = nil
            self.apply(target)
        else
            active[self] = true
            driver:Show()
        end
    end
    return a
end
UI.NewAnim = NewAnim

local function Lerp(a, b, t) return a + (b - a) * t end

function UI.FadeInOnShow(frame, speed)
    local anim = NewAnim(function(v) frame:SetAlpha(v) end, speed or 14)
    frame:HookScript("OnShow", function()
        anim:To(0, true)
        anim:To(1)
    end)
end

-- ---------------------------------------------------------------------------
-- Typography
-- ---------------------------------------------------------------------------

local locale = GetLocale()
local FONT_PATH = (locale == "koKR" or locale == "zhCN" or locale == "zhTW") and STANDARD_TEXT_FONT
    or "Fonts\\ARIALN.TTF"

local function MakeFont(name, size, alpha)
    local f = CreateFont(name)
    if f:SetFont(FONT_PATH, size, "") == false then f:SetFont(STANDARD_TEXT_FONT, size, "") end
    f:SetTextColor(1, 1, 1, alpha)
    return f
end

local F = {
    title = MakeFont("CurrencyInfoFontTitle", 18, 1),
    body  = MakeFont("CurrencyInfoFontBody",  14, 0.90),
    small = MakeFont("CurrencyInfoFontSmall", 12, 0.55),
}
UI.Fonts = F

-- kind: "title" | "body" | "small"
function UI.Text(parent, kind, text)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(F[kind or "body"])
    if text then fs:SetText(text) end
    return fs
end

-- ---------------------------------------------------------------------------
-- Surfaces
-- ---------------------------------------------------------------------------

local function Px(f)
    local scale = f:GetEffectiveScale()
    if not scale or scale <= 0 then return 1 end
    return PixelUtil.GetNearestPixelSize(1, scale, 1)
end

-- Four hairline edges; the returned object has :SetColor(r, g, b, a).
function UI.Border(f, r, g, b, a)
    local px = Px(f)
    local top = f:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(px)
    local bottom = f:CreateTexture(nil, "BORDER")
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(px)
    local left = f:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT", top, "BOTTOMLEFT"); left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT"); left:SetWidth(px)
    local right = f:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT"); right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT"); right:SetWidth(px)

    local border = { top, bottom, left, right }
    function border:SetColor(cr, cg, cb, ca)
        for _, t in ipairs(self) do t:SetColorTexture(cr, cg, cb, ca or 1) end
    end
    border:SetColor(r, g, b, a)
    return border
end

-- Solid background plus optional hairline border. Sets f.arBg and f.arBorder.
function UI.Surface(f, bg, line)
    local tex = f:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
    f.arBg = tex
    if line then f.arBorder = UI.Border(f, line[1], line[2], line[3], line[4]) end
    return f
end

function UI.Divider(parent, y, inset)
    local d = parent:CreateTexture(nil, "ARTWORK")
    d:SetHeight(Px(parent))
    d:SetColorTexture(1, 1, 1, 0.07)
    d:SetPoint("TOPLEFT",  parent, "TOPLEFT",  inset or 16, y)
    d:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(inset or 16), y)
    return d
end

-- Faint zebra band behind a row.
function UI.RowStripe(row, i)
    local t = row:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.028 or 0.012)
    return t
end

local MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function Round(frame, layer, size)
    local t = frame:CreateTexture(nil, layer)
    t:SetSize(size, size)
    t:SetColorTexture(1, 1, 1, 1)
    local m = frame:CreateMaskTexture()
    m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(t)
    t:AddMaskTexture(m)
    return t
end

-- ---------------------------------------------------------------------------
-- Widgets
-- ---------------------------------------------------------------------------

function UI.Button(parent, text, w, h)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w or 80, h or 24)
    UI.Surface(btn, C.btn, { 1, 1, 1, 0.10 })

    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(F.body)
    fs:SetPoint("LEFT", btn, "LEFT", 6, 0)
    fs:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    fs:SetJustifyH("CENTER")
    btn:SetFontString(fs)
    if text then btn:SetText(text) end

    local hover = NewAnim(function(v)
        btn.arBg:SetColorTexture(Lerp(C.btn[1], C.btnHover[1], v), Lerp(C.btn[2], C.btnHover[2], v),
            Lerp(C.btn[3], C.btnHover[3], v), 1)
        btn.arBorder:SetColor(Lerp(1, accent.r, v), Lerp(1, accent.g, v), Lerp(1, accent.b, v), Lerp(0.10, 0.75, v))
        if not btn.arSelected then fs:SetTextColor(1, 1, 1, Lerp(0.78, 1, v)) end
    end, 18)
    hover:To(0, true)
    UI.OnAccent(function() hover.apply(hover.value) end)
    btn:HookScript("OnEnter", function() hover:To(1) end)
    btn:HookScript("OnLeave", function() hover:To(0) end)

    -- Highlight the button as the active choice of a segmented pair.
    function btn:SetSelected(on)
        self.arSelected = on
        if on then
            local r, g, b = accent.r, accent.g, accent.b
            fs:SetTextColor(r, g, b, 1)
        end
        hover.apply(hover.value)
    end
    UI.OnAccent(function() if btn.arSelected then fs:SetTextColor(accent.r, accent.g, accent.b, 1) end end)
    return btn
end

function UI.CloseButton(parent, size)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size or 28, size or 28)
    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT_PATH, 24, "")
    fs:SetPoint("CENTER", btn, "CENTER", 0, 1)
    fs:SetText("\195\151")
    local hover = NewAnim(function(v)
        fs:SetTextColor(1, Lerp(1, 0.32, v), Lerp(1, 0.32, v), Lerp(0.5, 1, v))
    end, 18)
    hover:To(0, true)
    btn:SetScript("OnEnter", function() hover:To(1) end)
    btn:SetScript("OnLeave", function() hover:To(0) end)
    return btn
end

-- Pill toggle. onChange(checked) fires on user clicks only.
local TRACK_W, TRACK_H, KNOB = 30, 16, 12

function UI.Toggle(parent, checked, onChange)
    local btn = CreateFrame("CheckButton", nil, parent)
    btn:SetSize(36, 22)

    local capL = Round(btn, "ARTWORK", TRACK_H)
    capL:SetPoint("LEFT", btn, "LEFT", 2, 0)
    local capR = Round(btn, "ARTWORK", TRACK_H)
    capR:SetPoint("LEFT", capL, "LEFT", TRACK_W - TRACK_H, 0)
    local mid = btn:CreateTexture(nil, "ARTWORK")
    mid:SetColorTexture(1, 1, 1, 1)
    mid:SetPoint("TOPLEFT", capL, "TOP", 0, 0)
    mid:SetPoint("BOTTOMRIGHT", capR, "BOTTOM", 0, 0)
    local knob = Round(btn, "OVERLAY", KNOB)

    local on, hov
    local function Paint()
        local v, h = on.value, hov.value
        local boost = 0.05 * h
        local r = Lerp(C.off[1], accent.r, v) + boost
        local g = Lerp(C.off[2], accent.g, v) + boost
        local b = Lerp(C.off[3], accent.b, v) + boost
        capL:SetVertexColor(r, g, b, 1); capR:SetVertexColor(r, g, b, 1); mid:SetVertexColor(r, g, b, 1)
        knob:SetVertexColor(1, 1, 1, Lerp(0.6, 1, v))
        knob:ClearAllPoints()
        knob:SetPoint("CENTER", capL, "CENTER", v * (TRACK_W - TRACK_H), 0)
    end
    on  = NewAnim(Paint, 20)
    hov = NewAnim(Paint, 20)
    UI.OnAccent(Paint)

    local function Sync(instant) on:To(btn:GetChecked() and 1 or 0, instant) end
    btn:SetChecked(checked and true or false)
    Sync(true)
    btn:SetScript("OnClick", function(self)
        Sync(false)
        if onChange then onChange(self:GetChecked() and true or false) end
    end)
    -- Set the state from code (no onChange, no animation).
    function btn:SetState(v)
        self:SetChecked(v and true or false)
        Sync(true)
    end
    btn:HookScript("OnEnter", function() hov:To(1) end)
    btn:HookScript("OnLeave", function() hov:To(0) end)
    btn:HookScript("OnDisable", function() btn:SetAlpha(0.4) end)
    btn:HookScript("OnEnable",  function() btn:SetAlpha(1) end)
    return btn
end

-- Flat edit box. Returns the EditBox itself (border / background live on it).
function UI.Input(parent, w, h)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(w or 120, h or 24)
    eb:SetAutoFocus(false)
    UI.Surface(eb, C.input, { 1, 1, 1, 0.09 })
    eb:SetFontObject(F.body)
    eb:SetTextInsets(7, 7, 0, 0)
    eb:SetJustifyH("LEFT")
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local focus = NewAnim(function(v)
        eb.arBorder:SetColor(Lerp(1, accent.r, v), Lerp(1, accent.g, v), Lerp(1, accent.b, v), Lerp(0.09, 0.9, v))
    end, 18)
    focus:To(0, true)
    UI.OnAccent(function() focus.apply(focus.value) end)
    eb:HookScript("OnEditFocusGained", function() focus:To(1) end)
    eb:HookScript("OnEditFocusLost",   function() focus:To(0) end)

    -- Dim and lock the box, e.g. while another option makes it irrelevant.
    function eb:SetActive(on)
        self:SetEnabled(on)
        self:SetAlpha(on and 1 or 0.35)
    end
    return eb
end

-- Flat slider with a value readout to its right. onChange(value) fires on user changes only;
-- s:SetValueSilent(v) moves it without firing. fmt(v) formats the readout.
function UI.Slider(parent, w, minV, maxV, step, value, onChange, fmt)
    local s = CreateFrame("Slider", nil, parent)
    s:SetSize(w, 16)
    s:SetOrientation("HORIZONTAL")
    s:EnableMouse(true)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)

    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(4)
    track:SetColorTexture(1, 1, 1, 0.10)
    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("LEFT"); fill:SetHeight(4)
    UI.OnAccent(function(r, g, b) fill:SetColorTexture(r, g, b, 0.85) end)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(8, 14)
    thumb:SetColorTexture(1, 1, 1, 0.95)
    s:SetThumbTexture(thumb)
    local readout = UI.Text(s, "body")
    readout:SetPoint("LEFT", s, "RIGHT", 8, 0)

    local silent = false
    local function Paint(v)
        fill:SetWidth(math.max(0.001, (v - minV) / (maxV - minV) * w))
        readout:SetText(fmt and fmt(v) or tostring(v))
    end
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        v = math.floor(v * 10000 + 0.5) / 10000
        Paint(v)
        if not silent and onChange then onChange(v) end
    end)
    function s:SetValueSilent(v)
        silent = true
        self:SetValue(v)
        silent = false
        Paint(v)
    end
    s:SetValueSilent(value)
    return s
end

-- Scroll frame with a slim accent scrollbar in the gutter to its right.
function UI.ScrollFrame(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)

    local bar = CreateFrame("Slider", nil, sf)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(5)
    bar:SetPoint("TOPLEFT",    sf, "TOPRIGHT",    7, 0)
    bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 7, 0)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.05)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(5, 40)
    bar:SetThumbTexture(thumb)
    UI.OnAccent(function(r, g, b) thumb:SetColorTexture(r, g, b, 0.6) end)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar:Hide()

    local syncing = false
    bar:SetScript("OnValueChanged", function(_, v)
        if not syncing then sf:SetVerticalScroll(v) end
    end)

    sf:SetScript("OnScrollRangeChanged", function(_, _, yRange)
        bar:SetMinMaxValues(0, yRange)
        local view = sf:GetHeight()
        if view and view > 0 then thumb:SetHeight(math.max(24, view * view / (view + yRange))) end
        bar:SetShown(yRange > 1)
    end)
    sf:SetScript("OnVerticalScroll", function(self, offset)
        self:SetVerticalScroll(offset)
        syncing = true
        bar:SetValue(offset)
        syncing = false
    end)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 48)))
    end)
    return sf
end

-- options: array of { id, label }. onChange(option) fires on picks. maxHeight caps the popup;
-- up opens it above the button. The popup hangs off UIParent so scroll frames never clip it.
-- Returns the button; btn:SetCurrentId(id) changes the selection without firing onChange.
function UI.Dropdown(parent, width, options, currentId, onChange, maxHeight, up)
    local ITEM_H, PAD = 24, 4
    local totalH    = #options * ITEM_H
    local visibleH  = math.min(totalH, maxHeight or 220)
    local maxScroll = math.max(0, totalH - visibleH)
    local hasScroll = maxScroll > 0
    local selected  = currentId

    local btn = UI.Button(parent, nil, width, 24)
    local text = btn:GetFontString()
    text:ClearAllPoints()
    text:SetPoint("LEFT",  btn, "LEFT",   9, 0)
    text:SetPoint("RIGHT", btn, "RIGHT", -22, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetSize(12, 12)
    arrow:SetRotation(-math.pi / 2)
    arrow:SetPoint("RIGHT", btn, "RIGHT", -7, 0)
    arrow:SetVertexColor(1, 1, 1, 0.6)

    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetSize(width, visibleH + PAD * 2)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    UI.Surface(popup, C.popup, { 1, 1, 1, 0.14 })
    if up then
        popup:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 3)
    else
        popup:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -3)
    end
    popup:EnableMouse(true)
    popup:Hide()

    local scroll = CreateFrame("ScrollFrame", nil, popup)
    scroll:SetPoint("TOPLEFT",     popup, "TOPLEFT",     PAD, -PAD)
    scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", hasScroll and -(PAD + 7) or -PAD, PAD)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width - PAD * 2 - (hasScroll and 7 or 0), math.max(totalH, 1))
    scroll:SetScrollChild(content)

    local marks = {}
    local function Refresh()
        local shown
        for i, o in ipairs(options) do
            local cur = o.id == selected
            marks[i]:SetShown(cur)
            if cur then shown = o end
        end
        shown = shown or options[1]
        if shown then btn:SetText(shown.label) end
    end

    for i, o in ipairs(options) do
        local row = CreateFrame("Button", nil, content)
        row:SetHeight(ITEM_H)
        row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -(i - 1) * ITEM_H)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * ITEM_H)

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.07)

        local sel = row:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints()
        UI.OnAccent(function(r, g, b) sel:SetColorTexture(r, g, b, 0.14) end)
        local bar = row:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(2)
        UI.OnAccent(function(r, g, b) bar:SetColorTexture(r, g, b, 1) end)
        marks[i] = { SetShown = function(_, s) sel:SetShown(s); bar:SetShown(s) end }

        local lbl = row:CreateFontString(nil, "OVERLAY")
        lbl:SetFontObject(F.body)
        lbl:SetPoint("LEFT",  row, "LEFT",  9, 0)
        lbl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        lbl:SetText(o.label)

        row:SetScript("OnClick", function()
            selected = o.id
            popup:Hide()
            Refresh()
            onChange(o)
        end)
    end

    local bar
    if hasScroll then
        bar = CreateFrame("Slider", nil, popup)
        bar:SetOrientation("VERTICAL")
        bar:SetWidth(5)
        bar:SetPoint("TOPRIGHT",    popup, "TOPRIGHT",    -4, -PAD)
        bar:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -4,  PAD)
        local thumb = bar:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(5, math.max(24, visibleH * visibleH / totalH))
        UI.OnAccent(function(r, g, b) thumb:SetColorTexture(r, g, b, 0.6) end)
        bar:SetThumbTexture(thumb)
        bar:SetMinMaxValues(0, maxScroll)
        bar:SetValue(0)
        bar:SetValueStep(ITEM_H)
        bar:SetObeyStepOnDrag(true)
        bar:SetScript("OnValueChanged", function(_, v) scroll:SetVerticalScroll(v) end)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(_, delta)
            bar:SetValue(math.max(0, math.min(maxScroll, bar:GetValue() - delta * ITEM_H * 3)))
        end)
    end

    btn:SetScript("OnClick", function()
        if popup:IsShown() then popup:Hide() return end
        popup:Show()
        if bar then
            for i, o in ipairs(options) do
                if o.id == selected then bar:SetValue(math.min((i - 1) * ITEM_H, maxScroll)) break end
            end
        end
    end)
    parent:HookScript("OnHide", function() popup:Hide() end)

    function btn:SetCurrentId(id) selected = id; Refresh() end
    function btn:GetCurrentId() return selected end
    Refresh()
    return btn
end

-- get() -> r, g, b    set(r, g, b)    Opens the colour picker on click.
function UI.ColorSwatch(parent, get, set, size)
    size = size or 22
    local swatch = CreateFrame("Button", nil, parent)
    swatch:SetSize(size, size)
    UI.Surface(swatch, { 0, 0, 0, 1 }, { 1, 1, 1, 0.35 })
    local tex = swatch:CreateTexture(nil, "ARTWORK")
    local px = Px(swatch) * 2
    tex:SetPoint("TOPLEFT",     swatch, "TOPLEFT",     px, -px)
    tex:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -px, px)
    local function Paint() tex:SetColorTexture(get()) end
    Paint()
    swatch.Refresh = Paint

    local hover = NewAnim(function(v)
        swatch.arBorder:SetColor(Lerp(1, accent.r, v), Lerp(1, accent.g, v), Lerp(1, accent.b, v), Lerp(0.35, 1, v))
    end, 18)
    hover:To(0, true)
    UI.OnAccent(function() hover.apply(hover.value) end)
    swatch:SetScript("OnEnter", function() hover:To(1) end)
    swatch:SetScript("OnLeave", function() hover:To(0) end)
    swatch:SetScript("OnClick", function()
        local r, g, b = get()
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function() set(ColorPickerFrame:GetColorRGB()); Paint() end,
            cancelFunc = function(prev) set(prev.r, prev.g, prev.b); Paint() end,
        })
    end)
    return swatch
end
