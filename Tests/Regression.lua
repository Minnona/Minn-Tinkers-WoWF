local root = assert(arg[1], "Pass the addon directory")
local function fixture(saved)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local frames, timers, requests, nativeCalls, messages = {}, {}, {}, {}, {}
    local slots, lootAction = {}, nil
    local addon = {}
    local combat = false
    local camera = { value = 1.9, cap = 2.6, writes = 0 }
    env.C_CVar = {
        GetCVar = function() return camera.value and tostring(camera.value) end,
        GetCVarInfo = function()
            return camera.value and tostring(camera.value), "1.9", false, false, camera.locked, camera.secure, camera.readOnly
        end,
        SetCVar = function(_, value)
            camera.writes = camera.writes + 1
            if camera.reject then return false end
            camera.value = math.min(camera.cap, math.max(1, tonumber(value)))
            return true
        end,
    }
    env.InCombatLockdown = function() return combat end
    env.issecretvalue = function() return false end
    env.CreateColor = function(r, g, b, a) return {r = r, g = g, b = b, a = a} end
    env.MinnTinkersWoWFDB = saved
    env.Enum = { LootSlotType = { None = 0 } }
    env.ERR_INV_FULL = "Inventory is full."
    env.UISpecialFrames, env.SlashCmdList = {}, {}
    env.print = function(text) messages[#messages + 1] = text end
    local function frame(name)
        local f = { name = name, events = {}, scripts = {}, shown = false, children = {} }
        for _, method in ipairs({"ClearAllPoints", "SetFrameLevel", "SetFrameStrata", "SetMovable", "SetClampedToScreen", "EnableMouse", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetHitRectInsets", "SetAllPoints", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag", "SetJustifyH", "SetColorTexture", "SetAtlas", "SetTexCoord", "SetHighlightTexture", "RegisterForClicks"}) do
            f[method] = function() end
        end
        function f:RegisterEvent(event) self.events[event] = true end
        function f:UnregisterEvent(event) self.events[event] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        function f:IsEventRegistered(event) return self.events[event] == true end
        function f:SetScript(event, handler) self.scripts[event] = handler end
        function f:HookScript(event, handler)
            local previous = self.scripts[event]
            self.scripts[event] = function(...)
                if previous then previous(...) end
                handler(...)
            end
        end
        function f:SetShown(value)
            if self.shown ~= value then
                self.shown = value
                local handler = self.scripts[value and "OnShow" or "OnHide"]
                if handler then handler(self) end
                if not value then
                    local function hideChildren(parent)
                        for _, child in ipairs(parent.children) do
                            if child.scripts.OnHide then child.scripts.OnHide(child) end
                            hideChildren(child)
                        end
                    end
                    hideChildren(self)
                end
            end
        end
        function f:Show() self:SetShown(true) end
        function f:Hide() self:SetShown(false) end
        function f:IsShown() return self.shown end
        function f:GetName() return self.name end
        function f:SetPoint(...) self.point = {...} end
        function f:GetWidth() return self.width or 144 end
        function f:GetCenter() return self.centerX or 0, self.centerY or 0 end
        function f:GetEffectiveScale() return self.scale or 1 end
        function f:SetID(id) self.id = id end
        function f:SetSize(width, height) self.width, self.height = width, height end
        function f:GetSize() return self.width, self.height end
        function f:SetWidth(width) self.width = width end
        function f:SetResizable(value) self.resizable = value end
        function f:SetEnabled(value) self.enabled = value end
        function f:Init(target, minWidth, minHeight, maxWidth, maxHeight)
            self.target, self.bounds = target, {minWidth, minHeight, maxWidth, maxHeight}
        end
        function f:SetOnResizeStoppedCallback(callback) self.resizeStopped = callback end
        function f:GetID() return self.id end
        function f:SetHeight(height) self.height = height end
        function f:SetAlpha(value) self.alpha = value end
        function f:SetGradient(...) self.gradient = {...} end
        function f:GetHeight() return self.height or 10 end
        function f:GetFont() return self.font or "Native.ttf", self.fontSize or 10, self.fontFlags or "OUTLINE" end
        function f:SetFont(font, size, flags)
            self.font, self.fontSize, self.fontFlags = font, size, flags
            self.fontWrites = (self.fontWrites or 0) + 1
        end
        function f:SetValue(value)
            self.value = value
            if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
        end
        function f:SetTitle(value) self.title = value end
        function f:SetPortraitToAsset(value) self.portrait = value end
        function f:SetText(value) self.text = value end
        function f:SetTexture(value) self.texture = value end
        function f:GetStringWidth() return #self.text * 7 end
        function f:SetChecked(value) self.checked = value end
        function f:GetChecked() return self.checked end
        function f:CreateFontString() return frame() end
        function f:CreateTexture() return frame() end
        return f
    end
    env.UIParent = frame()
    env.LootFrame = frame()
    env.LootFrame:RegisterEvent("LOOT_OPENED")
    env.LootFrame.OnEvent = function(_, event, auto, item)
        nativeCalls[#nativeCalls + 1] = {event, auto, item}
    end
    env.CreateFrame = function(_, name, parent, template)
        local f = frame(name)
        if parent then parent.children[#parent.children + 1] = f end
        frames[#frames + 1] = f
        if name then env[name] = f end
        if template == "ButtonFrameTemplate" then f.Inset = frame(); f.children[#f.children + 1] = f.Inset end
        if template == "UICheckButtonTemplate" then f.Text = frame() end
        return f
    end
    env.ButtonFrameTemplate_HideButtonBar = function() end
    env.PanelTemplates_SetNumTabs = function(f, count) f.numTabs = count end
    env.PanelTemplates_SetTab = function(f, id) f.selectedTab = id end
    env.hooksecurefunc = function(object, method, hook)
        if type(object) == "string" then object, method, hook = env, object, method end
        local original = object[method]
        object[method] = function(...)
            original(...)
            hook(...)
        end
    end
    local function actionButton()
        local button = { HotKey = frame(), Count = frame(), Name = frame() }
        button.Count.fontSize, button.Count.height = 12, 12
        button.Name.font, button.Name.fontSize, button.Name.height = "Macro.ttf", 9, 9
        function button:UpdateHotkeys() self.HotKey:SetHeight(10) end
        return button
    end
    local buttons = { actionButton(), actionButton() }
    env.ActionBarButtonEventsFrame = { ForEachFrame = function(_, callback)
        for _, button in ipairs(buttons) do callback(button) end
    end, RegisterFrame = function(_, button) buttons[#buttons + 1] = button end }
    env.GameTooltip = frame()
    function env.GameTooltip:SetOwner(owner) self.owner = owner end
    function env.GameTooltip:IsOwned(owner) return self.owner == owner end
    function env.GameTooltip:AddLine(text) self.description = text end
    env.GetNumLootItems = function() return #slots end
    env.GetLootSlotType = function(i) return slots[i] and slots[i].kind or 0 end
    env.GetLootSlotInfo = function(i) return nil, nil, nil, nil, nil, slots[i].locked end
    env.LootSlot = function(i)
        requests[#requests + 1] = i
        if lootAction then lootAction(i) else slots[i].kind = 0 end
    end
    env.C_Timer = { NewTimer = function(delay, callback)
        local timer = { delay = delay, Cancel = function(self) self.cancelled = true end }
        timer.callback = function() timer.fired = true; callback() end
        timers[#timers + 1] = timer
        return timer
    end }
    local function emit(event, ...)
        if env.LootFrame.events[event] then env.LootFrame.OnEvent(env.LootFrame, event, ...) end
        local listeners = {}
        for _, f in ipairs(frames) do if f.events[event] then listeners[#listeners + 1] = f end end
        for _, f in ipairs(listeners) do f.scripts.OnEvent(f, event, ...) end
    end
    for _, file in ipairs({"Core.lua", "Modules/FastLoot.lua", "Modules/ActionBarFonts.lua", "Modules/CameraDistance.lua", "Modules/Questing.lua", "Modules/GossipSkip.lua", "Modules/AutoSellJunk.lua", "Modules/CombatIndicator.lua", "UI/Options.lua"}) do
        local chunk = assert(loadfile(root .. "/" .. file))
        setfenv(chunk, env)("Minn Tinkers WoWF", addon)
    end
    return {env = env, addon = addon, frames = frames, timers = timers, requests = requests,
        native = nativeCalls, messages = messages, emit = emit,
        buttons = buttons, newButton = actionButton, combat = function(value) combat = value end,
        camera = camera,
        flush = function(delay)
            local count = #timers
            for index = 1, count do
                local timer = timers[index]
                if timer.delay == delay and not timer.cancelled and not timer.fired then
                    timer.fired = true
                    timer.callback()
                end
            end
        end,
        slots = function(value) slots = value end, action = function(value) lootAction = value end,
        login = function() emit("ADDON_LOADED", "Minn Tinkers WoWF"); emit("PLAYER_LOGIN") end}
end
local function item(kind, locked) return { kind = kind or 1, locked = locked } end

local f = fixture({ fastAutoloot = false, extra = "preserved" }); f.login()
assert(f.env.MinnTinkersWoWFDB.fastAutoloot == false and f.env.MinnTinkersWoWFDB.extra == "preserved")
assert(f.env.LootFrame:IsEventRegistered("LOOT_OPENED"))
f.slots({item()}); f.emit("LOOT_READY", true); f.emit("LOOT_OPENED", true)
assert(#f.requests == 0 and #f.native == 1)

f = fixture(); f.login()
assert(f.env.MinnTinkersWoWFDB.fastAutoloot == true and not f.env.LootFrame:IsEventRegistered("LOOT_OPENED"))
f.slots({item(), item(2), item(3)})
f.emit("LOOT_READY", true); f.emit("LOOT_READY", true)
f.emit("LOOT_OPENED", true, true); f.emit("LOOT_OPENED", true, true)
assert(table.concat(f.requests, ",") == "3,2,1" and #f.native == 0 and #f.timers == 1)
f.addon.SetFastAutoloot(false)
assert(not f.env.LootFrame:IsEventRegistered("LOOT_OPENED"))
f.emit("LOOT_CLOSED")
assert(f.timers[1].cancelled and f.env.LootFrame:IsEventRegistered("LOOT_OPENED"))
f.slots({item()}); f.emit("LOOT_READY", true); f.emit("LOOT_OPENED", true)
assert(#f.requests == 3 and #f.native == 1)
f.addon.SetFastAutoloot(true); f.emit("LOOT_READY", true)
assert(#f.requests == 4)
f.emit("LOOT_CLOSED")

f = fixture(); f.login(); f.slots({item()})
f.emit("LOOT_READY", false); f.emit("LOOT_OPENED", false, true)
assert(#f.requests == 0 and f.native[1][2] == false and f.native[1][3] == true)
f.emit("LOOT_CLOSED")
f.slots({item(1, true)}); f.emit("LOOT_READY", true); f.emit("LOOT_OPENED", true)
f.timers[1].callback(); assert(#f.native == 2)
f.emit("UI_ERROR_MESSAGE", 1, "error"); assert(#f.native == 2)
f.emit("LOOT_CLOSED")

f = fixture(); f.login(); f.slots({item(), item()})
f.action(function() f.emit("LOOT_BIND_CONFIRM", 2) end)
f.emit("LOOT_READY", true); assert(#f.requests == 1 and #f.native == 0)
f.emit("LOOT_OPENED", true, true); assert(#f.native == 1 and #f.timers == 0)
f.emit("LOOT_CLOSED")

f = fixture(); f.login(); f.slots({item()}); f.action(function() end)
f.emit("LOOT_READY", true); f.emit("LOOT_OPENED", true)
f.emit("UI_ERROR_MESSAGE", 1, f.env.ERR_INV_FULL)
assert(#f.native == 1 and f.timers[1].cancelled)
f.emit("LOOT_CLOSED")
f = fixture(); f.login(); f.slots({item(), item()})
f.action(function() f.emit("LOOT_CLOSED") end)
f.emit("LOOT_READY", true); assert(#f.requests == 1 and #f.timers == 0)

f = fixture({fastAutoloot = false}); f.login()
f.env.LootFrame.shown = true
f.addon.SetFastAutoloot(true)
assert(f.env.LootFrame:IsEventRegistered("LOOT_OPENED"))
f.emit("LOOT_CLOSED") -- Native window can still be playing its closing animation.
assert(not f.env.LootFrame:IsEventRegistered("LOOT_OPENED"))
f.addon.SetFastAutoloot(false); assert(f.env.LootFrame:IsEventRegistered("LOOT_OPENED"))

f = fixture(); f.env.C_Timer = nil; f.login()
assert(f.env.LootFrame:IsEventRegistered("LOOT_OPENED") and #f.messages == 1)
f = fixture(); f.env.LootFrame:UnregisterEvent("LOOT_OPENED"); f.login()
f.emit("LOOT_READY", true); assert(#f.requests == 0 and #f.messages == 1)

f = fixture(); f.login(); assert(not f.env.MinnTinkersWoWFOptions)
f.env.SlashCmdList.MINNTINKERSWOWF()
local window, check = f.env.MinnTinkersWoWFOptions, f.env.MinnTinkersWoWFFastAutoloot
assert(window:IsShown() and window.title == "Minn Tinkers WoWF")
assert(window.portrait == f.addon.icon and window.selectedTab == 1 and window.numTabs == 2)
assert(window.Inset.children[1]:IsShown() and not window.Inset.children[2]:IsShown())
assert(f.env.UISpecialFrames[1] == window:GetName() and check:GetChecked())
check:SetChecked(false); check.scripts.OnClick(check)
assert(f.env.MinnTinkersWoWFDB.fastAutoloot == false and f.env.LootFrame:IsEventRegistered("LOOT_OPENED"))
check.scripts.OnEnter(check)
assert(f.env.GameTooltip:IsShown() and f.env.GameTooltip.description:find("Requires Auto Loot", 1, true))
f.env.SlashCmdList.MINNTINKERSWOWF()
assert(not window:IsShown() and not f.env.GameTooltip:IsShown())
local count = #f.frames
f.env.SlashCmdList.MINNTINKERSWOWF()
assert(#f.frames == count and not check:GetChecked())
local reload = fixture(f.env.MinnTinkersWoWFDB); reload.login()
assert(reload.env.LootFrame:IsEventRegistered("LOOT_OPENED"))

-- Independent sizes, no compounding, unchanged native fonts by default.
f = fixture(); f.login()
local fonts, button = f.addon.ActionBarFonts, f.buttons[1]
assert(button.HotKey.fontWrites == nil and button.Count.fontWrites == nil and button.Name.fontWrites == nil)
fonts.SetIncrease("keybinds", 4)
assert(select(2, button.HotKey:GetFont()) == 14 and button.HotKey:GetHeight() == 14)
assert(select(2, button.Count:GetFont()) == 12 and select(2, button.Name:GetFont()) == 9)
fonts.SetIncrease("itemCount", 3); fonts.SetIncrease("macroText", 5)
assert(select(2, button.Count:GetFont()) == 15 and select(2, button.Name:GetFont()) == 14)
assert(button.Name.font == "Macro.ttf" and button.Name.fontFlags == "OUTLINE")
local writes = button.HotKey.fontWrites
fonts.Apply(); fonts.Apply(); button:UpdateHotkeys()
assert(button.HotKey.fontWrites == writes and button.HotKey:GetHeight() == 14)

-- New buttons inherit changes. Reset restores native size and geometry.
local late = f.newButton()
f.env.ActionBarButtonEventsFrame:RegisterFrame(late)
assert(select(2, late.HotKey:GetFont()) == 14 and select(2, late.Name:GetFont()) == 14)
fonts.SetIncrease("keybinds", 0)
assert(select(2, button.HotKey:GetFont()) == 10 and button.HotKey:GetHeight() == 10)
assert(select(2, button.Count:GetFont()) == 15)

-- Secure-frame descendants are untouched during combat; latest setting wins.
f.combat(true); fonts.SetIncrease("itemCount", 8); fonts.SetIncrease("itemCount", 6)
button:UpdateHotkeys()
assert(select(2, button.Count:GetFont()) == 15)
local duringCombat = f.newButton()
f.env.ActionBarButtonEventsFrame:RegisterFrame(duringCombat)
assert(duringCombat.Name.fontWrites == nil)
f.combat(false); f.emit("PLAYER_REGEN_ENABLED")
assert(select(2, button.Count:GetFont()) == 18 and select(2, duringCombat.Name:GetFont()) == 14)
fonts.SetIncrease("macroText", 0)
assert(select(2, button.Name:GetFont()) == 9 and button.Name:GetHeight() == 9)

-- UI tabs and slider settings survive reopen and reload.
f.env.SlashCmdList.MINNTINKERSWOWF()
f.env.MinnTinkersWoWFOptionsTab2.scripts.OnClick(f.env.MinnTinkersWoWFOptionsTab2)
assert(f.env.MinnTinkersWoWFOptions.selectedTab == 2)
assert(not f.env.MinnTinkersWoWFOptions.Inset.children[1]:IsShown() and f.env.MinnTinkersWoWFOptions.Inset.children[2]:IsShown())
f.env.MinnTinkersWoWFFont_keybinds:SetValue(7)
assert(f.env.MinnTinkersWoWFDB.actionbarFonts.keybinds == 7 and select(2, button.HotKey:GetFont()) == 17)
f.env.MinnTinkersWoWFFont_itemCount:SetValue(2)
f.env.MinnTinkersWoWFFont_macroText:SetValue(3)
assert(select(2, button.HotKey:GetFont()) == 17 and select(2, button.Count:GetFont()) == 14 and select(2, button.Name:GetFont()) == 12)
f.env.SlashCmdList.MINNTINKERSWOWF(); f.env.SlashCmdList.MINNTINKERSWOWF()
assert(f.env.MinnTinkersWoWFFont_keybinds.value == 7)
reload = fixture(f.env.MinnTinkersWoWFDB); reload.login()
assert(select(2, reload.buttons[1].HotKey:GetFont()) == 17)
assert(select(2, reload.buttons[1].Count:GetFont()) == 14 and select(2, reload.buttons[1].Name:GetFont()) == 12)
f = fixture(); f.env.ActionBarButtonEventsFrame = nil; f.login()
assert(#f.messages == 1)

-- Camera slider changes only the supported limit, preserves native settings on first load.
f = fixture(); f.login()
assert(f.camera.value == 1.9 and f.camera.writes == 0 and f.env.MinnTinkersWoWFDB.cameraMaxFactor == nil)
f.env.SlashCmdList.MINNTINKERSWOWF()
local cameraSlider, resize = f.env.MinnTinkersWoWFCameraDistance, f.env.MinnTinkersWoWFResize
window = f.env.MinnTinkersWoWFOptions
assert(cameraSlider.value == 1.9 and cameraSlider.enabled and f.camera.writes == 0)
assert(window.resizable and window.width == 700 and window.height == 480)
assert(table.concat(resize.bounds, ",") == "560,420,1100,800")
cameraSlider:SetValue(2.6)
assert(f.camera.value == 2.6 and f.env.MinnTinkersWoWFDB.cameraMaxFactor == 2.6)
f.addon.CameraDistance.SetFactor(100); assert(f.camera.value == 2.6)
f.addon.CameraDistance.SetFactor(-1); assert(f.camera.value == 1)
f.camera.cap = 2.4
cameraSlider:SetValue(2.6)
assert(cameraSlider.value == 2.4 and f.env.MinnTinkersWoWFDB.cameraMaxFactor == 2.4)
f.camera.reject = true
assert(not f.addon.CameraDistance.SetFactor(2) and f.env.MinnTinkersWoWFDB.cameraMaxFactor == 2.4)
window:SetSize(850, 600); resize.resizeStopped(window)
assert(f.env.MinnTinkersWoWFDB.windowWidth == 850 and f.env.MinnTinkersWoWFDB.windowHeight == 600)
reload = fixture(f.env.MinnTinkersWoWFDB); reload.login(); reload.env.SlashCmdList.MINNTINKERSWOWF()
assert(reload.camera.value == 2.4 and reload.env.MinnTinkersWoWFOptions.width == 850 and reload.env.MinnTinkersWoWFOptions.height == 600)

-- Restricted/missing CVars remain untouched, and programmatic UI refresh does not write.
for _, restriction in ipairs({"locked", "secure", "readOnly"}) do
    f = fixture({cameraMaxFactor = 2.6}); f.camera[restriction] = true; f.login()
    assert(f.camera.writes == 0 and f.camera.value == 1.9 and #f.messages == 1)
    f.env.SlashCmdList.MINNTINKERSWOWF()
    assert(not f.env.MinnTinkersWoWFCameraDistance.enabled and f.camera.writes == 0)
end
f = fixture(); f.env.C_CVar = nil; f.login(); f.env.SlashCmdList.MINNTINKERSWOWF()
assert(not f.env.MinnTinkersWoWFCameraDistance.enabled)
f = fixture({windowWidth = 100, windowHeight = 900}); f.login(); f.env.SlashCmdList.MINNTINKERSWOWF()
assert(f.env.MinnTinkersWoWFOptions.width == 560 and f.env.MinnTinkersWoWFOptions.height == 800)
print("PASS: loot/font regressions, camera bounds/readback/persistence/restrictions, larger resizable window, saved size and UI refresh without writes")

local function questFixture(saved)
    local f = fixture(saved)
    local env = f.env
    local state = { id = 10, available = {}, active = {}, repeatable = {}, logs = {}, choices = {},
        shift = false, accepted = 0, completed = 0, rewarded = 0, selected = 0 }
    env.Enum.QuestFrequency = { Daily = 1, Weekly = 2 }
    env.QuestFrame = env.CreateFrame("Frame")
    env.QuestFrame:Show()
    env.IsShiftKeyDown = function() return state.shift end
    env.GetQuestID = function() return state.id end
    env.C_QuestLog = {
        IsRepeatableQuest = function(id) return state.repeatable[id] or false end,
        GetLogIndexForQuestID = function(id) return state.logs[id] and id end,
        GetInfo = function(id) return state.logs[id] end,
    }
    env.C_GossipInfo = {
        GetAvailableQuests = function() return state.available end,
        GetActiveQuests = function() return state.active end,
        SelectAvailableQuest = function(id) state.selected = id end,
        SelectActiveQuest = function(id) state.selected = id end,
    }
    env.GetNumAvailableQuests = function() return #state.available end
    env.GetNumActiveQuests = function() return #state.active end
    env.GetAvailableQuestInfo = function(index)
        local info = state.available[index]
        return false, info.frequency, info.repeatable, false, info.questID
    end
    env.GetActiveTitle = function(index) return "Quest", state.active[index].isComplete end
    env.GetActiveQuestID = function(index) return state.active[index].questID end
    env.SelectAvailableQuest = function(index) state.selected = state.available[index].questID end
    env.SelectActiveQuest = function(index) state.selected = state.active[index].questID end
    env.AcceptQuest = function() state.accepted = state.accepted + 1 end
    env.IsQuestCompletable = function() return state.completable ~= false end
    env.CompleteQuest = function() state.completed = state.completed + 1 end
    env.GetNumQuestChoices = function() return #state.choices end
    env.GetNumQuestRewards = function() return state.fixedRewards or 0 end
    env.GetQuestItemInfo = function(_, index) return "Reward", 1, state.choices[index].quantity end
    env.GetQuestItemLink = function(_, index) return state.choices[index].link end
    env.C_Item = { GetItemInfo = function(link)
        for _, choice in ipairs(state.choices) do
            if choice.link == link then return "Reward", link, 1, 1, 1, "", "", 1, "", 1, choice.price end
        end
    end }
    env.QuestInfoFrame = { rewardsFrame = { RewardButtons = {} }, itemChoice = 0 }
    env.QuestInfo_ShowRewards = function() env.QuestInfoFrame.itemChoice = 0 end
    env.QuestInfoItem_OnClick = function(button) env.QuestInfoFrame.itemChoice = button:GetID() end
    env.QuestRewardCompleteButton_OnClick = function()
        state.rewarded = state.rewarded + 1
        state.rewardIndex = env.QuestInfoFrame.itemChoice
        state.moneyConfirmation = state.moneyCost and true or false
    end
    local function choices(items)
        state.choices = items
        env.QuestInfoFrame.itemChoice = 0
        env.QuestInfoFrame.rewardsFrame.RewardButtons = {}
        for index in ipairs(items) do
            local button = env.CreateFrame("Button")
            button.type = "choice"; button:SetID(index); button:Show()
            env.QuestInfoFrame.rewardsFrame.RewardButtons[index] = button
        end
    end
    return f, state, choices
end

-- Preserve independent settings and skip unlimited repeatables in both quest list styles.
f, quest, choices = questFixture(); f.login()
assert(f.env.MinnTinkersWoWFDB.questing.autoAccept and f.env.MinnTinkersWoWFDB.questing.autoTurnIn)
assert(not f.env.MinnTinkersWoWFDB.questing.vendorReward)
quest.available = {{questID = 11, repeatable = true}, {questID = 12, repeatable = false}}
f.emit("GOSSIP_SHOW"); assert(quest.selected == 12)
quest.id = 12; f.emit("QUEST_DETAIL"); assert(quest.accepted == 1)
quest.id = 11; quest.repeatable[11] = true
f.emit("QUEST_DETAIL"); f.emit("QUEST_PROGRESS"); f.emit("QUEST_COMPLETE")
assert(quest.accepted == 1 and quest.completed == 0 and quest.rewarded == 0)
quest.available = {{questID = 13, repeatable = true, frequency = 1}}
f.emit("GOSSIP_SHOW"); assert(quest.selected == 13)
quest.id = 13; f.emit("QUEST_DETAIL"); assert(quest.accepted == 2)
quest.active = {{questID = 14, isComplete = true}, {questID = 15, isComplete = false}}
quest.logs[14] = {frequency = 2}; quest.repeatable[14] = true
f.emit("QUEST_GREETING"); assert(quest.selected == 14)
quest.id = 14; f.emit("QUEST_PROGRESS"); assert(quest.completed == 1)
quest.completable = false; f.emit("QUEST_PROGRESS"); assert(quest.completed == 1)
quest.active = {}; quest.available = {{questID = 11, repeatable = true}, {questID = 16, repeatable = false}}
f.emit("QUEST_GREETING"); assert(quest.selected == 16)

-- Opening with Shift latches manual behavior through this conversation.
f, quest = questFixture(); f.login(); quest.shift = true
f.emit("QUEST_DETAIL"); quest.shift = false
f.emit("QUEST_DETAIL"); f.emit("QUEST_PROGRESS"); f.emit("QUEST_COMPLETE")
assert(quest.accepted == 0 and quest.completed == 0 and quest.rewarded == 0)
f.env.QuestFrame:Hide(); f.emit("QUEST_FINISHED"); f.timers[#f.timers].callback()
f.env.QuestFrame:Show(); f.emit("QUEST_DETAIL"); assert(quest.accepted == 1)

-- A quest/gossip transition keeps Shift bypass latched while native NPC interaction continues.
f, quest = questFixture(); f.login()
f.env.Enum.PlayerInteractionType = { Gossip = 1, QuestGiver = 2 }
local interacting = true
f.env.C_PlayerInteractionManager = { IsInteractingWithNpcOfType = function() return interacting end }
quest.shift = true; f.emit("QUEST_DETAIL"); quest.shift = false
f.env.QuestFrame:Hide(); f.emit("QUEST_FINISHED"); f.timers[#f.timers].callback()
f.env.QuestFrame:Show(); f.emit("QUEST_DETAIL"); assert(quest.accepted == 0)
interacting = false; f.env.QuestFrame:Hide(); f.emit("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 2)
f.timers[#f.timers].callback(); f.env.QuestFrame:Show(); f.emit("QUEST_DETAIL")
assert(quest.accepted == 1)

-- Only quests without loot auto-complete; item rewards always require confirmation.
f, quest, choices = questFixture(); f.login()
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 1)
quest.fixedRewards = 1
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 1)
f.addon.Questing.SetOption("vendorReward", true)
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 1)
quest.fixedRewards = 0
f.addon.Questing.SetOption("vendorReward", false)
choices({{link = "item:a", quantity = 1, price = 20}})
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 1 and f.env.QuestInfoFrame.itemChoice == 0)
choices({{link = "item:a", quantity = 1, price = 20}, {link = "item:b", quantity = 3, price = 10}})
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 1 and f.env.QuestInfoFrame.itemChoice == 0)
f.addon.Questing.SetOption("vendorReward", true)
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 1 and f.env.QuestInfoFrame.itemChoice == 2)
-- The player can change the suggestion without automation claiming it.
f.env.QuestInfoItem_OnClick(f.env.QuestInfoFrame.rewardsFrame.RewardButtons[1])
f.emit("QUEST_ITEM_UPDATE")
assert(quest.rewarded == 1 and f.env.QuestInfoFrame.itemChoice == 1)
-- Equal prices select the first; zero vendor prices are valid.
choices({{link = "item:a", quantity = 1, price = 0}, {link = "item:b", quantity = 1, price = 0}})
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 1 and f.env.QuestInfoFrame.itemChoice == 1)
f.addon.Questing.SetOption("autoTurnIn", false)
choices({{link = "item:a", quantity = 1, price = 20}, {link = "item:b", quantity = 1, price = 10}})
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 1 and f.env.QuestInfoFrame.itemChoice == 1)
f.addon.Questing.SetOption("autoTurnIn", true)
choices({{link = "item:a", quantity = 1, price = 20}})
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 1 and f.env.QuestInfoFrame.itemChoice == 1)
choices({})
quest.moneyCost = true; f.emit("QUEST_COMPLETE"); assert(quest.moneyConfirmation)

-- Missing data waits on item events; Shift, timeout, close, or a manual selection cancels it.
local function missingPrices()
    local test, state, setChoices = questFixture(); test.login()
    test.addon.Questing.SetOption("vendorReward", true)
    setChoices({{link = "item:a", quantity = 1, price = 20}, {link = "item:b", quantity = 3}})
    test.emit("QUEST_COMPLETE")
    assert(state.rewarded == 0 and #test.timers == 1)
    return test, state
end
f, quest = missingPrices(); quest.choices[2].price = 10
f.emit("GET_ITEM_INFO_RECEIVED", 2, true)
assert(quest.rewarded == 0 and f.env.QuestInfoFrame.itemChoice == 2 and f.timers[1].cancelled)
f.emit("QUEST_ITEM_UPDATE"); assert(quest.rewarded == 0)
f, quest = missingPrices(); quest.shift = true; f.emit("MODIFIER_STATE_CHANGED")
quest.shift = false; quest.choices[2].price = 10; f.emit("GET_ITEM_INFO_RECEIVED")
assert(quest.rewarded == 0 and f.timers[1].cancelled)
f, quest = missingPrices(); f.timers[1].callback(); quest.choices[2].price = 10
f.emit("GET_ITEM_INFO_RECEIVED"); assert(quest.rewarded == 0)
f, quest = missingPrices(); f.emit("QUEST_FINISHED"); quest.choices[2].price = 10
f.emit("GET_ITEM_INFO_RECEIVED"); assert(quest.rewarded == 0)
f, quest = missingPrices()
f.env.QuestInfoItem_OnClick(f.env.QuestInfoFrame.rewardsFrame.RewardButtons[1])
quest.choices[2].price = 10; f.emit("GET_ITEM_INFO_RECEIVED")
assert(quest.rewarded == 0 and f.env.QuestInfoFrame.itemChoice == 1)
f, quest = missingPrices(); quest.id = 999; f.emit("GET_ITEM_INFO_RECEIVED")
assert(quest.rewarded == 0)

print("PASS: quest selection, repeatable exclusions, Shift bypass and reward regressions")

-- Removed module preferences are cleaned up without changing other saved settings.
f = fixture({popupProtection = {enabled = true}, extra = "preserved"}); f.login()
assert(f.env.MinnTinkersWoWFDB.popupProtection == nil and f.env.MinnTinkersWoWFDB.extra == "preserved")
f.env.SlashCmdList.MINNTINKERSWOWF()
assert(f.addon.PopupProtection == nil and f.env.MinnTinkersWoWFPopup_enabled == nil)

-- One shared toggle, minimap tooltip cleanup, tab persistence and unknown-tab fallback.
f = fixture()
f.env.Minimap = f.env.CreateFrame("Frame")
f.login()
assert(f.env.SLASH_MINNTINKERSWOWF1 == "/minn")
assert(f.env.SlashCmdList.MINNTINKERSWOWF == f.addon.ToggleOptions)
local minimap = assert(f.env.MinnTinkersWoWFMinimapButton)
assert(not f.env.MinnTinkersWoWFOptions)
minimap.scripts.OnEnter(minimap)
assert(f.env.GameTooltip:IsShown() and f.env.GameTooltip.description:find("/minn", 1, true))
minimap.scripts.OnLeave(minimap); assert(not f.env.GameTooltip:IsShown())
minimap.scripts.OnClick(minimap)
window = f.env.MinnTinkersWoWFOptions
assert(window:IsShown() and window.selectedTab == 1)
f.env.MinnTinkersWoWFOptionsTab2.scripts.OnClick(f.env.MinnTinkersWoWFOptionsTab2)
assert(f.env.MinnTinkersWoWFDB.lastTab == "UI")
minimap.scripts.OnClick(minimap); assert(not window:IsShown())
f.env.SlashCmdList.MINNTINKERSWOWF(); assert(window:IsShown() and window.selectedTab == 2)
reload = fixture(f.env.MinnTinkersWoWFDB); reload.login(); reload.env.SlashCmdList.MINNTINKERSWOWF()
assert(reload.env.MinnTinkersWoWFOptions.selectedTab == 2)
assert(reload.env.MinnTinkersWoWFOptions.Inset.children[2]:IsShown())
f = fixture({lastTab = "Removed category"}); f.login(); f.env.SlashCmdList.MINNTINKERSWOWF()
assert(f.env.MinnTinkersWoWFOptions.selectedTab == 1 and f.env.MinnTinkersWoWFDB.lastTab == "Universal")
print("PASS: /minn and minimap share one lazy window; tooltip cleanup, tab reopen/reload persistence and invalid-tab fallback")

-- Drag geometry follows the real minimap radius and scaled cursor, then stops updating.
f = fixture()
f.env.Minimap = f.env.CreateFrame("Frame")
f.env.Minimap:SetSize(198, 198)
f.env.Minimap.centerX, f.env.Minimap.centerY, f.env.Minimap.scale = 300, 200, 0.8
local cursorX, cursorY = 320, 160
f.env.GetCursorPosition = function() return cursorX, cursorY end
f.login()
minimap = f.env.MinnTinkersWoWFMinimapButton
assert(minimap.scripts.OnUpdate == nil)
minimap.scripts.OnDragStart(minimap); minimap.scripts.OnUpdate(minimap)
assert(math.abs(f.env.MinnTinkersWoWFDB.minimapAngle) < 0.0001)
assert(math.abs(minimap.point[4] - 104) < 0.0001 and math.abs(minimap.point[5]) < 0.0001)
cursorX, cursorY = 240, 240
minimap.scripts.OnUpdate(minimap)
assert(math.abs(f.env.MinnTinkersWoWFDB.minimapAngle - 90) < 0.0001)
assert(math.abs(minimap.point[4]) < 0.0001 and math.abs(minimap.point[5] - 104) < 0.0001)
minimap.scripts.OnDragStop(minimap); assert(minimap.scripts.OnUpdate == nil)
reload = fixture(f.env.MinnTinkersWoWFDB)
reload.env.Minimap = reload.env.CreateFrame("Frame"); reload.env.Minimap:SetSize(198, 198)
reload.login()
assert(math.abs(reload.env.MinnTinkersWoWFMinimapButton.point[5] - 104) < 0.0001)
minimap.scripts.OnDragStart(minimap); minimap:Hide(); minimap.scripts.OnHide(minimap)
assert(minimap.scripts.OnUpdate == nil)
print("PASS: scaled minimap drag geometry, saved angle restoration, and drag-stop/hide cleanup without idle updates")

-- Counts and macro labels must never inspect or change secret layout geometry.
f = fixture(); f.login()
local action = f.buttons[1]
action.Count.GetHeight = function() error("Count height must remain unread") end
action.Count.SetHeight = function() error("Count height must remain untouched") end
action.Name.GetHeight = function() error("Macro height must remain unread") end
action.Name.SetHeight = function() error("Macro height must remain untouched") end
f.addon.ActionBarFonts.SetIncrease("itemCount", 5)
f.addon.ActionBarFonts.SetIncrease("macroText", 4)
assert(select(2, action.Count:GetFont()) == 17 and select(2, action.Name:GetFont()) == 13)
f.addon.ActionBarFonts.SetIncrease("itemCount", 0)
f.addon.ActionBarFonts.SetIncrease("macroText", 0)
assert(select(2, action.Count:GetFont()) == 12 and select(2, action.Name:GetFont()) == 9)

-- Opaque mock tokens test guard paths; Lua 5.1 cannot produce real secret numbers.
f = fixture(); f.login()
local secret = setmetatable({}, {__add = function() error("Secret arithmetic") end,
    __lt = function() error("Secret comparison") end, __le = function() error("Secret comparison") end})
f.env.issecretvalue = function(value) return rawequal(value, secret) end
action = f.buttons[1]
local secretHeight = false
local originalHeight = action.HotKey.GetHeight
action.HotKey.GetHeight = function(self) if secretHeight then return secret end; return originalHeight(self) end
f.addon.ActionBarFonts.SetIncrease("keybinds", 3)
secretHeight = true
local writes = 0
action.HotKey.SetHeight = function() writes = writes + 1 end
f.addon.ActionBarFonts.SetIncrease("keybinds", 4)
assert(select(2, action.HotKey:GetFont()) == 14 and writes == 0)
local lateSecret = f.newButton()
lateSecret.HotKey.GetHeight = function() return secret end
lateSecret.HotKey.SetHeight = function() error("Secret height must remain untouched") end
lateSecret.Count.GetFont = function() return "Native.ttf", secret, "OUTLINE" end
lateSecret.Count.SetFont = function() error("Secret baseline must be skipped") end
f.addon.ActionBarFonts.SetIncrease("itemCount", 3)
f.env.ActionBarButtonEventsFrame:RegisterFrame(lateSecret)
assert(select(2, lateSecret.HotKey:GetFont()) == 14)
print("PASS: count/macro geometry untouched, secret keybind heights skipped, secret font baselines skipped")


-- Persistent glow follows combat events, supports live changes, and restores preferences.
f = fixture(); f.login()
local glow = assert(f.env.MinnTinkersWoWFCombatGlow)
assert(not glow:IsShown() and glow.alpha == 0.25 and glow.scripts.OnUpdate == nil)
f.combat(true); f.emit("PLAYER_REGEN_DISABLED"); assert(glow:IsShown())
f.addon.CombatIndicator.SetOption("opacity", 40); assert(glow.alpha == 0.4 and glow:IsShown())
f.addon.CombatIndicator.SetOption("width", 30); assert(f.addon.CombatIndicator.GetWidth() == 30)
f.addon.CombatIndicator.SetOption("enabled", false); assert(not glow:IsShown())
f.addon.CombatIndicator.SetOption("enabled", true); assert(glow:IsShown())
f.combat(false); f.emit("PLAYER_REGEN_ENABLED"); assert(not glow:IsShown())
reload = fixture(f.env.MinnTinkersWoWFDB); reload.combat(true); reload.login()
assert(reload.env.MinnTinkersWoWFCombatGlow:IsShown() and reload.env.MinnTinkersWoWFCombatGlow.alpha == 0.4)
reload.env.SlashCmdList.MINNTINKERSWOWF()
assert(reload.env.MinnTinkersWoWFCombat_enabled:GetChecked())
assert(reload.env.MinnTinkersWoWFCombat_opacity.value == 40 and reload.env.MinnTinkersWoWFCombat_width.value == 30)
f = fixture({combatIndicator = {enabled = false, opacity = 25, width = 20}}); f.combat(true); f.login()
assert(not f.env.MinnTinkersWoWFCombatGlow:IsShown())
f.addon.CombatIndicator.SetOption("opacity", 100); assert(f.addon.CombatIndicator.GetOpacity() == 60)
f.addon.CombatIndicator.SetOption("width", -10); assert(f.addon.CombatIndicator.GetWidth() == 8)
print("PASS: combat enter/leave, live enable/opacity/width, combat reload, saved controls and bounds without polling")


-- Gossip skips only a sole usable option, with no quests, without bypassing confirmations.
local function gossipFixture(saved)
    local test = fixture(saved)
    local env = test.env
    local state = {options = {{gossipOptionID = 42, status = 0}}, available = {}, active = {}, shift = false, selected = {}}
    env.GossipFrame = env.CreateFrame("Frame"); env.GossipFrame:Show()
    env.Enum.GossipOptionStatus = {Available = 0, Unavailable = 1, Locked = 2, AlreadyComplete = 3}
    env.IsShiftKeyDown = function() return state.shift end
    env.C_GossipInfo = {
        GetOptions = function() return state.options end,
        GetAvailableQuests = function() return state.available end,
        GetActiveQuests = function() return state.active end,
        SelectOption = function(...)
            assert(select("#", ...) == 1, "Must preserve native confirmation")
            state.selected[#state.selected + 1] = (...)
        end,
    }
    test.login()
    return test, state
end
f, gossip = gossipFixture(); f.emit("GOSSIP_SHOW")
assert(#gossip.selected == 1 and gossip.selected[1] == 42)
f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 1)
gossip.options[1].gossipOptionID = 43; f.emit("GOSSIP_SHOW"); assert(gossip.selected[2] == 43)
f.emit("GOSSIP_CLOSED"); f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 3)
f, gossip = gossipFixture(); gossip.options[2] = {gossipOptionID = 43, status = 0}
f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 0)
gossip.options = {}; f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 0)
for _, status in ipairs({1, 2, 3}) do
    f, gossip = gossipFixture(); gossip.options[1].status = status
    f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 0)
end
for _, key in ipairs({"available", "active"}) do
    f, gossip = gossipFixture(); gossip[key] = {{questID = 1}}
    f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 0)
end
f, gossip = gossipFixture(); gossip.shift = true; f.emit("GOSSIP_SHOW")
gossip.shift = false; f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 0)
f.emit("GOSSIP_CLOSED"); f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 1)
f, gossip = gossipFixture({skipSingleGossip = false}); f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 0)
f.env.SlashCmdList.MINNTINKERSWOWF(); assert(not f.env.MinnTinkersWoWFGossipSkip:GetChecked())
f.addon.GossipSkip.SetEnabled(true); f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 1)
reload, gossip = gossipFixture(f.env.MinnTinkersWoWFDB); reload.emit("GOSSIP_SHOW"); assert(#gossip.selected == 1)
print("PASS: sole gossip option, quest/multiple/locked exclusions, Shift bypass, repeat-loop guard, native confirmations and saved toggle")


-- Sell from carried bags after the merchant opens; filter quality/locks/value strictly.
local function merchantFixture(saved)
    local test = fixture(saved)
    local env = test.env
    local state = {shift = false, sales = {}, excluded = {}, capacity = {[0] = 5, [4] = 1}, bags = {
        [0] = {{quality = 0, isLocked = false, hasNoValue = false},
            {quality = 1, isLocked = false, hasNoValue = false},
            {quality = 0, isLocked = true, hasNoValue = false},
            {quality = 0, isLocked = false, hasNoValue = true},
            {isLocked = false, hasNoValue = false}},
        [4] = {{quality = 0, isLocked = false, hasNoValue = false}},
    }}
    for bag, items in pairs(state.bags) do
        for slot, value in ipairs(items) do value.itemID = bag * 100 + slot end
    end
    env.MerchantFrame = env.CreateFrame("Frame")
    env.Enum.BagIndex = {Backpack = 0}; env.Enum.ItemQuality = {Poor = 0}
    env.Enum.BagSlotFlags = {ExcludeJunkSell = 64}
    env.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4
    env.IsShiftKeyDown = function() return state.shift end
    env.C_Container = {
        GetContainerNumSlots = function(bag) return state.capacity[bag] or 0 end,
        GetContainerItemInfo = function(bag, slot) return state.bags[bag][slot] end,
        GetBackpackSellJunkDisabled = function() return state.excluded[0] or false end,
        GetBagSlotFlag = function(bag, flag)
            assert(flag == env.Enum.BagSlotFlags.ExcludeJunkSell)
            return state.excluded[bag] or false
        end,
        UseContainerItem = function(bag, slot)
            assert(env.MerchantFrame:IsShown(), "Must not use items outside vendor")
            state.sales[#state.sales + 1] = bag .. ":" .. slot
            state.bags[bag][slot] = nil
        end,
    }
    test.login()
    local function open()
        test.emit("MERCHANT_SHOW")
        env.MerchantFrame:Show()
        test.flush(0)
    end
    return test, state, open
end
f, vendor, open = merchantFixture(); open()
assert(table.concat(vendor.sales, ",") == "0:1,4:1")
f.emit("MERCHANT_SHOW"); f.emit("MERCHANT_UPDATE"); assert(#vendor.sales == 2)
f.emit("MERCHANT_CLOSED"); open(); assert(#vendor.sales == 2)
f, vendor, open = merchantFixture(); vendor.shift = true; open(); assert(#vendor.sales == 0)
vendor.shift = false; f.emit("MERCHANT_SHOW"); assert(#vendor.sales == 0)
f.emit("MERCHANT_CLOSED"); open(); assert(#vendor.sales == 2)
f, vendor, open = merchantFixture({autoSellJunk = false}); open(); assert(#vendor.sales == 0)
f.addon.AutoSellJunk.SetEnabled(true); f.emit("MERCHANT_SHOW"); assert(#vendor.sales == 0)
f.emit("MERCHANT_CLOSED"); open(); assert(#vendor.sales == 2)
f.addon.AutoSellJunk.SetEnabled(false)
reload, vendor, open = merchantFixture(f.env.MinnTinkersWoWFDB); open(); assert(#vendor.sales == 0)
reload.env.SlashCmdList.MINNTINKERSWOWF(); assert(not reload.env.MinnTinkersWoWFAutoSellJunk:GetChecked())
f, vendor = merchantFixture(); f.emit("MERCHANT_SHOW"); f.emit("MERCHANT_CLOSED")
assert(f.timers[1].cancelled and #vendor.sales == 0)
f, vendor = merchantFixture(); f.emit("MERCHANT_SHOW"); f.timers[1].callback(); assert(#vendor.sales == 0)
f, vendor, open = merchantFixture()
local secret = {}; f.env.issecretvalue = function(value) return rawequal(value, secret) end
vendor.bags[0][1].quality = secret; vendor.bags[4][1].isLocked = secret
open(); assert(#vendor.sales == 0)
f = fixture(); f.login(); f.env.SlashCmdList.MINNTINKERSWOWF()
assert(not f.env.MinnTinkersWoWFAutoSellJunk.enabled)
print("PASS: delayed merchant readiness, grey-only carried-bag sales, locked/valueless/unknown/secret exclusions, Shift/disabled/closed bypass and saved toggle")

-- Audit regressions: unrelated errors do not expose automatic loot.
do
    local test = fixture(); test.login(); test.slots({item()}); test.action(function() end)
    test.emit("LOOT_READY", true); test.emit("LOOT_OPENED", true)
    test.emit("UI_ERROR_MESSAGE", 999, "Spell is not ready yet")
    assert(#test.native == 0 and not test.timers[1].cancelled)
    local secret = {}; test.env.issecretvalue = function(value) return rawequal(value, secret) end
    test.emit("UI_ERROR_MESSAGE", 999, secret)
    assert(#test.native == 0)
    test.emit("UI_ERROR_MESSAGE", 1, test.env.ERR_INV_FULL)
    assert(#test.native == 1 and test.timers[1].cancelled)
end
print("PASS: unrelated UI errors preserve fast loot; full bags restore native loot")

-- Native reward rendering clears itemChoice; the post-hook restores only addon suggestions.
do
    local test, state, rewards = questFixture(); test.login()
    test.env.QuestFrame:Hide(); state.shift = true
    test.emit("QUEST_ITEM_UPDATE"); test.emit("GET_ITEM_INFO_RECEIVED")
    state.shift = false; test.env.QuestFrame:Show(); test.emit("QUEST_DETAIL")
    assert(state.accepted == 1, "Background events must not latch a manual session")
    test.addon.Questing.SetOption("vendorReward", true)
    rewards({{link = "cheap", quantity = 1, price = 1}, {link = "expensive", quantity = 1, price = 10}})
    test.emit("QUEST_COMPLETE"); assert(test.env.QuestInfoFrame.itemChoice == 2)
    test.env.QuestInfo_ShowRewards(); assert(test.env.QuestInfoFrame.itemChoice == 2)
    test.env.QuestInfoFrame.questLog = true; test.env.QuestInfo_ShowRewards()
    assert(test.env.QuestInfoFrame.itemChoice == 0, "Do not select rewards on quest-log panels")
    test.env.QuestInfoFrame.questLog = false; test.env.QuestInfo_ShowRewards()
    assert(test.env.QuestInfoFrame.itemChoice == 2)
    test.emit("QUEST_ITEM_UPDATE"); assert(state.rewarded == 0)
    test.env.QuestInfoItem_OnClick(test.env.QuestInfoFrame.rewardsFrame.RewardButtons[1])
    test.env.QuestInfo_ShowRewards(); test.emit("QUEST_ITEM_UPDATE")
    assert(test.env.QuestInfoFrame.itemChoice == 0, "Never override a player's choice after native refresh")
    test.emit("QUEST_COMPLETE"); state.shift = true; test.emit("MODIFIER_STATE_CHANGED")
    state.shift = false; test.env.QuestInfo_ShowRewards()
    assert(test.env.QuestInfoFrame.itemChoice == 0 and state.rewarded == 0)
    local pending, missing = missingPrices()
    pending.env.QuestInfo_ShowRewards(); assert(#pending.timers == 1)
    missing.choices[2].price = 10; pending.emit("GET_ITEM_INFO_RECEIVED", 2, true)
    pending.env.QuestInfo_ShowRewards()
    assert(pending.env.QuestInfoFrame.itemChoice == 2 and pending.timers[1].cancelled)
    pending.env.QuestFrame:Hide(); pending.emit("QUEST_FINISHED"); pending.flush(0)
    pending.env.QuestInfo_ShowRewards(); assert(pending.env.QuestInfoFrame.itemChoice == 0)
end
print("PASS: background quest events, native reward refresh, manual choice, Shift and close cancellation")

-- Gossip may be shown in a later native interaction transition.
do
    local test, state = gossipFixture(); test.env.GossipFrame:Hide()
    test.emit("GOSSIP_SHOW"); assert(#state.selected == 0)
    test.env.GossipFrame:Show(); test.flush(0)
    assert(#state.selected == 1)
    test, state = gossipFixture(); test.env.GossipFrame:Hide()
    test.emit("GOSSIP_SHOW"); test.flush(0); assert(#state.selected == 0)
    test.env.GossipFrame:Show(); test.flush(0); assert(#state.selected == 1)
    test, state = gossipFixture(); test.env.GossipFrame:Hide(); state.shift = true
    test.emit("GOSSIP_SHOW"); state.shift = false; test.env.GossipFrame:Show(); test.flush(0)
    assert(#state.selected == 0)
    test, state = gossipFixture(); test.env.GossipFrame:Hide()
    test.emit("GOSSIP_SHOW"); test.emit("GOSSIP_CLOSED"); test.env.GossipFrame:Show(); test.flush(0)
    assert(#state.selected == 0 and test.timers[1].cancelled)
    test, state = gossipFixture(); test.env.GossipFrame:Hide()
    test.emit("GOSSIP_SHOW"); test.addon.GossipSkip.SetEnabled(false)
    test.env.GossipFrame:Show(); test.flush(0); assert(#state.selected == 0)
end
print("PASS: late gossip visibility, delayed show, opening Shift, close and disable cancellation")

-- Availability is reflected by controls, and font changes visit only the affected category.
do
    local test = fixture(); test.env.ActionBarButtonEventsFrame = nil; test.login()
    test.addon.ToggleOptions()
    for _, name in ipairs({"MinnTinkersWoWFFont_keybinds", "MinnTinkersWoWFFont_itemCount",
        "MinnTinkersWoWFFont_macroText", "MinnTinkersWoWFQuest_autoAccept", "MinnTinkersWoWFQuest_autoTurnIn",
        "MinnTinkersWoWFQuest_vendorReward", "MinnTinkersWoWFGossipSkip"}) do
        assert(test.env[name].enabled == false, name .. " must be disabled when unavailable")
    end
    test = questFixture(); test.login(); test.addon.ToggleOptions()
    assert(test.env.MinnTinkersWoWFQuest_autoAccept.enabled)
    test = gossipFixture(); test.addon.ToggleOptions(); assert(test.env.MinnTinkersWoWFGossipSkip.enabled)
    test = fixture({actionbarFonts = {keybinds = 1, itemCount = 1, macroText = 1}}); test.login()
    local reads = 0
    for _, button in ipairs(test.buttons) do
        for _, region in ipairs({"Count", "Name"}) do
            local text, original = button[region], button[region].GetFont
            text.GetFont = function(self) reads = reads + 1; return original(self) end
        end
    end
    test.addon.ActionBarFonts.SetIncrease("keybinds", 6)
    test.buttons[1]:UpdateHotkeys()
    assert(reads == 0, "Keybind changes must not inspect count or macro fonts")
    test.camera.cap = 0.8; assert(test.addon.CameraDistance.SetFactor(2.6))
    assert(test.env.MinnTinkersWoWFDB.cameraMaxFactor == 0.8 and test.addon.CameraDistance.GetFactor() == 0.8)
end
print("PASS: unavailable controls, independent font updates and unclamped accepted camera readback")

-- Merchant retries are event-driven, limited to original skipped slots, and bounded.
do
    local test, state, visit = merchantFixture()
    state.excluded[0], state.excluded[4] = true, true
    visit(); assert(#state.sales == 0 and #test.timers == 1)
    test, state, visit = merchantFixture(); visit()
    assert(#state.sales == 2 and #test.timers == 2)
    local timers = #test.timers
    test.emit("ITEM_LOCK_CHANGED", 0, 2); assert(#test.timers == timers)
    state.bags[0][3].isLocked = false; state.bags[0][5].quality = 0
    test.emit("ITEM_LOCK_CHANGED", 0, 3); test.emit("GET_ITEM_INFO_RECEIVED", 5, true)
    assert(#test.timers == timers + 1, "Coalesce simultaneous retry events")
    test.flush(0); assert(#state.sales == 4 and test.timers[2].cancelled)
    test.emit("BAG_UPDATE_DELAYED"); test.flush(0); assert(#state.sales == 4)
    assert(state.bags[0][1] == nil and state.bags[0][3] == nil and state.bags[0][5] == nil)

    test, state, visit = merchantFixture(); visit(); test.flush(3)
    state.bags[0][3].isLocked = false; test.emit("ITEM_LOCK_CHANGED", 0, 3); test.flush(0)
    assert(#state.sales == 2, "No retries after the three-second window")
    test, state, visit = merchantFixture(); visit()
    state.bags[0][3].itemID = 999; state.bags[0][3].isLocked = false
    test.emit("ITEM_LOCK_CHANGED", 0, 3); test.flush(0); assert(#state.sales == 2)
    test, state, visit = merchantFixture(); visit()
    state.excluded[0] = true; state.bags[0][3].isLocked = false
    test.emit("ITEM_LOCK_CHANGED", 0, 3); test.flush(0)
    assert(#state.sales == 2 and test.timers[2].cancelled)
    test, state, visit = merchantFixture(); visit()
    state.bags[0][3].isLocked = false; test.emit("ITEM_LOCK_CHANGED", 0, 3)
    test.addon.AutoSellJunk.SetEnabled(false); test.flush(0)
    assert(#state.sales == 2 and test.timers[2].cancelled and test.timers[3].cancelled)
    test, state, visit = merchantFixture(); visit()
    state.bags[0][3].isLocked = false; test.emit("ITEM_LOCK_CHANGED", 0, 3)
    test.emit("MERCHANT_CLOSED"); test.flush(0); assert(#state.sales == 2)
    test, state, visit = merchantFixture(); visit()
    state.bags[0][3].isLocked = false; state.shift = true
    test.emit("ITEM_LOCK_CHANGED", 0, 3); test.flush(0)
    state.shift = false; test.emit("ITEM_LOCK_CHANGED", 0, 3); test.flush(0); assert(#state.sales == 2)

    test, state = merchantFixture(); test.emit("MERCHANT_SHOW"); test.flush(0)
    assert(#state.sales == 0)
    test.env.MerchantFrame:Show(); test.flush(0); assert(#state.sales == 2)
    test, state = merchantFixture(); state.shift = true; test.emit("MERCHANT_SHOW")
    state.shift = false; test.env.MerchantFrame:Show(); test.flush(0); assert(#state.sales == 0)
    test, state, visit = merchantFixture()
    local secret = {}; test.env.issecretvalue = function(value) return rawequal(value, secret) end
    state.excluded[0], state.excluded[4] = secret, secret; visit(); assert(#state.sales == 0)
    test, state, visit = merchantFixture()
    local useItem = test.env.C_Container.UseContainerItem
    test.env.C_Container.UseContainerItem = function(bag, slot)
        useItem(bag, slot); test.emit("MERCHANT_CLOSED")
    end
    visit(); assert(#state.sales == 1 and #test.timers == 1)
end
print("PASS: excluded bags, real inventory removal, bounded skipped-item retries, identity checks and cancellation")
