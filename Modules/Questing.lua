local _, addon = ...
local module = {}
addon.Questing = module
local events = CreateFrame("Frame")
local session, manual, rewardQuest, rewardTimer, selectingReward
local initialized
local questInfo = {}

local function CancelLookup()
    events:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    if rewardTimer then rewardTimer:Cancel(); rewardTimer = nil end
end

local function CancelReward()
    rewardQuest = nil
    CancelLookup()
end

local function EndSessionIfClosed()
    C_Timer.NewTimer(0, function()
        local types = Enum.PlayerInteractionType
        if types and C_PlayerInteractionManager
            and C_PlayerInteractionManager.IsInteractingWithNpcOfType then
            if C_PlayerInteractionManager.IsInteractingWithNpcOfType(types.Gossip)
                or C_PlayerInteractionManager.IsInteractingWithNpcOfType(types.QuestGiver) then return end
        end
        if (QuestFrame and QuestFrame:IsShown()) or (GossipFrame and GossipFrame:IsShown()) then return end
        CancelReward()
        session, manual = nil, nil
        questInfo = {}
    end)
end

local function Bypassed()
    if IsShiftKeyDown() then
        manual = true
        CancelReward()
    end
    return manual
end

local function BeginSession()
    if not session then
        session = true
        manual = IsShiftKeyDown()
    end
    return not Bypassed()
end

local function Eligible(id, info)
    if not id or id <= 0 then return false end
    info = info or questInfo[id]
    local repeatable = info and info.repeatable
    if repeatable == nil then repeatable = C_QuestLog.IsRepeatableQuest(id) end
    if not repeatable then return true end
    local frequency = info and info.frequency
    if not frequency then
        local index = C_QuestLog.GetLogIndexForQuestID(id)
        local logInfo = index and C_QuestLog.GetInfo(index)
        frequency = logInfo and logInfo.frequency
    end
    return frequency == Enum.QuestFrequency.Daily or frequency == Enum.QuestFrequency.Weekly
        or (id == GetQuestID() and ((QuestIsDaily and QuestIsDaily()) or (QuestIsWeekly and QuestIsWeekly()))) or false
end

local function SelectReward(index)
    local rewards = QuestInfoFrame and QuestInfoFrame.rewardsFrame
    for _, button in ipairs(rewards and rewards.RewardButtons or {}) do
        if button.type == "choice" and button:GetID() == index and button:IsShown() then
            selectingReward = true
            QuestInfoItem_OnClick(button)
            selectingReward = false
            return true
        end
    end
    return false
end

local function FinishReward()
    if not rewardQuest or Bypassed() or GetQuestID() ~= rewardQuest
        or not (QuestFrame and QuestFrame:IsShown()) then
        CancelReward()
        return
    end
    local settings = MinnTinkersWoWFDB.questing
    local count, best, bestValue = GetNumQuestChoices(), nil, -1
    local hasItems = count > 0 or GetNumQuestRewards() > 0
    if hasItems and not settings.vendorReward then CancelReward(); return end
    if count > 0 then
        if count == 1 then
            best = 1
        else
            for index = 1, count do
                local _, _, quantity = GetQuestItemInfo("choice", index)
                local link = GetQuestItemLink("choice", index)
                local price = link and select(11, C_Item.GetItemInfo(link))
                if not price or not quantity then
                    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
                    if not rewardTimer then
                        rewardTimer = C_Timer.NewTimer(3, CancelReward)
                    end
                    return
                end
                local value = price * quantity
                if value > bestValue then best, bestValue = index, value end
            end
        end
        if QuestInfoFrame.itemChoice ~= best and not SelectReward(best) then CancelReward(); return end
        -- Keep the suggestion alive when Blizzard rebuilds the reward buttons.
        CancelLookup()
        return
    end
    CancelReward()
    if settings.autoTurnIn and not hasItems and not Bypassed() then
        -- Preserve Blizzard's confirmation for quests that charge money.
        QuestRewardCompleteButton_OnClick()
    end
end

function module.SetOption(key, value)
    MinnTinkersWoWFDB.questing[key] = value and true or false
    CancelReward()
end

function module.IsAvailable()
    return initialized == true
end

function module.Initialize()
    if not (C_GossipInfo and C_QuestLog and C_QuestLog.IsRepeatableQuest and C_Item
        and C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetActiveQuests
        and C_GossipInfo.SelectAvailableQuest and C_GossipInfo.SelectActiveQuest
        and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo
        and C_Item.GetItemInfo and Enum.QuestFrequency and QuestInfoFrame and QuestInfoItem_OnClick
        and QuestInfo_ShowRewards and QuestRewardCompleteButton_OnClick
        and C_Timer and C_Timer.NewTimer) then return end
    initialized = true
    for _, event in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL",
        "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_ITEM_UPDATE", "MODIFIER_STATE_CHANGED",
        "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" }) do
        events:RegisterEvent(event)
    end
    hooksecurefunc("QuestInfoItem_OnClick", function()
        if not selectingReward then CancelReward() end
    end)
    hooksecurefunc("QuestInfo_ShowRewards", function()
        if rewardQuest and not QuestInfoFrame.questLog then FinishReward() end
    end)
    events:SetScript("OnEvent", function(_, event)
        if event == "MODIFIER_STATE_CHANGED" then
            if session then Bypassed() end
            return
        elseif event == "QUEST_FINISHED" then
            CancelReward()
            EndSessionIfClosed()
            return
        elseif event == "GOSSIP_CLOSED" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
            if session then EndSessionIfClosed() end
            return
        elseif event == "QUEST_ITEM_UPDATE" or event == "GET_ITEM_INFO_RECEIVED" then
            -- Background item updates must not start a conversation or latch Shift.
            if rewardQuest then FinishReward() end
            return
        end
        if not BeginSession() then return end
        local settings = MinnTinkersWoWFDB.questing
        if event == "GOSSIP_SHOW" then
            local available, active = C_GossipInfo.GetAvailableQuests(), C_GossipInfo.GetActiveQuests()
            for _, info in ipairs(available) do questInfo[info.questID] = info end
            for _, info in ipairs(active) do questInfo[info.questID] = info end
            if settings.autoTurnIn then
                for _, info in ipairs(active) do
                    if info.isComplete and Eligible(info.questID, info) then
                        C_GossipInfo.SelectActiveQuest(info.questID)
                        return
                    end
                end
            end
            if settings.autoAccept then
                for _, info in ipairs(available) do
                    if Eligible(info.questID, info) then
                        C_GossipInfo.SelectAvailableQuest(info.questID)
                        return
                    end
                end
            end
        elseif event == "QUEST_GREETING" then
            if settings.autoTurnIn then
                for index = 1, GetNumActiveQuests() do
                    local _, complete = GetActiveTitle(index)
                    local id = GetActiveQuestID(index)
                    if complete and Eligible(id) then SelectActiveQuest(index); return end
                end
            end
            if settings.autoAccept then
                for index = 1, GetNumAvailableQuests() do
                    local _, frequency, repeatable, _, id = GetAvailableQuestInfo(index)
                    local info = { frequency = frequency, repeatable = repeatable }
                    if id then questInfo[id] = info end
                    if Eligible(id, info) then SelectAvailableQuest(index); return end
                end
            end
        elseif event == "QUEST_DETAIL" then
            CancelReward()
            if settings.autoAccept and Eligible(GetQuestID()) and not (QuestGetAutoAccept and QuestGetAutoAccept()) then AcceptQuest() end
        elseif event == "QUEST_PROGRESS" then
            CancelReward()
            if settings.autoTurnIn and Eligible(GetQuestID()) and IsQuestCompletable() then CompleteQuest() end
        elseif event == "QUEST_COMPLETE" then
            CancelReward()
            if (settings.autoTurnIn or settings.vendorReward) and Eligible(GetQuestID()) then
                rewardQuest = GetQuestID()
                FinishReward()
            end
        end
    end)
end
