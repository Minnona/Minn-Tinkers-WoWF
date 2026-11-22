local _, addon = ...
local window
local rowHeight, rowSpacing, sectionGap = 26, 32, 24

local function CreateSlider(page, name, y, option)
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(rowHeight)
    row:SetPoint("TOPLEFT", 12, -y)
    row:SetPoint("TOPRIGHT", -12, -y)
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight_NoShadow")
    label:SetPoint("LEFT", 4, 0)
    label:SetWidth(148)
    label:SetJustifyH("LEFT")
    label:SetText(option.label)
    local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight_NoShadow")
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
        if refreshing then return end
        if option.applyOnRelease then
            valueText:SetText(option.format(value))
        else
            option.setValue(value)
            self:Refresh()
        end
    end)
    if option.applyOnRelease then
        slider:HookScript("OnMouseUp", function(self, button)
            if button ~= "LeftButton" then return end
            option.setValue(self:GetValue())
            self:Refresh()
        end)
    end
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
    local background = page:CreateTexture(nil, "ARTWORK")
    background:SetAtlas("common-button-list-collapseExpand")
    background:SetPoint("TOPLEFT", 12, -y + 4)
    background:SetPoint("TOPRIGHT", -12, -y + 4)
    background:SetHeight(22)
    local heading = page:CreateFontString(nil, "OVERLAY", "Game15Font_Shadow")
    heading:SetPoint("TOPLEFT", 22, -y)
    heading:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    heading:SetText(title)
    return y + 24
end

local function CreateCheck(page, name, y, rightColumn, label, tooltip, getValue, setValue, isAvailable)
    local check = CreateFrame("CheckButton", name, page, "CheckboxWithLabelTemplate")
    if rightColumn then
        check:SetPoint("TOPLEFT", page, "TOP", 0, -y)
    else
        check:SetPoint("TOPLEFT", 12, -y)
    end
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

local function SetLegacyBackground(inset)
    local atlas = "Legacy-Rewards-Tracker-background"
    inset.Bg:SetColorTexture(0, 0, 0, 1)
    local background = inset:CreateTexture(nil, "BACKGROUND", nil, -4)
    background:SetAllPoints()
    background:SetAtlas(atlas)
    background:SetHorizTile(false)
    background:SetVertTile(false)

    local info = C_Texture and C_Texture.GetAtlasInfo(atlas)
    local file = info and (info.file or info.filename)
    if not file or info.width <= 0 or info.height <= 0 then return end

    -- Scale once to the native Progress Track's approximate content size.
    local scale = math.max(910 / info.width, 550 / info.height)
    local artWidth, artHeight = info.width * scale, info.height * scale
    local uSpan = info.rightTexCoord - info.leftTexCoord
    local vSpan = info.bottomTexCoord - info.topTexCoord
    -- Use the atlas bounds on the source sheet, as Blizzard does for cropped textures.
    background:SetTexture(file)
    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", inset)
    background:SetPoint("TOPRIGHT", inset)

    local fadeHeight = 64
    local fadeStart = artHeight - fadeHeight
    local fade = inset:CreateTexture(nil, "BACKGROUND", nil, -3)
    fade:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, -fadeStart)
    fade:SetPoint("TOPRIGHT", inset, "TOPRIGHT", 0, -fadeStart)
    fade:SetColorTexture(1, 1, 1, 1)
    local clear = CreateColor(0, 0, 0, 0)

    local function UpdateCrop(_, width, height)
        if width <= 0 or height <= 0 then return end
        local sideCrop = (1 - math.min(width / artWidth, 1)) / 2 * uSpan
        local visibleHeight = math.min(height, artHeight)
        background:SetHeight(visibleHeight)
        background:SetTexCoord(info.leftTexCoord + sideCrop, info.rightTexCoord - sideCrop,
            info.topTexCoord, info.topTexCoord + visibleHeight / artHeight * vSpan)
        local visibleFade = visibleHeight - fadeStart
        fade:SetShown(visibleFade > 0)
        if visibleFade > 0 then
            fade:SetHeight(visibleFade)
            fade:SetGradient("VERTICAL", CreateColor(0, 0, 0, visibleFade / fadeHeight), clear)
        end
    end
    inset:HookScript("OnSizeChanged", UpdateCrop)
    UpdateCrop(inset, inset:GetWidth(), inset:GetHeight())
end

local function CreateOptions()
    local width, minHeight, maxHeight = 560, 670, 800
    window = CreateFrame("Frame", "MinnTinkersWoWFOptions", UIParent, "ButtonFrameTemplate")
    window:Hide()
    window:SetSize(width, math.min(maxHeight, math.max(minHeight,
        tonumber(MinnTinkersWoWFDB.windowHeight) or minHeight)))
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetPortraitToAsset(addon.icon)
    ButtonFrameTemplate_HideButtonBar(window)
    SetLegacyBackground(window.Inset)
    window.onCloseCallback = function()
        window:Hide()
        return false
    end
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
    resize:Init(window, width, minHeight, width, maxHeight)
    window.onResizeStartCallback = function()
        window:StartSizing("BOTTOM", true)
        return false
    end
    local function SaveHeight()
        MinnTinkersWoWFDB.windowHeight = window:GetHeight()
    end
    resize:SetOnResizeStoppedCallback(SaveHeight)
    window:HookScript("OnHide", function()
        resize.isActive = false
        SaveHeight()
    end)
    table.insert(UISpecialFrames, window:GetName())

    local pages, tabs = {}, {}
    local categories = { "Universal", "UI", "Chat" }
    local icons = { "INV_Misc_Gear_01", "INV_Misc_Spyglass_03", "INV_Misc_Note_01", "ClassIcon_Hunter" }
    local _, playerClass = UnitClass("player")
    if playerClass == "HUNTER" then categories[#categories + 1] = "Hunter" end
    local function SelectTab(id)
        MinnTinkersWoWFDB.lastTab = categories[id]
        window:SetTitle(addon.title .. " - " .. categories[id])
        for index, page in ipairs(pages) do
            tabs[index]:SetChecked(index == id)
            page:SetShown(index == id)
        end
    end
    for id, title in ipairs(categories) do
        local page = CreateFrame("Frame", nil, window.Inset)
        page:SetAllPoints()
        pages[id] = page
        local tab = CreateFrame("Frame", "MinnTinkersWoWFOptionsTab" .. id, window, "LargeSideTabButtonTemplate")
        tabs[id] = tab
        tab:SetID(id)
        tab:EnableMouse(true)
        tab.tooltipText = title
        tab.Icon:SetTexture("Interface/Icons/" .. icons[id])
        tab:SetFillToInterior(true)
        if id == 1 then
            tab:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, -60)
            window:SetClampRectInsets(0, tab:GetWidth(), 0, 0)
        else
            tab:SetPoint("TOPLEFT", tabs[id - 1], "BOTTOMLEFT", 0, -2)
        end
        tab:SetCustomOnMouseUpHandler(function(self, mouseButton, upInside)
            if mouseButton == "LeftButton" and upInside then SelectTab(self:GetID()) end
        end)
    end
    local selected = 1
    for id, title in ipairs(categories) do
        if title == MinnTinkersWoWFDB.lastTab then selected = id; break end
    end
    SelectTab(selected)

    local y = CreateSection(pages[1], 16, "Looting")

    local check = CreateCheck(pages[1], "MinnTinkersWoWFFastAutoloot", y, false,
        "Fast autoloot", "Skips the loot window and animation. Requires Auto Loot.",
        function() return MinnTinkersWoWFDB.fastAutoloot end, addon.SetFastAutoloot)

    y = CreateSection(pages[1], y + rowHeight + sectionGap, "Game options")
    local camera = CreateSlider(pages[1], "MinnTinkersWoWFCameraDistance", y, {
        label = "Max camera distance",
        min = addon.CameraDistance.min, max = addon.CameraDistance.max, step = 0.1,
        getValue = addon.CameraDistance.GetFactor,
        setValue = addon.CameraDistance.SetFactor,
        isAvailable = addon.CameraDistance.IsAvailable,
        format = function(value)
            return string.format("%.1f", value)
        end,
        tooltip = "Lets you zoom farther out, up to 4.0.",
    })

    local graphics = addon.WorldGraphics
    local grassDensity = CreateSlider(pages[1], "MinnTinkersWoWFGrassDensity", y + rowSpacing, {
        label = "Grass density", min = graphics.minDensity, max = graphics.maxDensity, step = 8,
        getValue = graphics.GetDensity, setValue = graphics.SetDensity, isAvailable = graphics.IsDensityAvailable,
        format = tostring, tooltip = "Adds more grass and ground plants.", applyOnRelease = true,
    })
    local grassDistance = CreateSlider(pages[1], "MinnTinkersWoWFGrassDistance", y + rowSpacing * 2, {
        label = "Grass distance", min = graphics.minDistance, max = graphics.maxDistance, step = 10,
        getValue = graphics.GetDistance, setValue = graphics.SetDistance, isAvailable = graphics.IsDistanceAvailable,
        format = tostring, tooltip = "Shows grass farther away and blends it into the distance.", applyOnRelease = true,
    })

    local checks = {}
    checks[#checks + 1] = CreateCheck(pages[1], "MinnTinkersWoWFQuietFishing", y + rowSpacing * 3, false,
        "Quiet while fishing", "Fades out music and ambience and raises effects to 100%. Your usual volumes start returning eight seconds after you stop fishing.",
        function() return MinnTinkersWoWFDB.quietFishing end, addon.FishingSound.SetEnabled, addon.FishingSound.IsAvailable)
    local sparkles = CreateCheck(pages[1], "MinnTinkersWoWFQuestSparkles", y + rowSpacing * 3, true,
        "Quest item sparkles", "Shows sparkles on quest objects and lootables when Outline Mode is off.",
        graphics.GetSparkles, graphics.SetSparkles, graphics.IsSparklesAvailable)
    sparkles:HookScript("OnClick", sparkles.Refresh)
    checks[#checks + 1] = sparkles

    y = CreateSection(pages[1], y + rowSpacing * 3 + rowHeight + sectionGap, "Questing")
    for index, option in ipairs({
        { key = "autoAccept", label = "Auto accept", tooltip = "Accepts quests for you. Skips turn-ins you can repeat anytime, like cloth donations." },
        { key = "autoTurnIn", label = "Auto turn in", tooltip = "Turns in finished quests when there's one reward option or none. Skips repeatable turn-ins like cloth donations." },
        { key = "vendorReward", label = "Choose highest vendor-value reward", tooltip = "Suggests the reward that sells for the most. You can pick another before turning in the quest." },
    }) do
        local key = option.key
        checks[#checks + 1] = CreateCheck(pages[1], "MinnTinkersWoWFQuest_" .. key,
            index == 3 and y + rowSpacing or y, index == 2, option.label, option.tooltip,
            function() return MinnTinkersWoWFDB.questing[key] end,
            function(value) addon.Questing.SetOption(key, value) end, addon.Questing.IsAvailable)
    end
    local shiftNote = pages[1]:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall2")
    shiftNote:SetPoint("TOPLEFT", 16, -(y + rowSpacing * 2 + 6))
    shiftNote:SetText("Hold Shift to handle quests manually.")

    y = CreateSection(pages[1], y + rowSpacing * 2 + rowHeight + sectionGap, "NPC interaction")
    checks[#checks + 1] = CreateCheck(pages[1], "MinnTinkersWoWFGossipSkip", y, false,
        "Skip single-option gossip", "Picks the only dialogue option when the NPC has no quests listed. Hold Shift to see the dialogue.",
        function() return MinnTinkersWoWFDB.skipSingleGossip end,
        addon.GossipSkip.SetEnabled, addon.GossipSkip.IsAvailable)

    local junkCheck = CreateCheck(pages[1], "MinnTinkersWoWFAutoSellJunk", y, true,
        "Auto sell junk", "Sells grey items when you open a vendor, skipping bags you've excluded. Hold Shift when opening the vendor to skip selling.",
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
            tooltip = "Set to zero for the default size. Changes made in combat apply afterward.",
        })
        sliders[key] = slider
    end
    y = CreateSection(pages[2], y + (#addon.ActionBarFonts.options - 1) * rowSpacing + rowHeight + sectionGap, "Combat indicator")
    checks[#checks + 1] = CreateCheck(pages[2], "MinnTinkersWoWFCombat_enabled", y, false,
        "Persistent red edge glow", "Glows red around the edge of your screen while you're in combat.",
        function() return MinnTinkersWoWFDB.combatIndicator.enabled end,
        function(value) addon.CombatIndicator.SetOption("enabled", value) end)
    local combatOpacity = CreateSlider(pages[2], "MinnTinkersWoWFCombat_opacity", y + rowSpacing, {
        label = "Opacity", min = 5, max = 60, step = 1,
        getValue = addon.CombatIndicator.GetOpacity,
        setValue = function(value) addon.CombatIndicator.SetOption("opacity", value) end,
        format = function(value) return string.format("%d%%", value) end,
        tooltip = "Sets how visible the combat glow is.",
    })
    local combatWidth = CreateSlider(pages[2], "MinnTinkersWoWFCombat_width", y + rowSpacing * 2, {
        label = "Border width", min = 8, max = 48, step = 1,
        getValue = addon.CombatIndicator.GetWidth,
        setValue = function(value) addon.CombatIndicator.SetOption("width", value) end,
        format = function(value) return string.format("%d", value) end,
        tooltip = "Sets how far the glow extends from the edge of the screen.",
    })
    y = y + rowSpacing * 2 + rowHeight + sectionGap
    local rangeY = CreateSection(pages[2], y, "Range indicator")
    local range = addon.RangeIndicator
    local rangeEnabled = CreateCheck(pages[2], "MinnTinkersWoWFRangeEnabled", rangeY, false,
        "Show range indicator", "Shows a dot for your chosen spell. It turns red when your target is out of range.",
        function() return range.GetSettings().enabled end, range.SetEnabled, range.IsAvailable)
    local rangeUnlocked = CreateCheck(pages[2], "MinnTinkersWoWFRangeUnlocked", rangeY, true,
        "Unlock position", "Drag the dot to move it, even without a target.",
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
    spellInput:SetFontObject("GameFontHighlightSmall")
    spellInput:SetAutoFocus(false)
    spellInput:SetMaxLetters(128)
    spellInput:SetHeight(20)
    spellInput:SetPoint("TOPLEFT", 58, -(rangeY + rowSpacing + 4))
    spellInput:SetPoint("TOPRIGHT", -196, -(rangeY + rowSpacing + 4))
    local selectSpell = CreateFrame("Button", "MinnTinkersWoWFRangeSelectSpell", pages[2], "SharedButtonSmallTemplate")
    selectSpell:SetWidth(80)
    selectSpell:SetPoint("TOPRIGHT", -104, -(rangeY + rowSpacing))
    selectSpell:SetText("Select")
    local clearSpell = CreateFrame("Button", "MinnTinkersWoWFRangeClearSpell", pages[2], "SharedButtonSmallTemplate")
    clearSpell:SetWidth(80)
    clearSpell:SetPoint("TOPRIGHT", -16, -(rangeY + rowSpacing))
    clearSpell:SetText("Clear")
    local rangeStatus = pages[2]:CreateFontString("MinnTinkersWoWFRangeStatus", "OVERLAY", "GameFontHighlightSmall2")
    rangeStatus:SetPoint("TOPLEFT", 16, -(rangeY + rowSpacing * 2 + 6))
    rangeStatus:SetPoint("TOPRIGHT", -16, -(rangeY + rowSpacing * 2 + 6))
    rangeStatus:SetJustifyH("LEFT")
    rangeStatus:SetMaxLines(1)
    local rangeSize = CreateSlider(pages[2], "MinnTinkersWoWFRangeSize", rangeY + rowSpacing * 3, {
        label = "Indicator size", min = 8, max = 96, step = 1,
        getValue = function() return range.GetSettings().size end,
        setValue = range.SetSize, isAvailable = range.IsAvailable,
        format = function(value) return string.format("%d", value) end,
        tooltip = "Sets how big the dot is.",
    })
    local rangeOpacity = CreateSlider(pages[2], "MinnTinkersWoWFRangeOpacity", rangeY + rowSpacing * 4, {
        label = "Indicator opacity", min = 10, max = 100, step = 1,
        getValue = function() return range.GetSettings().opacity end,
        setValue = range.SetOpacity, isAvailable = range.IsAvailable,
        format = function(value) return string.format("%d%%", value) end,
        tooltip = "Sets how visible the dot is.",
    })
    local rangeClassColor = CreateCheck(pages[2], "MinnTinkersWoWFRangeClassColor", rangeY + rowSpacing * 5, true,
        "Use class color", "Use your class color for the in-range dot. Turn it off for white.",
        function() return range.GetSettings().useClassColor end, range.SetClassColor, range.IsAvailable)
    checks[#checks + 1] = rangeClassColor
    local resetRange = CreateFrame("Button", "MinnTinkersWoWFRangeResetPosition", pages[2], "SharedButtonSmallTemplate")
    resetRange:SetWidth(120)
    resetRange:SetPoint("TOPLEFT", 16, -(rangeY + rowSpacing * 5))
    resetRange:SetText("Reset position")
    resetRange:SetScript("OnClick", range.ResetPosition)

    local barY = CreateSection(pages[2], rangeY + rowSpacing * 5 + rowHeight + sectionGap, "Bar visibility")
    local barVisibility = addon.BarVisibility
    for index, option in ipairs({
        { key = "hideBagBar", label = "Hide bag bar", tooltip = "Hides the bag buttons. Your bag keybinds still work." },
        { key = "hideMicroBar", label = "Hide microbar", tooltip = "Hides the character, spellbook, and other menu buttons." },
    }) do
        local key = option.key
        checks[#checks + 1] = CreateCheck(pages[2], "MinnTinkersWoWF_" .. key, barY, index == 2, option.label,
            option.tooltip .. " Changes made in combat apply afterward.",
            function() return barVisibility.GetHidden(key) end,
            function(value) barVisibility.SetHidden(key, value) end,
            function() return barVisibility.IsAvailable(key) end)
    end

    local function RefreshRangeOptions()
        local available = range.IsAvailable()
        local info = range.GetSpellInfo()
        rangeEnabled:Refresh(); rangeUnlocked:Refresh(); rangeSize:Refresh(); rangeOpacity:Refresh(); rangeClassColor:Refresh()
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
        if not canaccessallvalues(kind, id) or kind ~= "spell" then
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
        GameTooltip:AddLine("Drop a spell from your spellbook here, or type its name and press Enter.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    local function HideSpellTooltip(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    spellSlot:HookScript("OnLeave", HideSpellTooltip)
    spellSlot:HookScript("OnHide", HideSpellTooltip)
    y = CreateSection(pages[3], 16, "Chat input")
    for index, option in ipairs({
        {key = "preserveDraft", label = "Keep unfinished messages", tooltip = "Press Esc to leave chat. Your draft is there when you open it again."},
        {key = "arrowHistory", label = "Up/Down message history", tooltip = "Press Up or Down to revisit recent messages. Type commands like /target directly."},
    }) do
        local key = option.key
        checks[#checks + 1] = CreateCheck(pages[3], "MinnTinkersWoWFChat_" .. key, y, index == 2,
            option.label, option.tooltip, function() return MinnTinkersWoWFDB.chat[key] end,
            function(value) addon.ChatInput.SetOption(key, value) end, addon.ChatInput.IsAvailable)
    end
    y = CreateSection(pages[3], y + rowHeight + sectionGap, "Chat tools")
    checks[#checks + 1] = CreateCheck(pages[3], "MinnTinkersWoWFChatURLs", y, false,
        "Clickable chat URLs", "Click a web address in chat, then press Ctrl+C to copy it.",
        function() return MinnTinkersWoWFDB.chatURLs end, addon.ChatURLs.SetEnabled, addon.ChatURLs.IsAvailable)
    checks[#checks + 1] = CreateCheck(pages[3], "MinnTinkersWoWFChat_copyChat", y, true,
        "Copy chat button", "Click the button beside chat, then use Ctrl+A and Ctrl+C to copy messages.",
        function() return MinnTinkersWoWFDB.chat.copyChat end,
        function(value) addon.ChatTools.SetOption("copyChat", value) end, addon.ChatTools.IsAvailable)
    checks[#checks + 1] = CreateCheck(pages[3], "MinnTinkersWoWFChat_unreadMarker", y + rowSpacing, false,
        "New-message glow", "Pulses in your class color when new messages arrive while you're scrolled up.",
        function() return MinnTinkersWoWFDB.chat.unreadMarker end,
        function(value) addon.ChatTools.SetOption("unreadMarker", value) end, addon.ChatTools.IsAvailable)
    checks[#checks + 1] = CreateCheck(pages[3], "MinnTinkersWoWFChat_saveHistory", y + rowSpacing, true,
        "Save chat history", "Keeps recent chat after a reload or logout.",
        function() return MinnTinkersWoWFDB.chat.saveHistory end,
        addon.ChatHistory.SetEnabled, addon.ChatHistory.IsAvailable)
    y = CreateSection(pages[3], y + rowSpacing + rowHeight + sectionGap, "Appearance")
    checks[#checks + 1] = CreateCheck(pages[3], "MinnTinkersWoWFChat_enhancedShadow", y, false,
        "Enhanced chat shadow", "Adds a slightly larger shadow to chat text.",
        function() return MinnTinkersWoWFDB.chat.enhancedShadow end,
        addon.ChatShadow.SetEnabled, addon.ChatShadow.IsAvailable)
    y = CreateSection(pages[3], y + rowHeight + sectionGap, "Timestamps")
    local timestamps = CreateFrame("DropdownButton", "MinnTinkersWoWFChatTimestamps", pages[3], "WowStyle1DropdownTemplate")
    timestamps:SetSize(240, rowHeight)
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
        timestamps:OverrideText(label)
        timestamps:SetEnabled(addon.ChatTools.TimestampsAvailable())
    end
    timestamps:SetupMenu(function(_, menu)
        for _, option in ipairs(timestampOptions) do
            local value = option[1]
            if value then menu:CreateRadio(option[2], function() return addon.ChatTools.GetTimestampFormat() == value end,
                function() addon.ChatTools.SetTimestampFormat(value); RefreshTimestamps() end) end
        end
    end)
    local timestampHint = pages[3]:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall2")
    timestampHint:SetPoint("TOPLEFT", 16, -(y + rowSpacing + 6))
    timestampHint:SetText("Applies to new messages.")
    pages[3]:HookScript("OnShow", RefreshTimestamps)
    local RefreshHunterOptions
    if pages[4] then
        RefreshHunterOptions = addon.CreateHunterOptions(pages[4], CreateSection, CreateCheck, CreateSlider, checks)
    end
    window:SetScript("OnShow", function()
        check:Refresh()
        for _, control in ipairs(checks) do control:Refresh() end
        for _, option in ipairs(addon.ActionBarFonts.options) do
            sliders[option.key]:Refresh()
        end
        camera:Refresh()
        grassDensity:Refresh()
        grassDistance:Refresh()
        combatOpacity:Refresh()
        combatWidth:Refresh()
        RefreshRangeOptions()
        RefreshTimestamps()
        if RefreshHunterOptions then RefreshHunterOptions() end
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
        GameTooltip:AddLine("Click or type /minn to open settings. Drag to move the button.", 1, 1, 1)
        GameTooltip:Show()
    end)
    local function HideTooltip(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    button:HookScript("OnLeave", HideTooltip)
    button:HookScript("OnHide", HideTooltip)
end
