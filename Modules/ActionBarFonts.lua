local _, addon = ...
local module = {}
addon.ActionBarFonts = module

module.options = {
    { key = "keybinds", region = "HotKey", label = "Keybinds" },
    { key = "itemCount", region = "Count", label = "Item count" },
    { key = "macroText", region = "Name", label = "Macro names" },
}

local originalFonts = {}
local hookedButtons = {}
local events = CreateFrame("Frame")
local initialized

function module.GetIncrease(key)
    local value = tonumber(MinnTinkersWoWFDB.actionbarFonts[key]) or 0
    return math.floor(math.min(12, math.max(0, value)))
end

local function ApplyButton(button, key)
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    for _, option in ipairs(module.options) do
        local text = button[option.region]
        if text and (not key or option.key == key) then
            local increase = module.GetIncrease(option.key)
            local original = originalFonts[text]
            if increase > 0 and not original then
                local font, size, flags = text:GetFont()
                if not issecretvalue(font) and not issecretvalue(size) and not issecretvalue(flags)
                    and font and size then
                    original = { font = font, size = size, flags = flags }
                    -- Only HotKey has a native fixed-height constraint to expand.
                    if option.region == "HotKey" then
                        local height = text:GetHeight()
                        if not issecretvalue(height) then original.height = height end
                    end
                    originalFonts[text] = original
                end
            end
            if original and (increase > 0 or original.modified) then
                local size = original.size + increase
                local font, currentSize, flags = text:GetFont()
                if issecretvalue(font) or issecretvalue(currentSize) or issecretvalue(flags)
                    or font ~= original.font or currentSize ~= size or flags ~= original.flags then
                    text:SetFont(original.font, size, original.flags)
                end
                original.modified = increase > 0
                if original.height then
                    local currentHeight = text:GetHeight()
                    if not issecretvalue(currentHeight) then
                        local height = increase > 0 and math.max(original.height, size) or original.height
                        if currentHeight ~= height then text:SetHeight(height) end
                    end
                end
                if increase == 0 and option.region == "HotKey" and button.UpdateHotkeys then
                    button:UpdateHotkeys(button.buttonType)
                end
            end
        end
    end
end

local function AttachButton(button, key)
    if not hookedButtons[button] then
        hookedButtons[button] = true
        if button.UpdateHotkeys then
            hooksecurefunc(button, "UpdateHotkeys", function(self) ApplyButton(self, "keybinds") end)
        end
    end
    ApplyButton(button, key)
end

function module.Apply(key)
    if not initialized then
        return
    end
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    ActionBarButtonEventsFrame:ForEachFrame(function(button) AttachButton(button, key) end)
end

function module.IsAvailable()
    return initialized == true
end

function module.Initialize()
    if not ActionBarButtonEventsFrame or not ActionBarButtonEventsFrame.ForEachFrame
        or not ActionBarButtonEventsFrame.RegisterFrame or type(issecretvalue) ~= "function" then
        print(addon.title .. ": Action-bar font controls are unavailable in this client.")
        return
    end
    initialized = true
    hooksecurefunc(ActionBarButtonEventsFrame, "RegisterFrame", function(_, button)
        AttachButton(button)
    end)
    module.Apply()
end

function module.SetIncrease(key, value)
    MinnTinkersWoWFDB.actionbarFonts[key] = math.floor(math.min(12, math.max(0, value)))
    module.Apply(key)
end

events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    module.Apply()
end)
