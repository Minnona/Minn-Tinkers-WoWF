local _, addon = ...
local window
local rowHeight, rowSpacing, sectionGap = 26, 32, 24

local function IncreaseFont(text)
    local font, size, flags = text:GetFont()
    text:SetFont(font, size + 1, flags)
end

local function CreateSlider(page, name, y, option)
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(rowHeight)
    row:SetPoint("TOPLEFT", 12, -y)
    row:SetPoint("TOPRIGHT", -12, -y)
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 4, 0)
    label:SetWidth(148)
    label:SetJustifyH("LEFT")
    IncreaseFont(label)
    label:SetText(option.label)
    local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    IncreaseFont(valueText)
    valueText:SetPoint("RIGHT", -4, 0)
    local slider = CreateFrame("Slider", name, row, "MinimalSliderTemplate")
    slider:SetPoint("TOPLEFT", 162, -4)
    slider:SetPoint("TOPRIGHT", -98, -4)
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
    IncreaseFont(heading)
    heading:SetText(title)
    local line = page:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.65, 0.55, 0.3, 0.45)
    line:SetHeight(1)
    line:SetPoint("LEFT", heading, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", page, "RIGHT", -16, 0)
    return y + 24
end

local function CreateCheck(page, name, y, rightColumn, label, tooltip, getValue, setValue, isAvailable)
    local check = CreateFrame("CheckButton", name, page, "UICheckButtonTemplate")
    if rightColumn then
        check:SetPoint("TOPLEFT", page, "TOP", 0, -y)
    else
        check:SetPoint("TOPLEFT", 12, -y)
    end
    check:SetSize(rowHeight, rowHeight)
    IncreaseFont(check.Text)
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
        math.min(800, math.max(670, tonumber(MinnTinkersWoWFDB.windowHeight) or 670)))
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
    resize:Init(window, 560, 670, 1100, 800)
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
    local categories = { "Universal", "UI", "Chat" }
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
        IncreaseFont(tab:GetFontString())
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

    local y = CreateSection(pages[1], 16, "Looting")

    local check = CreateFrame("CheckButton", "MinnTinkersWoWFFastAutoloot", pages[1], "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 12, -y)
    check:SetSize(rowHeight, rowHeight)
    IncreaseFont(check.Text)
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

    y = CreateSection(pages[1], y + rowHeight + sectionGap, "Camera")
    local camera = CreateSlider(pages[1], "MinnTinkersWoWFCameraDistance", y, {
        label = "Max camera distance",
        min = addon.CameraDistance.min, max = addon.CameraDistance.max, step = 0.1,
        getValue = addon.CameraDistance.GetFactor,
        setValue = addon.CameraDistance.SetFactor,
        isAvailable = addon.CameraDistance.IsAvailable,
        format = function(value)
            return string.format("%.1f", value)
        end,
        tooltip = "Sets the maximum zoom-out limit. Stock settings stop at 2.0; this slider allows up to 4.0, subject to the client's limit. Use the mouse wheel to zoom out. The current zoom is not changed automatically.",
    })

    local checks = {}
    y = CreateSection(pages[1], y + rowHeight + sectionGap, "Questing")
    for index, option in ipairs({
        { key = "autoAccept", label = "Auto accept", tooltip = "Accepts available quests. Skips unlimited repeatable turn-ins, such as cloth donations; daily and weekly quests remain eligible. Hold Shift to handle the conversation manually." },
        { key = "autoTurnIn", label = "Auto turn in", tooltip = "Completes finished quests with zero or one reward choice, including fixed rewards, excluding unlimited repeatable turn-ins. Two or more choices require your click to complete. Hold Shift to bypass." },
        { key = "vendorReward", label = "Choose highest vendor-value reward", tooltip = "Preselects the reward with the highest total vendor selling price, including stack quantity. Quests with two or more choices require your click to complete, and you can change the selection. Ties select the first reward; missing prices leave the choice manual. Does not sell items. Hold Shift to bypass." },
    }) do
        local key = option.key
        checks[#checks + 1] = CreateCheck(pages[1], "MinnTinkersWoWFQuest_" .. key,
            index == 3 and y + rowSpacing or y, index == 2, option.label, option.tooltip,
            function() return MinnTinkersWoWFDB.questing[key] end,
            function(value) addon.Questing.SetOption(key, value) end, addon.Questing.IsAvailable)
    end
    local shiftNote = pages[1]:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    IncreaseFont(shiftNote)
    shiftNote:SetPoint("TOPLEFT", 16, -(y + rowSpacing * 2 + 6))
    shiftNote:SetText("Hold Shift to handle quests manually.")

    y = CreateSection(pages[1], y + rowSpacing * 2 + rowHeight + sectionGap, "NPC interaction")
    checks[#checks + 1] = CreateCheck(pages[1], "MinnTinkersWoWFGossipSkip", y, false,
        "Skip single-option gossip", "Automatically selects an NPC's only available dialogue option when no quests are listed. Multiple options, locked choices and normal confirmations remain manual. Hold Shift to read the dialogue instead.",
        function() return MinnTinkersWoWFDB.skipSingleGossip end,
        addon.GossipSkip.SetEnabled, addon.GossipSkip.IsAvailable)

    local junkCheck = CreateCheck(pages[1], "MinnTinkersWoWFAutoSellJunk", y, true,
        "Auto sell junk", "Sells poor-quality items with vendor value from carried bags, respecting bags excluded from junk selling. Temporarily locked or uncached items retry on events for up to three seconds. Hold Shift when opening the vendor to bypass. Enabling applies on the next visit; disabling stops pending work.",
        function() return MinnTinkersWoWFDB.autoSellJunk end,
        addon.AutoSellJunk.SetEnabled, addon.AutoSellJunk.IsAvailable)
    checks[#checks + 1] = junkCheck

    y = CreateSection(pages[2], 16, "Action-bar text")
    local sliders = {}
    for index, option in ipairs(addon.ActionBarFonts.options) do
        local key = option.key
        local slider = CreateSlider(pages[2], "MinnTinkersWoWFFont_" .. key, y + (index - 1) * rowSpacing, {
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
    y = CreateSection(pages[2], y + (#addon.ActionBarFonts.options - 1) * rowSpacing + rowHeight + sectionGap, "Combat indicator")
    checks[#checks + 1] = CreateCheck(pages[2], "MinnTinkersWoWFCombat_enabled", y, false,
        "Persistent red edge glow", "Shows a soft red glow along the screen edges while in combat. Keeps the center clear and does not intercept clicks. Blizzard's low-health warning remains independent.",
        function() return MinnTinkersWoWFDB.combatIndicator.enabled end,
        function(value) addon.CombatIndicator.SetOption("enabled", value) end)
    local combatOpacity = CreateSlider(pages[2], "MinnTinkersWoWFCombat_opacity", y + rowSpacing, {
        label = "Opacity", min = 5, max = 60, step = 1,
        getValue = addon.CombatIndicator.GetOpacity,
        setValue = function(value) addon.CombatIndicator.SetOption("opacity", value) end,
        format = function(value) return string.format("%d%%", value) end,
        tooltip = "Sets the combat glow's intensity. Lower values keep it subtle. Changes apply immediately, including during combat.",
    })
    local combatWidth = CreateSlider(pages[2], "MinnTinkersWoWFCombat_width", y + rowSpacing * 2, {
        label = "Border width", min = 8, max = 48, step = 1,
        getValue = addon.CombatIndicator.GetWidth,
        setValue = function(value) addon.CombatIndicator.SetOption("width", value) end,
        format = function(value) return string.format("%d", value) end,
        tooltip = "Sets the width of the soft edge glow in UI units. The inner edge fades to transparent. Changes apply immediately, including during combat.",
    })
    local _, playerClass = UnitClass("player")
    y = y + rowSpacing * 2 + rowHeight + sectionGap
    if playerClass == "HUNTER" then
        y = CreateSection(pages[2], y, "Pet")
        checks[#checks + 1] = CreateCheck(pages[2], "MinnTinkersWoWFPetHappiness", y, false,
            "Pet happiness bar", "Replaces the hunter pet's happiness face with a thin red/yellow/green meter below its focus bar. The fill shows happiness reserve; the colored thirds are visual guides. Mouseover retains Blizzard's happiness, damage bonus and diet tooltip.",
            function() return MinnTinkersWoWFDB.petHappinessBar end,
            addon.PetHappinessBar.SetEnabled, addon.PetHappinessBar.IsAvailable)
        y = y + rowHeight + sectionGap
    end
    local rangeY = CreateSection(pages[2], y, "Range indicator")
    local range = addon.RangeIndicator
    local rangeEnabled = CreateCheck(pages[2], "MinnTinkersWoWFRangeEnabled", rangeY, false,
        "Show range indicator", "Shows a white dot when the target is in range of your selected spell, red when out of range. Hides when no valid check is available. This checks range, not cooldowns, resources or line of sight. Settings are saved per character.",
        function() return range.GetSettings().enabled end, range.SetEnabled, range.IsAvailable)
    local rangeUnlocked = CreateCheck(pages[2], "MinnTinkersWoWFRangeUnlocked", rangeY, true,
        "Unlock position", "Shows a draggable preview even without a target. Drag the circle to move it. Locking makes it click-through. Reset position below brings it back near screen center.",
        function() return not range.GetSettings().locked end,
        function(value) range.SetLocked(not value) end, range.IsAvailable)
    checks[#checks + 1], checks[#checks + 2] = rangeEnabled, rangeUnlocked
    local spellSlot = CreateFrame("Button", "MinnTinkersWoWFRangeSpellSlot", pages[2], "UIPanelButtonTemplate")
    spellSlot:SetSize(rowHeight, rowHeight)
    spellSlot:SetPoint("TOPLEFT", 16, -(rangeY + rowSpacing))
    spellSlot.icon = spellSlot:CreateTexture(nil, "ARTWORK")
    spellSlot.icon:SetPoint("TOPLEFT", 3, -3)
    spellSlot.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    local spellInput = CreateFrame("EditBox", "MinnTinkersWoWFRangeSpellInput", pages[2], "InputBoxTemplate")
    IncreaseFont(spellInput)
    spellInput:SetAutoFocus(false)
    spellInput:SetMaxLetters(128)
    spellInput:SetHeight(20)
    spellInput:SetPoint("TOPLEFT", 58, -(rangeY + rowSpacing + 3))
    spellInput:SetPoint("TOPRIGHT", -160, -(rangeY + rowSpacing + 3))
    local selectSpell = CreateFrame("Button", "MinnTinkersWoWFRangeSelectSpell", pages[2], "UIPanelButtonTemplate")
    selectSpell:SetSize(62, rowHeight)
    IncreaseFont(selectSpell:GetFontString())
    selectSpell:SetPoint("TOPRIGHT", -86, -(rangeY + rowSpacing))
    selectSpell:SetText("Select")
    local clearSpell = CreateFrame("Button", "MinnTinkersWoWFRangeClearSpell", pages[2], "UIPanelButtonTemplate")
    clearSpell:SetSize(62, rowHeight)
    IncreaseFont(clearSpell:GetFontString())
    clearSpell:SetPoint("TOPRIGHT", -16, -(rangeY + rowSpacing))
    clearSpell:SetText("Clear")
    local rangeStatus = pages[2]:CreateFontString("MinnTinkersWoWFRangeStatus", "OVERLAY", "GameFontHighlightSmall")
    rangeStatus:SetPoint("TOPLEFT", 16, -(rangeY + rowSpacing * 2 + 6))
    rangeStatus:SetPoint("TOPRIGHT", -16, -(rangeY + rowSpacing * 2 + 6))
    IncreaseFont(rangeStatus)
    rangeStatus:SetJustifyH("LEFT")
    rangeStatus:SetMaxLines(1)
    local rangeSize = CreateSlider(pages[2], "MinnTinkersWoWFRangeSize", rangeY + rowSpacing * 3, {
        label = "Indicator size", min = 8, max = 96, step = 1,
        getValue = function() return range.GetSettings().size end,
        setValue = range.SetSize, isAvailable = range.IsAvailable,
        format = function(value) return string.format("%d", value) end,
        tooltip = "Resizes the range circle in UI units. Changes apply immediately. Position and size are saved per character.",
    })
    local rangeOpacity = CreateSlider(pages[2], "MinnTinkersWoWFRangeOpacity", rangeY + rowSpacing * 4, {
        label = "Indicator opacity", min = 10, max = 100, step = 1,
        getValue = function() return range.GetSettings().opacity end,
        setValue = range.SetOpacity, isAvailable = range.IsAvailable,
        format = function(value) return string.format("%d%%", value) end,
        tooltip = "Adjusts the range circle's opacity. Changes apply immediately and are saved per character.",
    })
    local resetRange = CreateFrame("Button", "MinnTinkersWoWFRangeResetPosition", pages[2], "UIPanelButtonTemplate")
    resetRange:SetSize(120, rowHeight)
    IncreaseFont(resetRange:GetFontString())
    resetRange:SetPoint("TOPLEFT", 16, -(rangeY + rowSpacing * 5))
    resetRange:SetText("Reset position")
    resetRange:SetScript("OnClick", range.ResetPosition)
    local function RefreshRangeOptions()
        local available = range.IsAvailable()
        local info = range.GetSpellInfo()
        rangeEnabled:Refresh(); rangeUnlocked:Refresh(); rangeSize:Refresh(); rangeOpacity:Refresh()
        for _, control in ipairs({spellSlot, spellInput, selectSpell, clearSpell, resetRange}) do control:SetEnabled(available) end
        spellSlot.icon:SetTexture(info and info.iconID or "Interface\\Icons\\INV_Misc_QuestionMark")
        spellInput:SetText(info and info.name or "")
        rangeStatus:SetTextColor(1, 1, 1)
        if not available then
            rangeStatus:SetText("Range checking is unavailable in this client.")
        elseif info then
            rangeStatus:SetText("Selected: " .. info.name)
        else
            rangeStatus:SetText("Drop a spell here, or enter its name and press Enter.")
        end
    end
    range.OnSettingsChanged = function()
        if window:IsShown() and pages[2]:IsShown() then RefreshRangeOptions() end
    end
    pages[2]:HookScript("OnShow", RefreshRangeOptions)
    local function SelectSpellID(id)
        local success, message = range.SelectSpell(id)
        if success then
            RefreshRangeOptions()
        else
            rangeStatus:SetText(message)
            rangeStatus:SetTextColor(1, 0.35, 0.35)
        end
        return success
    end
    local function SubmitSpell()
        local matches = range.FindSpells(spellInput:GetText())
        spellInput:ClearFocus()
        if #matches == 0 then
            rangeStatus:SetText("No learned spell with a range check matches that name.")
            rangeStatus:SetTextColor(1, 0.35, 0.35)
        elseif #matches == 1 then
            SelectSpellID(matches[1].spellID)
        else
            MenuUtil.CreateContextMenu(spellInput, function(_, menu)
                menu:CreateTitle("Choose a spell")
                menu:SetScrollMode(240)
                for _, info in ipairs(matches) do
                    local id = info.spellID
                    local label = info.name .. (info.subName ~= "" and (" (" .. info.subName .. ")") or "")
                    menu:CreateButton(label, function() SelectSpellID(id) end)
                end
            end)
        end
    end
    spellInput:SetScript("OnEnterPressed", SubmitSpell)
    spellInput:SetScript("OnEscapePressed", spellInput.ClearFocus)
    selectSpell:SetScript("OnClick", SubmitSpell)
    clearSpell:SetScript("OnClick", range.ClearSpell)
    local function ReceiveSpell()
        local kind, _, _, id = GetCursorInfo()
        if not canaccessvalue(kind, id) or kind ~= "spell" then
            rangeStatus:SetText("Drop an ability from your spellbook.")
            rangeStatus:SetTextColor(1, 0.35, 0.35)
        elseif SelectSpellID(id) then
            spellInput:ClearFocus()
            ClearCursor()
        end
    end
    spellSlot:SetScript("OnReceiveDrag", ReceiveSpell)
    spellSlot:SetScript("OnClick", ReceiveSpell)
    spellSlot:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Tracked spell")
        local info = range.GetSpellInfo()
        if info then GameTooltip:AddLine(info.name, 1, 1, 1) end
        GameTooltip:AddLine("Drag a learned spell from the spellbook into this slot. You can also type its name and press Enter.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    local function HideSpellTooltip(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    spellSlot:HookScript("OnLeave", HideSpellTooltip)
    spellSlot:HookScript("OnHide", HideSpellTooltip)
    y = CreateSection(pages[3], 16, "Chat input")
    for index, option in ipairs({
        {key = "preserveDraft", label = "Keep unfinished messages", tooltip = "Escape unfocuses chat and keeps your draft for this session. Opening chat normally restores its text and destination. An explicit chat command starts a new message. Autocomplete keeps its native Escape behavior."},
        {key = "arrowHistory", label = "Up/Down message history", tooltip = "Use plain Up and Down to browse the last 32 messages, saved per character across reloads and normal game exits. History is shared by your chat windows. Down past the newest restores your draft. Autocomplete keeps its native arrow behavior."},
    }) do
        local key = option.key
        checks[#checks + 1] = CreateCheck(pages[3], "MinnTinkersWoWFChat_" .. key, y, index == 2,
            option.label, option.tooltip, function() return MinnTinkersWoWFDB.chat[key] end,
            function(value) addon.ChatInput.SetOption(key, value) end, addon.ChatInput.IsAvailable)
    end
    y = CreateSection(pages[3], y + rowHeight + sectionGap, "Chat tools")
    checks[#checks + 1] = CreateCheck(pages[3], "MinnTinkersWoWFChatURLs", y, false,
        "Clickable chat URLs", "Highlights web addresses in new chat messages, including bare domains such as discord.gg/invite. Click a link to select its address in a copy window, then press Ctrl+C. Existing WoW links remain intact.",
        function() return MinnTinkersWoWFDB.chatURLs end, addon.ChatURLs.SetEnabled, addon.ChatURLs.IsAvailable)
    checks[#checks + 1] = CreateCheck(pages[3], "MinnTinkersWoWFChat_copyChat", y, true,
        "Copy chat button", "Adds a Copy icon to the left of each chat input. Opens its retained messages as plain text for Ctrl+A and Ctrl+C. Restricted messages cannot be copied. Combat log is excluded.",
        function() return MinnTinkersWoWFDB.chat.copyChat end,
        function(value) addon.ChatTools.SetOption("copyChat", value) end, addon.ChatTools.IsAvailable)
    checks[#checks + 1] = CreateCheck(pages[3], "MinnTinkersWoWFChat_unreadMarker", y + rowSpacing, false,
        "New-message marker", "Shows a small New messages button when messages arrive while you are scrolled up. Click it to return to the bottom. Clears when you reach the bottom; scrolling speed stays native.",
        function() return MinnTinkersWoWFDB.chat.unreadMarker end,
        function(value) addon.ChatTools.SetOption("unreadMarker", value) end, addon.ChatTools.IsAvailable)
    y = CreateSection(pages[3], y + rowSpacing + rowHeight + sectionGap, "Timestamps")
    local timestamps = CreateFrame("Button", "MinnTinkersWoWFChatTimestamps", pages[3], "UIPanelButtonTemplate")
    timestamps:SetSize(240, rowHeight)
    IncreaseFont(timestamps:GetFontString())
    timestamps:SetPoint("TOPLEFT", 16, -y)
    local timestampOptions = {
        {"none", "Off"}, {TIMESTAMP_FORMAT_HHMM_24HR, "24-hour (21:34)"},
        {TIMESTAMP_FORMAT_HHMMSS_24HR, "24-hour with seconds"},
        {TIMESTAMP_FORMAT_HHMM_AMPM, "12-hour (9:34 PM)"},
        {TIMESTAMP_FORMAT_HHMMSS_AMPM, "12-hour with seconds"},
    }
    local function RefreshTimestamps()
        local current = addon.ChatTools.GetTimestampFormat()
        local label = current == "none" and "Off" or "Custom"
        for _, option in ipairs(timestampOptions) do if option[1] == current then label = option[2]; break end end
        timestamps:SetText("Timestamps: " .. label)
        timestamps:SetEnabled(addon.ChatTools.TimestampsAvailable() and MenuUtil ~= nil)
    end
    timestamps:SetScript("OnClick", function(self)
        MenuUtil.CreateContextMenu(self, function(_, menu)
            menu:CreateTitle("Timestamps")
            for _, option in ipairs(timestampOptions) do
                local value = option[1]
                if value then menu:CreateRadio(option[2], function() return addon.ChatTools.GetTimestampFormat() == value end,
                    function() addon.ChatTools.SetTimestampFormat(value); RefreshTimestamps() end) end
            end
        end)
    end)
    local timestampHint = pages[3]:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    IncreaseFont(timestampHint)
    timestampHint:SetPoint("TOPLEFT", 16, -(y + rowSpacing + 6))
    timestampHint:SetText("Uses Blizzard's timestamp setting; applies to new messages.")
    pages[3]:HookScript("OnShow", RefreshTimestamps)
    window:SetScript("OnShow", function()
        check:SetChecked(MinnTinkersWoWFDB.fastAutoloot)
        for _, control in ipairs(checks) do control:Refresh() end
        for _, option in ipairs(addon.ActionBarFonts.options) do
            sliders[option.key]:Refresh()
        end
        camera:Refresh()
        combatOpacity:Refresh()
        combatWidth:Refresh()
        RefreshRangeOptions()
        RefreshTimestamps()
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
