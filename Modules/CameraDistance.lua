local _, addon = ...
local module = { min = 1, max = 4.0 }
addon.CameraDistance = module
local cvar = "cameraDistanceMaxZoomFactor"
local cvarLower = cvar:lower()
local events = CreateFrame("Frame")
local applying, initialized

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
    applying = true
    local success = C_CVar.SetCVar(cvar, tostring(value))
    applying = false
    if not success then
        return false
    end
    -- Store what the client accepted, including any beta-specific clamp.
    local accepted = tonumber(C_CVar.GetCVar(cvar))
    if not accepted then return false end
    MinnTinkersWoWFDB.cameraMaxFactor = accepted
    return true
end

local function RestoreSavedFactor()
    if applying then return end
    local saved = tonumber(MinnTinkersWoWFDB.cameraMaxFactor)
    if not saved or not module.IsAvailable() or module.GetFactor() == saved then return end
    -- Ignore synchronous notifications from our own write; never replace the saved preference here.
    applying = true
    C_CVar.SetCVar(cvar, tostring(saved))
    applying = false
end

function module.Initialize()
    if initialized then return end
    initialized = true
    events:RegisterEvent("CVAR_UPDATE")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    local saved = tonumber(MinnTinkersWoWFDB.cameraMaxFactor)
    if saved and not module.SetFactor(saved) then
        print(addon.title .. ": The camera-distance setting could not be applied in this client.")
    end
end

events:SetScript("OnEvent", function(_, event, name)
    if event == "CVAR_UPDATE" and (type(name) ~= "string" or name:lower() ~= cvarLower) then return end
    RestoreSavedFactor()
end)
