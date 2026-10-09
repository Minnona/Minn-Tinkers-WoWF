local _, addon = ...
local module = {}
addon.PetHappinessBar = module
local frame, icon, iconAlpha, mask
local borders = {}
local fills, viewports = {}, {}
local replacingIcon = false

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
    if not canaccessvalue(shown, hunterPet) or not shown or not hunterPet then RestoreIcon(); return end
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

local function UpdateBorder()
    for _, border in ipairs(borders) do border:SetAlpha(0) end
    local atlas = PetFrameTexture:GetAtlas()
    if not canaccessvalue(atlas) or not atlas then return end
    local info = C_Texture.GetAtlasInfo(atlas)
    if not info then return end
    local x, y, width, height = PetFrameTexture:GetRect()
    local barX, barY, barWidth, barHeight = PetFrameManaBar:GetRect()
    local left, right = info.leftTexCoord, info.rightTexCoord
    local top, bottom = info.topTexCoord, info.bottomTexCoord
    if not canaccessvalue(x, y, width, height, barX, barY, barWidth, barHeight, left, right, top, bottom)
        or not x or not barX or width <= 0 or height <= 0 then return end
    -- Use the native focus-bar trim. Atlas coordinates identify its actual image in the sheet.
    local capRight = left + (right - left) * (barX + barWidth + 4 - x) / width
    local capLeft = capRight - (right - left) * 8 / width
    local middleLeft = capLeft - (right - left) * 4 / width
    local trimTop = top + (bottom - top) * (y + height - barY - barHeight - 2) / height
    local trimBottom = top + (bottom - top) * (y + height - barY + 4) / height
    for _, border in ipairs(borders) do border:SetTexture(info.file or info.filename) end
    -- Mirror the clean end cap at the left, avoiding the portrait join in the original artwork.
    borders[1]:SetTexCoord(capRight, capLeft, trimTop, trimBottom)
    borders[2]:SetTexCoord(middleLeft, capLeft, trimTop, trimBottom)
    borders[3]:SetTexCoord(capLeft, capRight, trimTop, trimBottom)
    for _, border in ipairs(borders) do border:SetAlpha(1) end
end

local function Layout(self, width)
    if not canaccessvalue(width) or type(width) ~= "number" or width <= 4 then return end
    local innerWidth = width - 4
    if mask then
        -- Match Blizzard's 84x7 visible window inside the full 128x16 mask canvas.
        mask:ClearAllPoints()
        mask:SetPoint("TOPLEFT", self, "TOPLEFT", 2 - innerWidth * 21 / 84, 3)
        mask:SetSize(innerWidth * 128 / 84, 16)
    end
    for index, viewport in ipairs(viewports) do
        local offset = (index - 1) * innerWidth / 3
        viewport:ClearAllPoints()
        viewport:SetPoint("TOPLEFT", self, "TOPLEFT", 2 + offset, -2)
        -- One-pixel gaps divide the fixed color zones, independently of the protected fill.
        viewport:SetSize(innerWidth / 3 - (index < 3 and 1 or 0), 7)
        fills[index]:ClearAllPoints()
        fills[index]:SetPoint("TOPLEFT", viewport, "TOPLEFT", -offset, 0)
        fills[index]:SetSize(innerWidth, 7)
    end
    UpdateBorder()
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
    if not (PetFrame and PetFrameTexture and PetFrameManaBar and PetFrameHappiness and PetFrameHappiness.Texture
        and PetFrameHappiness.OnEnter and HasPetUI and UnitPower and UnitPowerMax
        and C_Texture and C_Texture.GetAtlasInfo
        and Enum.PowerType and Enum.PowerType.Happiness and type(canaccessvalue) == "function") then return end
    icon = PetFrameHappiness
    iconAlpha = icon.Texture:GetAlpha()
    frame = CreateFrame("Frame", "MinnTinkersWoWFPetHappinessBar", PetFrame)
    frame:SetAlpha(0)
    frame:SetPoint("TOPLEFT", PetFrameManaBar, "BOTTOMLEFT", 0, -2)
    frame:SetPoint("TOPRIGHT", PetFrameManaBar, "BOTTOMRIGHT", 0, -2)
    frame:SetHeight(11)
    -- Use the standalone bar mask; its padded canvas is larger than the visible bar.
    local maskAtlas = "UI-HUD-UnitFrame-Party-PortraitOff-Bar-Mana-Mask"
    if C_Texture.GetAtlasInfo(maskAtlas) then
        mask = frame:CreateMaskTexture(nil, "ARTWORK")
        mask:SetAtlas(maskAtlas, false, nil, true, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    for index, color in ipairs({{0.9, 0.15, 0.1}, {1, 0.72, 0.08}, {0.15, 0.8, 0.25}}) do
        local viewport = CreateFrame("Frame", nil, frame)
        viewport:SetClipsChildren(true)
        local background = viewport:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(color[1] * 0.15, color[2] * 0.15, color[3] * 0.15, 1)
        local fill = CreateFrame("StatusBar", "MinnTinkersWoWFPetHappinessFill" .. index, viewport)
        fill:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        fill:SetStatusBarColor(color[1], color[2], color[3])
        if mask then
            background:AddMaskTexture(mask)
            fill:GetStatusBarTexture():AddMaskTexture(mask)
        end
        viewports[index], fills[index] = viewport, fill
    end
    -- Keep the full native corner/shadow padding outside the fill; no rectangular backdrop.
    for index = 1, 3 do borders[index] = frame:CreateTexture(nil, "BORDER") end
    borders[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 0)
    borders[1]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -2, -2)
    borders[1]:SetWidth(8)
    borders[3]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 0)
    borders[3]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
    borders[3]:SetWidth(8)
    borders[2]:SetPoint("TOPLEFT", borders[1], "TOPRIGHT")
    borders[2]:SetPoint("BOTTOMRIGHT", borders[3], "BOTTOMLEFT")
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
            if not canaccessvalue(unit, powerType) or unit ~= "pet" or powerType ~= "HAPPINESS" then return end
        elseif event == "UNIT_HAPPINESS" then
            if not canaccessvalue(unit) or unit ~= "pet" then return end
        elseif event == "UNIT_PET" then
            if not canaccessvalue(unit) or unit ~= "player" then return end
        end
        Refresh()
    end)
    -- Only the icon's texture changes; Blizzard retains control of the pet frame's visibility.
    PetFrame:HookScript("OnShow", function() UpdateBorder(); Refresh() end)
    module.SetEnabled(MinnTinkersWoWFDB.petHappinessBar)
end
