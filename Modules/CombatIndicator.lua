local _, addon = ...
local module = {}
addon.CombatIndicator = module
local glow
local edges = {}
local inCombat = false

function module.GetOpacity()
    return math.max(5, math.min(60, tonumber(MinnTinkersWoWFDB.combatIndicator.opacity) or 25))
end

function module.GetWidth()
    return math.max(8, math.min(48, tonumber(MinnTinkersWoWFDB.combatIndicator.width) or 20))
end

function module.Refresh()
    if not glow then return end
    glow:SetAlpha(module.GetOpacity() / 100)
    local width = module.GetWidth()
    for index, edge in ipairs(edges) do
        if index <= 2 then edge:SetHeight(width) else edge:SetWidth(width) end
    end
    glow:SetShown(MinnTinkersWoWFDB.combatIndicator.enabled and inCombat)
end

function module.SetOption(key, value)
    local settings = MinnTinkersWoWFDB.combatIndicator
    if key == "enabled" then
        settings.enabled = value and true or false
    elseif key == "opacity" then
        settings.opacity = math.floor(math.max(5, math.min(60, value)) + 0.5)
    elseif key == "width" then
        settings.width = math.floor(math.max(8, math.min(48, value)) + 0.5)
    end
    module.Refresh()
end

function module.Initialize()
    glow = CreateFrame("Frame", "MinnTinkersWoWFCombatGlow", UIParent)
    glow:Hide()
    glow:SetAllPoints(UIParent)
    glow:SetFrameStrata("BACKGROUND")
    glow:EnableMouse(false)
    local red, clear = CreateColor(1, 0, 0, 1), CreateColor(1, 0, 0, 0)
    for index, spec in ipairs({
        { "TOP", "VERTICAL", clear, red },
        { "BOTTOM", "VERTICAL", red, clear },
        { "LEFT", "HORIZONTAL", red, clear },
        { "RIGHT", "HORIZONTAL", clear, red },
    }) do
        local edge = glow:CreateTexture(nil, "ARTWORK")
        edge:SetColorTexture(1, 1, 1, 1)
        edge:SetGradient(spec[2], spec[3], spec[4])
        if index <= 2 then
            edge:SetPoint(spec[1] .. "LEFT", glow)
            edge:SetPoint(spec[1] .. "RIGHT", glow)
        else
            edge:SetPoint("TOP" .. spec[1], glow)
            edge:SetPoint("BOTTOM" .. spec[1], glow)
        end
        edges[index] = edge
    end
    inCombat = InCombatLockdown()
    module.Refresh()
    glow:RegisterEvent("PLAYER_REGEN_DISABLED")
    glow:RegisterEvent("PLAYER_REGEN_ENABLED")
    glow:SetScript("OnEvent", function(_, event)
        inCombat = event == "PLAYER_REGEN_DISABLED"
        module.Refresh()
    end)
end
