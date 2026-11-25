local _, addon = ...
local module = {}
addon.GroupRequests = module

local events = CreateFrame("Frame")
local summonTimer
local resurrectionCasts = {}
local pendingResurrection
local partyUnits = {"party1", "party2", "party3", "party4"}
local resurrectionMatchWindow = 1

-- Regular Classic resurrection ranks only. Rebirth and item effects stay manual.
local regularResurrections = {
    [2006] = true, [2010] = true, [10880] = true, [10881] = true, [20770] = true, -- Resurrection
    [7328] = true, [10322] = true, [10324] = true, [20772] = true, [20773] = true, -- Redemption
    [2008] = true, [20609] = true, [20610] = true, [20776] = true, [20777] = true, -- Ancestral Spirit
}

local function IsFriendOrGuildmate(guid)
    if not canaccessvalue(guid) or type(guid) ~= "string" or guid == "" then return false end
    if C_FriendList and C_FriendList.IsFriend then
        local friend = C_FriendList.IsFriend(guid)
        if canaccessvalue(friend) and friend then return true end
    end
    if not (GetNumGuildMembers and GetGuildRosterInfo) then return false end
    local count = GetNumGuildMembers()
    if not canaccessvalue(count) or type(count) ~= "number" then return false end
    for index = 1, count do
        local memberGUID = select(17, GetGuildRosterInfo(index))
        if canaccessvalue(memberGUID) and memberGUID == guid then return true end
    end
    return false
end

local function OnGroupInvite(guid, questSession)
    if not canaccessvalue(questSession) or questSession then return end
    if not MinnTinkersWoWFDB.groupInvitesTrustedOnly or IsFriendOrGuildmate(guid) then
        -- The client closes the prompt when it clears the invite.
        pcall(AcceptGroup)
    end
end

local function StopSummonTimer()
    if summonTimer then
        summonTimer:Cancel()
        summonTimer = nil
    end
end

local function GetSummonTimeLeft()
    local remaining = C_SummonInfo.GetSummonConfirmTimeLeft()
    if canaccessvalue(remaining) and type(remaining) == "number" and remaining > 0 then return remaining end
end

local function ScheduleSummon(remaining)
    local timer
    timer = C_Timer.NewTimer(math.max(0, remaining - 5), function()
        if summonTimer ~= timer then return end
        summonTimer = nil
        local timeLeft = GetSummonTimeLeft()
        if not timeLeft then return end
        if timeLeft > 5 then
            ScheduleSummon(timeLeft)
            return
        end
        local fighting, canTeleport = UnitAffectingCombat("player"), PlayerCanTeleport()
        if canaccessallvalues(fighting, canTeleport) and fighting == false and canTeleport == true then
            pcall(C_SummonInfo.ConfirmSummon)
        end
    end)
    summonTimer = timer
end

local function OnSummon()
    StopSummonTimer()
    local remaining = GetSummonTimeLeft()
    if remaining then ScheduleSummon(remaining) end
end

local function ClearResurrection()
    for _, unit in ipairs(partyUnits) do resurrectionCasts[unit] = nil end
    pendingResurrection = nil
end

local function CanAutoResurrect()
    local inside, instanceType = IsInInstance()
    local encounter, dead = IsEncounterInProgress(), UnitIsDeadOrGhost("player")
    return canaccessallvalues(inside, instanceType, encounter, dead)
        and inside == true and instanceType == "party" and encounter == false and dead == true
        and not InCombatLockdown()
end

local function IsResurrectionCaster(unit, offerer)
    local name, realm = UnitFullName(unit)
    if not canaccessallvalues(name, realm) or not name then return false end
    if not realm or realm == "" then
        if offerer == name then return true end
        realm = GetNormalizedRealmName()
        if not canaccessvalue(realm) or not realm or realm == "" then return false end
    end
    return offerer == name .. "-" .. realm
end

local function TryAcceptResurrection(unit, cast, offer)
    if not cast.finishedAt or math.abs(offer.at - cast.finishedAt) > resurrectionMatchWindow then return end
    ClearResurrection()
    local offerer, fighting = ResurrectGetOfferer(), UnitAffectingCombat(unit)
    if canaccessallvalues(offerer, fighting) and offerer == offer.name and fighting == false and CanAutoResurrect() then
        pcall(AcceptResurrect)
    end
end

local function OnResurrectionOffer(offerer)
    pendingResurrection = nil
    if not canaccessvalue(offerer) or type(offerer) ~= "string" or offerer == "" or not CanAutoResurrect() then
        ClearResurrection()
        return
    end
    local now = GetTime()
    for _, unit in ipairs(partyUnits) do
        local cast = resurrectionCasts[unit]
        if cast and IsResurrectionCaster(unit, offerer) then
            local offer = {name = offerer, at = now, cast = cast}
            if cast.finishedAt then
                TryAcceptResurrection(unit, cast, offer)
            else
                -- Some offers arrive just before the cast-completion event.
                pendingResurrection = offer
            end
            return
        end
    end
end

local function OnPartyCast(event, unit, guid, spellID)
    if not canaccessvalue(unit) or type(unit) ~= "string" then
        ClearResurrection()
        return
    end
    local cast = resurrectionCasts[unit]
    if event == "UNIT_SPELLCAST_START" then
        resurrectionCasts[unit] = nil
        if canaccessallvalues(guid, spellID) and guid and regularResurrections[spellID] and CanAutoResurrect() then
            local fighting = UnitAffectingCombat(unit)
            if canaccessvalue(fighting) and fighting == false then
                resurrectionCasts[unit] = {guid = guid, spellID = spellID}
            end
        end
    elseif cast then
        if event == "UNIT_SPELLCAST_SUCCEEDED" and canaccessallvalues(guid, spellID)
            and cast.guid == guid and cast.spellID == spellID and not cast.finishedAt and CanAutoResurrect() then
            local fighting = UnitAffectingCombat(unit)
            if not canaccessvalue(fighting) or fighting ~= false then
                resurrectionCasts[unit] = nil
                return
            end
            cast.finishedAt = GetTime()
            if pendingResurrection and pendingResurrection.cast == cast then
                TryAcceptResurrection(unit, cast, pendingResurrection)
                pendingResurrection = nil
            end
        else
            resurrectionCasts[unit] = nil
        end
    end
end

function module.CanAcceptGroupInvites()
    return AcceptGroup ~= nil and canaccessvalue ~= nil
end

function module.CanFilterGroupInvites()
    return module.CanAcceptGroupInvites()
        and (C_FriendList and C_FriendList.IsFriend or GetNumGuildMembers and GetGuildRosterInfo) ~= nil
end

function module.CanAcceptSummons()
    return not not (C_SummonInfo and C_SummonInfo.GetSummonConfirmTimeLeft and C_SummonInfo.ConfirmSummon
        and C_Timer and C_Timer.NewTimer and PlayerCanTeleport and UnitAffectingCombat
        and canaccessvalue and canaccessallvalues)
end

function module.CanAcceptResurrections()
    return not not (AcceptResurrect and ResurrectGetOfferer and IsInInstance and IsEncounterInProgress
        and UnitIsDeadOrGhost and UnitFullName and GetNormalizedRealmName and UnitAffectingCombat
        and canaccessvalue and canaccessallvalues)
end

local function SetEvent(event, enabled)
    if enabled then
        events:RegisterEvent(event)
    else
        events:UnregisterEvent(event)
    end
end

local function RefreshGuildRoster()
    if MinnTinkersWoWFDB.autoAcceptGroupInvites and MinnTinkersWoWFDB.groupInvitesTrustedOnly
        and C_GuildInfo and C_GuildInfo.GuildRoster and IsInGuild then
        local inGuild = IsInGuild()
        if canaccessvalue(inGuild) and inGuild then pcall(C_GuildInfo.GuildRoster) end
    end
end

function module.SetAcceptGroupInvites(enabled)
    MinnTinkersWoWFDB.autoAcceptGroupInvites = enabled == true
    SetEvent("PARTY_INVITE_REQUEST", enabled and module.CanAcceptGroupInvites())
    if module.CanFilterGroupInvites() then RefreshGuildRoster() end
end

function module.SetTrustedInvitesOnly(enabled)
    MinnTinkersWoWFDB.groupInvitesTrustedOnly = enabled == true
    if module.CanFilterGroupInvites() then RefreshGuildRoster() end
end

function module.SetAcceptSummons(enabled)
    MinnTinkersWoWFDB.autoAcceptSummons = enabled == true
    local active = enabled and module.CanAcceptSummons()
    SetEvent("CONFIRM_SUMMON", active)
    SetEvent("CANCEL_SUMMON", active)
    if not active then StopSummonTimer() end
end

function module.SetAcceptResurrections(enabled)
    MinnTinkersWoWFDB.autoAcceptDungeonResurrections = enabled == true
    local active = enabled and module.CanAcceptResurrections()
    ClearResurrection()
    SetEvent("RESURRECT_REQUEST", active)
    SetEvent("PLAYER_ENTERING_WORLD", active)
    SetEvent("PLAYER_REGEN_DISABLED", active)
    SetEvent("PLAYER_ALIVE", active)
    SetEvent("GROUP_ROSTER_UPDATE", active)
    for _, event in ipairs({"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED"}) do
        if active then
            events:RegisterUnitEvent(event, unpack(partyUnits))
        else
            events:UnregisterEvent(event)
        end
    end
end

function module.Initialize()
    local db = MinnTinkersWoWFDB
    if db.groupInvitesTrustedOnly == nil then db.groupInvitesTrustedOnly = true end
    module.SetAcceptGroupInvites(db.autoAcceptGroupInvites)
    module.SetAcceptSummons(db.autoAcceptSummons)
    module.SetAcceptResurrections(db.autoAcceptDungeonResurrections)
end

events:SetScript("OnEvent", function(_, event, first, second, third, ...)
    if event == "PARTY_INVITE_REQUEST" then
        local guid, questSession = select(5, ...)
        OnGroupInvite(guid, questSession)
    elseif event == "CONFIRM_SUMMON" then
        OnSummon()
    elseif event == "CANCEL_SUMMON" then
        StopSummonTimer()
    elseif event == "RESURRECT_REQUEST" then
        OnResurrectionOffer(first)
    elseif event:sub(1, 15) == "UNIT_SPELLCAST_" then
        OnPartyCast(event, first, second, third)
    else
        ClearResurrection()
    end
end)
