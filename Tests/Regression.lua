local root = assert(arg[1], "Pass the addon directory")
local function MockValueAccess(env, accessible)
    env.canaccessvalue = function(...)
        assert(select("#", ...) == 1, "Use canaccessallvalues to check multiple values")
        return accessible(...)
    end
    env.canaccessallvalues = function(...)
        for index = 1, select("#", ...) do
            if not accessible((select(index, ...))) then return false end
        end
        return true
    end
end

local function IsSelected(env, id)
    local window = env.MinnTinkersWoWFOptions
    for index, page in ipairs(window.Inset.children) do
        local tab = env["MinnTinkersWoWFOptionsTab" .. index]
        if tab.checked ~= (index == id) or page:IsShown() ~= (index == id) then return false end
    end
    return window.Inset.children[id] ~= nil
end

local function ClickTab(tab)
    tab.scripts.OnMouseUp(tab, "LeftButton", true)
end

local function fixture(saved, characterSaved)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local frames, timers, requests, nativeCalls, messages = {}, {}, {}, {}, {}
    local slots, lootAction = {}, nil
    local addon = {}
    local combat = false
    local emit
    local camera = { value = 1.9, cap = 4.0, writes = 0 }
    env.C_CVar = {
        GetCVar = function() return camera.value and tostring(camera.value) end,
        GetCVarInfo = function()
            return camera.value and tostring(camera.value), "1.9", false, false, camera.locked, camera.secure, camera.readOnly
        end,
        SetCVar = function(name, value)
            camera.writes = camera.writes + 1
            if camera.reject then return false end
            local accepted = math.min(camera.cap, math.max(1, tonumber(value)))
            local changed = camera.value ~= accepted
            camera.value = accepted
            if changed and emit then emit("CVAR_UPDATE", name, tostring(accepted)) end
            return true
        end,
    }
    env.InCombatLockdown = function() return combat end
    env.issecretvalue = function() return false end
    env.NORMAL_FONT_COLOR = {GetRGB = function() return 1, 0.82, 0 end}
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
        function f:RegisterUnitEvent(event) self:RegisterEvent(event) end
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
        function f:SetClampRectInsets(...) self.clamp = {...} end
        function f:GetWidth() return self.width or 144 end
        function f:GetCenter() return self.centerX or 0, self.centerY or 0 end
        function f:GetEffectiveScale() return self.scale or 1 end
        function f:SetID(id) self.id = id end
        function f:StartSizing(edge, fromMouse) self.sizing = {edge, fromMouse} end
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
        function f:GetValue() return self.value end
        function f:SetTitle(value) self.title = value end
        function f:SetPortraitToAsset(value) self.portrait = value end
        function f:SetText(value) self.text = value end
        function f:GetText() return self.text or "" end
        function f:SetAutoFocus(value) self.autoFocus = value end
        function f:SetMaxLetters(value) self.maxLetters = value end
        function f:SetMaxLines(value) self.maxLines = value end
        function f:SetFocus() self.focus = true end
        function f:ClearFocus() self.focus = false end
        function f:SetFontObject(value) self.fontObject = value end
        function f:SetFontHeight(value) self.fontSize = value end
        function f:SetTextColor(...) self.color = {...} end
        function f:SetTexture(value) self.texture = value end
        function f:GetStringWidth() return #self.text * 7 end
        function f:SetChecked(value) self.checked = value end
        function f:GetChecked() return self.checked end
        function f:CreateFontString(name, _, fontObject)
            local text = frame(name)
            text.fontObject = fontObject
            self.fontStrings = self.fontStrings or {}
            self.fontStrings[#self.fontStrings + 1] = text
            if name then env[name] = text end
            return text
        end
        function f:CreateTexture()
            local texture = frame()
            function texture:SetHorizTile() end
            function texture:SetVertTile() end
            return texture
        end
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
        if template == "ButtonFrameTemplate" then
            f.Inset = frame(); f.children[#f.children + 1] = f.Inset
            f.Inset.Bg = frame()
            f.CloseButton = frame()
            f.CloseButton:SetScript("OnClick", function(self)
                local continueHide = not f.onCloseCallback or f.onCloseCallback(self)
                if continueHide then env.HideUIPanel(f) end
            end)
        end
        if template == "CheckboxWithLabelTemplate" then
            f.Text = frame()
            f.Text.fontObject = "GameFontNormalSmall"
        end
        if template == "LargeSideTabButtonTemplate" then
            f.Icon = frame()
            f:SetSize(52, 54)
            function f:SetFillToInterior(value) self.fillToInterior = value end
            function f:SetCustomOnMouseUpHandler(handler)
                self:SetScript("OnMouseUp", handler)
            end
        end
        if template == "WowStyle1DropdownTemplate" then
            f.OverrideText = f.SetText
            function f:SetupMenu(generator) self.menuGenerator = generator end
        end
        return f
    end
    env.ButtonFrameTemplate_HideButtonBar = function() end
    env.HideUIPanel = function(f)
        assert(not combat, "Blizzard panel close path is blocked in combat")
        env.nativePanelHideCalls = (env.nativePanelHideCalls or 0) + 1
        f:Hide()
    end
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
    emit = function(event, ...)
        if env.LootFrame.events[event] then env.LootFrame.OnEvent(env.LootFrame, event, ...) end
        local listeners = {}
        for _, f in ipairs(frames) do if f.events[event] then listeners[#listeners + 1] = f end end
        for _, f in ipairs(listeners) do f.scripts.OnEvent(f, event, ...) end
    end
    for _, file in ipairs({"Core.lua", "Modules/FastLoot.lua", "Modules/ActionBarFonts.lua", "Modules/BarVisibility.lua", "Modules/CameraDistance.lua", "Modules/WorldGraphics.lua", "Modules/FishingSound.lua", "Modules/Questing.lua", "Modules/GossipSkip.lua", "Modules/AutoSellJunk.lua", "Modules/CombatIndicator.lua", "Modules/ChatURLs.lua", "Modules/ChatInput.lua", "Modules/ChatTools.lua", "Modules/ChatHistory.lua", "Modules/ChatShadow.lua", "Modules/RangeIndicator.lua", "Modules/PetHappinessBar.lua", "Modules/BuffReminder.lua", "UI/HunterOptions.lua", "UI/Options.lua"}) do
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
assert(window:IsShown() and window.title == "Minn Tinkers WoWF - Universal")
assert(window.portrait == f.addon.icon and IsSelected(f.env, 1) and #window.Inset.children == 4)
assert(window.Inset.children[1]:IsShown() and not window.Inset.children[2]:IsShown())
local firstTab, secondTab = f.env.MinnTinkersWoWFOptionsTab1, f.env.MinnTinkersWoWFOptionsTab2
assert(firstTab.template == "LargeSideTabButtonTemplate" and firstTab.point[3] == "TOPRIGHT")
assert(secondTab.point[2] == firstTab and secondTab.point[3] == "BOTTOMLEFT" and window.clamp[2] == firstTab:GetWidth())
secondTab.scripts.OnMouseUp(secondTab, "RightButton", true)
secondTab.scripts.OnMouseUp(secondTab, "LeftButton", false)
assert(IsSelected(f.env, 1))
assert(check.template == "CheckboxWithLabelTemplate")
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
ClickTab(f.env.MinnTinkersWoWFOptionsTab2)
assert(IsSelected(f.env, 2))
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
assert(window.resizable and window.width == 560 and window.height == 670)
assert(table.concat(resize.bounds, ",") == "560,670,560,800")
assert(window.onResizeStartCallback(resize) == false and window.sizing[1] == "BOTTOM" and window.sizing[2])
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
window:SetHeight(740); resize.resizeStopped(window)
assert(f.env.MinnTinkersWoWFDB.windowWidth == nil and f.env.MinnTinkersWoWFDB.windowHeight == 740)
f.env.MinnTinkersWoWFDB.windowWidth = 1100 -- Ignore a saved width from the older resizable window.
reload = fixture(f.env.MinnTinkersWoWFDB); reload.login(); reload.env.SlashCmdList.MINNTINKERSWOWF()
assert(reload.camera.value == 2.4 and reload.env.MinnTinkersWoWFOptions.width == 560 and reload.env.MinnTinkersWoWFOptions.height == 740)

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
print("PASS: loot/font regressions, camera bounds/readback/persistence/restrictions, vertical-only resizing, saved size and UI refresh without writes")

do
    local test = fixture({cameraMaxFactor = 4}); test.login()
    local env, camera, module = test.env, test.camera, test.addon.CameraDistance
    local cvar = "cameraDistanceMaxZoomFactor"
    local nativeSet = env.C_CVar.SetCVar
    module.Initialize(); assert(camera.writes == 1)
    env.C_CVar.SetCVar(cvar, "2.6")
    assert(camera.value == 4 and camera.writes == 3 and env.MinnTinkersWoWFDB.cameraMaxFactor == 4)
    local writes = camera.writes
    for _ = 1, 100 do test.emit("CVAR_UPDATE", cvar, "4") end
    test.emit("CVAR_UPDATE", "unrelatedSetting", "0")
    assert(camera.writes == writes and #test.timers == 0, "Stable or unrelated events must not write or poll")
    camera.value = 2.6; test.emit("CVAR_UPDATE", cvar:lower(), "2.6"); assert(camera.value == 4)
    module.SetFactor(3.2)
    assert(camera.value == 3.2 and env.MinnTinkersWoWFDB.cameraMaxFactor == 3.2, "Slider changes must replace the enforced preference")
    test.combat(true); env.C_CVar.SetCVar(cvar, "2.6"); assert(camera.value == 3.2)
    camera.value = 2.6; test.emit("PLAYER_ENTERING_WORLD"); assert(camera.value == 3.2)
    for _, restriction in ipairs({"locked", "secure", "readOnly"}) do
        camera[restriction] = true; camera.value = 2.6; writes = camera.writes
        test.emit("CVAR_UPDATE", cvar, "2.6")
        assert(camera.writes == writes and env.MinnTinkersWoWFDB.cameraMaxFactor == 3.2)
        camera[restriction] = false
    end
    camera.reject = true; writes = camera.writes
    test.emit("CVAR_UPDATE", cvar, "2.6")
    assert(camera.writes == writes + 1 and env.MinnTinkersWoWFDB.cameraMaxFactor == 3.2)
    camera.reject = false
    -- Simulate another synchronous listener immediately undoing our restore.
    local external = false
    env.C_CVar.SetCVar = function(name, value)
        local result = nativeSet(name, value)
        if not external then
            external = true
            nativeSet(name, "2.6")
            external = false
        end
        return result
    end
    writes = camera.writes
    test.emit("CVAR_UPDATE", cvar, "2.6")
    assert(camera.writes <= writes + 2 and env.MinnTinkersWoWFDB.cameraMaxFactor == 3.2,
        "Conflicting listeners must not recurse or replace the saved preference")
    local untouched = fixture(); untouched.login(); untouched.camera.value = 2.6
    untouched.emit("CVAR_UPDATE", cvar, "2.6"); untouched.emit("PLAYER_ENTERING_WORLD")
    assert(untouched.camera.writes == 0, "No camera preference means no override")
end
print("PASS: camera preference overrides external changes, ignores stable/unrelated events, follows slider changes, respects restrictions and avoids recursive writes without polling")

do
    local test = fixture(); test.login(); test.addon.ToggleOptions()
    local env, window = test.env, test.env.MinnTinkersWoWFOptions
    test.combat(true)
    window:SetHeight(720)
    window.CloseButton.scripts.OnClick(window.CloseButton)
    assert(not window:IsShown() and env.nativePanelHideCalls == nil)
    assert(env.MinnTinkersWoWFDB.windowWidth == nil and env.MinnTinkersWoWFDB.windowHeight == 720)
    test.addon.ToggleOptions(); assert(window:IsShown())
    test.combat(false); window.CloseButton.scripts.OnClick(window.CloseButton)
    assert(not window:IsShown() and env.nativePanelHideCalls == nil)
end
print("PASS: options close button uses the native callback to hide the addon window in and out of combat, preserving size and reopen behavior")

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

-- Dialogue UI replaces the native quest frame and builds its completion page separately.
do
    local function dialogueFixture()
        local test, state, choices = questFixture()
        local env = test.env
        env.QuestFrame:Hide()
        local dialogue = env.CreateFrame("Frame")
        env.DUIQuestFrame = dialogue
        local button = env.CreateFrame("Button", nil, dialogue)
        dialogue.AcceptButton = button
        button.type = "complete"
        button:Show()
        function button:IsVisible() return dialogue:IsShown() and self:IsShown() end
        function button:IsEnabled() return not state.disabled end
        function button:Click(mouseButton)
            assert(mouseButton == "LeftButton")
            assert(not state.moneyCost and #state.choices <= 1)
            state.dialogueReward = #state.choices
            dialogue:Hide()
        end
        env.GetQuestMoneyToGet = function() return state.moneyCost and 1 or 0 end
        test.login()
        return test, state, choices, dialogue
    end
    for count = 0, 2 do
        local test, state, choices, dialogue = dialogueFixture()
        local items = {}
        for index = 1, count do items[index] = {link = "item:" .. index} end
        choices(items)
        test.emit("QUEST_COMPLETE")
        assert(state.dialogueReward == nil)
        dialogue.questID, dialogue.handler = state.id, "HandleQuestComplete"
        dialogue:Show()
        test.emit("QUEST_ITEM_UPDATE")
        test.flush(0)
        assert(state.dialogueReward == (count < 2 and count or nil))
        assert(state.rewarded == 0, "Do not call the hidden Blizzard reward handler")
    end
    for _, block in ipairs({"closed", "shift", "changed", "wrong page", "disabled", "repeatable", "paid", "setting"}) do
        local test, state, _, dialogue = dialogueFixture()
        dialogue.questID, dialogue.handler = state.id, "HandleQuestComplete"
        dialogue:Show()
        if block == "repeatable" then state.repeatable[state.id] = true end
        if block == "paid" then
            state.moneyCost = true
            test.emit("QUEST_PROGRESS")
            assert(state.completed == 0)
        end
        test.emit("QUEST_COMPLETE")
        if block == "closed" then test.emit("QUEST_FINISHED") end
        if block == "shift" then
            state.shift = true
            test.emit("MODIFIER_STATE_CHANGED")
            state.shift = false
        end
        if block == "changed" then state.id = state.id + 1 end
        if block == "wrong page" then dialogue.handler = "HandleQuestProgress" end
        if block == "disabled" then state.disabled = true end
        if block == "setting" then test.addon.Questing.SetOption("autoTurnIn", false) end
        test.flush(0)
        assert(state.dialogueReward == nil and state.rewarded == 0, block)
    end
    local test, state = dialogueFixture()
    test.env.QuestFrame:RegisterEvent("QUEST_COMPLETE")
    test.env.QuestFrame:SetScript("OnEvent", function() end)
    test.env.QuestFrame:Show()
    test.emit("QUEST_COMPLETE")
    assert(state.rewarded == 1 and state.dialogueReward == nil and #test.timers == 0)
end
print("PASS: Dialogue UI auto turn-in timing, reward choices, bypasses and native fallback")

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
assert(window:IsShown() and IsSelected(f.env, 1))
ClickTab(f.env.MinnTinkersWoWFOptionsTab2)
assert(f.env.MinnTinkersWoWFDB.lastTab == "UI")
minimap.scripts.OnClick(minimap); assert(not window:IsShown())
f.env.SlashCmdList.MINNTINKERSWOWF(); assert(window:IsShown() and IsSelected(f.env, 2))
reload = fixture(f.env.MinnTinkersWoWFDB); reload.login(); reload.env.SlashCmdList.MINNTINKERSWOWF()
assert(IsSelected(reload.env, 2))
assert(reload.env.MinnTinkersWoWFOptions.Inset.children[2]:IsShown())
f = fixture({lastTab = "Removed category"}); f.login(); f.env.SlashCmdList.MINNTINKERSWOWF()
assert(IsSelected(f.env, 1) and f.env.MinnTinkersWoWFDB.lastTab == "Universal")
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
local function gossipFixture(saved, withDialogue)
    local test = fixture(saved)
    local env = test.env
    local state = {options = {{gossipOptionID = 42, orderIndex = 3, status = 0}}, available = {}, active = {}, shift = false, selected = {}}
    local restricted = newproxy()
    state.restricted = restricted
    MockValueAccess(env, function(value) return not rawequal(value, restricted) end)
    env.GossipFrame = env.CreateFrame("Frame"); env.GossipFrame:Show()
    env.Enum.GossipOptionStatus = {Available = 0, Unavailable = 1, Locked = 2, AlreadyComplete = 3}
    env.IsShiftKeyDown = function() return state.shift end
    env.C_GossipInfo = {
        GetOptions = function() return state.options end,
        GetAvailableQuests = function() return state.available end,
        GetActiveQuests = function() return state.active end,
        SelectOptionByIndex = function(...)
            assert(select("#", ...) == 1, "Must preserve native confirmation")
            state.selected[#state.selected + 1] = (...)
        end,
    }
    if withDialogue then
        env.GossipFrame:Hide()
        local dialogue = env.CreateFrame("Frame")
        env.DUIQuestFrame = dialogue
        local button = env.CreateFrame("Button", nil, dialogue)
        state.dialogue, state.button, state.clicks, state.now = dialogue, button, 0, 1
        env.GetTime = function() return state.now end
        function dialogue:ShowUI(event)
            self.handler = event == "GOSSIP_SHOW" and "HandleGossip" or "HandleQuestDetail"
            self:Show()
        end
        button.type, button.id, button.gossipOptionID = "gossip", 3, 42
        button:Show()
        function button:IsVisible() return self:IsShown() and dialogue:IsShown() end
        function button:IsEnabled() return not state.disabled end
        function button:Click(mouseButton)
            assert(mouseButton == "LeftButton")
            state.clicks = state.clicks + 1
            env.C_GossipInfo.SelectOptionByIndex(self.id)
        end
        dialogue.optionButtonPool = {ProcessActiveObjects = function(_, visit) visit(button) end}
    end
    test.login()
    return test, state
end
f, gossip = gossipFixture(); f.emit("GOSSIP_SHOW")
assert(#gossip.selected == 1 and gossip.selected[1] == 3)
f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 1)
gossip.options[1].gossipOptionID = 43; f.emit("GOSSIP_SHOW"); assert(gossip.selected[2] == 3)
f.emit("GOSSIP_CLOSED"); f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 3)
f, gossip = gossipFixture()
gossip.options = {{orderIndex = 0, status = 0}}
f.emit("GOSSIP_SHOW"); f.emit("GOSSIP_SHOW")
assert(#gossip.selected == 1 and gossip.selected[1] == 0, "A sole row without an ID still selects by its native index")
f.emit("GOSSIP_CLOSED"); f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 2)
for _, key in ipairs({"orderIndex", "gossipOptionID", "status"}) do
    f, gossip = gossipFixture(); gossip.options[1][key] = gossip.restricted
    f.emit("GOSSIP_SHOW"); assert(#gossip.selected == 0)
end
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

-- Dialogue UI handles its own option click to prepare the game UI for panels such as vendors.
do
    local test, state = gossipFixture(nil, true)
    test.emit("GOSSIP_SHOW"); test.flush(0)
    assert(#state.selected == 0)
    state.dialogue.handler = "HandleGossip"
    state.dialogue:Show(); test.flush(0)
    assert(state.clicks == 1 and state.selected[1] == 3)
    test.emit("GOSSIP_SHOW"); test.flush(0)
    assert(state.clicks == 1 and #state.selected == 1)
    test.emit("GOSSIP_CLOSED"); test.emit("GOSSIP_SHOW"); test.flush(0)
    assert(state.clicks == 2 and #state.selected == 2)

    for _, block in ipairs({"Shift", "quest", "closed", "confirmation", "wrong option", "locked", "wrong page"}) do
        test, state = gossipFixture(nil, true)
        state.dialogue.handler = block == "wrong page" and "HandleQuestDetail" or "HandleGossip"
        state.dialogue:Show()
        if block == "quest" then state.available = {{questID = 1}} end
        if block == "confirmation" then state.dialogue.requireGossipConfirm = true end
        if block == "wrong option" then state.button.gossipOptionID = 99 end
        if block == "locked" then state.disabled = true end
        test.emit("GOSSIP_SHOW")
        if block == "Shift" then
            state.shift = true
            test.emit("MODIFIER_STATE_CHANGED")
            state.shift = false
        elseif block == "closed" then
            test.emit("GOSSIP_CLOSED")
        end
        test.flush(0)
        assert(#state.selected == 0 and state.clicks == 0, block)
    end

    test, state = gossipFixture(nil, true)
    test.env.GossipFrame:Show()
    test.emit("GOSSIP_SHOW"); test.flush(0)
    assert(state.clicks == 0 and #state.selected == 1 and state.selected[1] == 3)
end
print("PASS: Dialogue UI gossip lifecycle, matching option click, exclusions and native fallback")

-- The Dialogue UI page and our GOSSIP_SHOW listener can finish in either order.
do
    local test, state = gossipFixture(nil, true)
    state.dialogue:ShowUI("GOSSIP_SHOW")
    assert(state.clicks == 0, "Page rendering alone must not select an option")
    test.emit("GOSSIP_SHOW")
    assert(state.clicks == 1 and #test.timers == 0, "Ready page should skip in the current update")

    test, state = gossipFixture(nil, true)
    test.emit("GOSSIP_SHOW")
    assert(state.clicks == 0)
    state.dialogue:ShowUI("GOSSIP_SHOW")
    assert(state.clicks == 1 and test.timers[1].cancelled, "Fresh page should skip as soon as rendering finishes")
    test.flush(0)
    assert(state.clicks == 1, "Fallback must not select the same option again")

    test, state = gossipFixture(nil, true)
    state.dialogue:ShowUI("GOSSIP_SHOW")
    state.now = state.now + 0.01
    test.emit("GOSSIP_SHOW")
    assert(state.clicks == 0, "A readiness signal from an earlier frame must not trigger the immediate path")
    test.flush(0)
    assert(state.clicks == 1, "Keep the deferred fallback")

    test, state = gossipFixture(nil, true)
    state.dialogue:ShowUI("GOSSIP_SHOW")
    state.shift = true
    test.emit("GOSSIP_SHOW")
    test.flush(0)
    assert(state.clicks == 0, "Opening with Shift must bypass the immediate path")
end
print("PASS: Dialogue UI skips as soon as the page is ready in either listener order")

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
    MockValueAccess(env, function() return true end)
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
    MockValueAccess(test.env, function(value) return not rawequal(value, secret) end)
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
    MockValueAccess(env, function(value) return not rawequal(value, secret) end)
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
    local tab = env.MinnTinkersWoWFOptionsTab2; ClickTab(tab)
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
    local tab = env.MinnTinkersWoWFOptionsTab2; ClickTab(tab)
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
    local tab = env.MinnTinkersWoWFOptionsTab2; ClickTab(tab)
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
    local state = {hunter = true, value = 200, maximum = 900, reads = 0, maximumReads = 0, writes = 0, tooltipCalls = 0}
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
    MockValueAccess(env, function(value)
        return not rawequal(value, state.secretValue) and not rawequal(value, state.secretMaximum)
    end)
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
    env.PetFrameManaBar:SetSize(77, 7)
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
        if name == "MinnTinkersWoWFPetHappinessBar" then
            f.width = env.PetFrameManaBar:GetWidth() - 8
        end
        function f:RegisterUnitEvent(event, ...)
            self:RegisterEvent(event)
            self.unitEvents = self.unitEvents or {}
            self.unitEvents[event] = {...}
        end
        function f:SetClipsChildren(value) self.clips = value end
        function f:SetStatusBarTexture(value) self.barTexture = value end
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
    assert(frame.height == 6)
    assert(frame.point[2] == env.PetFrameManaBar and frame.point[3] == "BOTTOMRIGHT" and frame.point[4] == -4 and frame.point[5] == -4)
    local colors = {{0.9, 0.15, 0.1}, {1, 0.72, 0.08}, {0.15, 0.8, 0.25}}
    for index = 1, 3 do
        local fill = env["MinnTinkersWoWFPetHappinessFill" .. index]
        assert(fill.parent.clips and fill.height == 6)
        assert(fill.barTexture == "Interface\\Buttons\\WHITE8X8")
        assert(table.concat(fill.barColor, ",") == table.concat(colors[index], ","))
        assert(fill.minimum == 0 and rawequal(fill.maximum, state.secretMaximum) and rawequal(fill.value, state.secretValue))
    end
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
    assert(state.reads == 2 and state.writes == 6)
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
        frame.scripts.OnSizeChanged(frame, width, 6)
        for index = 1, 3 do
            local fill = env["MinnTinkersWoWFPetHappinessFill" .. index]
            assert(fill.width == width and fill.height == 6)
            assert(fill.parent.width == width / 3 - (index < 3 and 1 or 0))
            assert(fill.parent.point[4] + fill.point[4] == 0)
        end
        local last = env.MinnTinkersWoWFPetHappinessFill3.parent
        assert(math.abs(last.point[4] + last.width - width) < 0.000001, "Color zones must end at the focus bar edge")
    end
    geometry(77); geometry(100)
    frame.scripts.OnSizeChanged(frame, state.secretValue, 6)
    frame.scripts.OnSizeChanged(frame, 0, 6)
    assert(env.MinnTinkersWoWFPetHappinessFill1.width == 100)
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
    local tab = env.MinnTinkersWoWFOptionsTab4; ClickTab(tab)
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
    local unavailable = fixture(); unavailable.login(); unavailable.addon.ToggleOptions()
    assert(not unavailable.addon.PetHappinessBar.IsAvailable() and unavailable.env.MinnTinkersWoWFPetHappiness.enabled == false)
end
print("PASS: happiness bar anchoring/resizing, pet replacement/dismissal, hidden pet frame, non-hunters, unavailable/invalid values, UI toggle and reload persistence")

local function chatFixture(saved, characterSaved)
    local test = fixture(saved, characterSaved)
    local env, create = test.env, test.env.CreateFrame
    local state = {reads = 0, timestamp = "none", secret = newproxy(), classRGB = {0.4, 0.6, 0.8}, colorQueries = 0}
    env.C_ClassColor = {GetClassColor = function(class)
        assert(class == select(2, env.UnitClass("player")))
        state.colorQueries = state.colorQueries + 1
        return {GetRGB = function() return unpack(state.classRGB) end}
    end}
    MockValueAccess(env, function(value) return not rawequal(value, state.secret) end)
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
        function frame:EnableMouse(value) self.mouseEnabled = value end
        function frame:CreateAnimationGroup()
            local group = {playing = false, plays = 0, stops = 0}
            self.animationGroup = group
            function group:SetLooping(value) self.loop = value end
            function group:Play() self.playing = true; self.plays = self.plays + 1 end
            function group:Stop() self.playing = false; self.stops = self.stops + 1 end
            function group:CreateAnimation(kind)
                local animation = {kind = kind}
                self.animation = animation
                function animation:SetFromAlpha(value) self.from = value end
                function animation:SetToAlpha(value) self.to = value end
                function animation:SetDuration(value) self.duration = value end
                function animation:SetSmoothing(value) self.smoothing = value end
                return animation
            end
            return group
        end
        local createTexture = frame.CreateTexture
        function frame:CreateTexture(...)
            local texture = createTexture(self, ...)
            self.textures = self.textures or {}
            self.textures[#self.textures + 1] = texture
            function texture:SetColorTexture(...) self.colorTexture = {...} end
            return texture
        end
        function frame:SetMultiLine(value) self.multiline = value end
        function frame:SetFontObject(value) self.fontObject = value end
        function frame:SetScrollChild(value) self.scrollChild = value end
        function frame:SetVerticalScroll(value) self.offset = value end
        function frame:HighlightText() self.highlighted = true end
        return frame
    end
    env.IsSecureCmd = function(command)
        local secure = { ["/TARGET"] = true, ["/TAR"] = true, ["/CAST"] = true, ["/USE"] = true, ["/ZIELEN"] = true }
        return secure[command:upper()]
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
        chat.lineColors, chat.maximum, chat.active = {}, 120, true
        chat.shadowColor, chat.shadowOffset, chat.shadowWrites = {0, 0, 0, 1}, {1, -1}, 0
        function chat:GetShadowColor() return unpack(self.shadowColor) end
        function chat:GetShadowOffset() return unpack(self.shadowOffset) end
        function chat:SetShadowColor(...)
            assert(env.canaccessallvalues(...))
            self.shadowColor = {...}; self.shadowWrites = self.shadowWrites + 1
        end
        function chat:SetShadowOffset(...)
            assert(env.canaccessallvalues(...))
            self.shadowOffset = {...}; self.shadowWrites = self.shadowWrites + 1
        end
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
        box:SetScript("OnEnterPressed", function(self)
            if state.autocomplete then state.autocomplete = false; return end
            self:SendMessage()
        end)
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
        chat.displayCallbacks = {}
        function chat:AddOnDisplayRefreshedCallback(callback) self.displayCallbacks[#self.displayCallbacks + 1] = callback end
        function chat:SetScrollOffset(value)
            self.offset = value
            for _, callback in ipairs(self.displayCallbacks) do callback(self) end
        end
        function chat:ScrollToBottom() self:SetScrollOffset(0) end
        function chat:AddMessage(text, r, g, b)
            if #self.lines == self.maximum then table.remove(self.lines, 1); table.remove(self.lineColors, 1) end
            self.lines[#self.lines + 1] = text
            self.lineColors[#self.lineColors + 1] = {r, g, b}
        end
        function chat:BackFillMessage(text, r, g, b)
            if #self.lines < self.maximum then
                table.insert(self.lines, 1, text); table.insert(self.lineColors, 1, {r, g, b})
                for _, callback in ipairs(self.displayCallbacks) do callback(self) end
            end
        end
        function chat:GetMaxLines() return self.maximum end
        function chat:SetMaxLines(value) self.maximum = value end
        function chat:GetNumMessages() return #self.lines end
        function chat:GetMessageInfo(index)
            state.reads = state.reads + 1
            local colors = self.lineColors[index] or {}
            return self.lines[index], colors[1], colors[2], colors[3]
        end
        function chat:Clear() self.lines, self.lineColors = {}, {}; self:SetScrollOffset(0) end
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
    env.FCF_OpenTemporaryWindow = function()
        local temporary = makeChat("ChatFrame4"); temporary.isTemporary = true
        env.CHAT_FRAMES[#env.CHAT_FRAMES + 1] = "ChatFrame4"
    end
    env.FCF_IterateActiveChatWindows = function(callback)
        for _, name in ipairs(env.CHAT_FRAMES) do
            local frame = env[name]
            if frame.active and callback(frame) then break end
        end
    end
    state.chat, state.box, state.makeChat = chat, box, makeChat
    state.open = function(text, frame)
        env.ChatFrameUtil.OpenChat(text, frame)
        local input = frame and frame.editBox or box
        if input.setText == 1 then input:SetText(input.text); input.setText = 0 end
    end
    return test, state
end

do
    local test, state = chatFixture()
    local nativeSend = state.box.SendMessage
    test.login()
    local env, box = test.env, state.box
    assert(box.SendMessage == nativeSend, "Protected slash commands must retain the native send method")
    assert(test.addon.ChatInput.IsAvailable() and box.altArrows == false)
    state.open(""); box:SetChatType("WHISPER"); box:SetTellTarget("Minnona-Northdale")
    box:SetText("unfinished whisper", true)
    state.autocomplete = true; box.scripts.OnEnterPressed(box)
    assert(box:GetText() == "unfinished whisper" and #box.history == 0)
    state.autocomplete = true; box.scripts.OnEscapePressed(box)
    assert(box:GetText() == "unfinished whisper" and box.focus and box:IsShown())
    box.scripts.OnEscapePressed(box)
    assert(box:GetText() == "unfinished whisper" and not box.focus and not box:IsShown())
    state.open("")
    assert(box:GetText() == "unfinished whisper" and box:GetChatType() == "WHISPER" and box:GetTellTarget() == "Minnona-Northdale")
    box.scripts.OnEnterPressed(box); state.open("")
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
    local target, targetState = chatFixture()
    local targetBox = target.env.ChatFrame1.editBox
    local executed = 0
    targetBox.SendMessage = function(self)
        assert(self:GetText() == "/target Black Ooze")
        executed = executed + 1
        self:AddHistoryLine(self:GetText())
        self:SetText(""); self:Hide(); self:ClearFocus()
    end
    local commandSend = targetBox.SendMessage
    target.login()
    assert(targetBox.SendMessage == commandSend)
    targetBox:SetText("/target Black Ooze", true)
    targetBox.scripts.OnEnterPressed(targetBox)
    assert(executed == 1 and target.env.MinnTinkersWoWFCharDB.chatHistory[1] == "/target Black Ooze")
    targetBox.scripts.OnEscapePressed(targetBox); targetState.open("")
    assert(targetBox:GetText() == "", "Executed commands must not become cancelled drafts")
end
print("PASS: chat draft Escape/reopen, autocomplete, whisper/channel routing, explicit commands, empty/sent/disabled/secret drafts, native arrow mode restoration, late windows and no polling")

do
    local test, state = chatFixture()
    local nativeScroll, nativeClear = state.chat.SetScrollOffset, state.chat.Clear
    test.login()
    local env, chat = test.env, state.chat
    assert(chat.SetScrollOffset == nativeScroll and chat.Clear == nativeClear,
        "Secure scrolling and clearing methods must not be wrapped by addon hooks")
    assert(#chat.displayCallbacks == 1)
    test.addon.ChatTools.Initialize(); assert(#chat.displayCallbacks == 1)
    local copy, marker = chat.children[1], chat.children[2]
    assert(copy.template == "UIMenuButtonStretchTemplate" and copy:IsShown() and not marker:IsShown())
    local pulse = marker.animationGroup
    assert(pulse.loop == "BOUNCE" and not pulse.playing and pulse.animation.kind == "Alpha")
    assert(pulse.animation.from == 0.35 and pulse.animation.to == 1 and pulse.animation.duration == 0.8
        and pulse.animation.smoothing == "IN_OUT")
    assert(marker.template == nil and marker.mouseEnabled == false and not marker.scripts.OnClick and not marker.scripts.OnUpdate)
    assert(marker.text == nil and marker.height == 10 and marker.point[1] == "BOTTOMRIGHT" and marker.point[2] == chat)
    assert(#marker.textures == 2 and marker.textures[2].height == 2)
    assert(marker.textures[1].gradient[1] == "VERTICAL" and marker.textures[1].gradient[2].a == 0.6
        and marker.textures[1].gradient[3].a == 0)
    assert(marker.textures[2].colorTexture[1] == 0.4 and marker.textures[2].colorTexture[2] == 0.6
        and marker.textures[2].colorTexture[3] == 0.8 and state.colorQueries == 1)
    assert(copy.width == 26 and copy.height == 26 and copy.point[2] == chat.buttonFrame and copy.point[3] == "BOTTOM" and copy.point[4] == 0 and copy.point[5] == -4)
    chat:AddMessage("at bottom"); assert(not marker:IsShown() and state.reads == 0)
    chat:SetScrollOffset(3); assert(not marker:IsShown())
    chat:AddMessage("|cff00ff00|Hplayer:Name|h[Name]|h|r: hello |Ticon:12|t https://example.com")
    assert(marker:IsShown() and state.reads == 0, "Unread tracking must never scan chat history")
    assert(pulse.playing and pulse.plays == 1)
    chat:AddMessage("another unread message")
    assert(pulse.plays == 1, "Messages must not restart the pulse")
    chat:ScrollToBottom(); assert(chat:AtBottom() and not marker:IsShown())
    assert(not pulse.playing and pulse.stops == 1)
    chat:SetScrollOffset(2); chat:AddMessage(state.secret)
    test.addon.ChatTools.SetOption("unreadMarker", false); assert(not marker:IsShown())
    assert(not pulse.playing)
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
    ClickTab(env.MinnTinkersWoWFOptionsTab3)
    assert(env.MinnTinkersWoWFDB.lastTab == "Chat" and env.MinnTinkersWoWFChatURLs.point[3] == -114)
    local timestamps = env.MinnTinkersWoWFChatTimestamps
    assert(timestamps.enabled and timestamps.text == "Off")
    env.MenuUtil.CreateContextMenu(timestamps, timestamps.menuGenerator)
    assert(#state.menu == 5 and state.menu[1].selected())
    state.menu[3].callback()
    assert(state.timestamp == "%H:%M:%S" and timestamps.text == "24-hour with seconds")
    local reload = chatFixture(env.MinnTinkersWoWFDB); reload.login(); reload.addon.ToggleOptions()
    assert(IsSelected(reload.env, 3) and not reload.env.MinnTinkersWoWFDB.chat.copyChat)
    local warrior = fixture(); warrior.env.UnitClass = function() return "Warrior", "WARRIOR" end
    warrior.login(); warrior.addon.ToggleOptions()
    assert(not warrior.env.MinnTinkersWoWFPetHappiness and warrior.env.MinnTinkersWoWFRangeEnabled.point[3] == -316)
    assert(not env.MinnTinkersWoWFChat_copyChat.checked and env.MinnTinkersWoWFChat_copyChat.enabled)
    assert(env.MinnTinkersWoWFChat_unreadMarker.Text.text == "New-message glow")
    assert(state.colorQueries == 1, "Messages and UI refreshes must not repeatedly request class colors")
end
print("PASS: class-colored click-through native pulse/reset without polling or restarts, cached native color, on-demand copy/order/reuse/secret exclusion, toggles, timestamps and tab persistence")

do
    local test, state = chatFixture(); test.login(); test.emit("PLAYER_ENTERING_WORLD")
    local env, chat = test.env, state.chat
    assert(test.addon.ChatHistory.IsAvailable() and chat.maximum == 200)
    chat:SetMaxLines(500)
    for index = 1, 250 do chat:AddMessage("message " .. index, 0.2, 0.3, 0.4) end
    local linked = "[21:34] |Hplayer:Minnona|h[Minnona]|h: |Hitem:123|h[Item]|h |Hminntinkersurl:discord.gg/test|h[discord.gg/test]|h"
    chat:AddMessage(linked, 0.4, 0.6, 0.8)
    assert(state.reads == 0 and #test.timers == 0, "Saving must do no per-message reads or polling")
    local count = #test.frames; test.addon.ChatHistory.Initialize(); assert(#test.frames == count)
    test.emit("PLAYER_LOGOUT")
    local saved = env.MinnTinkersWoWFCharDB.chatMessages.ChatFrame1
    assert(#saved == 200 and saved[1][1] == "message 52" and saved[200][1] == linked and state.reads == 200)
    assert(saved[200][2] == 0.4 and saved[200][3] == 0.6 and saved[200][4] == 0.8)
    local reload, reloaded = chatFixture(env.MinnTinkersWoWFDB, env.MinnTinkersWoWFCharDB)
    reloaded.chat:SetMaxLines(300)
    local nativeScroll, nativeClear, nativeBackfill = reloaded.chat.SetScrollOffset, reloaded.chat.Clear, reloaded.chat.BackFillMessage
    reloaded.chat:AddMessage("login message", 1, 0.5, 0)
    reload.login(); reload.emit("PLAYER_ENTERING_WORLD")
    assert(#reloaded.chat.lines == 201 and reloaded.chat.lines[1] == "message 52"
        and reloaded.chat.lines[200] == linked and reloaded.chat.lines[201] == "login message")
    assert(reloaded.chat.lineColors[200][1] == 0.4 and reloaded.chat.lineColors[200][3] == 0.8)
    assert(reloaded.chat.SetScrollOffset == nativeScroll and reloaded.chat.Clear == nativeClear
        and reloaded.chat.BackFillMessage == nativeBackfill)
    assert(not reloaded.chat.children[2]:IsShown() and reloaded.reads == 0, "Restored messages must not become unread or be rescanned")
    reload.emit("PLAYER_ENTERING_WORLD"); assert(#reloaded.chat.lines == 201, "Zoning must not replay history")
    reload.emit("PLAYER_LOGOUT")
    local relog, relogged = chatFixture(env.MinnTinkersWoWFDB, env.MinnTinkersWoWFCharDB)
    relog.login(); relog.emit("PLAYER_ENTERING_WORLD")
    assert(#relogged.chat.lines == 200 and relogged.chat.lines[199] == linked and relogged.chat.lines[200] == "login message")
    relog.emit("PLAYER_LOGOUT")
    local restart, restarted = chatFixture(env.MinnTinkersWoWFDB, env.MinnTinkersWoWFCharDB)
    restart.login(); restart.emit("PLAYER_ENTERING_WORLD"); assert(#restarted.chat.lines == 200)
    local other, otherState = chatFixture(env.MinnTinkersWoWFDB)
    other.login(); other.emit("PLAYER_ENTERING_WORLD"); assert(#otherState.chat.lines == 0, "Visible history must remain per character")
    restart.addon.ToggleOptions()
    assert(restart.env.MinnTinkersWoWFChat_saveHistory.checked and restart.env.MinnTinkersWoWFChat_saveHistory.enabled)
end
print("PASS: bounded displayed chat snapshot, zero per-message work, formatted links/colors/order, startup messages kept, replay once, reload/relog/restart and character isolation")

do
    local test, state = chatFixture(); test.login(); test.emit("PLAYER_ENTERING_WORLD")
    local env, chat = test.env, state.chat
    env.FCF_OpenNewWindow(); env.FCF_OpenTemporaryWindow()
    local combat = state.makeChat("ChatFrame2"); env.CHAT_FRAMES[#env.CHAT_FRAMES + 1] = "ChatFrame2"
    local closed = state.makeChat("ChatFrame5"); closed.active = false; env.CHAT_FRAMES[#env.CHAT_FRAMES + 1] = "ChatFrame5"
    chat:AddMessage("visible", 0.1, 0.2, 0.3); chat:AddMessage(state.secret)
    chat:AddMessage("secret color", state.secret, 1, 1); chat:AddMessage("invalid color", 2, 1, 1)
    chat:AddMessage("defaults")
    env.ChatFrame3:AddMessage("second permanent window", 1, 0, 0)
    env.ChatFrame4:AddMessage("temporary"); combat:AddMessage("combat"); closed:AddMessage("closed")
    assert(env.ChatFrame3.maximum == 200 and env.ChatFrame4.maximum == 120)
    test.emit("PLAYER_LOGOUT")
    local history = env.MinnTinkersWoWFCharDB.chatMessages
    assert(#history.ChatFrame1 == 2 and history.ChatFrame1[1][1] == "visible"
        and history.ChatFrame1[2][1] == "defaults" and history.ChatFrame1[2][2] == 1)
    assert(history.ChatFrame3[1][1] == "second permanent window" and not history.ChatFrame2
        and not history.ChatFrame4 and not history.ChatFrame5)
    test.addon.ChatHistory.SetEnabled(false); chat:AddMessage("not saved"); test.emit("PLAYER_LOGOUT")
    assert(env.MinnTinkersWoWFCharDB.chatMessages == history, "Disabling must preserve previously saved history")
    local disabled, disabledState = chatFixture(env.MinnTinkersWoWFDB, env.MinnTinkersWoWFCharDB)
    disabled.login(); disabled.emit("PLAYER_ENTERING_WORLD")
    assert(#disabledState.chat.lines == 0 and disabledState.chat.maximum == 120)
    disabled.addon.ChatHistory.SetEnabled(true); assert(disabledState.chat.maximum == 200)
    assert(#disabledState.chat.lines == 0, "Enabling mid-session must not reinsert stale messages")
    disabledState.chat:AddMessage("current session"); disabled.emit("PLAYER_LOGOUT")
    assert(disabled.env.MinnTinkersWoWFCharDB.chatMessages.ChatFrame1[1][1] == "current session")
    local malformed, malformedState = chatFixture(nil, {chatMessages = {ChatFrame1 = {"bad", {false}, {"bad color", "red"}, {"valid", 1, 1, 1}}}})
    malformed.login(); malformed.emit("PLAYER_ENTERING_WORLD")
    assert(#malformedState.chat.lines == 1 and malformedState.chat.lines[1] == "valid")
    local unavailable = fixture(); unavailable.login(); assert(not unavailable.addon.ChatHistory.IsAvailable())
end
print("PASS: permanent windows only, late-window capacity, secret/color/malformed exclusion, independent toggle and saved-data retention, disabled restore and no stale replay on enable")

do
    local test, state = chatFixture()
    local chat = state.chat
    chat.shadowColor, chat.shadowOffset = {0.1, 0.2, 0.3, 0.4}, {0.5, -0.75}
    local font, size, flags = chat:GetFont()
    local nativeColor, nativeOffset = chat.SetShadowColor, chat.SetShadowOffset
    test.login()
    local module = test.addon.ChatShadow
    assert(module.IsAvailable() and test.env.MinnTinkersWoWFDB.chat.enhancedShadow)
    assert(chat.shadowColor[1] == 0 and chat.shadowColor[4] == 1
        and chat.shadowOffset[1] == 1.5 and chat.shadowOffset[2] == -1.5 and chat.shadowWrites == 2)
    assert(chat.SetShadowColor == nativeColor and chat.SetShadowOffset == nativeOffset, "Do not wrap native font methods")
    local currentFont, currentSize, currentFlags = chat:GetFont()
    assert(currentFont == font and currentSize == size and currentFlags == flags)
    module.Initialize(); module.SetEnabled(true); assert(chat.shadowWrites == 2)
    chat:SetFont("Changed.ttf", 17, "OUTLINE")
    for index = 1, 1000 do chat:AddMessage("message " .. index, 0.2, 0.4, 0.6) end
    assert(chat.shadowWrites == 2 and state.reads == 0 and #test.timers == 0)
    assert(chat.lineColors[1][1] == 0.2 and not chat.scripts.OnUpdate)
    test.combat(true); module.SetEnabled(false)
    assert(chat.shadowColor[1] == 0.1 and chat.shadowColor[4] == 0.4
        and chat.shadowOffset[1] == 0.5 and chat.shadowOffset[2] == -0.75)
    assert(chat.font == "Changed.ttf" and chat.fontSize == 17 and chat.fontFlags == "OUTLINE")
    module.SetEnabled(false); assert(chat.shadowWrites == 4)
    test.env.FCF_OpenNewWindow(); assert(test.env.ChatFrame3.shadowWrites == 0)
    module.SetEnabled(true)
    assert(test.env.ChatFrame3.shadowOffset[1] == 1.5 and test.env.ChatFrame3.shadowWrites == 2)
    test.env.FCF_OpenTemporaryWindow(); assert(test.env.ChatFrame4.shadowOffset[1] == 1.5)
    module.SetEnabled(false)
    assert(test.env.ChatFrame3.shadowOffset[1] == 1 and test.env.ChatFrame4.shadowOffset[2] == -1)
    test.addon.ToggleOptions()
    local check = test.env.MinnTinkersWoWFChat_enhancedShadow
    assert(check.enabled and not check.checked and check.Text.text == "Enhanced chat shadow")
    check:SetChecked(true); check.scripts.OnClick(check); assert(chat.shadowOffset[1] == 1.5)
    local reload, reloaded = chatFixture(test.env.MinnTinkersWoWFDB); reload.login()
    assert(reloaded.chat.shadowOffset[1] == 1.5)
    reload.addon.ChatShadow.SetEnabled(false)
    local disabled, disabledState = chatFixture(reload.env.MinnTinkersWoWFDB); disabled.login()
    assert(disabledState.chat.shadowWrites == 0 and disabledState.chat.shadowOffset[1] == 1)
    local migrated, migratedState = chatFixture({chat = {enhancedShadow = true, textOutline = false}}); migrated.login()
    assert(migrated.env.MinnTinkersWoWFDB.chat.enhancedShadow == false and migratedState.chat.shadowWrites == 0)
    local secret, secretState = chatFixture()
    secretState.chat.shadowOffset[1] = secretState.secret
    secret.login(); assert(secretState.chat.shadowWrites == 0 and not secret.addon.ChatShadow.IsAvailable())
    local unavailable = fixture(); unavailable.login(); unavailable.addon.ToggleOptions()
    assert(not unavailable.env.MinnTinkersWoWFChat_enhancedShadow.enabled)
end
print("PASS: native chat shadow toggle/custom restoration, fonts/colors retained, size changes, no per-message work, combat, late windows, duplicate guards, UI/reload/disabled persistence and secret exclusion")


do
    local test, state = chatFixture(); test.login()
    local box, env = state.box, test.env
    local function arrow(key) box.scripts.OnArrowPressed(box, key) end
    state.open(""); box.altArrows = true; box.scripts.OnEditFocusGained(box); assert(not box.altArrows)
    box:SetText("draft", true); arrow("UP")
    assert(box:GetText() == "draft", "Empty history must preserve input")
    box:SetText("first", true); box.scripts.OnEnterPressed(box)
    state.open(""); box:SetText("second", true); box.scripts.OnEnterPressed(box)
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
-- Protected commands remain saved but are never restored through addon text insertion.
do
    local entries = {"/target Older", "/s safe chat", "/cast Frostbolt", "ordinary message", "/TaR Black Ooze", "/use 13", "/zielen Localized"}
    local test, state = chatFixture(nil, {chatHistory = entries}); test.login(); state.open("")
    local box = state.box
    local writes, setText = {}, box.SetText
    function box:SetText(text, userInput)
        writes[#writes + 1] = text
        setText(self, text, userInput)
    end
    local function arrow(key) box.scripts.OnArrowPressed(box, key) end
    arrow("UP"); assert(box:GetText() == "ordinary message")
    arrow("UP"); assert(box:GetText() == "/s safe chat")
    arrow("UP"); assert(box:GetText() == "/s safe chat")
    arrow("DOWN"); assert(box:GetText() == "ordinary message")
    arrow("DOWN"); assert(box:GetText() == "")
    for _, text in ipairs(writes) do
        local command = text:match("^(/[^%s]+)")
        assert(not command or not test.env.IsSecureCmd(command), "History must not insert protected commands")
    end
    assert(#test.env.MinnTinkersWoWFCharDB.chatHistory == #entries, "Keep existing saved command history intact")
    box:SetText("/target Black Ooze", true)
    local count = #writes
    arrow("UP"); arrow("DOWN")
    assert(box:GetText() == "/target Black Ooze" and #writes == count, "Do not rewrite a manually typed protected command")
    box.scripts.OnEscapePressed(box); state.open("")
    assert(box:GetText() == "", "Escape must not restore a protected command through addon text")
    local only, onlyState = chatFixture(nil, {chatHistory = {"/target Black Ooze", "/cast Frostbolt"}})
    only.login(); onlyState.open("")
    onlyState.box.scripts.OnArrowPressed(onlyState.box, "UP")
    onlyState.box.scripts.OnArrowPressed(onlyState.box, "DOWN")
    assert(onlyState.box:GetText() == "")
    local reload, reloaded = chatFixture(nil, test.env.MinnTinkersWoWFCharDB)
    reload.login(); reloaded.open(""); reloaded.box.scripts.OnArrowPressed(reloaded.box, "UP")
    assert(reloaded.box:GetText() == "ordinary message")
end
print("PASS: protected command/alias history exclusions, bidirectional bounds, saved data preservation, direct typing, Escape cancellation and reload")
print("PASS: actual Up/Down history traversal, both bounds, scratch draft/destination restoration, empty/cleared history, editing, modifiers/autocomplete, independent toggle, secrets and bounded storage")


-- SavedVariables are character-specific; only sent messages survive a fresh Lua environment.
do
    local test, state = chatFixture(); test.login()
    state.open(""); state.box:SetText("first saved", true); state.box.scripts.OnEnterPressed(state.box)
    state.open(""); state.box:SetText("second saved", true); state.box.scripts.OnEnterPressed(state.box)
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

do
    local function barFixture(saved, microShown)
        local test = fixture(saved)
        local env = test.env
        MockValueAccess(env, function() return true end)
        local bags = env.CreateFrame("Frame", "BagsBar")
        local micro = env.CreateFrame("Frame", "MicroMenu")
        local anchor = env.CreateFrame("Frame", "MicroButtonAndBagsBar")
        function bags:IsProtected() return true end
        function micro:IsProtected() return false end
        local nativeBagSetShown = bags.SetShown
        function bags:SetShown(shown)
            assert(not env.InCombatLockdown(), "Protected bar visibility must wait for combat to end")
            nativeBagSetShown(self, shown)
        end
        bags:Show(); micro:SetShown(microShown); anchor:Show()
        return test, bags, micro, anchor, nativeBagSetShown
    end

    local test, bags, micro, anchor, nativeBagSetShown = barFixture(nil, true)
    test.login(); test.addon.ToggleOptions()
    local env = test.env
    local bagCheck, microCheck = env.MinnTinkersWoWF_hideBagBar, env.MinnTinkersWoWF_hideMicroBar
    assert(bagCheck.enabled and microCheck.enabled and not bagCheck.checked and not microCheck.checked)
    assert(bags:IsShown() and micro:IsShown())
    bagCheck:SetChecked(true); bagCheck.scripts.OnClick(bagCheck)
    assert(not bags:IsShown() and micro:IsShown() and anchor:IsShown())
    bags:Show(); assert(not bags:IsShown(), "A native re-show must respect the saved toggle")
    test.combat(true)
    nativeBagSetShown(bags, true)
    assert(bags:IsShown(), "A protected native re-show in combat must wait for a safe hide")
    microCheck:SetChecked(true); microCheck.scripts.OnClick(microCheck)
    assert(not micro:IsShown() and env.MinnTinkersWoWFDB.hideMicroBar)
    test.combat(false); test.emit("PLAYER_REGEN_ENABLED")
    assert(not bags:IsShown() and not micro:IsShown())
    test.combat(true)
    bagCheck:SetChecked(false); bagCheck.scripts.OnClick(bagCheck)
    assert(not bags:IsShown() and not env.MinnTinkersWoWFDB.hideBagBar)
    test.combat(false); test.emit("PLAYER_REGEN_ENABLED")
    assert(bags:IsShown() and not micro:IsShown() and #test.timers == 0)

    local reload, freshBags, freshMicro = barFixture(env.MinnTinkersWoWFDB, true)
    reload.login(); assert(freshBags:IsShown() and not freshMicro:IsShown())
    local hidden, _, nativeHidden = barFixture({ hideMicroBar = true }, false)
    hidden.login(); hidden.addon.BarVisibility.SetHidden("hideMicroBar", false)
    assert(not nativeHidden:IsShown(), "Turning off the option must not show an independently hidden bar")
end
print("PASS: independent bar toggles, native re-show, combat deferral, reload and native visibility restoration")


-- Changing panel height reveals more art at an unchanged scale and fades the bottom into black.
do
    local test = fixture()
    local env, background, fade = test.env
    env.C_Texture = {GetAtlasInfo = function(atlas)
        assert(atlas == "Legacy-Rewards-Tracker-background")
        return {file = 123, width = 1024, height = 768,
            leftTexCoord = 0.125, rightTexCoord = 0.625, topTexCoord = 0.25, bottomTexCoord = 0.625}
    end}
    local createFrame = env.CreateFrame
    env.CreateFrame = function(kind, name, parent, template)
        local frame = createFrame(kind, name, parent, template)
        if name == "MinnTinkersWoWFOptions" then
            local inset = frame.Inset
            inset:SetSize(550, 606)
            local createTexture = inset.CreateTexture
            function inset:CreateTexture(_, layer, _, sublevel)
                assert(layer == "BACKGROUND")
                local texture = createTexture(self)
                if sublevel == -4 then
                    background = texture
                    function background:SetTexCoord(...) self.coords = {...} end
                else
                    assert(sublevel == -3)
                    fade = texture
                end
                return texture
            end
        end
        return frame
    end
    test.login(); test.addon.ToggleOptions()
    local inset = env.MinnTinkersWoWFOptions.Inset
    assert(background.texture == 123 and background.coords[3] == 0.25)
    local small, smallHeight = background.coords, background.height
    assert(not fade:IsShown())
    inset.scripts.OnSizeChanged(inset, 550, 650)
    assert(fade:IsShown() and fade.height > 0 and fade.height < 64)
    inset.scripts.OnSizeChanged(inset, 550, 736)
    local large = background.coords
    for index = 1, 3 do assert(large[index] == small[index]) end
    assert(large[4] == 0.625 and background.height < 736 and fade.height == 64 and fade:IsShown())
    local texelsPerUnit = (large[4] - large[3]) * 2048 / background.height
    assert(math.abs(texelsPerUnit - (small[4] - small[3]) * 2048 / smallHeight) < 1e-8)
    assert(math.abs(texelsPerUnit - (large[2] - large[1]) * 2048 / 550) < 1e-8)
    inset.scripts.OnSizeChanged(inset, 550, 606)
    for index = 1, 4 do assert(background.coords[index] == small[index]) end
end
print("PASS: Legacy Points art keeps its scale and fades into the backing at maximum height")

-- Grass preview never writes CVars. Releasing applies the accepted distance and its fade.
do
    local test = fixture()
    local env, writes = test.env, {}
    local density, distance, fade = "groundEffectDensity", "groundEffectDist", "groundEffectFade"
    local sparkles = "outlineModeShowLootEffectWhenDisabled"
    local values = {[density] = 24, [distance] = 200, [fade] = 70, [sparkles] = 1, graphicsOutlineMode = 2}
    local caps, denied, locked = {}, {}, {}
    local getCVar, getCVarInfo = env.C_CVar.GetCVar, env.C_CVar.GetCVarInfo
    env.C_CVar.GetCVar = function(name)
        return values[name] and tostring(values[name]) or getCVar(name)
    end
    env.C_CVar.GetCVarInfo = function(name)
        if values[name] then return tostring(values[name]), nil, false, false, locked[name], false, false end
        return getCVarInfo(name)
    end
    env.C_CVar.SetCVar = function(name, value)
        writes[#writes + 1] = name
        if denied[name] then return false end
        values[name] = math.min(caps[name] or math.huge, tonumber(value))
        return true
    end
    test.login()
    test.addon.ToggleOptions()
    local densitySlider, distanceSlider = env.MinnTinkersWoWFGrassDensity, env.MinnTinkersWoWFGrassDistance
    assert(densitySlider.enabled and distanceSlider.enabled and #writes == 0)

    densitySlider:SetValue(80)
    densitySlider:SetValue(256)
    assert(#writes == 0 and values[density] == 24)
    densitySlider.scripts.OnMouseUp(densitySlider, "RightButton")
    assert(#writes == 0)
    densitySlider.scripts.OnMouseUp(densitySlider, "LeftButton")
    assert(#writes == 1 and writes[1] == density and values[density] == 256 and values[distance] == 200)

    distanceSlider:SetValue(410)
    assert(#writes == 1)
    distanceSlider.scripts.OnMouseUp(distanceSlider, "LeftButton")
    assert(#writes == 3 and values[distance] == 410 and values[fade] == 220)
    distanceSlider:SetValue(500)
    distanceSlider.scripts.OnMouseUp(distanceSlider, "LeftButton")
    assert(values[distance] == 500 and values[fade] == 370)
    distanceSlider:SetValue(320)
    distanceSlider.scripts.OnMouseUp(distanceSlider, "LeftButton")
    assert(values[distance] == 320 and values[fade] == 70 and values[density] == 256)

    caps[distance] = 410
    distanceSlider:SetValue(500)
    distanceSlider.scripts.OnMouseUp(distanceSlider, "LeftButton")
    assert(distanceSlider.value == 410 and values[distance] == 410 and values[fade] == 220)
    denied[fade] = true
    assert(not test.addon.WorldGraphics.SetDistance(320))
    assert(values[distance] == 410 and values[fade] == 220, "Roll back distance when the fade write fails")
    locked[fade] = true
    local count = #writes
    distanceSlider:Refresh()
    assert(not distanceSlider.enabled and not test.addon.WorldGraphics.SetDistance(500) and #writes == count)
    test.addon.ToggleOptions(); test.addon.ToggleOptions()
    assert(#writes == count, "Opening the settings must not write graphics CVars")

    local checkbox = env.MinnTinkersWoWFQuestSparkles
    assert(checkbox.enabled and checkbox:GetChecked(), "Read the game's saved sparkle setting")
    checkbox:SetChecked(false); checkbox.scripts.OnClick(checkbox)
    assert(not checkbox:GetChecked() and values[sparkles] == 0 and #writes == count + 1 and writes[#writes] == sparkles)
    denied[sparkles] = true
    checkbox:SetChecked(true); checkbox.scripts.OnClick(checkbox)
    assert(not checkbox:GetChecked() and values[sparkles] == 0, "Show the actual setting after a rejected write")
    denied[sparkles] = nil
    checkbox:SetChecked(true); checkbox.scripts.OnClick(checkbox)
    assert(checkbox:GetChecked() and values[sparkles] == 1 and values.graphicsOutlineMode == 2)
    locked[sparkles] = true; checkbox:Refresh()
    assert(checkbox:GetChecked() and not checkbox.enabled)
end
print("PASS: grass controls and quest sparkles, accepted values, release-only sliders and failure recovery")

-- Fishing audio fades in both directions and restores only the temporary channels.
do
    local test = fixture()
    local env = test.env
    MockValueAccess(env, function() return true end)
    local music, ambience, effects = "Sound_MusicVolume", "Sound_AmbienceVolume", "Sound_SFXVolume"
    local original, temp = {[music] = 0.8, [ambience] = 0.3, [effects] = 0.45}, {}
    local channelName = nil
    env.UnitChannelInfo = function(unit)
        assert(unit == "player")
        return channelName
    end
    env.C_Spell = {GetSpellName = function(spellID)
        return (spellID == 7620 or spellID == 7731) and "Localized Fishing" or "Other spell"
    end}
    local getCVarInfo = env.C_CVar.GetCVarInfo
    env.C_CVar.GetCVarInfo = function(name)
        if original[name] then return tostring(temp[name] or original[name]), nil, false, false, false, false, false end
        return getCVarInfo(name)
    end
    env.C_CVar.SetTempCVar = function(name, value)
        assert(name == music or name == ambience or name == effects)
        temp[name] = tonumber(value)
    end
    env.C_CVar.RemoveTempCVar = function(name) temp[name] = nil end
    test.login()
    test.addon.ToggleOptions()
    local quiet = env.MinnTinkersWoWFQuietFishing
    assert(quiet.enabled and not quiet.checked and not next(temp))
    quiet:SetChecked(true); quiet.scripts.OnClick(quiet)
    local frame
    for _, candidate in ipairs(test.frames) do
        if candidate:IsEventRegistered("UNIT_SPELLCAST_CHANNEL_START") then frame = candidate end
    end
    local function start(guid)
        channelName = "Localized Fishing"
        test.emit("UNIT_SPELLCAST_CHANNEL_START", "player", guid, 7731)
    end
    local function stop(guid)
        channelName = nil
        test.emit("UNIT_SPELLCAST_CHANNEL_STOP", "player", guid, 7731)
    end
    local function tick(delta) frame.scripts.OnUpdate(frame, delta) end
    test.emit("UNIT_SPELLCAST_CHANNEL_START", "player", "other", 1)
    assert(not frame.scripts.OnUpdate)
    start("first")
    assert(not next(temp))
    tick(0.3)
    assert(temp[music] == 0.4 and temp[ambience] == 0.15 and temp[effects] == 0.725)
    tick(0.3)
    assert(temp[music] == 0 and temp[ambience] == 0 and temp[effects] == 1 and not frame.scripts.OnUpdate)
    stop("first")
    assert(test.timers[1].delay == 8 and not frame.scripts.OnUpdate)
    start("second")
    assert(test.timers[1].cancelled and not frame.scripts.OnUpdate)
    test.emit("UNIT_SPELLCAST_CHANNEL_STOP", "player", "first", 7731)
    assert(#test.timers == 1)
    stop("second"); test.flush(8)
    tick(0.75)
    assert(temp[music] == 0.4 and temp[ambience] == 0.15 and temp[effects] == 0.725)
    start("third")
    tick(0.3)
    assert(temp[music] == 0.2 and temp[ambience] == 0.075 and temp[effects] == 0.8625)
    tick(0.3)
    stop("third"); test.flush(8)
    tick(1.5)
    assert(not next(temp) and original[music] == 0.8 and original[ambience] == 0.3 and original[effects] == 0.45)
    original[effects] = 0
    start("fourth"); tick(0.3)
    assert(temp[effects] == 0.5)
    test.emit("PLAYER_LOGOUT")
    assert(not next(temp) and original[effects] == 0 and not frame.scripts.OnUpdate)
end
print("PASS: fishing audio fade out and in, recasts, delayed recovery, sound preferences, defaults and logout")

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
    gap(universal, "Game options", env.MinnTinkersWoWFFastAutoloot)
    gap(universal, "Questing", env.MinnTinkersWoWFQuietFishing)
    local sparkles = env.MinnTinkersWoWFQuestSparkles
    assert(y(sparkles) == y(env.MinnTinkersWoWFQuietFishing) and sparkles.point[2] == universal and sparkles.point[3] == "TOP")
    local note
    for _, text in ipairs(universal.fontStrings) do if text.text == "Hold Shift to handle quests manually." then note = text end end
    assert(y(heading(universal, "NPC interaction")) - (y(note) - 6 + 26) == 24)
    assert(y(env.MinnTinkersWoWFAutoSellJunk) + 26 < 606)
    gap(ui, "Combat indicator", env.MinnTinkersWoWFFont_macroText.parent)
    gap(ui, "Range indicator", env.MinnTinkersWoWFCombat_width.parent)
    gap(ui, "Bar visibility", env.MinnTinkersWoWFRangeResetPosition)
    gap(chat, "Chat tools", env.MinnTinkersWoWFChat_preserveDraft)
    gap(chat, "Appearance", env.MinnTinkersWoWFChat_unreadMarker)
    gap(chat, "Timestamps", env.MinnTinkersWoWFChat_enhancedShadow)
    for _, rows in ipairs({
        {env.MinnTinkersWoWFCameraDistance.parent, env.MinnTinkersWoWFGrassDensity.parent, env.MinnTinkersWoWFGrassDistance.parent, env.MinnTinkersWoWFQuietFishing},
        {env.MinnTinkersWoWFFont_keybinds.parent, env.MinnTinkersWoWFFont_itemCount.parent, env.MinnTinkersWoWFFont_macroText.parent},
        {env.MinnTinkersWoWFCombat_enabled, env.MinnTinkersWoWFCombat_opacity.parent, env.MinnTinkersWoWFCombat_width.parent},
        {env.MinnTinkersWoWFRangeEnabled, env.MinnTinkersWoWFRangeSpellSlot},
        {env.MinnTinkersWoWFRangeSize.parent, env.MinnTinkersWoWFRangeOpacity.parent, env.MinnTinkersWoWFRangeResetPosition},
    }) do
        for index = 2, #rows do assert(y(rows[index]) - y(rows[index - 1]) == 32) end
    end
    assert(y(env.MinnTinkersWoWFRangeResetPosition) + 26 == 502 and window.height == 670)
    assert(y(env.MinnTinkersWoWF_hideBagBar) + 26 == 576 and y(env.MinnTinkersWoWF_hideMicroBar) == y(env.MinnTinkersWoWF_hideBagBar))
    assert(heading(ui, "Range indicator").fontObject == "Game15Font_Shadow")
    assert(env.MinnTinkersWoWFRangeEnabled.Text.fontObject == "GameFontNormalSmall")
    assert(env.MinnTinkersWoWFCameraDistance.parent.fontStrings[1].fontObject == "GameFontHighlight_NoShadow")
    assert(note.fontObject == "GameFontHighlightSmall2")
    local input = env.MinnTinkersWoWFRangeSpellInput
    local selectSpell, clearSpell = env.MinnTinkersWoWFRangeSelectSpell, env.MinnTinkersWoWFRangeClearSpell
    assert(input.fontObject == "GameFontHighlightSmall")
    for _, button in ipairs({selectSpell, clearSpell, env.MinnTinkersWoWFRangeResetPosition}) do
        assert(button.template == "SharedButtonSmallTemplate")
    end
    assert(selectSpell.point[2] - selectSpell:GetWidth() > input.point[2])
    assert(clearSpell.point[2] - clearSpell:GetWidth() > selectSpell.point[2])
end
print("PASS: consistent control spacing, non-overlapping spell controls, and native professions fonts and buttons")

local function buffFixture(saved, characterSaved, playerClass)
    local test = fixture(saved, characterSaved)
    local env = test.env
    env.UIParent:SetSize(1920, 1080)
    local secret = setmetatable({}, {__index = function() error("Read secret aura") end,
        __tostring = function() error("Converted secret aura") end})
    local state = {now = 100, aura = {expirationTime = 1600}, reads = 0, spellReads = 0,
        known = true, secret = secret, casts = 0, protectedWrites = 0}
    env.UnitClass = function() return playerClass or "Hunter", playerClass or "HUNTER" end
    MockValueAccess(env, function(value) return not rawequal(value, secret) end)
    env.GetTime = function() return state.now end
    env.UnitOnTaxi = function(unit)
        assert(unit == "player")
        return state.onTaxi or false
    end
    env.Enum.SpellBookSpellBank, env.Enum.SpellBookItemType = {Player = 0}, {Spell = 1}
    local spells = {
        [19506] = {spellID = 19506, name = "Localized Trueshot Aura", iconID = 1000},
        [20906] = {spellID = 20906, name = "Localized Trueshot Aura", iconID = 1001},
    }
    env.C_Spell = {
        GetSpellInfo = function(id) state.spellReads = state.spellReads + 1; return spells[id] end,
        IsSpellPassive = function() return state.passive or false end,
    }
    env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = 2} end,
        GetSpellBookItemInfo = function(slot)
            local info = spells[slot == 1 and 19506 or 20906]
            return {name = info.name, spellID = info.spellID, itemType = 1, isOffSpec = false}
        end,
        IsSpellKnown = function(id) return state.known and (id == 19506 or not state.onlyFirstRank) end,
    }
    env.C_UnitAuras = {GetAuraDataBySpellName = function(unit, name, filter)
        assert(not env.InCombatLockdown(), "Aura data should not be queried in combat")
        assert(unit == "player" and name == "Localized Trueshot Aura" and filter == "HELPFUL")
        state.reads = state.reads + 1
        return state.aura
    end}
    env.GameTooltip.SetSpellByID = function(self, id) self.spellID = id end
    local create = env.CreateFrame
    env.CreateFrame = function(kind, name, parent, template)
        if template == "SecureActionButtonTemplate" then assert(not env.InCombatLockdown()) end
        local f = create(kind, name, parent, template)
        function f:RegisterUnitEvent(event, unit) self:RegisterEvent(event); self.unitFilter = unit end
        if name == "MinnTinkersWoWFBuffReminder" then
            state.button = f
            f.attributes = {}
            function f:SetAttribute(key, value)
                assert(not env.InCombatLockdown(), "Secure attribute write in combat")
                state.protectedWrites = state.protectedWrites + 1
                self.attributes[key] = value
            end
            for _, method in ipairs({"SetShown", "SetSize", "SetPoint", "ClearAllPoints", "StopMovingOrSizing", "StartMoving"}) do
                local native = f[method]
                f[method] = function(self, ...)
                    assert(not env.InCombatLockdown(), "Protected " .. method .. " in combat")
                    state.protectedWrites = state.protectedWrites + 1
                    return native(self, ...)
                end
                if method == "SetShown" then state.nativeShown = native end
            end
            function f:SetNormalAtlas(atlas) self.normalAtlas = atlas end
            function f:SetPushedAtlas(atlas) self.pushedAtlas = atlas end
            function f:GetHighlightTexture() return self.highlight end
            local createTexture = f.CreateTexture
            function f:CreateTexture(...)
                local texture = createTexture(self, ...)
                function texture:AddMaskTexture(mask) self.mask = mask end
                return texture
            end
            function f:CreateMaskTexture(...) return createTexture(self, ...) end
            local texture = createTexture(f)
            function texture:SetAtlas(value) self.atlas = value end
            f.highlight = texture
            state.nativeClick = function(self)
                if self.attributes.spell1 and self.attributes.type1 == "spell" then state.casts = state.casts + 1 end
            end
            f.scripts.OnClick = state.nativeClick
        end
        return f
    end
    env.RegisterStateDriver = function(f, name, condition)
        assert(not env.InCombatLockdown())
        assert(name == "visibility" and condition == "[combat] hide")
        f.visibilityDriver = condition
    end
    function state.enterCombat()
        test.combat(true)
        if state.button then state.nativeShown(state.button, false) end -- Simulated native secure driver.
        test.emit("PLAYER_REGEN_DISABLED")
    end
    function state.leaveCombat()
        test.combat(false)
        test.emit("PLAYER_REGEN_ENABLED")
    end
    return test, state
end

-- One deadline timer, no per-frame work; rebuff confirmation comes from UNIT_AURA.
do
    local test, state = buffFixture(); test.login()
    local env, reminder, button = test.env, test.addon.BuffReminder, state.button
    assert(reminder.IsAvailable() and button.attributes.spell1 == 20906 and button.attributes.unit == "player")
    assert(button.template == "SecureActionButtonTemplate" and button.scripts.OnClick == state.nativeClick)
    assert(button.normalAtlas == "gamepad-actionbar-squareslot-border-normal")
    assert(button.pushedAtlas == "gamepad-actionbar-squareslot-border-pressed")
    assert(button.highlight.atlas == "gamepad-actionbar-squareslot-border-hover" and button.icon.mask)
    assert(not button.shown and not button.scripts.OnUpdate)
    assert(#test.timers == 1 and test.timers[1].delay == 1440)
    local reads, spellReads, writes = state.reads, state.spellReads, state.protectedWrites
    for index = 1, 1000 do test.emit("UNIT_AURA", "party1") end
    assert(state.reads == reads and #test.timers == 1)
    for index = 1, 1000 do test.emit("UNIT_AURA", "player") end
    assert(state.reads == reads + 1000 and #test.timers == 1 and state.spellReads == spellReads)
    assert(state.protectedWrites == writes, "Unchanged aura updates must not redraw or rewrite the button")
    state.now = 1540; test.flush(1440)
    assert(button.shown and #test.timers == 1)
    button.scripts.OnClick(button)
    assert(state.casts == 1 and button.shown, "Clicking without an actual aura refresh must keep the reminder")
    state.aura = {expirationTime = 3140}; test.emit("UNIT_AURA", "player")
    assert(not button.shown and #test.timers == 2 and test.timers[2].delay == 1540)
    state.aura = nil; test.emit("UNIT_AURA", "player")
    assert(button.shown and test.timers[2].cancelled)
    state.aura = {expirationTime = 0}; test.emit("UNIT_AURA", "player")
    assert(not button.shown, "A permanent aura is active, not expiring")
    state.aura = {expirationTime = state.now - 1}; test.emit("UNIT_AURA", "player"); assert(button.shown)
    reminder.SetEnabled(false); assert(not button.shown)
    reads = state.reads; test.emit("UNIT_AURA", "player"); assert(state.reads == reads)
    reminder.SetEnabled(true); assert(button.shown)
    local frames = #test.frames; reminder.Initialize(19506); assert(#test.frames == frames)
    state.known = false; test.emit("SPELLS_CHANGED")
    assert(not button.shown and button.attributes.spell1 == nil)
    state.known, state.onlyFirstRank = true, true; test.emit("SPELLS_CHANGED")
    assert(button.attributes.spell1 == 19506 and button.shown)
    state.passive = true; test.emit("SPELLS_CHANGED"); assert(not button.shown)
end
print("PASS: localized learned buff ranks, native secure click/art, one threshold timer, no redundant redraws, unrelated-unit exclusion, missing/permanent buffs, confirmed refresh and disable cancellation")

-- Protected frames stay untouched through combat, including reload and configuration changes.
do
    local test, state = buffFixture(); test.login()
    local button, reminder = state.button, test.addon.BuffReminder
    local timer = test.timers[1]
    state.enterCombat(); assert(not button.shown and timer.cancelled)
    local reads, writes = state.reads, state.protectedWrites
    state.aura = nil
    test.emit("UNIT_AURA", "player"); test.emit("SPELLS_CHANGED")
    test.emit("DISPLAY_SIZE_CHANGED"); test.emit("UI_SCALE_CHANGED")
    reminder.SetLocked(false); reminder.SetSize(64); reminder.ResetPosition(); reminder.SetEnabled(false)
    button.scripts.OnDragStart(button); button.scripts.OnDragStop(button)
    assert(state.reads == reads and state.protectedWrites == writes and not button.shown)
    state.leaveCombat(); assert(button.width == 64 and not button.shown)
    reminder.SetEnabled(true); assert(button.shown)
    state.aura = {expirationTime = 1600}; test.emit("UNIT_AURA", "player")
    assert(button.shown, "Unlocked mode previews an otherwise hidden reminder")
    reminder.SetLocked(true); assert(not button.shown)
    local reload, reloadState = buffFixture(nil, {buffReminder = {enabled = true, locked = true, size = 60}})
    reload.combat(true); reload.login()
    assert(not reloadState.button and #reload.timers == 0)
    reloadState.leaveCombat()
    assert(reloadState.button and reloadState.button.width == 60 and not reloadState.button.shown)
    local secretTest, secretState = buffFixture(); secretState.aura = secretState.secret; secretTest.login()
    assert(not secretState.button.shown and #secretTest.timers == 0)
    secretState.aura = {expirationTime = secretState.secret}; secretTest.emit("UNIT_AURA", "player")
    assert(not secretState.button.shown and #secretTest.timers == 0)
    secretState.aura = nil; secretTest.emit("UNIT_AURA", secretState.secret)
    assert(not secretState.button.shown)
    secretTest.emit("UNIT_AURA", "player"); assert(secretState.button.shown)
end
print("PASS: secure combat hiding, deferred login/size/position/toggles, no combat aura queries or protected writes, post-combat revalidation and secret-data exclusion")

-- Hunter category preserves old happiness settings and stores reminder geometry per character.
do
    local test, state = buffFixture({petHappinessBar = false}); test.login(); test.addon.ToggleOptions()
    local env, window, reminder = test.env, test.env.MinnTinkersWoWFOptions, test.addon.BuffReminder
    assert(#window.Inset.children == 4 and env.MinnTinkersWoWFOptionsTab4.tooltipText == "Hunter")
    assert(env.MinnTinkersWoWFPetHappiness.parent == window.Inset.children[4])
    assert(not env.MinnTinkersWoWFPetHappiness.checked and env.MinnTinkersWoWFRangeEnabled.parent == window.Inset.children[2])
    ClickTab(env.MinnTinkersWoWFOptionsTab4)
    assert(env.MinnTinkersWoWFDB.lastTab == "Hunter" and env.MinnTinkersWoWFBuffReminderEnabled.checked)
    local unlock = env.MinnTinkersWoWFBuffReminderUnlocked
    unlock:SetChecked(true); unlock.scripts.OnClick(unlock); assert(state.button.shown)
    state.button.centerX, state.button.centerY = 30, 15
    state.button.scripts.OnDragStop(state.button)
    assert(reminder.GetSettings().x == 30 and reminder.GetSettings().y == 15)
    env.MinnTinkersWoWFBuffReminderSize:SetValue(72); assert(state.button.width == 72)
    assert(env.MinnTinkersWoWFBuffReminderReset.template == "SharedButtonSmallTemplate")
    env.MinnTinkersWoWFBuffReminderReset.scripts.OnClick()
    assert(reminder.GetSettings().x == 0 and reminder.GetSettings().y == 0)
    reminder.SetLocked(true)
    local reload, reloadState = buffFixture(env.MinnTinkersWoWFDB, env.MinnTinkersWoWFCharDB)
    reload.login(); reload.addon.ToggleOptions()
    assert(IsSelected(reload.env, 4) and reloadState.button.width == 72)
    assert(not reload.env.MinnTinkersWoWFDB.petHappinessBar)
    local mage, mageState = buffFixture(env.MinnTinkersWoWFDB, nil, "MAGE")
    mage.login(); mage.addon.ToggleOptions()
    assert(#mage.env.MinnTinkersWoWFOptions.Inset.children == 3 and not mage.env.MinnTinkersWoWFOptionsTab4)
    assert(IsSelected(mage.env, 1) and not mageState.button and mageState.reads == 0)
    for _, frame in ipairs(mage.frames) do assert(not frame.events.UNIT_AURA, "Other classes must not subscribe to hunter reminders") end
    local alt, altState = buffFixture(); alt.login(); assert(altState.button.width == 48)
    local invalid, invalidState = buffFixture(nil, {buffReminder = {size = -100, x = math.huge, y = "invalid", enabled = true}})
    invalid.login(); assert(invalidState.button.width == 24 and invalid.addon.BuffReminder.GetSettings().x == 0)
    invalid.addon.BuffReminder.GetSettings().x = 9000
    invalid.emit("DISPLAY_SIZE_CHANGED")
    assert(invalid.addon.BuffReminder.GetSettings().x <= invalid.env.UIParent:GetWidth() / 2)
end
print("PASS: hunter-only tab/events, shared range retained, happiness setting preserved, reminder controls/drag/reset, per-character geometry and reload, unavailable-class fallback and invalid/offscreen positions")

-- Flight paths temporarily suppress buffs; do not turn that into a rebuff prompt.
do
    local test, state = buffFixture(); test.login()
    local button, reminder = state.button, test.addon.BuffReminder
    local timer, reads = test.timers[1], state.reads
    state.onTaxi, state.aura = true, nil
    test.emit("PLAYER_CONTROL_LOST")
    assert(not button.shown and timer.cancelled and state.reads == reads)
    for index = 1, 100 do
        test.emit("UNIT_AURA", "player")
        test.emit("UNIT_FLAGS", "player")
    end
    reminder.SetLocked(false); reminder.SetSize(56)
    assert(not button.shown and state.reads == reads and #test.timers == 1,
        "Flight must suppress preview and aura queries without starting a replacement timer")
    reminder.SetLocked(true)
    state.onTaxi, state.aura = false, {expirationTime = 2000}
    test.emit("PLAYER_CONTROL_GAINED")
    assert(not button.shown and state.reads == reads + 1)
    assert(#test.timers == 2 and test.timers[2].delay == 1840)
    local queries = state.reads
    test.emit("UNIT_FLAGS", "pet"); assert(state.reads == queries)
    state.aura = nil; test.emit("UNIT_AURA", "player"); assert(button.shown)
    state.onTaxi = true; test.emit("UNIT_FLAGS", "player"); assert(not button.shown)
    test.emit("PLAYER_CONTROL_GAINED"); assert(not button.shown,
        "A control event must use actual flight state")
    state.onTaxi = false; test.emit("PLAYER_CONTROL_GAINED")
    assert(button.shown, "A genuinely missing buff must still be reported after landing")
    state.aura = {expirationTime = 2000}; test.emit("UNIT_AURA", "player"); assert(not button.shown)
    test.emit("PLAYER_CONTROL_LOST"); assert(not button.shown,
        "Other causes of control loss must not alter buff tracking")
    local reload, reloadState = buffFixture(nil, {buffReminder = {enabled = true, locked = false}})
    reloadState.onTaxi, reloadState.aura = true, nil
    reload.login(); assert(not reloadState.button.shown and reloadState.reads == 0 and #reload.timers == 0)
    reload.emit("PLAYER_ENTERING_WORLD"); assert(not reloadState.button.shown and reloadState.reads == 0)
    reloadState.enterCombat()
    local writes = reloadState.protectedWrites
    reload.emit("PLAYER_CONTROL_GAINED"); reload.emit("UNIT_FLAGS", "player")
    assert(reloadState.protectedWrites == writes and reloadState.reads == 0)
    reloadState.leaveCombat(); assert(not reloadState.button.shown and reloadState.reads == 0)
    reloadState.onTaxi, reloadState.aura = false, {expirationTime = 0}
    reload.addon.BuffReminder.SetLocked(true)
    reload.emit("PLAYER_CONTROL_GAINED"); assert(not reloadState.button.shown and #reload.timers == 0)
    state.onTaxi = state.secret; test.emit("UNIT_FLAGS", "player")
    assert(not button.shown and test.timers[#test.timers].cancelled)
    state.onTaxi = false; test.emit("UNIT_FLAGS", "player")
    assert(not button.shown and not test.timers[#test.timers].cancelled)
end
print("PASS: flight hiding/timer cancellation, no flight aura queries or preview, actual taxi-state checks, landing refresh/restoration, flight reload, unrelated flags, combat and secret state")
