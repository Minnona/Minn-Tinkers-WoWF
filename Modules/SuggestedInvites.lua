local _, addon = ...
local module = {}
addon.SuggestedInvites = module

local events = CreateFrame("Frame")
local available, lastAttempt

local function IsGroupMember(guid, inRaid, count)
    if not canaccessvalue(guid) or not guid then return false end
    local prefix = inRaid and "raid" or "party"
    for index = 1, inRaid and count or count - 1 do
        local member = UnitGUID(prefix .. index)
        if canaccessvalue(member) and member == guid then return true end
    end
    return false
end

local function OnInviteConfirmation()
    local invite = GetNextPendingInviteConfirmation()
    if not canaccessvalue(invite) or invite == lastAttempt then return end
    lastAttempt = nil
    if not invite or not C_PartyInfo.CanInvite() then return end
    if C_QuestSession and C_QuestSession.HasJoined and C_QuestSession.HasJoined() then return end

    local count, inRaid = GetNumGroupMembers(), IsInRaid()
    if not canaccessallvalues(count, inRaid) or count < 2 or count >= (inRaid and 40 or 5) then return end
    local kind, _, _, rolesInvalid, willConvertToRaid = GetInviteConfirmationInfo(invite)
    if not canaccessallvalues(kind, rolesInvalid, willConvertToRaid)
        or kind ~= LE_INVITE_CONFIRMATION_SUGGEST or rolesInvalid or willConvertToRaid then return end
    local invalidQueues = C_PartyInfo.GetInviteConfirmationInvalidQueues(invite)
    if not canaccessvalue(invalidQueues) or (invalidQueues and #invalidQueues > 0) then return end
    local suggester = C_PartyInfo.GetInviteReferralInfo(invite)
    if not IsGroupMember(suggester, inRaid, count) then return end

    lastAttempt = invite
    if pcall(RespondToInviteConfirmation, invite, true) then
        local nextInvite = GetNextPendingInviteConfirmation()
        if canaccessvalue(nextInvite) and nextInvite ~= invite then
            lastAttempt = nil
            StaticPopup_Hide("GROUP_INVITE_CONFIRMATION", invite)
        end
    end
end

function module.IsAvailable()
    return available == true
end

function module.SetEnabled(enabled)
    MinnTinkersWoWFDB.autoInviteSuggestions = enabled and true or false
    if not available then return end
    if enabled then
        events:RegisterEvent("GROUP_INVITE_CONFIRMATION")
    else
        events:UnregisterEvent("GROUP_INVITE_CONFIRMATION")
        lastAttempt = nil
    end
end

function module.Initialize()
    if not (LE_INVITE_CONFIRMATION_SUGGEST and GetNextPendingInviteConfirmation and GetInviteConfirmationInfo
        and RespondToInviteConfirmation and StaticPopup_Hide and C_PartyInfo and C_PartyInfo.CanInvite
        and C_PartyInfo.GetInviteReferralInfo and C_PartyInfo.GetInviteConfirmationInvalidQueues
        and GetNumGroupMembers and IsInRaid and UnitGUID and canaccessvalue and canaccessallvalues) then return end
    available = true
    module.SetEnabled(MinnTinkersWoWFDB.autoInviteSuggestions)
end

events:SetScript("OnEvent", OnInviteConfirmation)
