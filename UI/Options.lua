local _, addon = ...
local window

local function CreateSlider(page, name, y, option)
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(32)
    row:SetPoint("TOPLEFT", 12, -y)
    row:SetPoint("TOPRIGHT", -12, -y)
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 4, 0)
    label:SetWidth(130)
    label:SetJustifyH("LEFT")
    label:SetText(option.label)
    local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("RIGHT", -4, 0)
    local slider = CreateFrame("Slider", name, row, "MinimalSliderTemplate")
    slider:SetPoint("TOPLEFT", 144, -7)
    slider:SetPoint("TOPRIGHT", -98, -7)
    slider:SetHeight(19)
    slider:SetMinMaxValues(option.min, option.max)
    slider:SetValueStep(option.step)
    slider:SetObeyStepOnDrag(true)
    local refreshing
    function slider:Refresh()
        refreshing = true
        local value = option.getValue()
        self:SetValue(value)
        valueText:SetText(option.format(value))
        if option.isAvailable then self:SetEnabled(option.isAvailable()) end
        refreshing = false
    end
    slider:SetScript("OnValueChanged", function(self, value)
        if refreshing then
            return
        end
        option.setValue(value)
        self:Refresh()
    end)
    slider:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(option.label)
        GameTooltip:AddLine(option.tooltip, 1, 1, 1, true)
        if option.isAvailable and not option.isAvailable() then
            GameTooltip:AddLine("Unavailable in this client.", 1, 0.35, 0.35)
        end
        GameTooltip:Show()
    end)
    local function HideTooltip(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end
    slider:HookScript("OnLeave", HideTooltip)
    slider:HookScript("OnHide", HideTooltip)
    return slider
end

local function CreateSection(page, y, title)
    local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 16, -y)
    heading:SetText(title)
    local line = page:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.65, 0.55, 0.3, 0.45)
    line:SetHeight(1)
    line:SetPoint("LEFT", heading, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", page, "RIGHT", -16, 0)
end

local function CreateCheck(page, name, y, rightColumn, label, tooltip, getValue, setValue, isAvailable)
    local check = CreateFrame("CheckButton", name, page, "UICheckButtonTemplate")
    if rightColumn then
        check:SetPoint("TOPLEFT", page, "TOP", 0, -y)
    else
        check:SetPoint("TOPLEFT", 12, -y)
    end
    check:SetSize(26, 26)
    check.Text:SetText(label)
    check:SetHitRectInsets(0, -check.Text:GetStringWidth() - 4, 0, 0)
    check:SetScript("OnClick", function(self) setValue(self:GetChecked()) end)
    function check:Refresh()
        self:SetChecked(getValue())
        if isAvailable then self:SetEnabled(isAvailable()) end
    end
    check:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label)
        GameTooltip:AddLine(tooltip, 1, 1, 1, true)
        if isAvailable and not isAvailable() then
            GameTooltip:AddLine("Unavailable in this client.", 1, 0.35, 0.35)
        end
        GameTooltip:Show()
    end)
    local function HideTooltip(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    check:HookScript("OnLeave", HideTooltip)
    check:HookScript("OnHide", HideTooltip)
    return check
end

local function CreateOptions()
    window = CreateFrame("Frame", "MinnTinkersWoWFOptions", UIParent, "ButtonFrameTemplate")
    window:Hide()
    window:SetSize(
        math.min(1100, math.max(560, tonumber(MinnTinkersWoWFDB.windowWidth) or 700)),
        math.min(800, math.max(450, tonumber(MinnTinkersWoWFDB.windowHeight) or 480)))
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetTitle(addon.title)
    window:SetPortraitToAsset(addon.icon)
    ButtonFrameTemplate_HideButtonBar(window)
    window:SetMovable(true)
    window:SetResizable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:HookScript("OnHide", window.StopMovingOrSizing)
    local resize = CreateFrame("Button", "MinnTinkersWoWFResize", window, "PanelResizeButtonTemplate")
    resize:SetPoint("BOTTOMRIGHT", -3, 3)
    resize:Init(window, 560, 450, 1100, 800)
    local function SaveSize()
        MinnTinkersWoWFDB.windowWidth, MinnTinkersWoWFDB.windowHeight = window:GetSize()
    end
    resize:SetOnResizeStoppedCallback(SaveSize)
    window:HookScript("OnHide", function()
        resize.isActive = false
        SaveSize()
    end)
    table.insert(UISpecialFrames, window:GetName())

    local pages = {}
    local categories = { "Universal", "UI" }
    local function SelectTab(id)
        MinnTinkersWoWFDB.lastTab = categories[id]
        PanelTemplates_SetTab(window, id)
        for index, page in ipairs(pages) do
            page:SetShown(index == id)
        end
    end
    for id, title in ipairs(categories) do
        local page = CreateFrame("Frame", nil, window.Inset)
        page:SetAllPoints()
        pages[id] = page
        local tab = CreateFrame("Button", "MinnTinkersWoWFOptionsTab" .. id, window, "PanelTabButtonTemplate")
        tab:SetID(id)
        tab:SetText(title)
        if id == 1 then
            tab:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 12, 2)
        end
        tab:SetScript("OnClick", function(self)
            SelectTab(self:GetID())
        end)
    end
    PanelTemplates_SetNumTabs(window, #pages)
    local selected = 1
    for id, title in ipairs(categories) do
        if title == MinnTinkersWoWFDB.lastTab then selected = id; break end
    end
    SelectTab(selected)

    CreateSection(pages[1], 16, "Looting")

    local check = CreateFrame("CheckButton", "MinnTinkersWoWFFastAutoloot", pages[1], "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 12, -34)
    check:SetSize(26, 26)
    check.Text:SetText("Fast autoloot")
    check:SetHitRectInsets(0, -check.Text:GetStringWidth() - 4, 0, 0)
    check:SetScript("OnClick", function(self)
        addon.SetFastAutoloot(self:GetChecked())
    end)
    check:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Fast autoloot")
        GameTooltip:AddLine("Collects loot immediately without the loot window or animations. Requires Auto Loot; manual looting and confirmations remain available.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    check:HookScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end)
    check:HookScript("OnHide", function()
        if GameTooltip:IsOwned(check) then
            GameTooltip:Hide()
        end
    end)

    CreateSection(pages[1], 76, "Camera")
    local camera = CreateSlider(pages[1], "MinnTinkersWoWFCameraDistance", 96, {
        label = "Max camera distance",
        min = addon.CameraDistance.min, max = addon.CameraDistance.max, step = 0.1,
        getValue = addon.CameraDistance.GetFactor,
        setValue = addon.CameraDistance.SetFactor,
        isAvailable = addon.CameraDistance.IsAvailable,
        format = function(value)
            return string.format("%.1f", value)
        end,
        tooltip = "Sets the maximum zoom-out limit. Stock settings stop at 2.0; this slider allows up to 2.6, subject to the client's limit. Use the mouse wheel to zoom out. The current zoom is not changed automatically.",
    })

    local checks = {}
    CreateSection(pages[1], 148, "Questing")
    for index, option in ipairs({
        { key = "autoAccept", label = "Auto accept", tooltip = "Accepts available quests. Skips unlimited repeatable turn-ins, such as cloth donations; daily and weekly quests remain eligible. Hold Shift to handle the conversation manually." },
        { key = "autoTurnIn", label = "Auto turn in", tooltip = "Completes finished quests with no item rewards, excluding unlimited repeatable turn-ins. Any item reward, including fixed rewards, requires your click to complete. Hold Shift to bypass." },
        { key = "vendorReward", label = "Choose highest vendor-value reward", tooltip = "Preselects the reward with the highest total vendor selling price, including stack quantity. You can change the selection and must click to complete any quest with item rewards. Ties select the first reward; missing prices leave the choice manual. Does not sell items. Hold Shift to bypass." },
    }) do
        local key = option.key
        checks[#checks + 1] = CreateCheck(pages[1], "MinnTinkersWoWFQuest_" .. key,
            index == 3 and 198 or 172, index == 2, option.label, option.tooltip,
            function() return MinnTinkersWoWFDB.questing[key] end,
            function(value) addon.Questing.SetOption(key, value) end, addon.Questing.IsAvailable)
    end
    local shiftNote = pages[1]:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    shiftNote:SetPoint("TOPLEFT", 18, -230)
    shiftNote:SetText("Hold Shift to handle quests manually.")

    CreateSection(pages[1], 258, "NPC interaction")
    checks[#checks + 1] = CreateCheck(pages[1], "MinnTinkersWoWFGossipSkip", 280, false,
        "Skip single-option gossip", "Automatically selects an NPC's only available dialogue option when no quests are listed. Multiple options, locked choices and normal confirmations remain manual. Hold Shift to read the dialogue instead.",
        function() return MinnTinkersWoWFDB.skipSingleGossip end,
        addon.GossipSkip.SetEnabled, addon.GossipSkip.IsAvailable)

    local junkCheck = CreateCheck(pages[1], "MinnTinkersWoWFAutoSellJunk", 280, true,
        "Auto sell junk", "Sells poor-quality items with vendor value from carried bags, respecting bags excluded from junk selling. Temporarily locked or uncached items retry on events for up to three seconds. Hold Shift when opening the vendor to bypass. Enabling applies on the next visit; disabling stops pending work.",
        function() return MinnTinkersWoWFDB.autoSellJunk end,
        addon.AutoSellJunk.SetEnabled, addon.AutoSellJunk.IsAvailable)
    checks[#checks + 1] = junkCheck

    CreateSection(pages[2], 16, "Action-bar text")
    local sliders = {}
    for index, option in ipairs(addon.ActionBarFonts.options) do
        local key = option.key
        local slider = CreateSlider(pages[2], "MinnTinkersWoWFFont_" .. key, 40 + (index - 1) * 34, {
            label = option.label, min = 0, max = 12, step = 1,
            getValue = function() return addon.ActionBarFonts.GetIncrease(key) end,
            isAvailable = addon.ActionBarFonts.IsAvailable,
            setValue = function(value)
                local increase = math.floor(value + 0.5)
                if addon.ActionBarFonts.GetIncrease(key) ~= increase then
                    addon.ActionBarFonts.SetIncrease(key, increase)
                end
            end,
            format = function(value) return value == 0 and "Default" or ("+" .. value .. " px") end,
            tooltip = "Increases this text on Blizzard action bars. Zero restores its native size. Changes made in combat apply after combat.",
        })
        sliders[key] = slider
    end
    CreateSection(pages[2], 158, "Combat indicator")
    checks[#checks + 1] = CreateCheck(pages[2], "MinnTinkersWoWFCombat_enabled", 180, false,
        "Persistent red edge glow", "Shows a soft red glow along the screen edges while in combat. Keeps the center clear and does not intercept clicks. Blizzard's low-health warning remains independent.",
        function() return MinnTinkersWoWFDB.combatIndicator.enabled end,
        function(value) addon.CombatIndicator.SetOption("enabled", value) end)
    local combatOpacity = CreateSlider(pages[2], "MinnTinkersWoWFCombat_opacity", 212, {
        label = "Opacity", min = 5, max = 60, step = 1,
        getValue = addon.CombatIndicator.GetOpacity,
        setValue = function(value) addon.CombatIndicator.SetOption("opacity", value) end,
        format = function(value) return string.format("%d%%", value) end,
        tooltip = "Sets the combat glow's intensity. Lower values keep it subtle. Changes apply immediately, including during combat.",
    })
    local combatWidth = CreateSlider(pages[2], "MinnTinkersWoWFCombat_width", 246, {
        label = "Border width", min = 8, max = 48, step = 1,
        getValue = addon.CombatIndicator.GetWidth,
        setValue = function(value) addon.CombatIndicator.SetOption("width", value) end,
        format = function(value) return string.format("%d", value) end,
        tooltip = "Sets the width of the soft edge glow in UI units. The inner edge fades to transparent. Changes apply immediately, including during combat.",
    })
    CreateSection(pages[2], 298, "Chat")
    checks[#checks + 1] = CreateCheck(pages[2], "MinnTinkersWoWFChatURLs", 320, false,
        "Clickable chat URLs", "Highlights web addresses in new chat messages, including bare domains such as discord.gg/invite. Click a link to select its address in a copy window, then press Ctrl+C. Existing WoW links remain intact.",
        function() return MinnTinkersWoWFDB.chatURLs end,
        addon.ChatURLs.SetEnabled, addon.ChatURLs.IsAvailable)
    window:SetScript("OnShow", function()
        check:SetChecked(MinnTinkersWoWFDB.fastAutoloot)
        for _, control in ipairs(checks) do control:Refresh() end
        for _, option in ipairs(addon.ActionBarFonts.options) do
            sliders[option.key]:Refresh()
        end
        camera:Refresh()
        combatOpacity:Refresh()
        combatWidth:Refresh()
    end)
end

function addon.ToggleOptions()
    if not window then
        CreateOptions()
    end
    window:SetShown(not window:IsShown())
end

SLASH_MINNTINKERSWOWF1 = "/minn"
SlashCmdList.MINNTINKERSWOWF = addon.ToggleOptions

function addon.InitializeMinimapButton()
    if not Minimap then return end
    local button = CreateFrame("Button", "MinnTinkersWoWFMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(addon.icon)
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")
    local function PlaceButton()
        local angle = math.rad(tonumber(MinnTinkersWoWFDB.minimapAngle) or 135)
        local radius = Minimap:GetWidth() / 2 + 5
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end
    PlaceButton()
    button:SetScript("OnDragStart", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        self:SetScript("OnUpdate", function()
            local centerX, centerY = Minimap:GetCenter()
            if not centerX or not centerY then return end
            local cursorX, cursorY = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            MinnTinkersWoWFDB.minimapAngle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX))
            PlaceButton()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:HookScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnClick", addon.ToggleOptions)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(addon.title)
        GameTooltip:AddLine("Click to toggle settings. Drag to move around the minimap. /minn", 1, 1, 1)
        GameTooltip:Show()
    end)
    local function HideTooltip(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    button:HookScript("OnLeave", HideTooltip)
    button:HookScript("OnHide", HideTooltip)
end
