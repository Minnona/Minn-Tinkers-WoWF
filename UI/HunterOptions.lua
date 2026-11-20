local _, addon = ...

function addon.CreateHunterOptions(page, CreateSection, CreateCheck, CreateSlider, checks)
    local rowHeight, rowSpacing, sectionGap = 26, 32, 24
    local y = CreateSection(page, 16, "Pet")
    checks[#checks + 1] = CreateCheck(page, "MinnTinkersWoWFPetHappiness", y, false,
        "Pet happiness bar", "Shows how much happiness your pet has in a bar below its focus.",
        function() return MinnTinkersWoWFDB.petHappinessBar end,
        addon.PetHappinessBar.SetEnabled, addon.PetHappinessBar.IsAvailable)

    y = CreateSection(page, y + rowHeight + sectionGap, "Trueshot Aura")
    local reminder = addon.BuffReminder
    local enabled = CreateCheck(page, "MinnTinkersWoWFBuffReminderEnabled", y, false,
        "Clickable buff reminder", "Click to recast Trueshot Aura when it's missing or has a minute left. Hidden in combat and on flight paths.",
        function() return reminder.GetSettings().enabled end, reminder.SetEnabled, reminder.IsAvailable)
    local unlocked = CreateCheck(page, "MinnTinkersWoWFBuffReminderUnlocked", y, true,
        "Unlock position", "Right-drag the reminder to move it. Left-click still casts the buff.",
        function() return not reminder.GetSettings().locked end,
        function(value) reminder.SetLocked(not value) end, reminder.IsAvailable)
    checks[#checks + 1], checks[#checks + 2] = enabled, unlocked
    local size = CreateSlider(page, "MinnTinkersWoWFBuffReminderSize", y + rowSpacing, {
        label = "Button size", min = 24, max = 96, step = 1,
        getValue = function() return reminder.GetSettings().size end,
        setValue = reminder.SetSize, isAvailable = reminder.IsAvailable,
        format = function(value) return string.format("%d", value) end,
        tooltip = "Sets the size of the reminder. Changes made in combat apply afterward.",
    })
    local reset = CreateFrame("Button", "MinnTinkersWoWFBuffReminderReset", page, "SharedButtonSmallTemplate")
    reset:SetWidth(120)
    reset:SetPoint("TOPLEFT", 16, -(y + rowSpacing * 2))
    reset:SetText("Reset position")
    reset:SetScript("OnClick", reminder.ResetPosition)
    local function Refresh()
        enabled:Refresh()
        unlocked:Refresh()
        size:Refresh()
        reset:SetEnabled(reminder.IsAvailable())
    end
    page:HookScript("OnShow", Refresh)
    reminder.OnSettingsChanged = function()
        if page:IsShown() then Refresh() end
    end
    return Refresh
end
