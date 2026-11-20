local _, addon = ...
local module = {}
addon.BarVisibility = module

local bars = {}
local events = CreateFrame("Frame")

function module.GetHidden(key)
    return MinnTinkersWoWFDB[key] == true
end

local function Apply(key, bar)
    local show = not module.GetHidden(key)
    if show and not bar.hiddenByAddon then return end

    local frame = bar.frame
    if InCombatLockdown() and frame:IsProtected() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local shown = frame:IsShown()
    if not canaccessvalue(shown) then return end
    if shown == show then
        if show then bar.hiddenByAddon = nil end
        return
    end
    bar.hiddenByAddon = not show
    frame:SetShown(show)
end

local function Attach(key, frame)
    if not frame or bars[key] then return end
    local bar = { frame = frame }
    bars[key] = bar
    frame:HookScript("OnShow", function() Apply(key, bar) end)
    Apply(key, bar)
end

function module.Initialize()
    if not canaccessvalue then return end
    Attach("hideBagBar", BagsBar)
    Attach("hideMicroBar", MicroMenu)
end

function module.IsAvailable(key)
    return bars[key] ~= nil
end

function module.SetHidden(key, value)
    MinnTinkersWoWFDB[key] = value and true or false
    if bars[key] then Apply(key, bars[key]) end
end

events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    for key, bar in pairs(bars) do Apply(key, bar) end
end)
