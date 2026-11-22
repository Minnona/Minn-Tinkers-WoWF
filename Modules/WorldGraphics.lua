local _, addon = ...
local module = { minDensity = 48, maxDensity = 256, minDistance = 320, maxDistance = 500 }
addon.WorldGraphics = module

local densityCVar = "groundEffectDensity"
local distanceCVar = "groundEffectDist"
local fadeCVar = "groundEffectFade"
local sparklesCVar = "outlineModeShowLootEffectWhenDisabled"
local minFade, maxFade = 70, 370

local function ReadValue(name)
    return C_CVar and C_CVar.GetCVar and tonumber(C_CVar.GetCVar(name))
end

local function GetWritableValue(name)
    if not (C_CVar and C_CVar.GetCVarInfo and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    local value, _, _, _, locked, secure, readOnly = C_CVar.GetCVarInfo(name)
    if not (locked or secure or readOnly) then return tonumber(value) end
end

local function WriteValue(name, value, previous)
    if value == previous then return previous end
    if C_CVar.SetCVar(name, tostring(value)) then return ReadValue(name) end
end

function module.GetSparkles()
    return ReadValue(sparklesCVar) == 1
end

function module.IsSparklesAvailable()
    return GetWritableValue(sparklesCVar) ~= nil
end

function module.SetSparkles(enabled)
    local previous = GetWritableValue(sparklesCVar)
    if previous == nil then return false end
    local value = enabled and 1 or 0
    return WriteValue(sparklesCVar, value, previous) == value
end

function module.GetDensity()
    return ReadValue(densityCVar) or module.minDensity
end

function module.GetDistance()
    return ReadValue(distanceCVar) or module.minDistance
end

function module.IsDensityAvailable()
    return GetWritableValue(densityCVar) ~= nil
end

function module.IsDistanceAvailable()
    return GetWritableValue(distanceCVar) ~= nil and GetWritableValue(fadeCVar) ~= nil
end

function module.SetDensity(value)
    local previous = GetWritableValue(densityCVar)
    if not previous then return false end
    local density = math.floor(math.min(module.maxDensity, math.max(module.minDensity, value)) + 0.5)
    return WriteValue(densityCVar, density, previous) ~= nil
end

function module.SetDistance(value)
    local previousDistance, previousFade = GetWritableValue(distanceCVar), GetWritableValue(fadeCVar)
    if not (previousDistance and previousFade) then return false end
    local distance = math.floor(math.min(module.maxDistance, math.max(module.minDistance, value)) + 0.5)
    local accepted = WriteValue(distanceCVar, distance, previousDistance)
    if not accepted then return false end

    -- Match the macro at both ends and use the distance the client actually accepted.
    local fraction = (accepted - module.minDistance) / (module.maxDistance - module.minDistance)
    local fade = math.floor(minFade + (maxFade - minFade) * math.min(1, math.max(0, fraction)) + 0.5)
    if WriteValue(fadeCVar, fade, previousFade) then return true end
    if accepted ~= previousDistance then C_CVar.SetCVar(distanceCVar, tostring(previousDistance)) end
    return false
end
