local root = assert(arg[1], "Pass the addon directory")
local function fixture(saved, characterSaved)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local frames, timers, requests, nativeCalls, messages = {}, {}, {}, {}, {}
    local slots, lootAction = {}, nil
    local addon = {}
    local combat = false
    local camera = { value = 1.9, cap = 4.0, writes = 0 }
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
    env.UnitClass = function() return "Hunter", "HUNTER" end
    env.MinnTinkersWoWFDB = saved
    env.MinnTinkersWoWFCharDB = characterSaved
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
        function f:GetFontString()
            if not self.fontString then self.fontString = frame() end
            return self.fontString
        end
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
        function f:GetText() return self.text or "" end
        function f:SetAutoFocus(value) self.autoFocus = value end
        function f:SetMaxLetters(value) self.maxLetters = value end
        function f:SetMaxLines(value) self.maxLines = value end
        function f:SetFocus() self.focus = true end
        function f:ClearFocus() self.focus = false end
        function f:SetFontHeight(value) self.fontSize = value end
        function f:SetTextColor(...) self.color = {...} end
        function f:SetTexture(value) self.texture = value end
        function f:GetStringWidth() return #self.text * 7 end
        function f:SetChecked(value) self.checked = value end
        function f:GetChecked() return self.checked end
        function f:CreateFontString(name)
            local text = frame(name)
            self.fontStrings = self.fontStrings or {}
            self.fontStrings[#self.fontStrings + 1] = text
            if name then env[name] = text end
            return text
        end
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
        f.template, f.parent = template, parent
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
    for _, file in ipairs({"Core.lua", "Modules/FastLoot.lua", "Modules/ActionBarFonts.lua", "Modules/CameraDistance.lua", "Modules/Questing.lua", "Modules/GossipSkip.lua", "Modules/AutoSellJunk.lua", "Modules/CombatIndicator.lua", "Modules/ChatURLs.lua", "Modules/ChatInput.lua", "Modules/ChatTools.lua", "Modules/RangeIndicator.lua", "Modules/PetHappinessBar.lua", "UI/Options.lua"}) do
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
assert(window.portrait == f.addon.icon and window.selectedTab == 1 and window.numTabs == 3)
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
assert(window.resizable and window.width == 700 and window.height == 670)
assert(table.concat(resize.bounds, ",") == "560,670,1100,800")
assert(f.addon.CameraDistance.max == 4.0)
cameraSlider:SetValue(4.0)
assert(f.camera.value == 4.0 and f.env.MinnTinkersWoWFDB.cameraMaxFactor == 4.0)
local cameraReload = fixture(f.env.MinnTinkersWoWFDB); cameraReload.login()
assert(cameraReload.camera.value == 4.0)
f.addon.CameraDistance.SetFactor(100); assert(f.camera.value == 4.0)
f.addon.CameraDistance.SetFactor(-1); assert(f.camera.value == 1)
f.camera.cap = 2.4
cameraSlider:SetValue(4.0)
assert(cameraSlider.value == 2.4 and f.env.MinnTinkersWoWFDB.cameraMaxFactor == 2.4)
f.camera.reject = true
assert(not f.addon.CameraDistance.SetFactor(2) and f.env.MinnTinkersWoWFDB.cameraMaxFactor == 2.4)
window:SetSize(850, 600); resize.resizeStopped(window)
assert(f.env.MinnTinkersWoWFDB.windowWidth == 850 and f.env.MinnTinkersWoWFDB.windowHeight == 600)
reload = fixture(f.env.MinnTinkersWoWFDB); reload.login(); reload.env.SlashCmdList.MINNTINKERSWOWF()
assert(reload.camera.value == 2.4 and reload.env.MinnTinkersWoWFOptions.width == 850 and reload.env.MinnTinkersWoWFOptions.height == 670)

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
        if #state.choices == 1 then env.QuestInfoFrame.itemChoice = 1 end
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

-- Zero/one choices auto-complete, including fixed rewards; multiple choices stay manual.
f, quest, choices = questFixture(); f.login()
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 1)
quest.fixedRewards = 1
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 2)
f.addon.Questing.SetOption("vendorReward", true)
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 3)
quest.fixedRewards = 0
f.addon.Questing.SetOption("vendorReward", false)
choices({{link = "item:a", quantity = 1, price = 20}})
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 4 and quest.rewardIndex == 1)
choices({{link = "item:a", quantity = 1, price = 20}, {link = "item:b", quantity = 3, price = 10}})
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 4 and f.env.QuestInfoFrame.itemChoice == 0)
f.addon.Questing.SetOption("vendorReward", true)
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 4 and f.env.QuestInfoFrame.itemChoice == 2)
-- The player can change the suggestion without automation claiming it.
f.env.QuestInfoItem_OnClick(f.env.QuestInfoFrame.rewardsFrame.RewardButtons[1])
f.emit("QUEST_ITEM_UPDATE")
assert(quest.rewarded == 4 and f.env.QuestInfoFrame.itemChoice == 1)
-- Equal prices select the first; zero vendor prices are valid.
choices({{link = "item:a", quantity = 1, price = 0}, {link = "item:b", quantity = 1, price = 0}})
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 4 and f.env.QuestInfoFrame.itemChoice == 1)
f.addon.Questing.SetOption("autoTurnIn", false)
choices({{link = "item:a", quantity = 1, price = 20}, {link = "item:b", quantity = 1, price = 10}})
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 4 and f.env.QuestInfoFrame.itemChoice == 1)
f.addon.Questing.SetOption("autoTurnIn", true)
choices({{link = "item:a", quantity = 1, price = 20}})
f.emit("QUEST_COMPLETE"); assert(quest.rewarded == 5 and quest.rewardIndex == 1)
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

-- Choice thresholds preserve both toggles, bypasses and native money confirmation.
do
    for _, autoTurnIn in ipairs({false, true}) do
        for _, vendorReward in ipairs({false, true}) do
            for count = 0, 3 do
                local test, state, setChoices = questFixture({questing = {autoTurnIn = autoTurnIn, vendorReward = vendorReward}})
                test.login()
                local items = {}
                for index = 1, count do items[index] = {link = "item:" .. index, quantity = 1, price = index} end
                setChoices(items)
                state.fixedRewards = 2
                test.emit("QUEST_COMPLETE")
                local expected = autoTurnIn and count <= 1 and 1 or 0
                assert(state.rewarded == expected, "Auto turn-in threshold must depend on choices, independently of vendor selection")
                local selection = count > 0 and (vendorReward or autoTurnIn and count == 1) and count or 0
                assert(test.env.QuestInfoFrame.itemChoice == selection)
                test.env.QuestInfo_ShowRewards(); test.emit("QUEST_ITEM_UPDATE"); test.emit("GET_ITEM_INFO_RECEIVED")
                assert(state.rewarded == expected, "Reward refreshes must not submit again")
            end
        end
    end
    local test, state, setChoices = questFixture(); test.login()
    setChoices({{link = "uncached"}})
    test.env.C_Item.GetItemInfo = function() error("A sole choice must not need a vendor price") end
    state.moneyCost = true
    test.emit("QUEST_COMPLETE")
    assert(state.rewarded == 1 and state.rewardIndex == 1 and state.moneyConfirmation and #test.timers == 0)
    test, state, setChoices = questFixture(); test.login()
    setChoices({{link = "single"}}); state.shift = true
    test.emit("QUEST_COMPLETE"); assert(state.rewarded == 0)
    state.shift = false; test.emit("QUEST_ITEM_UPDATE"); assert(state.rewarded == 0)
    test, state, setChoices = questFixture(); test.login()
    setChoices({{link = "single"}}); state.repeatable[state.id] = true
    test.emit("QUEST_COMPLETE"); assert(state.rewarded == 0)
    state.logs[state.id] = {frequency = test.env.Enum.QuestFrequency.Daily}
    test.emit("QUEST_COMPLETE"); assert(state.rewarded == 1)
end
print("PASS: zero/one/two/three choices, fixed rewards, independent toggles, uncached sole reward, no duplicate submission, Shift, repeatables and native confirmations")

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

local function chatFixture(saved)
    local test = fixture(saved)
    local env = test.env
    local filters, handlers, popups = {}, {}, {}
    env.canaccessvalue = function() return true end
    env.CLOSE = "Close"
    env.StaticPopupDialogs = {}
    env.ChatFrameUtil = {
        AddMessageEventFilter = function(event, callback)
            assert(not filters[event], "Duplicate chat filter")
            filters[event] = callback
        end,
        RemoveMessageEventFilter = function(event, callback)
            assert(filters[event] == callback)
            filters[event] = nil
        end,
    }
    env.LinkUtil = {
        FormatLink = function(kind, text, url) return "|H" .. kind .. ":" .. url .. "|h" .. text .. "|h" end,
        IsLinkHandlerRegistered = function(kind) return handlers[kind] ~= nil end,
        RegisterLinkHandler = function(kind, callback)
            assert(not handlers[kind], "Duplicate link handler")
            handlers[kind] = callback
        end,
    }
    local editBox = {
        SetText = function(self, text) self.text = text end,
        SetFocus = function(self) self.focus = true end,
        ClearFocus = function(self) self.focus = false end,
        HighlightText = function(self) self.selected = true end,
    }
    local dialog = { GetEditBox = function() return editBox end }
    function dialog:Hide()
        self.shown = false
        env.StaticPopupDialogs[self.which].OnHide(self)
    end
    editBox.GetParent = function() return dialog end
    env.StaticPopup_Show = function(name, _, _, url)
        if dialog.shown then dialog:Hide() end
        dialog.which, dialog.shown = name, true
        popups[#popups + 1] = url
        env.StaticPopupDialogs[name].OnShow(dialog, url)
        return dialog
    end
    env.StaticPopup_Hide = function() if dialog.shown then dialog:Hide() end end
    env.StaticPopup_StandardEditBoxOnEscapePressed = function(box) box:GetParent():Hide() end
    env.SetItemRef = function(link, _, button)
        local kind, options = link:match("^([^:]+):(.*)$")
        if handlers[kind] then handlers[kind](link, nil, {options = options}, {button = button}) end
    end
    return test, filters, popups, dialog, editBox
end

-- Domain detection, punctuation and native markup are tested through the real filter callback.
do
    local test, filters = chatFixture()
    test.login()
    assert(test.env.MinnTinkersWoWFDB.chatURLs and test.addon.ChatURLs.IsAvailable())
    local filter = assert(filters.CHAT_MSG_CHANNEL)
    local function link(url) return "|cff71d5ff|Hminntinkersurl:" .. url .. "|h" .. url .. "|h|r" end
    for _, case in ipairs({
        {"discord.gg/asdasdsad", link("discord.gg/asdasdsad")},
        {"example.com", link("example.com")},
        {"www.example.com", link("www.example.com")},
        {"sub.example.online/path?q=1#fragment", link("sub.example.online/path?q=1#fragment")},
        {"example.com:8080/path", link("example.com:8080/path")},
        {"https://example.com/a?x=1&y=2", link("https://example.com/a?x=1&y=2")},
        {"HTTPS://Example.COM/CaseSensitive", link("HTTPS://Example.COM/CaseSensitive")},
        {"https://youtube.com/@Minn?q=mail@example.com", link("https://youtube.com/@Minn?q=mail@example.com")},
        {"https://localhost:8080/path", link("https://localhost:8080/path")},
        {"example.xn--p1ai", link("example.xn--p1ai")},
        {"Visit (discord.gg/invite), please!", "Visit (" .. link("discord.gg/invite") .. "), please!"},
        {"'example.com'.", "'" .. link("example.com") .. "'."},
        {"<https://example.com>", "<" .. link("https://example.com") .. ">"},
        {"https://en.wikipedia.org/wiki/Function_(mathematics)).", link("https://en.wikipedia.org/wiki/Function_(mathematics)") .. ")."},
        {"example.com and discord.gg/test", link("example.com") .. " and " .. link("discord.gg/test")},
        {"|cffff0000example.com red|r", "|cffff0000" .. link("example.com") .. "|cffff0000 red|r"},
        {"|Hitem:123|h[www.fake.com]|h example.com", "|Hitem:123|h[www.fake.com]|h " .. link("example.com")},
        {"|Hplayer:Example|h[example.com]|h |Hspell:123|h[example.com]|h discord.gg/test", "|Hplayer:Example|h[example.com]|h |Hspell:123|h[example.com]|h " .. link("discord.gg/test")},
        {"|TInterface/example.com:12|t |Aexample.com:12|a example.com", "|TInterface/example.com:12|t |Aexample.com:12|a " .. link("example.com")},
        {"|| example.com", "|| " .. link("example.com")},
    }) do
        local discard, text = filter(nil, "CHAT_MSG_CHANNEL", case[1], "Sender", nil, 7)
        assert(discard == false and text == case[2], "Unexpected URL parsing: " .. case[1] .. " => " .. tostring(text))
        assert(select(2, filter(nil, "CHAT_MSG_CHANNEL", text)) == nil, "Do not wrap links twice")
    end
    for _, text in ipairs({"hello there", "1.2.3", "3.14", "user@example.com", "user@example.com/path", "ftp://example.com/file", "https://", "bad..example.com", "-bad.example.com", "example.c", "|Hitem:123|h[example.com]", "|Texample.com"}) do
        assert(select(2, filter(nil, "CHAT_MSG_CHANNEL", text)) == nil, "Unexpected link: " .. text)
    end
    local function pack(...) return {n = select("#", ...), ...} end
    local args = pack(filter(nil, "CHAT_MSG_WHISPER", "example.com", "Sender", nil, 42, nil))
    assert(args.n == 6 and args[3] == "Sender" and args[4] == nil and args[5] == 42 and args[6] == nil)
    local secret = setmetatable({}, {__index = function() error("Read secret text") end})
    test.env.canaccessvalue = function(value) return not rawequal(value, secret) end
    assert(filter(nil, "CHAT_MSG_CHANNEL", secret) == false)
    assert(select(2, filter(nil, "CHAT_MSG_CHANNEL", nil)) == nil)
end
print("PASS: bare domains, protocols, multiple URLs, punctuation, balanced brackets, existing links/textures/colors, idempotence, chat arguments and inaccessible text")

-- Native copy popup, settings persistence and filter lifecycle, including combat/death-independent callbacks.
do
    local test, filters, popups, dialog, box = chatFixture()
    local native = test.env.SetItemRef
    test.login(); test.addon.ChatURLs.Initialize()
    test.addon.ChatURLs.SetEnabled(true)
    assert(test.env.SetItemRef == native)
    local count = 0
    for _ in pairs(filters) do count = count + 1 end
    assert(count == 18 and filters.CHAT_MSG_BN_WHISPER and filters.CHAT_MSG_INSTANCE_CHAT_LEADER)
    test.addon.ToggleOptions()
    local check = test.env.MinnTinkersWoWFChatURLs
    assert(check.enabled and check:GetChecked())
    test.env.SetItemRef("minntinkersurl:discord.gg/Test", nil, "RightButton")
    assert(#popups == 0)
    test.combat(true)
    test.env.SetItemRef("minntinkersurl:discord.gg/Test", nil, "LeftButton")
    assert(#popups == 1 and dialog.shown and box.focus and box.selected and box.text == "discord.gg/Test")
    local info = test.env.StaticPopupDialogs[dialog.which]
    assert(info.whileDead and info.hideOnEscape and info.maxLetters == 0 and not info.exclusive)
    test.env.SetItemRef("minntinkersurl:https://example.com/a:b?q=1", nil, "LeftButton")
    assert(#popups == 2 and box.text == "https://example.com/a:b?q=1")
    info.EditBoxOnEscapePressed(box)
    assert(not dialog.shown and not box.focus)
    for _, bad in ipairs({"javascript:alert(1)", "example.com|Hitem:1|h", "example.com\nother", "user@example.com"}) do
        test.env.SetItemRef("minntinkersurl:" .. bad, nil, "LeftButton")
    end
    assert(#popups == 2)
    test.env.SetItemRef("minntinkersurl:example.com", nil, "LeftButton")
    check:SetChecked(false); check.scripts.OnClick(check)
    assert(not dialog.shown and not box.focus and next(filters) == nil and not test.env.MinnTinkersWoWFDB.chatURLs)
    test.addon.ChatURLs.SetEnabled(false)
    test.env.SetItemRef("minntinkersurl:example.com", nil, "LeftButton")
    assert(dialog.shown, "Existing scrollback links remain usable after detection is disabled")
    info.EditBoxOnEnterPressed(box); assert(not dialog.shown and not box.focus)
    local reload, reloadFilters = chatFixture(test.env.MinnTinkersWoWFDB)
    reload.login(); assert(next(reloadFilters) == nil)
    reload.addon.ChatURLs.SetEnabled(true); assert(reloadFilters.CHAT_MSG_GUILD)
    test = fixture(); test.login(); test.addon.ToggleOptions()
    assert(not test.env.MinnTinkersWoWFChatURLs.enabled, "Unavailable APIs disable the control")
end
print("PASS: native copy popup selection/reuse/Esc/Enter, unchanged click handler, combat callbacks, malformed links, saved toggle, duplicate guards and filter removal")

local function rangeFixture(saved, characterSaved)
    local test = fixture(saved, characterSaved)
    local env = test.env
    local state = {ranges = {}, watches = {}, subscriptions = {}, checks = 0, cursor = {}, clears = 0, menus = {}}
    local secret = setmetatable({}, {__tostring = function() error("Used a secret") end, __index = function() error("Read a secret") end})
    state.secret = secret
    env.canaccessvalue = function(...)
        for index = 1, select("#", ...) do
            if rawequal(select(index, ...), secret) then return false end
        end
        return true
    end
    env.Enum.SpellBookSpellBank = {Player = 0, Pet = 1}
    env.Enum.SpellBookItemType = {Spell = 1, FutureSpell = 2, Flyout = 4}
    state.spells = {
        [75] = {spellID = 75, name = "Auto Shot", iconID = 100, subName = "", known = true, hasRange = true},
        [116] = {spellID = 116, name = "Frostbolt", iconID = 101, subName = "Rank 1", known = true, hasRange = true},
        [205] = {spellID = 205, name = "Frostbolt", iconID = 101, subName = "Rank 2", known = true, hasRange = true},
        [133] = {spellID = 133, name = "Fireball", iconID = 102, subName = "", known = true, hasRange = true},
        [197] = {spellID = 197, name = "Fire Blast", iconID = 103, subName = "", known = true, hasRange = true},
        [19434] = {spellID = 19434, name = "Aimed Shot", iconID = 104, subName = "", known = true, hasRange = true},
        [17] = {spellID = 17, name = "Self Buff", iconID = 105, subName = "", known = true, hasRange = false},
        [123] = {spellID = 123, name = "Passive", iconID = 106, subName = "", known = true, hasRange = true, isPassive = true},
        [124] = {spellID = 124, name = "Unknown", iconID = 107, subName = "", known = false, hasRange = true, isOffSpec = true},
    }
    local slots = {state.spells[75], state.spells[116], state.spells[205], state.spells[133], state.spells[197],
        state.spells[19434], state.spells[17], state.spells[123], state.spells[124], state.spells[75],
        {itemType = 4}, {itemType = 2, spellID = 999}}
    for _, info in pairs(state.spells) do info.itemType = 1 end
    env.C_SpellBook = {
        IsSpellKnown = function(id) return state.spells[id] and state.spells[id].known or false end,
        GetNumSpellBookSkillLines = function() return 2 end,
        GetSpellBookSkillLineInfo = function(index)
            return index == 1 and {itemIndexOffset = 0, numSpellBookItems = 4}
                or {itemIndexOffset = 4, numSpellBookItems = #slots - 4}
        end,
        GetSpellBookItemInfo = function(slot, bank) assert(bank == 0); return slots[slot] end,
    }
    env.C_Spell = {
        GetSpellInfo = function(id) return state.spells[id] end,
        IsSpellPassive = function(id) return state.spells[id] and state.spells[id].isPassive or false end,
        SpellHasRange = function(id) return state.spells[id] and state.spells[id].hasRange or false end,
        IsSpellInRange = function(id, unit)
            assert(unit == "target")
            state.checks = state.checks + 1
            return state.ranges[id]
        end,
        EnableSpellRangeCheck = function(id, value)
            state.watches[id] = value
            state.subscriptions[#state.subscriptions + 1] = {id, value}
            if value and state.synchronous then test.emit("SPELL_RANGE_CHECK_UPDATE", id, state.ranges[id], true) end
        end,
    }
    env.GetCursorInfo = function() return unpack(state.cursor) end
    env.ClearCursor = function() state.clears = state.clears + 1; state.cursor = {} end
    env.MenuUtil = {CreateContextMenu = function(owner, generator)
        local menu = {owner = owner, buttons = {}}
        function menu:CreateTitle(text) self.title = text end
        function menu:SetScrollMode(value) self.scroll = value end
        function menu:CreateButton(label, callback) self.buttons[#self.buttons + 1] = {label = label, click = callback} end
        generator(owner, menu)
        state.menus[#state.menus + 1] = menu
    end}
    env.UIParent:SetSize(1200, 800)
    env.UIParent.centerX, env.UIParent.centerY = 600, 400
    local create = env.CreateFrame
    env.CreateFrame = function(kind, name, parent, template)
        local frame = create(kind, name, parent, template)
        if name == "MinnTinkersWoWFRangeIndicator" then
            function frame:EnableMouse(value) self.mouseEnabled = value end
            function frame:SetClampedToScreen(value) self.clamped = value end
            function frame:SetFrameStrata(value) self.strata = value end
            function frame:StartMoving() self.moving = true end
            function frame:StopMovingOrSizing() self.moving = false end
            function frame:GetCenter()
                if self.dragX then return self.dragX, self.dragY end
                return env.UIParent.centerX + self.point[4], env.UIParent.centerY + self.point[5]
            end
            local setPoint, createText = frame.SetPoint, frame.CreateFontString
            function frame:SetPoint(...)
                setPoint(self, ...)
                self.dragX, self.dragY = nil, nil
            end
            function frame:CreateFontString(...)
                self.dot = createText(self, ...)
                local setColor = self.dot.SetTextColor
                function self.dot:SetTextColor(...)
                    self.colorWrites = (self.colorWrites or 0) + 1
                    setColor(self, ...)
                end
                return self.dot
            end
        end
        return frame
    end
    return test, state
end

-- Select a spell through the real settings controls, and retain the previous selection on invalid input.
do
    local test, state = rangeFixture(); test.login(); test.addon.ToggleOptions()
    local env, range = test.env, test.addon.RangeIndicator
    local tab = env.MinnTinkersWoWFOptionsTab2; tab.scripts.OnClick(tab)
    local input, slot = env.MinnTinkersWoWFRangeSpellInput, env.MinnTinkersWoWFRangeSpellSlot
    assert(range.IsAvailable() and range.GetSettings().enabled and range.GetSettings().locked)
    assert(not env.MinnTinkersWoWFRangeIndicator:IsShown())
    input:SetText("fIrE bAlL"); input:SetFocus(); input.scripts.OnEnterPressed(input)
    assert(range.GetSettings().spellID == 133 and input:GetText() == "Fireball" and not input.focus)
    assert(slot.icon.texture == 102 and state.watches[133])
    input:SetText("Frostbolt"); env.MinnTinkersWoWFRangeSelectSpell.scripts.OnClick()
    local menu = state.menus[#state.menus]
    assert(#menu.buttons == 2 and menu.scroll == 240 and range.GetSettings().spellID == 133)
    assert(menu.buttons[2].label == "Frostbolt (Rank 2)")
    menu.buttons[2].click(); assert(range.GetSettings().spellID == 205)
    input:SetText("frostbolt (rank 1)"); input.scripts.OnEnterPressed(input)
    assert(range.GetSettings().spellID == 116)
    input:SetText("Fire"); input.scripts.OnEnterPressed(input)
    assert(#state.menus[#state.menus].buttons == 2)
    input:SetText("Aimed"); input.scripts.OnEnterPressed(input)
    assert(range.GetSettings().spellID == 19434)
    input:SetText("Not A Spell"); input.scripts.OnEnterPressed(input)
    assert(range.GetSettings().spellID == 19434 and env.MinnTinkersWoWFRangeStatus:GetText():find("No learned", 1, true))
    assert(#range.FindSpells("Auto Shot") == 1, "Duplicate spellbook entries must not make a name ambiguous")
    assert(#range.FindSpells("") == 0 and #range.FindSpells("Self Buff") == 0 and #range.FindSpells("Passive") == 0)
    assert(#range.FindSpells("Unknown") == 0 and not range.SelectSpell(state.secret))
    for _, id in ipairs({17, 123, 124, 999}) do assert(not range.SelectSpell(id) and range.GetSettings().spellID == 19434) end
    state.cursor = {"item", 99}; slot.scripts.OnReceiveDrag()
    assert(state.clears == 0 and range.GetSettings().spellID == 19434)
    state.cursor = {"spell", 1, "spell", 17}; slot.scripts.OnReceiveDrag()
    assert(state.clears == 0 and range.GetSettings().spellID == 19434)
    state.cursor = {"spell", 1, "spell", state.secret}; slot.scripts.OnReceiveDrag()
    assert(state.clears == 0 and range.GetSettings().spellID == 19434)
    state.cursor = {"spell", 1, "spell", 75}; slot.scripts.OnReceiveDrag()
    assert(state.clears == 1 and range.GetSettings().spellID == 75 and input:GetText() == "Auto Shot")
    slot.scripts.OnEnter(slot); assert(env.GameTooltip:IsShown())
    slot.scripts.OnLeave(slot); assert(not env.GameTooltip:IsShown())
    env.MinnTinkersWoWFRangeClearSpell.scripts.OnClick()
    assert(range.GetSettings().spellID == nil and state.watches[75] == false and input:GetText() == "")
    test = fixture(); test.login(); test.addon.ToggleOptions()
    for _, name in ipairs({"RangeEnabled", "RangeUnlocked", "RangeSize", "RangeOpacity", "RangeSpellSlot", "RangeSpellInput", "RangeSelectSpell", "RangeClearSpell", "RangeResetPosition"}) do
        assert(test.env["MinnTinkersWoWF" .. name].enabled == false, "Missing range APIs must disable settings")
    end
end
print("PASS: range spell input, case/space matching, rank/partial disambiguation, native menus, drag/drop, invalid/passive/unknown spells, retained selection and unavailable controls")

-- Range transitions are event-driven, combat-safe and do not consume inaccessible payloads.
do
    local test, state = rangeFixture(nil, {rangeIndicator = {spellID = 75}})
    state.ranges[75], state.synchronous = true, true
    test.login()
    local env, range = test.env, test.addon.RangeIndicator
    local frame = env.MinnTinkersWoWFRangeIndicator
    assert(frame:IsShown() and frame.dot.color[1] == 1 and frame.dot.color[2] == 1 and not frame.mouseEnabled)
    local subscriptions, checks = #state.subscriptions, state.checks
    range.Initialize(); assert(#state.subscriptions == subscriptions)
    test.combat(true); test.emit("SPELL_RANGE_CHECK_UPDATE", 75, false, true)
    assert(frame:IsShown() and frame.dot.color[2] == 0.15 and state.checks == checks)
    local writes = frame.dot.colorWrites
    for _ = 1, 1000 do test.emit("SPELL_RANGE_CHECK_UPDATE", 75, false, true) end
    assert(state.checks == checks, "Range events must not issue extra range queries")
    test.emit("SPELL_RANGE_CHECK_UPDATE", 133, true, true)
    test.emit("SPELL_RANGE_CHECK_UPDATE", state.secret, true, true)
    assert(frame.dot.colorWrites == writes, "Repeated or unrelated events must not redraw the indicator")
    test.emit("SPELL_RANGE_CHECK_UPDATE", 75, state.secret, true); assert(not frame:IsShown())
    test.emit("SPELL_RANGE_CHECK_UPDATE", 75, true, state.secret); assert(not frame:IsShown())
    test.emit("SPELL_RANGE_CHECK_UPDATE", 75, true, false); assert(not frame:IsShown())
    state.ranges[75] = false; test.emit("PLAYER_TARGET_CHANGED")
    assert(frame:IsShown() and frame.dot.color[2] == 0.15 and state.checks == checks + 1)
    state.ranges[75] = nil; test.emit("PLAYER_TARGET_CHANGED"); assert(not frame:IsShown())
    range.SetLocked(false); assert(frame:IsShown() and frame.mouseEnabled and frame.dot.color[1] == 0.65 and frame.strata == "TOOLTIP")
    range.SetLocked(true); assert(not frame:IsShown() and not frame.mouseEnabled and frame.strata == "HIGH")
    range.SetEnabled(false); assert(state.watches[75] == false and not frame:IsEventRegistered("SPELL_RANGE_CHECK_UPDATE"))
    checks = state.checks
    test.emit("SPELL_RANGE_CHECK_UPDATE", 75, true, true); assert(not frame:IsShown() and state.checks == checks)
    state.ranges[75] = true; range.SetEnabled(true); assert(frame:IsShown() and state.watches[75])
    state.spells[75].known = false; test.emit("SPELLS_CHANGED")
    assert(not frame:IsShown() and range.GetSettings().spellID == 75 and not state.watches[75])
    state.spells[75].known = true; test.emit("SPELLS_CHANGED"); assert(frame:IsShown() and state.watches[75])
    range.SelectSpell(133); assert(not state.watches[75] and state.watches[133])
    state.ranges[133] = state.secret; test.emit("PLAYER_TARGET_CHANGED"); assert(not frame:IsShown())
    range.ClearSpell(); assert(not state.watches[133])
    assert(frame.scripts.OnUpdate == nil and #test.timers == 0, "Range checks must not poll")
end
print("PASS: native range events, initial/target state, white/red/unknown transitions, secrets, unchanged-state redraw avoidance, combat, enable/disable/clear and spellbook revalidation without polling")

-- Derive color from the player's class once; presentation changes never query range.
do
    local classes = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
    for index, class in ipairs(classes) do
        local test, state = rangeFixture(nil, {rangeIndicator = {spellID = 75}})
        local lookups = 0
        test.env.UnitClass = function(unit) assert(unit == "player"); return class, class end
        test.env.C_ClassColor = {GetClassColor = function(token)
            assert(token == class); lookups = lookups + 1
            return {GetRGB = function() return index / 10, 0.4, 0.6 end}
        end}
        state.ranges[75] = true; test.login(); test.addon.ToggleOptions()
        local range, frame = test.addon.RangeIndicator, test.env.MinnTinkersWoWFRangeIndicator
        assert(not range.GetSettings().useClassColor and frame.dot.color[1] == 1)
        local checks, subscriptions = state.checks, #state.subscriptions
        local control = test.env.MinnTinkersWoWFRangeClassColor
        control:SetChecked(true); control.scripts.OnClick(control)
        assert(range.GetSettings().useClassColor and frame.dot.color[1] == index / 10)
        assert(frame.dot.color[2] == 0.4 and frame.dot.color[3] == 0.6)
        test.combat(true)
        test.emit("SPELL_RANGE_CHECK_UPDATE", 75, false, true)
        range.SetClassColor(false); range.SetClassColor(true)
        assert(frame.dot.color[1] == 1 and frame.dot.color[2] == 0.15)
        test.emit("SPELL_RANGE_CHECK_UPDATE", 75, true, true)
        assert(frame.dot.color[1] == index / 10)
        range.SetClassColor(false); assert(frame.dot.color[1] == 1 and frame.dot.color[2] == 1)
        range.SetClassColor(true)
        test.emit("SPELL_RANGE_CHECK_UPDATE", 75, nil, false); range.SetLocked(false)
        assert(frame.dot.color[1] == 0.65)
        assert(state.checks == checks and #state.subscriptions == subscriptions and lookups == 1)
        local reload, reloadedState = rangeFixture(test.env.MinnTinkersWoWFDB, test.env.MinnTinkersWoWFCharDB)
        reload.env.C_ClassColor = {GetClassColor = function(token)
            assert(token == "HUNTER"); return {GetRGB = function() return 0.2, 0.7, 0.3 end}
        end}
        reloadedState.ranges[75] = true; reload.login()
        assert(reload.addon.RangeIndicator.GetSettings().useClassColor and reload.env.MinnTinkersWoWFRangeIndicator.dot.color[1] == 0.2)
        local other = rangeFixture(test.env.MinnTinkersWoWFDB); other.login()
        assert(not other.addon.RangeIndicator.GetSettings().useClassColor)
    end
    local fallback, state = rangeFixture(nil, {rangeIndicator = {spellID = 75, useClassColor = true}})
    state.ranges[75] = true; fallback.login()
    assert(fallback.env.MinnTinkersWoWFRangeIndicator.dot.color[1] == 1)
end
print("PASS: native player-class colors, white default, independent per-character persistence, combat/red/unknown states and presentation-only toggles without extra range calls")

-- Native drag, bounded size and coordinates, position recovery, and per-character persistence.
do
    local test, state = rangeFixture(); test.login()
    local range, env = test.addon.RangeIndicator, test.env
    local frame, settings = env.MinnTinkersWoWFRangeIndicator, range.GetSettings()
    range.SelectSpell(75); range.SetLocked(false)
    frame.scripts.OnDragStart(frame); assert(frame.moving and frame.clamped)
    frame.dragX, frame.dragY = 850, 550
    frame.scripts.OnDragStop(frame)
    assert(not frame.moving and settings.x == 250 and settings.y == 150)
    range.SetLocked(true); frame.scripts.OnDragStart(frame); assert(not frame.moving and not frame.mouseEnabled)
    range.SetSize(40.4); assert(settings.size == 40 and frame.width == 40 and frame.height == 40 and frame.dot.fontSize == 40)
    range.SetSize(200); assert(settings.size == 96)
    range.SetSize(-1); assert(settings.size == 8)
    settings.x, settings.y = 100000, -100000
    test.emit("DISPLAY_SIZE_CHANGED"); assert(settings.x == 596 and settings.y == -396)
    env.UIParent:SetSize(500, 300); test.emit("UI_SCALE_CHANGED")
    assert(settings.x == 246 and settings.y == -146)
    test.addon.ToggleOptions()
    local tab = env.MinnTinkersWoWFOptionsTab2; tab.scripts.OnClick(tab)
    env.MinnTinkersWoWFRangeResetPosition.scripts.OnClick()
    assert(settings.x == 0 and settings.y == -120 and settings.size == 8 and settings.spellID == 75)
    env.MinnTinkersWoWFRangeSize:SetValue(42); assert(settings.size == 42 and frame.dot.fontSize == 42)
    local unlock = env.MinnTinkersWoWFRangeUnlocked
    unlock:SetChecked(true); unlock.scripts.OnClick(unlock); assert(not settings.locked and frame.mouseEnabled)
    local enable = env.MinnTinkersWoWFRangeEnabled
    enable:SetChecked(false); enable.scripts.OnClick(enable); assert(not settings.enabled and not frame:IsShown())
    local reload = rangeFixture(env.MinnTinkersWoWFDB, env.MinnTinkersWoWFCharDB)
    reload.login()
    local restored = reload.addon.RangeIndicator.GetSettings()
    assert(restored.spellID == 75 and restored.size == 42 and restored.x == 0 and restored.y == -120 and not restored.enabled and not restored.locked)
    local other = rangeFixture(env.MinnTinkersWoWFDB); other.login()
    assert(other.addon.RangeIndicator.GetSettings().spellID == nil and other.addon.RangeIndicator.GetSettings().size == 24)
    local repaired = rangeFixture(nil, {rangeIndicator = {size = "bad", x = math.huge, y = 0/0, spellID = 75}, extra = "keep"})
    repaired.login()
    assert(repaired.addon.RangeIndicator.GetSettings().size == 24 and repaired.addon.RangeIndicator.GetSettings().x == 0
        and repaired.addon.RangeIndicator.GetSettings().y == -120 and repaired.env.MinnTinkersWoWFCharDB.extra == "keep")
    range.SetLocked(false); enable:SetChecked(true); enable.scripts.OnClick(enable)
    frame.scripts.OnDragStart(frame); assert(frame.moving)
    range.SetEnabled(false); assert(not frame.moving)
end
print("PASS: range drag/lock, resize and bounds, off-screen recovery, reset controls, display changes, per-character reload/alt isolation, saved-data repair and drag cancellation")

-- Opacity changes only presentation, including in combat, and persists per character.
do
    local test, state = rangeFixture(nil, {rangeIndicator = {spellID = 75}})
    state.ranges[75] = true
    test.login()
    local env, range = test.env, test.addon.RangeIndicator
    local frame, settings = env.MinnTinkersWoWFRangeIndicator, range.GetSettings()
    assert(settings.opacity == 100 and frame.alpha == 1)
    local checks, subscriptions, writes = state.checks, #state.subscriptions, frame.dot.colorWrites
    test.combat(true)
    range.SetOpacity(47.4); assert(settings.opacity == 47 and frame.alpha == 0.47 and frame:IsShown())
    range.SetOpacity(-1); assert(settings.opacity == 10 and frame.alpha == 0.1)
    range.SetOpacity(200); assert(settings.opacity == 100 and frame.alpha == 1)
    test.addon.ToggleOptions()
    local tab = env.MinnTinkersWoWFOptionsTab2; tab.scripts.OnClick(tab)
    local slider = env.MinnTinkersWoWFRangeOpacity
    slider:SetValue(35); assert(settings.opacity == 35 and frame.alpha == 0.35)
    slider:Refresh(); assert(settings.opacity == 35)
    assert(state.checks == checks and #state.subscriptions == subscriptions and frame.dot.colorWrites == writes,
        "Opacity changes must not query range, change tracking or redraw range colors")
    range.SetEnabled(false); range.SetOpacity(25)
    assert(not frame:IsShown() and frame.alpha == 0.25)
    local reload = rangeFixture(env.MinnTinkersWoWFDB, env.MinnTinkersWoWFCharDB); reload.login()
    assert(reload.addon.RangeIndicator.GetSettings().opacity == 25 and reload.env.MinnTinkersWoWFRangeIndicator.alpha == 0.25)
    local other = rangeFixture(env.MinnTinkersWoWFDB); other.login()
    assert(other.addon.RangeIndicator.GetSettings().opacity == 100)
    for _, saved in ipairs({"bad", math.huge, 0/0}) do
        local repaired = rangeFixture(nil, {rangeIndicator = {opacity = saved}, extra = "keep"}); repaired.login()
        assert(repaired.addon.RangeIndicator.GetSettings().opacity == 100 and repaired.env.MinnTinkersWoWFCharDB.extra == "keep")
    end
    for _, saved in ipairs({-20, 150}) do
        local repaired = rangeFixture(nil, {rangeIndicator = {opacity = saved}}); repaired.login()
        assert(repaired.addon.RangeIndicator.GetSettings().opacity == (saved < 10 and 10 or 100))
    end
end
print("PASS: range opacity default/bounds, slider, combat, presentation-only updates, per-character persistence and saved-data repair")

-- Pet happiness uses native protected-value sinks, clipped fixed color zones and no polling.
local function petFixture(saved)
    local test = fixture(saved)
    local env = test.env
    local state = {hunter = true, value = 200, maximum = 900, reads = 0, maximumReads = 0, writes = 0, tooltipCalls = 0, borders = {}, atlasReads = 0, outerBackgrounds = 0, masks = {}, zoneBackgrounds = {}, maskReads = 0}
    local secretMT = {
        __add = function() error("Secret happiness arithmetic") end,
        __sub = function() error("Secret happiness arithmetic") end,
        __mul = function() error("Secret happiness arithmetic") end,
        __div = function() error("Secret happiness arithmetic") end,
        __lt = function() error("Secret happiness comparison") end,
        __le = function() error("Secret happiness comparison") end,
        __concat = function() error("Secret happiness formatting") end,
        __tostring = function() error("Secret happiness formatting") end,
    }
    state.secretValue, state.secretMaximum = setmetatable({}, secretMT), setmetatable({}, secretMT)
    env.canaccessvalue = function(...)
        for index = 1, select("#", ...) do
            local value = select(index, ...)
            if rawequal(value, state.secretValue) or rawequal(value, state.secretMaximum) then return false end
        end
        return true
    end
    env.Enum.PowerType = {Happiness = 27}
    env.UnitClass = function() return state.hunter and "Hunter" or "Warrior", state.hunter and "HUNTER" or "WARRIOR" end
    env.HasPetUI = function() return true, state.hunter end
    env.UnitPower = function(unit, power)
        assert(unit == "pet" and power == 27)
        state.reads = state.reads + 1
        return state.value
    end
    env.UnitPowerMax = function(unit, power)
        assert(unit == "pet" and power == 27)
        state.maximumReads = state.maximumReads + 1
        return state.maximum
    end
    local create = env.CreateFrame
    env.PetFrame = create("Frame")
    env.PetFrame:Show()
    local setPetShown = env.PetFrame.SetShown
    state.setPetShown = function(value) setPetShown(env.PetFrame, value) end
    env.PetFrameManaBar = create("StatusBar", nil, env.PetFrame)
    env.PetFrameManaBar:SetSize(74, 7)
    env.PetFrameTexture = env.PetFrame:CreateTexture()
    function env.PetFrameTexture:GetRect() return 0, 0, 120, 49 end
    function env.PetFrameTexture:GetAtlas() return "UI-HUD-UnitFrame-TargetofTarget-PortraitOn" end
    function env.PetFrameTexture:GetTexture() error("Must use the atlas file and bounds") end
    function env.PetFrameTexture:GetTexCoord() error("Texture coordinates do not identify atlas sheet bounds") end
    env.C_Texture = {GetAtlasInfo = function(atlas)
        if atlas == "UI-HUD-UnitFrame-Party-PortraitOff-Bar-Mana-Mask" then
            state.maskReads = state.maskReads + 1
            return state.maskAtlas
        end
        assert(atlas == "UI-HUD-UnitFrame-TargetofTarget-PortraitOn")
        state.atlasReads = state.atlasReads + 1
        return state.atlas
    end}
    state.atlas = {file = 12345, leftTexCoord = 0.1, rightTexCoord = 0.5, topTexCoord = 0.2, bottomTexCoord = 0.6}
    function env.PetFrameManaBar:GetRect() return 40, 11, 74, 7 end
    env.PetFrameManaBarMask = env.PetFrameManaBar:CreateTexture()
    function env.PetFrameManaBarMask:GetAtlas() error("Do not crop the portrait mask") end
    function env.PetFrameManaBarMask:GetRect() error("Do not read secure mask geometry") end
    state.maskAtlas = {file = 54321, leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1}
    env.PetFrameHappiness = create("Frame", nil, env.PetFrame)
    local icon = env.PetFrameHappiness
    icon.Texture = icon:CreateTexture()
    icon.Texture:SetAlpha(0.8)
    function icon.Texture:GetAlpha() return self.alpha end
    icon.tooltipData = {happiness = 3}
    function icon:OnEnter()
        state.tooltipCalls = state.tooltipCalls + 1
        env.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        env.GameTooltip:SetText("Native happiness, damage bonus and diet")
        env.GameTooltip:Show()
    end
    -- Changing protected native frame visibility must never be part of replacement/restoration.
    for _, native in ipairs({env.PetFrame, icon}) do
        native.Show = function() error("Addon changed native pet frame visibility") end
        native.Hide = native.Show
        native.SetShown = native.Show
    end
    local hooked = env.hooksecurefunc
    env.hooksecurefunc = function(object, method, handler)
        assert(object ~= icon, "Happiness replacement must not alter Blizzard's update method")
        return hooked(object, method, handler)
    end
    env.CreateFrame = function(kind, name, parent, template)
        local f = create(kind, name, parent, template)
        f.kind, f.parent, f.template = kind, parent, template
        function f:GetFrameLevel() return 10 end
        local createTexture = f.CreateTexture
        local function textureWithMasks(self, ...)
            local texture = createTexture(self, ...)
            texture.masks = {}
            function texture:AddMaskTexture(mask) self.masks[#self.masks + 1] = mask end
            function texture:SetTexCoord(...) self.coords = {...} end
            function texture:SetTexture(file, horizontal, vertical)
                self.texture, self.horizontal, self.vertical = file, horizontal, vertical
            end
            function texture:SetAtlas(atlas, useSize, filter, reset, horizontal, vertical)
                self.atlas, self.useAtlasSize, self.resetTexCoords = atlas, useSize, reset
                self.horizontal, self.vertical = horizontal, vertical
            end
            return texture
        end
        function f:CreateMaskTexture(...)
            local texture = textureWithMasks(self, ...)
            state.masks[#state.masks + 1] = texture
            return texture
        end
        function f:CreateTexture(textureName, layer, ...)
            local texture = textureWithMasks(self, textureName, layer, ...)
            if name ~= "MinnTinkersWoWFPetHappinessBar" and layer == "BACKGROUND" then
                state.zoneBackgrounds[#state.zoneBackgrounds + 1] = texture
            end
            return texture
        end
        if name == "MinnTinkersWoWFPetHappinessBar" then
            local createTexture = f.CreateTexture
            function f:CreateTexture(textureName, layer, ...)
                local texture = createTexture(self, textureName, layer, ...)
                function texture:SetTexCoord(...) self.coords = {...} end
                if layer == "BORDER" then state.borders[#state.borders + 1] = texture end
                if layer == "BACKGROUND" then state.outerBackgrounds = state.outerBackgrounds + 1 end
                texture.layer = layer
                return texture
            end
        end
        function f:RegisterUnitEvent(event, ...)
            self:RegisterEvent(event)
            self.unitEvents = self.unitEvents or {}
            self.unitEvents[event] = {...}
        end
        function f:SetClipsChildren(value) self.clips = value end
        function f:SetBackdrop() error("Happiness bar must use native trim, not a tooltip backdrop") end
        function f:SetStatusBarTexture(value)
            self.barTexture = value
            self.fillTexture = textureWithMasks(self)
        end
        function f:GetStatusBarTexture() return self.fillTexture end
        function f:SetStatusBarColor(...) self.barColor = {...} end
        if kind == "StatusBar" then
            function f:SetMinMaxValues(minimum, maximum)
                self.minimum, self.maximum = minimum, maximum
            end
            function f:SetValue(value)
                self.value = value
                state.writes = state.writes + 1
            end
        end
        return f
    end
    return test, state
end

do
    local test, state = petFixture({extra = "keep"})
    state.value, state.maximum = state.secretValue, state.secretMaximum
    test.combat(true); test.login()
    local env, module = test.env, test.addon.PetHappinessBar
    local frame, icon = env.MinnTinkersWoWFPetHappinessBar, env.PetFrameHappiness
    assert(module.IsAvailable() and env.MinnTinkersWoWFDB.petHappinessBar and env.MinnTinkersWoWFDB.extra == "keep")
    assert(frame.alpha == 1 and icon.Texture.alpha == 0 and frame.parent == env.PetFrame)
    assert(frame.height == 11 and frame.template == nil and frame.backdrop == nil)
    assert(#state.borders == 3 and state.outerBackgrounds == 0, "Transparent corners need no outer rectangular background")
    local capRight = 0.1 + 0.4 * 118 / 120
    local capLeft = capRight - 0.4 * 8 / 120
    local top, bottom = 0.2 + 0.4 * 29 / 49, 0.2 + 0.4 * 42 / 49
    local expectedCoords = {{capRight, capLeft, top, bottom},
        {capLeft - 0.4 * 4 / 120, capLeft, top, bottom}, {capLeft, capRight, top, bottom}}
    for index, border in ipairs(state.borders) do
        assert(border.texture == 12345 and border.alpha == 1 and border.layer == "BORDER")
        for coord, value in ipairs(expectedCoords[index]) do assert(math.abs(border.coords[coord] - value) < 0.000001) end
    end
    assert(state.borders[1].width == 8 and state.borders[3].width == 8)
    assert(state.borders[1].point[4] == -2 and state.borders[1].point[5] == -2)
    assert(state.borders[3].point[4] == 2 and state.borders[3].point[5] == -2)
    assert(frame.point[2] == env.PetFrameManaBar and frame.point[3] == "BOTTOMRIGHT" and frame.point[5] == -2)
    assert(#state.masks == 1 and #state.zoneBackgrounds == 3)
    local mask = state.masks[1]
    assert(mask.atlas == "UI-HUD-UnitFrame-Party-PortraitOff-Bar-Mana-Mask" and mask.useAtlasSize == false)
    assert(mask.resetTexCoords and mask.coords == nil, "Use the full mask canvas without UV cropping")
    local function checkMaskGeometry(innerWidth)
        -- Model the native 84x7 alpha window in its 128x16 canvas, independently of texture UVs.
        local visibleWidth = 84 / 128 * mask.width
        local visibleHeight = 7 / 16 * mask.height
        local visibleLeft = mask.point[4] + 21 / 128 * mask.width
        local visibleTop = mask.point[5] - 5 / 16 * mask.height
        assert(math.abs(visibleWidth - innerWidth) < 0.000001 and math.abs(visibleHeight - 7) < 0.000001,
            "Native mask alpha window must span the full interior")
        assert(math.abs(visibleLeft - 2) < 0.000001 and math.abs(visibleTop + 2) < 0.000001,
            "Native mask alpha window must align with the fill")
    end
    checkMaskGeometry(frame:GetWidth() - 4)
    frame.width = 74; frame.scripts.OnSizeChanged(frame, 74, 11); checkMaskGeometry(70)
    frame.width = 100; frame.scripts.OnSizeChanged(frame, 100, 11); checkMaskGeometry(96)
    assert(mask.horizontal == "CLAMPTOBLACKADDITIVE" and mask.vertical == "CLAMPTOBLACKADDITIVE")
    assert(mask.point[2] == frame and mask.point[5] == 3)
    local colors = {{0.9, 0.15, 0.1}, {1, 0.72, 0.08}, {0.15, 0.8, 0.25}}
    for index = 1, 3 do
        local fill = env["MinnTinkersWoWFPetHappinessFill" .. index]
        assert(fill.parent.clips and fill.height == 7)
        assert(#fill.fillTexture.masks == 1 and #state.zoneBackgrounds[index].masks == 1)
        for maskIndex, mask in ipairs(state.masks) do
            assert(fill.fillTexture.masks[maskIndex] == mask and state.zoneBackgrounds[index].masks[maskIndex] == mask)
        end
        assert(fill.barTexture == "Interface\\TargetingFrame\\UI-StatusBar")
        assert(table.concat(fill.barColor, ",") == table.concat(colors[index], ","))
        assert(fill.minimum == 0 and rawequal(fill.maximum, state.secretMaximum) and rawequal(fill.value, state.secretValue))
    end
    local atlasReads = state.atlasReads
    assert(state.reads == 1 and state.maximumReads == 1 and state.writes == 3)
    module.Initialize(); assert(state.reads == 1 and state.writes == 3)
    assert(frame.unitEvents.UNIT_POWER_UPDATE[1] == "pet" and frame.unitEvents.UNIT_PET[1] == "player")
    for _ = 1, 1000 do test.emit("UNIT_POWER_UPDATE", "pet", "FOCUS") end
    test.emit("UNIT_POWER_UPDATE", "player", "HAPPINESS")
    test.emit("UNIT_POWER_UPDATE", state.secretValue, "HAPPINESS")
    test.emit("UNIT_POWER_UPDATE", "pet", state.secretValue)
    test.emit("UNIT_HAPPINESS", "player"); test.emit("UNIT_PET", "party1")
    assert(state.reads == 1 and state.maximumReads == 1 and state.writes == 3, "Unrelated power/unit events must not query or redraw happiness")
    test.emit("UNIT_POWER_UPDATE", "pet", "HAPPINESS")
    assert(state.reads == 2 and state.writes == 6 and state.atlasReads == atlasReads and state.maskReads == 1, "Happiness updates must not rebuild border or mask art")
    test.emit("UNIT_MAXPOWER", "pet", "HAPPINESS")
    test.emit("UNIT_HAPPINESS", "pet")
    test.emit("PET_UI_UPDATE"); test.emit("PLAYER_ENTERING_WORLD"); test.emit("UNIT_PET", "player")
    assert(state.reads == 7 and state.writes == 21)
    frame.scripts.OnEnter(frame)
    assert(state.tooltipCalls == 1 and env.GameTooltip:IsOwned(icon) and env.GameTooltip:IsShown())
    frame.scripts.OnLeave(frame); assert(not env.GameTooltip:IsShown())
    frame.scripts.OnEnter(frame); frame.scripts.OnHide(frame); assert(not env.GameTooltip:IsShown())
    icon.tooltipData = nil; frame.scripts.OnEnter(frame); assert(state.tooltipCalls == 2)
    icon.tooltipData = {}
    frame.scripts.OnEnter(frame)
    module.SetEnabled(false)
    assert(frame.alpha == 0 and icon.Texture.alpha == 0.8 and not env.GameTooltip:IsShown())
    assert(next(frame.events) == nil and not env.MinnTinkersWoWFDB.petHappinessBar)
    local reads = state.reads
    test.emit("UNIT_POWER_UPDATE", "pet", "HAPPINESS"); test.emit("UNIT_PET", "player")
    state.setPetShown(false); state.setPetShown(true)
    frame.scripts.OnEnter(frame)
    assert(state.reads == reads and state.tooltipCalls == 3)
    module.SetEnabled(true); assert(frame.alpha == 1 and icon.Texture.alpha == 0)
    assert(frame.scripts.OnUpdate == nil and #test.timers == 0, "Pet happiness must not poll")
end
print("PASS: protected happiness values passed directly to native bars, three fixed color zones, pet-only event filtering, tooltip reuse, combat, enable/disable and native icon restoration without polling")

do
    local test, state = petFixture(); test.login()
    local env, module = test.env, test.addon.PetHappinessBar
    local frame, icon = env.MinnTinkersWoWFPetHappinessBar, env.PetFrameHappiness
    local function geometry(width)
        frame.width = width
        frame.scripts.OnSizeChanged(frame, width, 11)
        local inner = width - 4
        for index = 1, 3 do
            local fill = env["MinnTinkersWoWFPetHappinessFill" .. index]
            assert(fill.width == inner and fill.height == 7)
            assert(fill.parent.width == inner / 3 - (index < 3 and 1 or 0))
            assert(fill.parent.point[4] == 2 + (index - 1) * inner / 3)
            assert(fill.point[4] == -(index - 1) * inner / 3)
        end
    end
    geometry(74); geometry(100)
    frame.scripts.OnSizeChanged(frame, state.secretValue, 10)
    frame.scripts.OnSizeChanged(frame, 0, 10)
    assert(env.MinnTinkersWoWFPetHappinessFill1.width == 96)
    local originalRect = env.PetFrameTexture.GetRect
    env.PetFrameTexture.GetRect = function() return state.secretValue, 0, 120, 49 end
    geometry(74); assert(state.borders[1].alpha == 0)
    env.PetFrameTexture.GetRect = function() end
    geometry(74); assert(state.borders[1].alpha == 0)
    env.PetFrameTexture.GetRect = originalRect
    geometry(74); assert(state.borders[1].alpha == 1 and state.borders[1].texture == 12345)
    local atlas = state.atlas
    state.atlas = nil; geometry(74)
    for _, border in ipairs(state.borders) do assert(border.alpha == 0) end
    state.atlas = atlas; geometry(74)
    atlas.leftTexCoord = state.secretValue; geometry(74)
    for _, border in ipairs(state.borders) do assert(border.alpha == 0) end
    atlas.leftTexCoord = 0.1; geometry(74)
    for _, border in ipairs(state.borders) do assert(border.alpha == 1) end
    assert(state.maskReads == 1, "Resize and pet display changes must not recrop masks")
    state.value = 800; test.emit("UNIT_POWER_UPDATE", "pet", "HAPPINESS")
    assert(env.MinnTinkersWoWFPetHappinessFill3.value == 800)
    state.hunter = false; test.emit("UNIT_PET", "player")
    assert(frame.alpha == 0 and icon.Texture.alpha == 0.8)
    local reads = state.reads
    test.emit("PET_UI_UPDATE"); assert(state.reads == reads)
    state.hunter = true; state.maximum = 0; test.emit("UNIT_PET", "player")
    assert(frame.alpha == 0 and state.reads == reads)
    state.maximum = 900; test.emit("UNIT_HAPPINESS", "pet")
    assert(frame.alpha == 1 and icon.Texture.alpha == 0)
    state.setPetShown(false); test.emit("UNIT_HAPPINESS", "pet")
    assert(frame.alpha == 0 and icon.Texture.alpha == 0.8)
    reads = state.reads; state.setPetShown(true)
    assert(frame.alpha == 1 and state.reads == reads + 1)
    state.hunter = state.secretValue; test.emit("PET_UI_UPDATE")
    assert(frame.alpha == 0 and icon.Texture.alpha == 0.8)
    state.hunter = true; state.value = nil; test.emit("PET_UI_UPDATE"); assert(frame.alpha == 0)
    state.value = 200; test.emit("PET_UI_UPDATE"); assert(frame.alpha == 1)
    test.addon.ToggleOptions()
    local tab = env.MinnTinkersWoWFOptionsTab2; tab.scripts.OnClick(tab)
    local check = env.MinnTinkersWoWFPetHappiness
    assert(check.enabled and check.checked)
    check:SetChecked(false); check.scripts.OnClick(check)
    assert(not env.MinnTinkersWoWFDB.petHappinessBar and frame.alpha == 0 and icon.Texture.alpha == 0.8)
    check:SetChecked(true); check.scripts.OnClick(check)
    assert(env.MinnTinkersWoWFDB.petHappinessBar and frame.alpha == 1)
    module.SetEnabled(false)
    local reload = petFixture(env.MinnTinkersWoWFDB); reload.login()
    assert(not reload.env.MinnTinkersWoWFDB.petHappinessBar and reload.env.MinnTinkersWoWFPetHappinessBar.alpha == 0
        and reload.env.PetFrameHappiness.Texture.alpha == 0.8)
    local nonHunter, nonHunterState = petFixture(); nonHunterState.hunter = false; nonHunter.login()
    assert(nonHunter.env.MinnTinkersWoWFPetHappinessBar.alpha == 0 and nonHunterState.reads == 0)
    local missingMask, missingMaskState = petFixture()
    missingMaskState.maskAtlas = nil
    missingMask.login()
    assert(#missingMaskState.masks == 0 and missingMask.env.MinnTinkersWoWFPetHappinessBar.alpha == 1)
    for index = 1, 3 do
        local fill = missingMask.env["MinnTinkersWoWFPetHappinessFill" .. index]
        assert(fill.value == 200 and #fill.fillTexture.masks == 0 and #missingMaskState.zoneBackgrounds[index].masks == 0,
            "An unavailable mask must not hide the fill or dim zones")
    end
    local unavailable = fixture(); unavailable.login(); unavailable.addon.ToggleOptions()
    assert(not unavailable.addon.PetHappinessBar.IsAvailable() and unavailable.env.MinnTinkersWoWFPetHappiness.enabled == false)
end
print("PASS: happiness bar anchoring/resizing, pet replacement/dismissal, hidden pet frame, non-hunters, unavailable/invalid values, UI toggle and reload persistence")

local function chatFixture(saved, characterSaved)
    local test = fixture(saved, characterSaved)
    local env, create = test.env, test.env.CreateFrame
    local state = {reads = 0, timestamp = "none", secret = newproxy()}
    env.canaccessvalue = function(...)
        for index = 1, select("#", ...) do if rawequal(select(index, ...), state.secret) then return false end end
        return true
    end
    env.TIMESTAMP_FORMAT_HHMM_24HR, env.TIMESTAMP_FORMAT_HHMMSS_24HR = "%H:%M", "%H:%M:%S"
    env.TIMESTAMP_FORMAT_HHMM_AMPM, env.TIMESTAMP_FORMAT_HHMMSS_AMPM = "%I:%M %p", "%I:%M:%S %p"
    env.MenuUtil = {CreateContextMenu = function(_, build)
        state.menu = {}
        build(nil, {
            CreateTitle = function() end,
            CreateRadio = function(_, label, selected, callback)
                state.menu[#state.menu + 1] = {label = label, selected = selected, callback = callback}
            end,
        })
    end}
    env.Settings = {
        GetValue = function(key) assert(key == "showTimestamps"); return state.timestamp end,
        SetValue = function(key, value) assert(key == "showTimestamps"); state.timestamp = value end,
    }
    env.CreateFrame = function(...)
        local frame = create(...)
        function frame:SetMultiLine(value) self.multiline = value end
        function frame:SetFontObject(value) self.fontObject = value end
        function frame:SetScrollChild(value) self.scrollChild = value end
        function frame:SetVerticalScroll(value) self.offset = value end
        function frame:HighlightText() self.highlighted = true end
        return frame
    end
    env.IsAltKeyDown = function() return state.altKey or false end
    env.IsControlKeyDown = function() return state.controlKey or false end
    env.IsShiftKeyDown = function() return state.shiftKey or false end
    env.AutoCompleteBox = {IsShown = function() return state.autocomplete or false end}
    env.CHAT_FRAMES = {"ChatFrame1"}
    local function makeChat(name)
        local chat = env.CreateFrame("Frame", name)
        chat.buttonFrame = env.CreateFrame("Frame", name .. "ButtonFrame")
        local box = env.CreateFrame("EditBox", name .. "EditBox")
        chat.editBox, chat.lines, chat.offset = box, {}, 0
        box.chatFrame, box.attributes, box.altArrows, box.history = chat, {chatType = "SAY", stickyType = "SAY"}, true, {}
        function box:GetAltArrowKeyMode() return self.altArrows end
        function box:SetAltArrowKeyMode(value) self.altArrows = value end
        function box:GetAttribute(key) return self.attributes[key] end
        function box:SetAttribute(key, value) self.attributes[key] = value end
        function box:GetChatType() return self.attributes.chatType end
        function box:SetChatType(value) self.attributes.chatType = value end
        function box:GetTellTarget() return self.attributes.tellTarget end
        function box:SetTellTarget(value) self.attributes.tellTarget = value end
        function box:UpdateHeader() self.headerType = self:GetChatType() end
        function box:ResetChatType() end
        function box:AddHistoryLine(text) self.history[#self.history + 1] = text end
        function box:ClearHistory() self.history = {} end
        function box:SendMessage()
            self:AddHistoryLine(self:GetText())
            self:SetText(""); self:ClearFocus(); self:Hide()
        end
        function box:SetText(value, userInput)
            self.textValue = value
            if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, userInput) end
        end
        function box:GetText() return self.textValue or "" end
        box:SetScript("OnEscapePressed", function(self)
            if state.autocomplete then state.autocomplete = false; return end
            self:SetChatType("SAY"); self:SetText(""); self:Hide(); self:ClearFocus()
        end)
        function chat:AtBottom() return self.offset == 0 end
        function chat:SetScrollOffset(value) self.offset = value end
        function chat:ScrollToBottom() self:SetScrollOffset(0) end
        function chat:AddMessage(text) self.lines[#self.lines + 1] = text end
        function chat:GetNumMessages() return #self.lines end
        function chat:GetMessageInfo(index) state.reads = state.reads + 1; return self.lines[index] end
        function chat:Clear() self.lines = {}; self:SetScrollOffset(0) end
        return chat, box
    end
    local chat, box = makeChat("ChatFrame1")
    env.ChatFrameUtil = {
        GetChatFocusOverride = function() return state.focusOverride end,
        ChooseBoxForSend = function(frame) return frame and frame.editBox or box end,
        OpenChat = function(text, frame)
            local input = frame and frame.editBox or box
            input:Show(); input:SetFocus()
            input.text, input.setText = text, text and 1 or nil
        end,
    }
    env.FCF_OpenNewWindow = function() makeChat("ChatFrame3"); env.CHAT_FRAMES[#env.CHAT_FRAMES + 1] = "ChatFrame3" end
    env.FCF_OpenTemporaryWindow = function() makeChat("ChatFrame4"); env.CHAT_FRAMES[#env.CHAT_FRAMES + 1] = "ChatFrame4" end
    state.chat, state.box, state.makeChat = chat, box, makeChat
    state.open = function(text, frame)
        env.ChatFrameUtil.OpenChat(text, frame)
        local input = frame and frame.editBox or box
        if input.setText == 1 then input:SetText(input.text); input.setText = 0 end
    end
    return test, state
end

do
    local test, state = chatFixture(); test.login()
    local env, box = test.env, state.box
    assert(test.addon.ChatInput.IsAvailable() and box.altArrows == false)
    state.open(""); box:SetChatType("WHISPER"); box:SetTellTarget("Minnona-Northdale")
    box:SetText("unfinished whisper", true)
    state.autocomplete = true; box.scripts.OnEscapePressed(box)
    assert(box:GetText() == "unfinished whisper" and box.focus and box:IsShown())
    box.scripts.OnEscapePressed(box)
    assert(box:GetText() == "unfinished whisper" and not box.focus and not box:IsShown())
    state.open("")
    assert(box:GetText() == "unfinished whisper" and box:GetChatType() == "WHISPER" and box:GetTellTarget() == "Minnona-Northdale")
    box:SendMessage(); state.open("")
    assert(box:GetText() == "" and #box.history == 1)
    box:SetChatType("CHANNEL"); box:SetAttribute("channelTarget", 4); box:SetText("channel draft", true)
    box.scripts.OnEscapePressed(box); state.open("")
    assert(box:GetText() == "channel draft" and box:GetChatType() == "CHANNEL" and box:GetAttribute("channelTarget") == 4)
    box.scripts.OnEscapePressed(box); state.open("/p ")
    assert(box:GetText() == "/p ", "Explicit commands must not restore the old draft's destination")
    box:SetText("temporary", true); box:SetText("", true); box.scripts.OnEscapePressed(box); state.open("")
    assert(box:GetText() == "", "A deliberately emptied draft must not return")
    box:SetText("hidden", true); box.scripts.OnEscapePressed(box)
    test.addon.ChatInput.SetOption("preserveDraft", false); state.open("")
    assert(box:GetText() == "")
    test.addon.ChatInput.SetOption("arrowHistory", false); assert(box.altArrows == true)
    test.addon.ChatInput.SetOption("arrowHistory", true); assert(box.altArrows == false)
    test.addon.ChatInput.SetOption("preserveDraft", true)
    box:SetText(state.secret, true); box.scripts.OnEscapePressed(box); state.open("")
    assert(box:GetText() == "", "Inaccessible text must never be retained or restored")
    env.FCF_OpenNewWindow(); env.FCF_OpenTemporaryWindow()
    assert(env.ChatFrame3.editBox.altArrows == false and env.ChatFrame4.editBox.altArrows == false)
    local hooks = box.scripts.OnEscapePressed
    test.addon.ChatInput.Initialize(); test.addon.ChatTools.Initialize()
    assert(hooks == box.scripts.OnEscapePressed, "Initialization must not install duplicate hooks")
    box:SetText("old conversation", true); box.scripts.OnEscapePressed(box); box:ClearHistory(); state.open("")
    assert(box:GetText() == "", "Reused chat windows must not restore drafts from the old conversation")
    assert(box.scripts.OnUpdate == nil and #test.timers == 0)
    test.combat(true); state.open(""); box:SetText("combat draft", true); box.scripts.OnEscapePressed(box); state.open("")
    assert(box:GetText() == "combat draft")
end
print("PASS: chat draft Escape/reopen, autocomplete, whisper/channel routing, explicit commands, empty/sent/disabled/secret drafts, native arrow mode restoration, late windows and no polling")

do
    local test, state = chatFixture(); test.login()
    local env, chat = test.env, state.chat
    local copy, marker = chat.children[1], chat.children[2]
    assert(copy.template == "UIMenuButtonStretchTemplate" and copy:IsShown() and not marker:IsShown())
    assert(copy.width == 26 and copy.height == 26 and copy.point[2] == chat.buttonFrame and copy.point[3] == "BOTTOM" and copy.point[4] == 0 and copy.point[5] == -4)
    chat:AddMessage("at bottom"); assert(not marker:IsShown() and state.reads == 0)
    chat:SetScrollOffset(3); assert(not marker:IsShown())
    chat:AddMessage("|cff00ff00|Hplayer:Name|h[Name]|h|r: hello |Ticon:12|t https://example.com")
    assert(marker:IsShown() and state.reads == 0, "Unread tracking must never scan chat history")
    marker.scripts.OnClick(); assert(chat:AtBottom() and not marker:IsShown())
    chat:SetScrollOffset(2); chat:AddMessage(state.secret)
    test.addon.ChatTools.SetOption("unreadMarker", false); assert(not marker:IsShown())
    test.addon.ChatTools.SetOption("unreadMarker", true); assert(not marker:IsShown())
    chat:AddMessage("new"); assert(marker:IsShown()); chat:Clear(); assert(not marker:IsShown())
    chat:AddMessage("oldest"); chat:AddMessage("|cff00ff00|Hitem:1|h[Item]|h|r |A:atlas:12:12|a || test")
    chat:AddMessage(state.secret); chat:AddMessage("newest")
    copy.scripts.OnEnter(copy); assert(env.GameTooltip:IsOwned(copy) and env.GameTooltip.text == "Copy chat")
    copy.scripts.OnLeave(copy); assert(not env.GameTooltip:IsShown())
    copy.scripts.OnClick()
    local window, input = env.MinnTinkersWoWFCopyChat, env.MinnTinkersWoWFCopyChatText
    assert(window:IsShown() and input.focus and input.highlighted and input.multiline)
    assert(input:GetText() == "oldest\n[Item]  | test\nnewest")
    local reads = state.reads; chat:AddMessage("after copy"); assert(state.reads == reads)
    copy.scripts.OnClick()
    assert(not window:IsShown() and not input.focus and input:GetText() == "" and state.reads == reads, "Closing must not read the chat buffer")
    copy.scripts.OnClick()
    assert(window:IsShown() and input:GetText():find("after copy", 1, true), "Reopening must refresh retained chat text")
    input.scripts.OnEscapePressed(); assert(not window:IsShown() and not input.focus and input:GetText() == "")
    test.addon.ChatTools.SetOption("copyChat", false); assert(not copy:IsShown())
    copy.scripts.OnClick(); assert(not window:IsShown())
    test.addon.ChatTools.SetOption("copyChat", true); copy.scripts.OnClick(); assert(window:IsShown())
    test.addon.ChatTools.SetOption("copyChat", false); assert(not window:IsShown())
    test.addon.ToggleOptions()
    env.MinnTinkersWoWFOptionsTab3.scripts.OnClick(env.MinnTinkersWoWFOptionsTab3)
    assert(env.MinnTinkersWoWFDB.lastTab == "Chat" and env.MinnTinkersWoWFChatURLs.point[3] == -114)
    local timestamps = env.MinnTinkersWoWFChatTimestamps
    assert(timestamps.enabled and timestamps.text == "Timestamps: Off")
    timestamps.scripts.OnClick(timestamps)
    assert(#state.menu == 5 and state.menu[1].selected())
    state.menu[3].callback()
    assert(state.timestamp == "%H:%M:%S" and timestamps.text == "Timestamps: 24-hour with seconds")
    local reload = chatFixture(env.MinnTinkersWoWFDB); reload.login(); reload.addon.ToggleOptions()
    assert(reload.env.MinnTinkersWoWFOptions.selectedTab == 3 and not reload.env.MinnTinkersWoWFDB.chat.copyChat)
    local warrior = fixture(); warrior.env.UnitClass = function() return "Warrior", "WARRIOR" end
    warrior.login(); warrior.addon.ToggleOptions()
    assert(not warrior.env.MinnTinkersWoWFPetHappiness and warrior.env.MinnTinkersWoWFRangeEnabled.point[3] == -316)
    assert(not env.MinnTinkersWoWFChat_copyChat.checked and env.MinnTinkersWoWFChat_copyChat.enabled)
end
print("PASS: event-driven unread marker/reset, on-demand plain-text copy/order/reuse/secret exclusion, independent toggles, native timestamps, Chat tab persistence and hunter-only Pet layout")


do
    local test, state = chatFixture(); test.login()
    local box, env = state.box, test.env
    local function arrow(key) box.scripts.OnArrowPressed(box, key) end
    state.open(""); box.altArrows = true; box.scripts.OnEditFocusGained(box); assert(not box.altArrows)
    box:SetText("draft", true); arrow("UP")
    assert(box:GetText() == "draft", "Empty history must preserve input")
    box:SetText("first", true); box:SendMessage()
    state.open(""); box:SetText("second", true); box:SendMessage()
    state.open(""); box:SetChatType("WHISPER"); box:SetTellTarget("Minnona"); box:SetText("draft", true)
    arrow("UP"); assert(box:GetText() == "second")
    arrow("UP"); assert(box:GetText() == "first")
    arrow("UP"); assert(box:GetText() == "first", "Oldest entry must not wrap")
    arrow("DOWN"); assert(box:GetText() == "second")
    arrow("DOWN"); assert(box:GetText() == "draft" and box:GetChatType() == "WHISPER" and box:GetTellTarget() == "Minnona")
    arrow("DOWN"); assert(box:GetText() == "draft")
    env.AutoCompleteBox.parent, state.autocomplete = box, true
    arrow("UP"); assert(box:GetText() == "draft", "Autocomplete must retain its arrows")
    state.autocomplete = false
    for _, modifier in ipairs({"altKey", "controlKey", "shiftKey"}) do
        state[modifier] = true; arrow("UP"); assert(box:GetText() == "draft"); state[modifier] = false
    end
    test.addon.ChatInput.SetOption("arrowHistory", false); arrow("UP"); assert(box:GetText() == "draft")
    test.addon.ChatInput.SetOption("arrowHistory", true)
    arrow("UP"); box:SetText("edited", true); arrow("UP"); assert(box:GetText() == "second")
    arrow("DOWN"); assert(box:GetText() == "edited", "Editing recalled text must start a new draft")
    box:ClearHistory(); arrow("UP"); assert(box:GetText() == "second", "Native history resets must retain saved messages")
    arrow("DOWN"); assert(box:GetText() == "edited")
    for index = 1, 40 do box:AddHistoryLine("entry " .. index) end
    box:AddHistoryLine("entry 40"); box:AddHistoryLine(state.secret)
    for index = 1, 40 do arrow("UP") end
    assert(box:GetText() == "entry 9", "Retain only 32 accessible entries and skip consecutive duplicates")
    for index = 1, 40 do arrow("DOWN") end
    assert(box:GetText() == "edited")
    test.addon.ChatInput.SetOption("preserveDraft", false)
    arrow("UP"); assert(box:GetText() == "entry 40", "History must work independently of Escape preservation")
    test.combat(true); arrow("UP"); assert(box:GetText() == "entry 39")
    assert(#test.timers == 0 and box.scripts.OnUpdate == nil)
end
print("PASS: actual Up/Down history traversal, both bounds, scratch draft/destination restoration, empty/cleared history, editing, modifiers/autocomplete, independent toggle, secrets and bounded storage")


-- SavedVariables are character-specific; only sent messages survive a fresh Lua environment.
do
    local test, state = chatFixture(); test.login()
    state.open(""); state.box:SetText("first saved", true); state.box:SendMessage()
    state.open(""); state.box:SetText("second saved", true); state.box:SendMessage()
    state.open(""); state.box:SetText("unsent draft", true); state.box.scripts.OnEscapePressed(state.box)
    local saved = test.env.MinnTinkersWoWFCharDB
    assert(#saved.chatHistory == 2 and saved.chatHistory[2] == "second saved")
    local serialized = string.format("return {chatHistory={%q,%q},extra=%q}", saved.chatHistory[1], saved.chatHistory[2], "preserved")
    local reloadedDB = assert(loadstring(serialized))()
    local reload, fresh = chatFixture(test.env.MinnTinkersWoWFDB, reloadedDB); reload.login()
    fresh.open(""); assert(fresh.box:GetText() == "", "Unsent drafts remain session-only")
    fresh.box.scripts.OnArrowPressed(fresh.box, "UP"); assert(fresh.box:GetText() == "second saved")
    fresh.box.scripts.OnArrowPressed(fresh.box, "UP"); assert(fresh.box:GetText() == "first saved")
    assert(reloadedDB.extra == "preserved")
    reload.env.FCF_OpenNewWindow()
    local newChat = reload.env.ChatFrame3
    fresh.open("", newChat); newChat.editBox.scripts.OnArrowPressed(newChat.editBox, "UP")
    assert(newChat.editBox:GetText() == "second saved", "New windows must share the character's saved history")
    newChat.editBox:ClearHistory()
    newChat.editBox:SetText("", true); newChat.editBox.scripts.OnArrowPressed(newChat.editBox, "UP")
    assert(newChat.editBox:GetText() == "second saved" and #reloadedDB.chatHistory == 2)
    newChat.editBox:AddHistoryLine("third saved")
    fresh.box:SetText("", true); fresh.box.scripts.OnArrowPressed(fresh.box, "UP")
    assert(fresh.box:GetText() == "third saved", "Messages from any input must update the shared history")
    local alt, other = chatFixture(test.env.MinnTinkersWoWFDB); alt.login()
    other.open(""); other.box.scripts.OnArrowPressed(other.box, "UP")
    assert(other.box:GetText() == "" and #alt.env.MinnTinkersWoWFCharDB.chatHistory == 0)
    for index = 1, 40 do newChat.editBox:AddHistoryLine("persisted " .. index) end
    assert(#reloadedDB.chatHistory == 32 and reloadedDB.chatHistory[1] == "persisted 9")
    local corrupt = {chatHistory = {false, 14, "", "valid", "valid", "last"}, extra = true}
    local repaired = chatFixture(nil, corrupt); repaired.login()
    assert(#corrupt.chatHistory == 2 and corrupt.chatHistory[1] == "valid" and corrupt.chatHistory[2] == "last" and corrupt.extra)
    local malformed = {chatHistory = "invalid"}; local repairedType = chatFixture(nil, malformed); repairedType.login()
    assert(type(malformed.chatHistory) == "table" and #malformed.chatHistory == 0)
end
print("PASS: sent-history serialization/reload, session-only drafts, per-character isolation, shared/reused windows, bounded saved storage and invalid saved-data repair")


-- Consistent rows and category gaps must fit the existing minimum window height.
do
    local test = fixture(); test.login(); test.addon.ToggleOptions()
    local env, window = test.env, test.env.MinnTinkersWoWFOptions
    local function y(region) return -region.point[#region.point] end
    local function heading(page, title)
        for _, text in ipairs(page.fontStrings) do if text.text == title then return text end end
        error("Missing section: " .. title)
    end
    local function gap(page, title, lastRow)
        assert(y(heading(page, title)) - (y(lastRow) + 26) == 24, "Section gaps must be equal: " .. title)
    end
    local universal, ui, chat = unpack(window.Inset.children)
    gap(universal, "Camera", env.MinnTinkersWoWFFastAutoloot)
    gap(universal, "Questing", env.MinnTinkersWoWFCameraDistance.parent)
    local note
    for _, text in ipairs(universal.fontStrings) do if text.text == "Hold Shift to handle quests manually." then note = text end end
    assert(y(heading(universal, "NPC interaction")) - (y(note) - 6 + 26) == 24)
    gap(ui, "Combat indicator", env.MinnTinkersWoWFFont_macroText.parent)
    gap(ui, "Pet", env.MinnTinkersWoWFCombat_width.parent)
    gap(ui, "Range indicator", env.MinnTinkersWoWFPetHappiness)
    gap(chat, "Chat tools", env.MinnTinkersWoWFChat_preserveDraft)
    gap(chat, "Timestamps", env.MinnTinkersWoWFChat_unreadMarker)
    for _, rows in ipairs({
        {env.MinnTinkersWoWFFont_keybinds.parent, env.MinnTinkersWoWFFont_itemCount.parent, env.MinnTinkersWoWFFont_macroText.parent},
        {env.MinnTinkersWoWFCombat_enabled, env.MinnTinkersWoWFCombat_opacity.parent, env.MinnTinkersWoWFCombat_width.parent},
        {env.MinnTinkersWoWFRangeEnabled, env.MinnTinkersWoWFRangeSpellSlot},
        {env.MinnTinkersWoWFRangeSize.parent, env.MinnTinkersWoWFRangeOpacity.parent, env.MinnTinkersWoWFRangeResetPosition},
    }) do
        for index = 2, #rows do assert(y(rows[index]) - y(rows[index - 1]) == 32) end
    end
    assert(y(env.MinnTinkersWoWFRangeResetPosition) + 26 == 576 and window.height == 670)
    assert(env.MinnTinkersWoWFRangeEnabled.Text.fontSize == 11 and heading(ui, "Range indicator").fontSize == 11)
    local originalSize = env.MinnTinkersWoWFRangeEnabled.Text.fontSize
    test.addon.ToggleOptions(); test.addon.ToggleOptions()
    assert(env.MinnTinkersWoWFRangeEnabled.Text.fontSize == originalSize, "Reopening must not keep increasing fonts")
end
print("PASS: equal category gaps, consistent control rows, hunter layout fits minimum size, slightly larger text and no font growth on reopen")
