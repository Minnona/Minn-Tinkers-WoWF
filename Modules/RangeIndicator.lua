local _, addon = ...
local module = {}
addon.RangeIndicator = module
local indicator, circle, activeSpell, inRange
local initialized = false
local classR, classG, classB = 1, 1, 1

function module.GetSettings()
    return MinnTinkersWoWFCharDB.rangeIndicator
end

function module.IsAvailable()
    return initialized
end

local function NotifySettings()
    if module.OnSettingsChanged then module.OnSettingsChanged() end
end

local function CanTrack(spellID)
    if not canaccessvalue(spellID) or type(spellID) ~= "number" or spellID <= 0 then return false end
    local known = C_SpellBook.IsSpellKnown(spellID)
    local passive = C_Spell.IsSpellPassive(spellID)
    local hasRange = C_Spell.SpellHasRange(spellID)
    return canaccessvalue(known, passive, hasRange) and known == true and not passive and hasRange == true
end

function module.GetSpellInfo()
    local id = module.GetSettings().spellID
    return initialized and type(id) == "number" and id > 0 and C_Spell.GetSpellInfo(id) or nil
end

local function RefreshDisplay()
    local settings = module.GetSettings()
    if inRange == nil then
        circle:SetTextColor(0.65, 0.65, 0.65)
    elseif inRange then
        if settings.useClassColor then
            circle:SetTextColor(classR, classG, classB)
        else
            circle:SetTextColor(1, 1, 1)
        end
    else
        circle:SetTextColor(1, 0.15, 0.15)
    end
    indicator:EnableMouse(not settings.locked)
    indicator:SetFrameStrata(settings.locked and "HIGH" or "TOOLTIP")
    indicator:SetShown(settings.enabled and (inRange ~= nil or not settings.locked))
end

local function SetRange(value, checksRange)
    -- An invalid or restricted check must never appear as "in range".
    if not canaccessvalue(value, checksRange) or not checksRange or type(value) ~= "boolean" then value = nil end
    if value ~= inRange then
        inRange = value
        RefreshDisplay()
    end
end

local function RefreshRange()
    if activeSpell then
        SetRange(C_Spell.IsSpellInRange(activeSpell, "target"), true)
    else
        SetRange(nil, false)
    end
end

local function PlaceIndicator()
    local settings = module.GetSettings()
    local xLimit = math.max(0, (UIParent:GetWidth() - settings.size) / 2)
    local yLimit = math.max(0, (UIParent:GetHeight() - settings.size) / 2)
    settings.x = math.max(-xLimit, math.min(xLimit, settings.x))
    settings.y = math.max(-yLimit, math.min(yLimit, settings.y))
    indicator:ClearAllPoints()
    indicator:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
end

local function SavePosition()
    indicator:StopMovingOrSizing()
    local x, y = indicator:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if x and y and parentX and parentY then
        local settings = module.GetSettings()
        settings.x, settings.y = x - parentX, y - parentY
        PlaceIndicator()
    end
end

local function RefreshTracking()
    local settings = module.GetSettings()
    local wanted = settings.enabled and CanTrack(settings.spellID) and settings.spellID or nil
    if wanted ~= activeSpell then
        local previous = activeSpell
        activeSpell, inRange = nil, nil
        indicator:UnregisterEvent("SPELL_RANGE_CHECK_UPDATE")
        if previous then C_Spell.EnableSpellRangeCheck(previous, false) end
        activeSpell = wanted
        if wanted then
            indicator:RegisterEvent("SPELL_RANGE_CHECK_UPDATE")
            C_Spell.EnableSpellRangeCheck(wanted, true)
        end
    end
    RefreshRange()
    RefreshDisplay()
end

function module.SelectSpell(spellID)
    if not initialized then return false, "Range checking is unavailable in this client." end
    if not CanTrack(spellID) then return false, "Choose a learned, active spell with a range check." end
    module.GetSettings().spellID = spellID
    RefreshTracking()
    NotifySettings()
    return true
end

function module.ClearSpell()
    module.GetSettings().spellID = nil
    if initialized then RefreshTracking() end
    NotifySettings()
end

function module.FindSpells(text)
    if not initialized then return {} end
    local query = text:lower():gsub("[%s()]", "")
    if query == "" then return {} end
    local exact, partial, seen = {}, {}, {}
    local bank = Enum.SpellBookSpellBank.Player
    for lineIndex = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)
        if line then
            for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                if item and item.itemType == Enum.SpellBookItemType.Spell and not item.isOffSpec
                    and not seen[item.spellID] and CanTrack(item.spellID) then
                    seen[item.spellID] = true
                    local name = item.name:lower():gsub("%s+", "")
                    local ranked = (item.name .. item.subName):lower():gsub("[%s()]", "")
                    local match = { spellID = item.spellID, name = item.name, subName = item.subName }
                    if name == query or ranked == query then
                        exact[#exact + 1] = match
                    elseif name:find(query, 1, true) then
                        partial[#partial + 1] = match
                    end
                end
            end
        end
    end
    return #exact > 0 and exact or partial
end

function module.SetEnabled(value)
    module.GetSettings().enabled = value and true or false
    if initialized then
        indicator:StopMovingOrSizing()
        RefreshTracking()
    end
    NotifySettings()
end

function module.SetLocked(value)
    if indicator then SavePosition() end
    module.GetSettings().locked = value and true or false
    if initialized then RefreshDisplay() end
    NotifySettings()
end

function module.SetSize(value)
    local settings = module.GetSettings()
    settings.size = math.floor(math.max(8, math.min(96, value)) + 0.5)
    if initialized then
        indicator:StopMovingOrSizing()
        indicator:SetSize(settings.size, settings.size)
        circle:SetFontHeight(settings.size)
        PlaceIndicator()
    end
    NotifySettings()
end

function module.SetOpacity(value)
    local settings = module.GetSettings()
    settings.opacity = math.floor(math.max(10, math.min(100, value)) + 0.5)
    if initialized then indicator:SetAlpha(settings.opacity / 100) end
    NotifySettings()
end

function module.SetClassColor(value)
    module.GetSettings().useClassColor = value and true or false
    if initialized then RefreshDisplay() end
    NotifySettings()
end

function module.ResetPosition()
    local settings = module.GetSettings()
    settings.x, settings.y = 0, -120
    if initialized then
        indicator:StopMovingOrSizing()
        PlaceIndicator()
    end
    NotifySettings()
end

function module.Initialize()
    if initialized then return end
    local settings = module.GetSettings()
    for key, value in pairs({enabled = true, locked = true, useClassColor = false, size = 24, opacity = 100, x = 0, y = -120}) do
        if settings[key] == nil then settings[key] = value end
    end
    for key, fallback in pairs({size = 24, opacity = 100, x = 0, y = -120}) do
        local value = tonumber(settings[key])
        settings[key] = value and value == value and math.abs(value) < math.huge and value or fallback
    end
    settings.size = math.floor(math.max(8, math.min(96, settings.size)) + 0.5)
    settings.opacity = math.floor(math.max(10, math.min(100, settings.opacity)) + 0.5)
    if not (C_Spell and C_Spell.EnableSpellRangeCheck and C_Spell.IsSpellInRange and C_Spell.SpellHasRange
        and C_Spell.IsSpellPassive and C_Spell.GetSpellInfo and C_SpellBook and C_SpellBook.IsSpellKnown
        and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo
        and C_SpellBook.GetSpellBookItemInfo and Enum.SpellBookSpellBank and Enum.SpellBookItemType
        and type(canaccessvalue) == "function" and GetCursorInfo and ClearCursor
        and MenuUtil and MenuUtil.CreateContextMenu) then return end
    settings.useClassColor = settings.useClassColor == true
    if C_ClassColor and C_ClassColor.GetClassColor then
        local _, class = UnitClass("player")
        if canaccessvalue(class) and class then
            local color = C_ClassColor.GetClassColor(class)
            if color then
                local r, g, b = color:GetRGB()
                if canaccessvalue(r, g, b) then classR, classG, classB = r, g, b end
            end
        end
    end
    indicator = CreateFrame("Frame", "MinnTinkersWoWFRangeIndicator", UIParent)
    indicator:Hide()
    indicator:SetFrameStrata("HIGH")
    indicator:SetFrameLevel(100)
    indicator:SetMovable(true)
    indicator:SetClampedToScreen(true)
    indicator:RegisterForDrag("LeftButton")
    circle = indicator:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    circle:SetPoint("CENTER")
    circle:SetText("●")
    indicator:SetScript("OnDragStart", function(self)
        if not module.GetSettings().locked then self:StartMoving() end
    end)
    indicator:SetScript("OnDragStop", SavePosition)
    indicator:HookScript("OnHide", indicator.StopMovingOrSizing)
    indicator:SetScript("OnEvent", function(_, event, spellID, value, checksRange)
        if event == "SPELL_RANGE_CHECK_UPDATE" then
            if canaccessvalue(spellID) and spellID == activeSpell then SetRange(value, checksRange) end
        elseif event == "PLAYER_TARGET_CHANGED" then
            RefreshRange()
        elseif event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            RefreshTracking()
            NotifySettings()
        else
            indicator:StopMovingOrSizing()
            PlaceIndicator()
        end
    end)
    for _, event in ipairs({"SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
        "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED"}) do indicator:RegisterEvent(event) end
    initialized = true
    module.SetSize(settings.size)
    module.SetOpacity(settings.opacity)
    RefreshTracking()
end
