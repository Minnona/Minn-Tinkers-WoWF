local _, addon = ...
local module = {}
addon.PetHappinessBar = module
local frame, icon, iconAlpha
local fills, viewports = {}, {}
local replacingIcon = false
local stripHeight = 6

function module.IsAvailable()
    return frame ~= nil
end

local function HideTooltip()
    if GameTooltip:IsOwned(icon) then GameTooltip:Hide() end
end

local function RestoreIcon()
    if not replacingIcon then return end
    replacingIcon = false
    frame:SetAlpha(0)
    icon.Texture:SetAlpha(iconAlpha)
    HideTooltip()
end

local function Refresh()
    if not MinnTinkersWoWFDB.petHappinessBar then RestoreIcon(); return end
    local shown = PetFrame:IsShown()
    local _, hunterPet = HasPetUI()
    if not canaccessallvalues(shown, hunterPet) or not shown or not hunterPet then RestoreIcon(); return end
    local maximum = UnitPowerMax("pet", Enum.PowerType.Happiness)
    if canaccessvalue(maximum) and (type(maximum) ~= "number" or maximum <= 0) then RestoreIcon(); return end
    local value = UnitPower("pet", Enum.PowerType.Happiness)
    if canaccessvalue(value) and type(value) ~= "number" then RestoreIcon(); return end
    -- Native bars consume protected values. Never compare, divide or format them in Lua.
    for _, fill in ipairs(fills) do
        fill:SetMinMaxValues(0, maximum)
        fill:SetValue(value)
    end
    if not replacingIcon then
        replacingIcon = true
        frame:SetAlpha(1)
        icon.Texture:SetAlpha(0)
    end
end

local function Layout(self, width)
    if not canaccessvalue(width) or type(width) ~= "number" or width <= 3 then return end
    for index, viewport in ipairs(viewports) do
        local offset = (index - 1) * width / 3
        viewport:ClearAllPoints()
        viewport:SetPoint("TOPLEFT", self, "TOPLEFT", offset, 0)
        -- One-pixel gaps divide the fixed color zones, independently of the protected fill.
        viewport:SetSize(width / 3 - (index < 3 and 1 or 0), stripHeight)
        fills[index]:ClearAllPoints()
        fills[index]:SetPoint("TOPLEFT", viewport, "TOPLEFT", -offset, 0)
        fills[index]:SetSize(width, stripHeight)
    end
end

function module.SetEnabled(value)
    MinnTinkersWoWFDB.petHappinessBar = value and true or false
    if not frame then return end
    frame:UnregisterAllEvents()
    if value then
        for _, event in ipairs({"UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_HAPPINESS"}) do
            frame:RegisterUnitEvent(event, "pet")
        end
        frame:RegisterUnitEvent("UNIT_PET", "player")
        frame:RegisterEvent("PET_UI_UPDATE")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
    Refresh()
end

function module.Initialize()
    if frame then return end
    if not (PetFrame and PetFrameManaBar and PetFrameHappiness and PetFrameHappiness.Texture
        and PetFrameHappiness.OnEnter and HasPetUI and UnitPower and UnitPowerMax
        and Enum.PowerType and Enum.PowerType.Happiness and canaccessvalue and canaccessallvalues) then return end
    icon = PetFrameHappiness
    iconAlpha = icon.Texture:GetAlpha()
    frame = CreateFrame("Frame", "MinnTinkersWoWFPetHappinessBar", PetFrame)
    frame:SetAlpha(0)
    frame:SetPoint("TOPLEFT", PetFrameManaBar, "BOTTOMLEFT", 4, -4)
    frame:SetPoint("TOPRIGHT", PetFrameManaBar, "BOTTOMRIGHT", -4, -4)
    frame:SetHeight(stripHeight)
    local clear, shade = CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.60)
    for index, color in ipairs({{0.9, 0.15, 0.1}, {1, 0.72, 0.08}, {0.15, 0.8, 0.25}}) do
        local viewport = CreateFrame("Frame", nil, frame)
        viewport:SetClipsChildren(true)
        local background = viewport:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(color[1] * 0.15, color[2] * 0.15, color[3] * 0.15, 1)
        local fill = CreateFrame("StatusBar", "MinnTinkersWoWFPetHappinessFill" .. index, viewport)
        fill:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        fill:SetStatusBarColor(color[1], color[2], color[3])
        local gradient = fill:CreateTexture(nil, "OVERLAY")
        -- The fill spans the full strip; each viewport reveals its slice of the same gradient.
        gradient:SetAllPoints()
        gradient:SetColorTexture(1, 1, 1, 1)
        gradient:SetGradient("HORIZONTAL", shade, clear)
        viewports[index], fills[index] = viewport, fill
    end
    frame:HookScript("OnSizeChanged", Layout)
    Layout(frame, frame:GetWidth())
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function()
        if replacingIcon and icon.tooltipData then icon:OnEnter() end
    end)
    frame:SetScript("OnLeave", HideTooltip)
    frame:HookScript("OnHide", HideTooltip)
    frame:SetScript("OnEvent", function(_, event, unit, powerType)
        if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
            if not canaccessallvalues(unit, powerType) or unit ~= "pet" or powerType ~= "HAPPINESS" then return end
        elseif event == "UNIT_HAPPINESS" then
            if not canaccessvalue(unit) or unit ~= "pet" then return end
        elseif event == "UNIT_PET" then
            if not canaccessvalue(unit) or unit ~= "player" then return end
        end
        Refresh()
    end)
    -- Only the icon's texture changes; Blizzard retains control of the pet frame's visibility.
    PetFrame:HookScript("OnShow", Refresh)
    module.SetEnabled(MinnTinkersWoWFDB.petHappinessBar)
end
