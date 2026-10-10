local _, addon = ...
local module = {}
addon.BuffReminder = module
local button, events, spell, seedSpell, timer, timerExpiration, spellDirty

function module.GetSettings()
    return MinnTinkersWoWFCharDB.buffReminder
end

function module.IsAvailable()
    return button ~= nil
end

local function NotifySettings()
    if module.OnSettingsChanged then module.OnSettingsChanged() end
end

local function CancelTimer()
    if timer then timer:Cancel() end
    timer, timerExpiration = nil, nil
end

local function PlaceButton()
    local settings = module.GetSettings()
    local xLimit = math.max(0, (UIParent:GetWidth() - settings.size) / 2)
    local yLimit = math.max(0, (UIParent:GetHeight() - settings.size) / 2)
    settings.x = math.max(-xLimit, math.min(xLimit, settings.x))
    settings.y = math.max(-yLimit, math.min(yLimit, settings.y))
    button:ClearAllPoints()
    button:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
end

local function Refresh()
    -- Visibility, spell attributes and geometry of a secure button cannot change here in combat.
    if not button or InCombatLockdown() then return end
    local onTaxi = UnitOnTaxi("player")
    if not canaccessvalue(onTaxi) or onTaxi then
        CancelTimer()
        if button:IsShown() then button:Hide() end
        return
    end
    local settings = module.GetSettings()
    local wanted = false
    local expiration
    if settings.enabled and spell then
        local aura = C_UnitAuras.GetAuraDataBySpellName("player", spell.name, "HELPFUL")
        if canaccessvalue(aura) then
            if not aura then
                wanted = true
            elseif canaccessvalue(aura.expirationTime) and type(aura.expirationTime) == "number" then
                expiration = aura.expirationTime
                if expiration > 0 then wanted = expiration - GetTime() <= 60 end
            end
        end
    end
    if expiration and expiration > GetTime() + 60 then
        if timerExpiration ~= expiration then
            CancelTimer()
            timerExpiration = expiration
            timer = C_Timer.NewTimer(expiration - GetTime() - 60, function()
                timer, timerExpiration = nil, nil
                Refresh()
            end)
        end
    else
        CancelTimer()
    end
    local show = settings.enabled and spell ~= nil and (wanted or not settings.locked)
    if button:IsShown() ~= show then
        if show then button:SetAttribute("statehidden", nil) end
        button:SetShown(show)
    end
end

local function ResolveSpell()
    if InCombatLockdown() then return end
    spell = nil
    local base = C_Spell.GetSpellInfo(seedSpell)
    if base and canaccessvalue(base.name) then
        -- Read the actual learned rank from the spellbook, using the localized base name.
        local bank = Enum.SpellBookSpellBank.Player
        for lineIndex = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local line = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)
            if line then
                for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                    if item and canaccessvalue(item.name, item.spellID, item.itemType, item.isOffSpec)
                        and item.itemType == Enum.SpellBookItemType.Spell and not item.isOffSpec and item.name == base.name then
                        local passive = C_Spell.IsSpellPassive(item.spellID)
                        local known = C_SpellBook.IsSpellKnown(item.spellID)
                        if canaccessvalue(passive, known) and not passive and known then
                            spell = C_Spell.GetSpellInfo(item.spellID)
                        end
                    end
                end
            end
        end
    end
    button:SetAttribute("spell1", spell and spell.spellID or nil)
    button.icon:SetTexture(spell and spell.iconID or "Interface\\Icons\\INV_Misc_QuestionMark")
end

local function ApplySettings()
    if not button or InCombatLockdown() then return end
    button:StopMovingOrSizing()
    button:SetSize(module.GetSettings().size, module.GetSettings().size)
    PlaceButton()
    Refresh()
end

function module.SetEnabled(value)
    module.GetSettings().enabled = value and true or false
    if not value then CancelTimer() end
    ApplySettings()
    NotifySettings()
end

function module.SetLocked(value)
    module.GetSettings().locked = value and true or false
    ApplySettings()
    NotifySettings()
end

function module.SetSize(value)
    module.GetSettings().size = math.floor(math.max(24, math.min(96, value)) + 0.5)
    ApplySettings()
    NotifySettings()
end

function module.ResetPosition()
    local settings = module.GetSettings()
    settings.x, settings.y = 0, 0
    ApplySettings()
    NotifySettings()
end

function module.Initialize(spellID)
    if button then return end
    local settings = module.GetSettings()
    if settings.enabled == nil then settings.enabled = true end
    if settings.locked == nil then settings.locked = true end
    for key, fallback in pairs({size = 48, x = 0, y = 0}) do
        local value = tonumber(settings[key])
        settings[key] = value and value == value and math.abs(value) < math.huge and value or fallback
    end
    settings.size = math.floor(math.max(24, math.min(96, settings.size)) + 0.5)
    if not (C_Spell and C_Spell.GetSpellInfo and C_Spell.IsSpellPassive and C_SpellBook
        and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo
        and C_SpellBook.GetSpellBookItemInfo and C_SpellBook.IsSpellKnown
        and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName and C_Timer and C_Timer.NewTimer
        and Enum.SpellBookSpellBank and Enum.SpellBookItemType and canaccessvalue and RegisterStateDriver and UnitOnTaxi) then return end
    if InCombatLockdown() then
        events = events or CreateFrame("Frame")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            module.Initialize(spellID)
            NotifySettings()
        end)
        return
    end
    seedSpell = spellID
    button = CreateFrame("Button", "MinnTinkersWoWFBuffReminder", UIParent, "SecureActionButtonTemplate")
    button:Hide()
    button:SetFrameStrata("HIGH")
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    button:RegisterForDrag("RightButton")
    button:SetAttribute("type1", "spell")
    button:SetAttribute("unit", "player")
    button:SetAttribute("useOnKeyDown", false)
    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetPoint("TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    local mask = button:CreateMaskTexture(nil, "BACKGROUND")
    mask:SetAtlas("SquareMask")
    mask:SetAllPoints(button.icon)
    button.icon:AddMaskTexture(mask)
    -- Use the same square border, press and hover atlases as Forever's native action bars.
    button:SetNormalAtlas("gamepad-actionbar-squareslot-border-normal")
    button:SetPushedAtlas("gamepad-actionbar-squareslot-border-pressed")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button:GetHighlightTexture():SetAtlas("gamepad-actionbar-squareslot-border-hover")
    button:SetScript("OnEnter", function(self)
        if not spell then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(spell.spellID)
        GameTooltip:AddLine("Left-click to buff. Right-drag while position is unlocked.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    local function HideTooltip(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    button:SetScript("OnLeave", HideTooltip)
    button:HookScript("OnHide", HideTooltip)
    button:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() and not module.GetSettings().locked then self:StartMoving() end
    end)
    button:SetScript("OnDragStop", function(self)
        if InCombatLockdown() then return end
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        if x and y and parentX and parentY then
            settings.x, settings.y = x - parentX, y - parentY
            PlaceButton()
        end
    end)
    -- No fallback "show": leaving combat must wait for a fresh aura check.
    RegisterStateDriver(button, "visibility", "[combat] hide")
    events = events or CreateFrame("Frame")
    events:RegisterUnitEvent("UNIT_AURA", "player")
    events:RegisterUnitEvent("UNIT_FLAGS", "player")
    for _, event in ipairs({"SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
        "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "SPELLS_CHANGED" then spellDirty = true end
        if event == "PLAYER_REGEN_DISABLED" then
            CancelTimer()
        elseif event == "UNIT_AURA" or event == "UNIT_FLAGS" then
            if canaccessvalue(unit) and unit == "player" then Refresh() end
        elseif event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" then
            Refresh()
        elseif not InCombatLockdown() then
            if spellDirty or event == "PLAYER_ENTERING_WORLD" then
                ResolveSpell()
                spellDirty = false
            end
            ApplySettings()
        end
    end)
    ResolveSpell()
    ApplySettings()
end
