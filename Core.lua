local addonName, addon = ...
local startup = CreateFrame("Frame")

addon.title = "Minn Tinkers WoWF"
addon.icon = "Interface\\Icons\\Spell_Shaman_Hex"

function addon.SetFastAutoloot(value)
    MinnTinkersWoWFDB.fastAutoloot = value
    if not addon.FastLoot.SetEnabled(value) then
        print(addon.title .. ": Fast autoloot could not activate. Required loot APIs are missing or another addon controls the loot window.")
    end
end

startup:RegisterEvent("ADDON_LOADED")
startup:RegisterEvent("PLAYER_LOGIN")
startup:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addonName then
            return
        end
        if type(MinnTinkersWoWFDB) ~= "table" then
            MinnTinkersWoWFDB = {}
        end
        if type(MinnTinkersWoWFCharDB) ~= "table" then
            MinnTinkersWoWFCharDB = {}
        end
        if type(MinnTinkersWoWFCharDB.rangeIndicator) ~= "table" then
            MinnTinkersWoWFCharDB.rangeIndicator = {}
        end
        if MinnTinkersWoWFDB.fastAutoloot == nil then
            MinnTinkersWoWFDB.fastAutoloot = true
        end
        if type(MinnTinkersWoWFDB.actionbarFonts) ~= "table" then
            MinnTinkersWoWFDB.actionbarFonts = {}
        end
        for _, option in ipairs(addon.ActionBarFonts.options) do
            if MinnTinkersWoWFDB.actionbarFonts[option.key] == nil then
                MinnTinkersWoWFDB.actionbarFonts[option.key] = 0
            end
        end
        if type(MinnTinkersWoWFDB.questing) ~= "table" then
            MinnTinkersWoWFDB.questing = {}
        end
        for key, value in pairs({ autoAccept = true, autoTurnIn = true, vendorReward = false }) do
            if MinnTinkersWoWFDB.questing[key] == nil then MinnTinkersWoWFDB.questing[key] = value end
        end
        if type(MinnTinkersWoWFDB.combatIndicator) ~= "table" then
            MinnTinkersWoWFDB.combatIndicator = {}
        end
        for key, value in pairs({ enabled = true, opacity = 25, width = 20 }) do
            if MinnTinkersWoWFDB.combatIndicator[key] == nil then MinnTinkersWoWFDB.combatIndicator[key] = value end
        end
        if MinnTinkersWoWFDB.skipSingleGossip == nil then
            MinnTinkersWoWFDB.skipSingleGossip = true
        end
        if MinnTinkersWoWFDB.autoSellJunk == nil then
            MinnTinkersWoWFDB.autoSellJunk = true
        end
        if MinnTinkersWoWFDB.chatURLs == nil then
            MinnTinkersWoWFDB.chatURLs = true
        end
        MinnTinkersWoWFDB.popupProtection = nil
        self:UnregisterEvent(event)
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        addon.SetFastAutoloot(MinnTinkersWoWFDB.fastAutoloot)
        addon.ActionBarFonts.Initialize()
        addon.CameraDistance.Initialize()
        addon.Questing.Initialize()
        addon.GossipSkip.Initialize()
        addon.AutoSellJunk.Initialize()
        addon.CombatIndicator.Initialize()
        addon.ChatURLs.Initialize()
        addon.RangeIndicator.Initialize()
        addon.InitializeMinimapButton()
    end
end)
