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
    local available, activeQuests = C_GossipInfo.GetAvailableQuests(), C_GossipInfo.GetActiveQuests()
    if not canaccessallvalues(available, activeQuests) or #available > 0 or #activeQuests > 0 then return end
    local options = C_GossipInfo.GetOptions()
    if not canaccessvalue(options) or #options ~= 1 then return end
    local option = options[1]
    if not canaccessvalue(option) then return end
    local index, id, status = option.orderIndex, option.gossipOptionID, option.status
    if not canaccessallvalues(index, id, status) or type(index) ~= "number" or status ~= Enum.GossipOptionStatus.Available then return end
    local key = id or ("index:" .. index)
    if attempted[key] then return end
    attempted[key] = true
    -- Native gossip rows use orderIndex. A row can have no gossipOptionID.
    -- Leave text/payment confirmations to Blizzard; never pass confirmed=true.
    C_GossipInfo.SelectOptionByIndex(index)
end

local function ScheduleSelection()
    if active and not pending and not manual and MinnTinkersWoWFDB.skipSingleGossip then
        pending = C_Timer.NewTimer(0, SelectSingleOption)
    end
end

function module.Initialize()
    if not (C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.SelectOptionByIndex and canaccessvalue and canaccessallvalues
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
