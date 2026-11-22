local _, addon = ...
local module = {}
addon.GossipSkip = module
local events = CreateFrame("Frame")
local attempted = {}
local active, manual = false, false
local initialized, pending, dialogueReadyAt

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

local function FindDialogueOption(dialogue, index, id)
    if dialogue.handler ~= "HandleGossip" or dialogue.requireGossipConfirm
        or (dialogue.InputBox and dialogue.InputBox:IsShown()) then return end
    local pool = dialogue.optionButtonPool
    if not (pool and pool.ProcessActiveObjects) then return end

    local match, matches = nil, 0
    pool:ProcessActiveObjects(function(button)
        if button.type == "gossip" and button.id == index and button.gossipOptionID == id
            and button:IsVisible() and button:IsEnabled() then
            match = button
            matches = matches + 1
        end
    end)
    if matches == 1 then return match end
end

local function SelectSingleOption()
    pending = nil
    if not active then return end
    local useNative = GossipFrame:IsShown()
    local dialogue = not useNative and DUIQuestFrame
    if not useNative and not (dialogue and dialogue:IsShown()) then return end
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
    if dialogue then
        local button = FindDialogueOption(dialogue, index, id)
        if not button then return end
        attempted[key] = true
        -- Dialogue UI restores the game UI before opening panels such as a vendor.
        button:Click("LeftButton")
    else
        attempted[key] = true
        -- Native gossip rows use orderIndex. Leave confirmations to Blizzard.
        C_GossipInfo.SelectOptionByIndex(index)
    end
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
    -- Either gossip window can appear after GOSSIP_SHOW.
    GossipFrame:HookScript("OnShow", ScheduleSelection)
    if DUIQuestFrame then
        DUIQuestFrame:HookScript("OnShow", ScheduleSelection)
        if DUIQuestFrame.ShowUI then
            hooksecurefunc(DUIQuestFrame, "ShowUI", function(dialogue, event)
                if event ~= "GOSSIP_SHOW" or dialogue.handler ~= "HandleGossip" or not dialogue:IsShown() then return end
                if pending then
                    CancelPending()
                    SelectSingleOption()
                else
                    -- Our GOSSIP_SHOW listener may run after Dialogue UI's listener in the same frame.
                    dialogueReadyAt = GetTime()
                end
            end)
        end
    end
    events:RegisterEvent("GOSSIP_SHOW")
    events:RegisterEvent("GOSSIP_CLOSED")
    events:RegisterEvent("MODIFIER_STATE_CHANGED")
    events:SetScript("OnEvent", function(_, event)
        if event == "GOSSIP_CLOSED" then
            CancelPending()
            active, manual = false, false
            dialogueReadyAt = nil
            attempted = {}
            return
        elseif event == "MODIFIER_STATE_CHANGED" then
            if active and IsShiftKeyDown() then manual = true; CancelPending() end
            return
        end
        active = true
        if IsShiftKeyDown() then manual = true end
        local dialogueReady = dialogueReadyAt and dialogueReadyAt == GetTime()
        dialogueReadyAt = nil
        if GossipFrame:IsShown() or dialogueReady then
            CancelPending()
            SelectSingleOption()
        else
            ScheduleSelection()
        end
    end)
end
