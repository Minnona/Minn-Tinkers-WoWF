local _, addon = ...
local module = {}
addon.ChatTools = module
local initialized = false
local frames = {}
local copyWindow, copyInput
local classR, classG, classB = 1, 1, 1

local function PlainText(text)
    return (text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
        :gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("||", "|"))
end

function module.CopyChat(chat)
    if not initialized or not MinnTinkersWoWFDB.chat.copyChat or not chat then return end
    if copyWindow and copyWindow:IsShown() then
        copyWindow:Hide()
        return
    end
    local count = chat:GetNumMessages()
    if not canaccessvalue(count) or type(count) ~= "number" then return end
    local lines = {}
    for index = 1, count do
        local text = chat:GetMessageInfo(index)
        if canaccessvalue(text) and type(text) == "string" then lines[#lines + 1] = PlainText(text) end
    end
    if not copyWindow then
        copyWindow = CreateFrame("Frame", "MinnTinkersWoWFCopyChat", UIParent, "ButtonFrameTemplate")
        copyWindow:Hide()
        copyWindow:SetSize(680, 420)
        copyWindow:SetPoint("CENTER")
        copyWindow:SetTitle("Copy chat — Ctrl+A, Ctrl+C")
        copyWindow:SetPortraitToAsset(addon.icon)
        ButtonFrameTemplate_HideButtonBar(copyWindow)
        copyWindow:SetFrameStrata("DIALOG")
        copyWindow:SetClampedToScreen(true)
        copyWindow:SetMovable(true)
        copyWindow:EnableMouse(true)
        copyWindow:RegisterForDrag("LeftButton")
        copyWindow:SetScript("OnDragStart", copyWindow.StartMoving)
        copyWindow:SetScript("OnDragStop", copyWindow.StopMovingOrSizing)
        table.insert(UISpecialFrames, copyWindow:GetName())
        local scroll = CreateFrame("ScrollFrame", nil, copyWindow.Inset, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 10, -10)
        scroll:SetPoint("BOTTOMRIGHT", -30, 10)
        copyInput = CreateFrame("EditBox", "MinnTinkersWoWFCopyChatText", scroll)
        copyInput:SetMultiLine(true)
        copyInput:SetAutoFocus(false)
        copyInput:SetFontObject(ChatFontNormal)
        copyInput:SetMaxLetters(0)
        copyInput:SetWidth(600)
        copyInput:SetHeight(1)
        scroll:SetScrollChild(copyInput)
        copyInput:SetScript("OnEscapePressed", function() copyWindow:Hide() end)
        copyWindow:HookScript("OnHide", function()
            copyInput:ClearFocus()
            copyInput:SetText("")
            copyWindow:StopMovingOrSizing()
        end)
        copyWindow.scroll = scroll
    end
    copyWindow:Show()
    copyWindow.scroll:SetVerticalScroll(0)
    copyInput:SetText(table.concat(lines, "\n"))
    copyInput:SetFocus()
    copyInput:HighlightText()
end

local function RefreshUnread(chat, state)
    local bottom = chat:AtBottom()
    if not canaccessvalue(bottom) then state.unread = false; state.marker:Hide(); return end
    if bottom then state.unread = false end
    state.marker:SetShown(MinnTinkersWoWFDB.chat.unreadMarker and state.unread and not bottom)
end

local function Attach(chat)
    if not chat or frames[chat] or chat == ChatFrame2 or chat.isCombatLog then return end
    if not (chat.editBox and chat.buttonFrame and chat.AtBottom and chat.AddMessage and chat.AddOnDisplayRefreshedCallback
        and chat.GetNumMessages and chat.GetMessageInfo) then return end
    local state = {unread = false}
    frames[chat] = state
    state.copy = CreateFrame("Button", nil, chat, "UIMenuButtonStretchTemplate")
    state.copy:SetSize(26, 26)
    state.copy:SetPoint("TOP", chat.buttonFrame, "BOTTOM", 0, -4)
    local icon = state.copy:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    state.copy:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Copy chat")
        GameTooltip:AddLine("Select and copy this window's messages with Ctrl+A, Ctrl+C. Click again to close.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    local function HideCopyTooltip(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    state.copy:HookScript("OnLeave", HideCopyTooltip)
    state.copy:HookScript("OnHide", HideCopyTooltip)
    state.copy:SetShown(MinnTinkersWoWFDB.chat.copyChat)
    state.copy:SetScript("OnClick", function() module.CopyChat(chat) end)
    state.marker = CreateFrame("Frame", nil, chat)
    state.marker:SetHeight(10)
    state.marker:SetPoint("BOTTOMLEFT", chat, "BOTTOMLEFT", 4, 0)
    state.marker:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", -4, 0)
    state.marker:EnableMouse(false)
    local glow = state.marker:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1)
    glow:SetGradient("VERTICAL", CreateColor(classR, classG, classB, 0.6), CreateColor(classR, classG, classB, 0))
    local line = state.marker:CreateTexture(nil, "OVERLAY", nil, 1)
    line:SetHeight(2)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetColorTexture(classR, classG, classB, 0.9)
    local pulse = state.marker:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.35)
    fade:SetToAlpha(1)
    fade:SetDuration(0.8)
    fade:SetSmoothing("IN_OUT")
    state.marker:SetScript("OnShow", function() pulse:Play() end)
    state.marker:SetScript("OnHide", function() pulse:Stop() end)
    state.marker:Hide()
    hooksecurefunc(chat, "AddMessage", function()
        if not MinnTinkersWoWFDB.chat.unreadMarker then return end
        local bottom = chat:AtBottom()
        if canaccessvalue(bottom) and not bottom then state.unread = true end
        RefreshUnread(chat, state)
    end)
    -- Keep secure scrolling methods intact; native refresh callbacks isolate addon code.
    chat:AddOnDisplayRefreshedCallback(function() RefreshUnread(chat, state) end)
    chat:HookScript("OnShow", function() RefreshUnread(chat, state) end)
end

function module.IsAvailable()
    return initialized
end

function module.SetOption(key, value)
    MinnTinkersWoWFDB.chat[key] = value and true or false
    for chat, state in pairs(frames) do
        if key == "copyChat" then
            state.copy:SetShown(value)
        elseif key == "unreadMarker" then
            if not value then state.unread = false end
            RefreshUnread(chat, state)
        end
    end
    if key == "copyChat" and not value and copyWindow then copyWindow:Hide() end
end

local uncensored = {excludedCensorSources = 255, profanityFilter = 0}

local function GetChatFilters()
    if not (C_CVar and C_CVar.GetCVar and C_CVar.GetCVarInfo and C_CVar.SetCVar) then return end
    local current, defaults = {}, {}
    for name in pairs(uncensored) do
        local value, default, _, _, locked, secure, readOnly = C_CVar.GetCVarInfo(name)
        current[name], defaults[name] = tonumber(value), tonumber(default)
        if not (current[name] and defaults[name]) or locked or secure or readOnly then return end
    end
    return current, defaults
end

function module.ChatFiltersAvailable()
    return GetChatFilters() ~= nil
end

function module.IsChatCensoringDisabled()
    return C_CVar and C_CVar.GetCVar
        and tonumber(C_CVar.GetCVar("excludedCensorSources")) == uncensored.excludedCensorSources
        and tonumber(C_CVar.GetCVar("profanityFilter")) == uncensored.profanityFilter
        or false
end

function module.SetChatCensoringDisabled(disabled)
    local current, defaults = GetChatFilters()
    if not current then return false end

    local settings = MinnTinkersWoWFDB.chat
    local previous = type(settings.previousChatFilters) == "table" and settings.previousChatFilters
    local target = disabled and uncensored or previous or defaults
    local changed = {}
    for name in pairs(uncensored) do
        local value = tonumber(target[name]) or defaults[name]
        if value ~= current[name] then
            changed[name] = true
            if not C_CVar.SetCVar(name, tostring(value)) or tonumber(C_CVar.GetCVar(name)) ~= value then
                for changedName in pairs(changed) do
                    if tonumber(C_CVar.GetCVar(changedName)) ~= current[changedName] then
                        C_CVar.SetCVar(changedName, tostring(current[changedName]))
                    end
                end
                return false
            end
        end
    end

    settings.previousChatFilters = disabled and (previous or current) or nil
    return true
end

function module.TimestampsAvailable()
    return Settings and Settings.GetValue and Settings.SetValue and TIMESTAMP_FORMAT_HHMM_24HR ~= nil
end

function module.GetTimestampFormat()
    return module.TimestampsAvailable() and Settings.GetValue("showTimestamps") or "none"
end

function module.SetTimestampFormat(value)
    if module.TimestampsAvailable() then Settings.SetValue("showTimestamps", value) end
end

function module.Initialize()
    if initialized or not (CHAT_FRAMES and canaccessvalue and canaccessallvalues and hooksecurefunc) then return end
    if C_ClassColor and C_ClassColor.GetClassColor then
        local _, class = UnitClass("player")
        if canaccessvalue(class) and class then
            local color = C_ClassColor.GetClassColor(class)
            if color then
                local r, g, b = color:GetRGB()
                if canaccessallvalues(r, g, b) then classR, classG, classB = r, g, b end
            end
        end
    end
    for _, name in ipairs(CHAT_FRAMES) do Attach(_G[name]) end
    if FCF_OpenNewWindow then hooksecurefunc("FCF_OpenNewWindow", function()
        for _, name in ipairs(CHAT_FRAMES) do Attach(_G[name]) end
    end) end
    if FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", function()
        for _, name in ipairs(CHAT_FRAMES) do Attach(_G[name]) end
    end) end
    initialized = true
end
