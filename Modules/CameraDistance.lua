local _, addon = ...
local module = {}
addon.CameraDistance = module

local cvar = "cameraDistanceMaxZoomFactor"
local cvarLower = cvar:lower()
local extendedDistance = 4
local zoomStep = 1.5
local events = CreateFrame("Frame")
local applyingDistance, initialized
local zoomButton, applyingBindings
local wheelBindings = {
    {"MOUSEWHEELUP", "CAMERAZOOMIN", "LeftButton"},
    {"MOUSEWHEELDOWN", "CAMERAZOOMOUT", "RightButton"},
}

local function ReadDistance()
    if not (C_CVar and C_CVar.GetCVarInfo and C_CVar.SetCVar and C_CVar.GetCVar) then return end
    local value, default, _, _, locked, secure, readOnly = C_CVar.GetCVarInfo(cvar)
    if locked or secure or readOnly then return end
    return tonumber(value), tonumber(default)
end

function module.IsAvailable()
    return ReadDistance() ~= nil
end

local function WriteDistance(value)
    applyingDistance = true
    local success = C_CVar.SetCVar(cvar, tostring(value))
    applyingDistance = false
    if success then return tonumber(C_CVar.GetCVar(cvar)) end
end

local function WatchDistance(enabled)
    if enabled then
        events:RegisterEvent("CVAR_UPDATE")
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        events:UnregisterEvent("CVAR_UPDATE")
        events:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end

local function RestoreExtendedDistance()
    if applyingDistance then return end
    local current, default = ReadDistance()
    if not current then return end
    local db = MinnTinkersWoWFDB
    if db.cameraDistanceBeforeExtension == nil then
        db.cameraDistanceBeforeExtension = current == extendedDistance and default or current
    end
    if current ~= extendedDistance then WriteDistance(extendedDistance) end
end

function module.SetExtendedDistance(enabled)
    local db = MinnTinkersWoWFDB
    if enabled == db.extendedCameraDistance then return end
    local current, default = ReadDistance()
    if not current then return end
    if enabled then
        if current ~= extendedDistance and WriteDistance(extendedDistance) ~= extendedDistance then
            if tonumber(C_CVar.GetCVar(cvar)) ~= current then WriteDistance(current) end
            return
        end
        db.cameraDistanceBeforeExtension = current
    else
        local previous = tonumber(db.cameraDistanceBeforeExtension) or default
        if current == extendedDistance and previous ~= current and (not previous or not WriteDistance(previous)) then
            return
        end
        db.cameraDistanceBeforeExtension = nil
    end
    db.extendedCameraDistance = enabled
    WatchDistance(enabled)
end

function module.IsFasterZoomAvailable()
    return type(GetBindingAction) == "function" and type(SetOverrideBindingClick) == "function"
        and type(ClearOverrideBindings) == "function"
        and type(CameraZoomIn) == "function" and type(CameraZoomOut) == "function"
end

local function RefreshWheelBindings()
    if applyingBindings then return end
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")

    applyingBindings = true
    if zoomButton then ClearOverrideBindings(events) end
    if MinnTinkersWoWFDB.fasterCameraZoom then
        if not zoomButton then
            zoomButton = CreateFrame("Button", "MinnTinkersWoWFCameraZoom")
            zoomButton:EnableMouse(false)
            zoomButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            zoomButton:SetScript("OnClick", function(_, button)
                if button == "LeftButton" then
                    CameraZoomIn(zoomStep)
                elseif button == "RightButton" then
                    CameraZoomOut(zoomStep)
                end
            end)
        end

        for _, binding in ipairs(wheelBindings) do
            local key, action, button = unpack(binding)
            if GetBindingAction(key) == action and GetBindingAction(key, true) == action then
                SetOverrideBindingClick(events, false, key, zoomButton:GetName(), button)
            end
        end
    end
    applyingBindings = false
end

function module.SetFasterZoom(enabled)
    MinnTinkersWoWFDB.fasterCameraZoom = enabled
    if not module.IsFasterZoomAvailable() then return end
    if enabled then
        events:RegisterEvent("UPDATE_BINDINGS")
    else
        events:UnregisterEvent("UPDATE_BINDINGS")
    end
    RefreshWheelBindings()
end

function module.Initialize()
    if initialized then return end
    initialized = true
    local db = MinnTinkersWoWFDB
    if db.extendedCameraDistance == nil then
        db.extendedCameraDistance = tonumber(db.cameraMaxFactor) == extendedDistance
    end
    db.cameraMaxFactor = nil
    if db.extendedCameraDistance then
        WatchDistance(true)
        RestoreExtendedDistance()
    end
    if db.fasterCameraZoom then module.SetFasterZoom(true) end
end

events:SetScript("OnEvent", function(_, event, name)
    if event == "CVAR_UPDATE" then
        if type(name) == "string" and name:lower() == cvarLower then RestoreExtendedDistance() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        RestoreExtendedDistance()
    else
        RefreshWheelBindings()
    end
end)
