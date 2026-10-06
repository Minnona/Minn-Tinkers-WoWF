local _, addon = ...
local module = {}
addon.GossipSkip = module
local events = CreateFrame("Frame")
local attempted = {}
local active, manual = false, false
local initialized, pending

local function CancelPending()
    if pending then pending:Cancel(); pending = nil end
end

function module.SetEnabled(value)
    MinnTinkersWoWFDB.skipSingleGossip = value and true or false
    if not value then CancelPending() end
end

function module.IsAvailable()
    return initialized == true
end

local function SelectSingleOption()
    pending = nil
    if not active or not (GossipFrame and GossipFrame:IsShown()) then return end
    if IsShiftKeyDown() then manual = true end
    if manual or not MinnTinkersWoWFDB.skipSingleGossip then return end
    if #C_GossipInfo.GetAvailableQuests() > 0 or #C_GossipInfo.GetActiveQuests() > 0 then return end
    local options = C_GossipInfo.GetOptions()
    if #options ~= 1 then return end
    local option = options[1]
    local id = option.gossipOptionID
    if not id or option.status ~= Enum.GossipOptionStatus.Available or attempted[id] then return end
    attempted[id] = true
    -- Leave text/payment confirmations to Blizzard; never pass confirmed=true.
    C_GossipInfo.SelectOption(id)
end

local function ScheduleSelection()
    if active and not pending and not manual and MinnTinkersWoWFDB.skipSingleGossip then
        pending = C_Timer.NewTimer(0, SelectSingleOption)
    end
end

function module.Initialize()
    if not (C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.SelectOption
        and C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetActiveQuests
        and Enum.GossipOptionStatus and GossipFrame and C_Timer and C_Timer.NewTimer) then return end
    initialized = true
    -- Native interaction transitions may show the frame after GOSSIP_SHOW.
    GossipFrame:HookScript("OnShow", ScheduleSelection)
    events:RegisterEvent("GOSSIP_SHOW")
    events:RegisterEvent("GOSSIP_CLOSED")
    events:RegisterEvent("MODIFIER_STATE_CHANGED")
    events:SetScript("OnEvent", function(_, event)
        if event == "GOSSIP_CLOSED" then
            CancelPending()
            active, manual = false, false
            attempted = {}
            return
        elseif event == "MODIFIER_STATE_CHANGED" then
            if active and IsShiftKeyDown() then manual = true; CancelPending() end
            return
        end
        active = true
        if IsShiftKeyDown() then manual = true end
        if GossipFrame:IsShown() then
            CancelPending()
            SelectSingleOption()
        else
            ScheduleSelection()
        end
    end)
end
