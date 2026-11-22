local _, addon = ...
local module = {}
addon.FishingSound = module

local events = CreateFrame("Frame")
local fishingVolumes = {
    Sound_MusicVolume = 0,
    Sound_AmbienceVolume = 0,
    Sound_SFXVolume = 1,
}
local resumeDelay, fadeOut, fadeIn = 8, 0.6, 1.5
local fishingName, fishing, cast, resumeTimer
local channels, fadingToFishing

local function IsFishing()
    local name = UnitChannelInfo("player")
    return canaccessvalue(name) and name == fishingName
end

local function CancelResume()
    if resumeTimer then resumeTimer:Cancel(); resumeTimer = nil end
end

local function RestoreVolumes()
    events:SetScript("OnUpdate", nil)
    if channels then
        for name, channel in pairs(channels) do
            if channel.changed then C_CVar.RemoveTempCVar(name) end
        end
    end
    channels, fadingToFishing = nil, nil
end

local function Fade(whileFishing)
    if not channels or fadingToFishing == whileFishing then return end
    fadingToFishing = whileFishing
    for _, channel in pairs(channels) do
        channel.from = channel.current
    end

    local duration = whileFishing and fadeOut or fadeIn
    local elapsed, lastUpdate = 0, 0
    events:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < duration and elapsed - lastUpdate < 1 / 30 then return end
        lastUpdate = elapsed
        local progress = math.min(elapsed / duration, 1)
        if progress == 1 and not whileFishing then RestoreVolumes(); return end
        local blend = progress * progress * (3 - 2 * progress)
        for name, channel in pairs(channels) do
            local target = whileFishing and fishingVolumes[name] or channel.original
            local value = math.floor((channel.from + (target - channel.from) * blend) * 10000 + 0.5) / 10000
            if value ~= channel.current then
                C_CVar.SetTempCVar(name, tostring(value))
                channel.current, channel.changed = value, true
            end
        end
        if progress == 1 then events:SetScript("OnUpdate", nil) end
    end)
end

local function StartFishing(castGUID)
    fishing, cast = true, castGUID
    CancelResume()
    if not channels then
        channels = {}
        for name, target in pairs(fishingVolumes) do
            local value, _, _, _, locked, secure, readOnly = C_CVar.GetCVarInfo(name)
            local volume = tonumber(value)
            if volume and volume >= 0 and volume <= 1 and volume ~= target and not (locked or secure or readOnly) then
                channels[name] = {original = volume, current = volume}
            end
        end
        if not next(channels) then channels = nil end
    end
    Fade(true)
end

local function StopFishing()
    fishing, cast = nil, nil
    if not channels or resumeTimer then return end
    resumeTimer = C_Timer.NewTimer(resumeDelay, function()
        resumeTimer = nil
        if IsFishing() then StartFishing(); return end
        Fade(false)
    end)
end

function module.IsAvailable()
    return fishingName ~= nil
end

function module.SetEnabled(enabled)
    MinnTinkersWoWFDB.quietFishing = enabled and true or false
    if not fishingName then return end
    if enabled then
        events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
        events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        if IsFishing() then StartFishing() end
    else
        events:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        events:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
        events:UnregisterEvent("PLAYER_ENTERING_WORLD")
        fishing, cast = nil, nil
        CancelResume()
        Fade(false)
    end
end

function module.Initialize()
    if not (UnitChannelInfo and canaccessvalue and C_Spell and C_Spell.GetSpellName and C_Timer and C_Timer.NewTimer
        and C_CVar and C_CVar.GetCVarInfo and C_CVar.SetTempCVar and C_CVar.RemoveTempCVar) then return end
    fishingName = C_Spell.GetSpellName(7620)
    if not fishingName then return end
    events:RegisterEvent("PLAYER_LOGOUT")
    module.SetEnabled(MinnTinkersWoWFDB.quietFishing)
end

events:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if event == "PLAYER_LOGOUT" then
        CancelResume()
        RestoreVolumes()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if IsFishing() then StartFishing() elseif fishing then StopFishing() end
    elseif unit == "player" then
        local guid = canaccessvalue(castGUID) and castGUID or nil
        if event == "UNIT_SPELLCAST_CHANNEL_START" then
            if canaccessvalue(spellID) and spellID and C_Spell.GetSpellName(spellID) == fishingName then
                StartFishing(guid)
            end
        elseif fishing and (not cast or not guid or cast == guid) then
            StopFishing()
        end
    end
end)
