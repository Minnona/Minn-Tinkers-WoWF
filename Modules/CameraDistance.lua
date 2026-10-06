local _, addon = ...
local module = { min = 1, max = 2.6 }
addon.CameraDistance = module
local cvar = "cameraDistanceMaxZoomFactor"

function module.IsAvailable()
    if not C_CVar or not C_CVar.GetCVarInfo or not C_CVar.SetCVar or not C_CVar.GetCVar then
        return false
    end
    local value, _, _, _, locked, secure, readOnly = C_CVar.GetCVarInfo(cvar)
    return tonumber(value) ~= nil and not locked and not secure and not readOnly
end

function module.GetFactor()
    local value = C_CVar and C_CVar.GetCVar and tonumber(C_CVar.GetCVar(cvar))
    return value or module.min
end

function module.SetFactor(value)
    if not module.IsAvailable() then
        return false
    end
    value = math.floor(math.min(module.max, math.max(module.min, value)) * 10 + 0.5) / 10
    if not C_CVar.SetCVar(cvar, tostring(value)) then
        return false
    end
    -- Store what the client accepted, including any beta-specific clamp.
    local accepted = tonumber(C_CVar.GetCVar(cvar))
    if not accepted then return false end
    MinnTinkersWoWFDB.cameraMaxFactor = accepted
    return true
end

function module.Initialize()
    local saved = tonumber(MinnTinkersWoWFDB.cameraMaxFactor)
    if saved and not module.SetFactor(saved) then
        print(addon.title .. ": The camera-distance setting could not be applied in this client.")
    end
end
