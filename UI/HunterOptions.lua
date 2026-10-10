local _, addon = ...

function addon.CreateHunterOptions(page, CreateSection, CreateCheck, CreateSlider, IncreaseFont, checks)
    local rowHeight, rowSpacing, sectionGap = 26, 32, 24
    local y = CreateSection(page, 16, "Pet")
    checks[#checks + 1] = CreateCheck(page, "MinnTinkersWoWFPetHappiness", y, false,
        "Pet happiness bar", "Replaces the hunter pet's happiness face with a thin red/yellow/green meter below its focus bar. The fill shows happiness reserve; the colored thirds are visual guides. Mouseover retains Blizzard's happiness, damage bonus and diet tooltip.",
        function() return MinnTinkersWoWFDB.petHappinessBar end,
        addon.PetHappinessBar.SetEnabled, addon.PetHappinessBar.IsAvailable)

    y = CreateSection(page, y + rowHeight + sectionGap, "Trueshot Aura")
    local reminder = addon.BuffReminder
    local enabled = CreateCheck(page, "MinnTinkersWoWFBuffReminderEnabled", y, false,
        "Clickable buff reminder", "Shows a native spell button when Trueshot Aura is missing or has one minute or less remaining. Left-click to buff yourself. Hides after the aura refreshes. No sound. Hidden in combat and during flight paths; rechecks afterward. Saved per character.",
        function() return reminder.GetSettings().enabled end, reminder.SetEnabled, reminder.IsAvailable)
    local unlocked = CreateCheck(page, "MinnTinkersWoWFBuffReminderUnlocked", y, true,
        "Unlock position", "Shows a preview while enabled and the spell is learned. Right-drag the reminder to move it; left-click still buffs. Position changes and resizing made in combat apply after combat.",
        function() return not reminder.GetSettings().locked end,
        function(value) reminder.SetLocked(not value) end, reminder.IsAvailable)
    checks[#checks + 1], checks[#checks + 2] = enabled, unlocked
    local size = CreateSlider(page, "MinnTinkersWoWFBuffReminderSize", y + rowSpacing, {
        label = "Button size", min = 24, max = 96, step = 1,
        getValue = function() return reminder.GetSettings().size end,
        setValue = reminder.SetSize, isAvailable = reminder.IsAvailable,
        format = function(value) return string.format("%d", value) end,
        tooltip = "Resizes the native buff button. Changes made in combat apply after combat. Saved per character.",
    })
    local reset = CreateFrame("Button", "MinnTinkersWoWFBuffReminderReset", page, "UIPanelButtonTemplate")
    reset:SetSize(120, rowHeight)
    reset:SetPoint("TOPLEFT", 16, -(y + rowSpacing * 2))
    IncreaseFont(reset:GetFontString())
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
