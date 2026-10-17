-- CurrencyInfo_Picker.lua
-- Searchable list of the character's currencies; click one to track / untrack it.

local ADDON_NAME, ns = ...

local CI = CurrencyInfoAddon
local UI = ns.UI

local W, H     = 400, 560
local ITEM_H   = 26

local function BuildPicker()
    local cfg = CI.configFrame
    local p = CreateFrame("Frame", nil, cfg)
    p:SetSize(W, H)
    p:SetPoint("CENTER", cfg, "CENTER", 0, 0)
    p:SetFrameLevel(cfg:GetFrameLevel() + 40)
    p:EnableMouse(true)
    UI.Surface(p, UI.Colors.popup, { 1, 1, 1, 0.18 })
    UI.FadeInOnShow(p)
    p:Hide()
    cfg:HookScript("OnHide", function() p:Hide() end)

    local title = UI.Text(p, "title", "Browse currencies")
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -14)
    UI.AccentText(title)
    local closeBtn = UI.CloseButton(p, 26)
    closeBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -10)
    closeBtn:SetScript("OnClick", function() p:Hide() end)

    -- Search
    local search = UI.Input(p, W - 32, 26)
    search:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -48)
    local placeholder = UI.Text(search, "small", "Search currencies...")
    placeholder:SetPoint("LEFT", search, "LEFT", 8, 0)
    placeholder:SetAlpha(0.7)

    -- List
    local sf = UI.ScrollFrame(p)
    sf:SetPoint("TOPLEFT",     p, "TOPLEFT",     16, -84)
    sf:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -30, 84)
    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(W - 46)
    content:SetHeight(1)
    sf:SetScrollChild(content)

    local emptyText = UI.Text(content, "small", "No matching currencies.")
    emptyText:SetPoint("TOP", content, "TOP", 0, -16)
    emptyText:Hide()

    -- Footer
    local note = UI.Text(p, "small", "Only currencies this character has discovered are listed. Use the ID box for others.")
    note:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 52)
    note:SetWidth(W - 32)
    note:SetJustifyH("LEFT")

    local addCapped = UI.Button(p, "Add all capped", 130, 26)
    addCapped:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 16)
    addCapped:SetScript("OnClick", function()
        local n = CI:AddAllCapped()
        if CI.SetFeedback then
            CI:SetFeedback(n > 0 and ("Added " .. n .. " capped currencies") or "No new capped currencies", 0.5, 1, 0.5)
        end
    end)
    addCapped:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Track every currency that has a maximum", 1, 1, 1)
        GameTooltip:Show()
    end)
    addCapped:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local done = UI.Button(p, "Done", 80, 26)
    done:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 16)
    done:SetScript("OnClick", function() p:Hide() end)

    -- Rows (pooled)
    local rows = {}

    local function Toggle(entry)
        if CI:FindTracked(entry.id) then
            CI:RemoveCurrency(entry.id)
        else
            CI:AddCurrency(entry.id)
        end
    end

    local function BuildRow(i)
        local b = CreateFrame("Button", nil, content)
        b:SetHeight(ITEM_H)
        b:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -(i - 1) * ITEM_H)
        b:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * ITEM_H)

        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.07)

        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(18, 18)
        b.icon:SetPoint("LEFT", b, "LEFT", 6, 0)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        b.name = UI.Text(b, "body")
        b.name:SetPoint("LEFT",  b.icon, "RIGHT", 8, 0)
        b.name:SetPoint("RIGHT", b, "RIGHT", -76, 0)
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)

        b.state = UI.Text(b, "small")
        b.state:SetPoint("RIGHT", b, "RIGHT", -8, 0)

        b.header = UI.Text(b, "small")
        b.header:SetPoint("LEFT", b, "LEFT", 6, -3)

        b:SetScript("OnClick", function(self) if self.entry then Toggle(self.entry) end end)
        return b
    end

    function p:Render()
        local filter = strtrim(search:GetText() or ""):lower()
        local shown = {}
        for _, e in ipairs(self.data or {}) do
            if filter == "" then
                shown[#shown + 1] = e
            elseif not e.isHeader and e.name:lower():find(filter, 1, true) then
                shown[#shown + 1] = e
            end
        end

        local acc = UI.accent
        for i, e in ipairs(shown) do
            local b = rows[i] or BuildRow(i)
            rows[i] = b
            b.entry = e
            b:Show()
            if e.isHeader then
                b:SetEnabled(false)
                b.icon:Hide(); b.name:Hide(); b.state:Hide()
                b.header:SetText(e.name:upper())
                b.header:Show()
            else
                b:SetEnabled(true)
                b.header:Hide()
                b.name:Show()
                b.name:SetText(e.name)
                b.icon:SetTexture(e.icon)
                b.icon:SetShown(e.icon ~= nil)
                local tracked = CI:FindTracked(e.id)
                b.state:SetText(tracked and "TRACKED" or (e.maxQuantity > 0 and "CAPPED" or ""))
                if tracked then
                    b.state:SetTextColor(acc.r, acc.g, acc.b, 1)
                else
                    b.state:SetTextColor(1, 1, 1, 0.4)
                end
                b.state:Show()
                b.name:SetAlpha(tracked and 1 or 0.85)
            end
        end
        for i = #shown + 1, #rows do
            rows[i]:Hide()
            rows[i].entry = nil
        end
        emptyText:SetShown(#shown == 0)
        content:SetHeight(math.max(#shown * ITEM_H, 1))
    end

    search:SetScript("OnTextChanged", function(self)
        placeholder:SetShown((self:GetText() or "") == "")
        p:Render()
    end)

    p:SetScript("OnShow", function()
        p.data = ns.GetCurrencyList()
        search:SetText("")
        sf:SetVerticalScroll(0)
        p:Render()
    end)

    return p
end

function CI:OpenPicker()
    if not self.configFrame then self:CreateConfigFrame() end
    if not self.configFrame:IsShown() then self:OpenConfig() end
    if not self.picker then self.picker = BuildPicker() end
    if self.picker:IsShown() then self.picker:Hide() else self.picker:Show() end
end

-- Re-render the status marks after the tracked list changed.
function CI:RefreshPicker()
    if self.picker and self.picker:IsShown() then self.picker:Render() end
end
