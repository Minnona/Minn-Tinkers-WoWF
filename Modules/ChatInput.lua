local _, addon = ...
local module = {}
addon.ChatInput = module
local initialized = false
local boxes = {}
local history

local function Capture(editBox, state, userInput)
    if not MinnTinkersWoWFDB.chat.preserveDraft then return end
    local text = editBox:GetText()
    if not canaccessvalue(text) or type(text) ~= "string" then
        state.current, state.draft = nil, nil
        return
    end
    if text == "" then
        if userInput then state.current, state.draft = nil, nil end
        return
    end
    local chatType, target, channel = editBox:GetChatType(), editBox:GetTellTarget(), editBox:GetAttribute("channelTarget")
    if not canaccessvalue(chatType, target, channel) then
        state.current, state.draft = nil, nil
        return
    end
    local current = state.current or {}
    current.text, current.chatType, current.target, current.channel = text, chatType, target, channel
    state.current = current
end

local function Attach(editBox)
    if not editBox or boxes[editBox] or editBox.isGM or editBox.disableActivate then return end
    local state = {altArrows = editBox:GetAltArrowKeyMode(), history = history}
    boxes[editBox] = state
    editBox:SetAltArrowKeyMode(not MinnTinkersWoWFDB.chat.arrowHistory and state.altArrows or false)
    editBox:HookScript("OnEditFocusGained", function(self)
        state.historyIndex, state.historyDraft = nil, nil
        self:SetAltArrowKeyMode(not MinnTinkersWoWFDB.chat.arrowHistory and state.altArrows or false)
    end)
    editBox:HookScript("OnTextChanged", function(self, userInput)
        if userInput and not state.browsing then state.historyIndex, state.historyDraft = nil, nil end
        Capture(self, state, userInput)
    end)
    hooksecurefunc(editBox, "AddHistoryLine", function(_, text)
        if not canaccessvalue(text) or type(text) ~= "string" or text == "" then return end
        local history = state.history
        if history[#history] ~= text then
            if #history == 32 then table.remove(history, 1) end
            history[#history + 1] = text
        end
        for _, boxState in pairs(boxes) do boxState.historyIndex, boxState.historyDraft = nil, nil end
    end)
    editBox:HookScript("OnArrowPressed", function(self, key)
        if not MinnTinkersWoWFDB.chat.arrowHistory or (key ~= "UP" and key ~= "DOWN")
            or IsAltKeyDown() or IsControlKeyDown() or IsShiftKeyDown() then return end
        if AutoCompleteBox and AutoCompleteBox:IsShown() and AutoCompleteBox.parent == self then return end
        local history = state.history
        if #history == 0 or (key == "DOWN" and not state.historyIndex) then return end
        if not state.historyIndex then
            local text, chatType = self:GetText(), self:GetChatType()
            local target, channel = self:GetTellTarget(), self:GetAttribute("channelTarget")
            if not canaccessvalue(text, chatType, target, channel) or type(text) ~= "string" then return end
            state.historyDraft = {text = text, chatType = chatType, target = target, channel = channel}
            state.historyIndex = #history + 1
        end
        state.historyIndex = math.max(1, math.min(#history + 1, state.historyIndex + (key == "UP" and -1 or 1)))
        state.browsing = true
        if state.historyIndex <= #history then
            self:SetText(history[state.historyIndex])
        else
            local draft = state.historyDraft
            self:SetChatType(draft.chatType)
            self:SetTellTarget(draft.target)
            self:SetAttribute("channelTarget", draft.channel)
            self:ResetChatType()
            self:SetText(draft.text)
            self:UpdateHeader()
            state.historyIndex, state.historyDraft = nil, nil
        end
        state.browsing = nil
    end)
    editBox:HookScript("OnEscapePressed", function(self)
        -- The native handler dismisses autocomplete first. Only a cleared input means chat was cancelled.
        if not MinnTinkersWoWFDB.chat.preserveDraft or not state.current then return end
        local text = self:GetText()
        if not canaccessvalue(text) or text ~= "" then return end
        state.draft, state.current = state.current, nil
        self:ClearFocus()
        self:SetText(state.draft.text)
    end)
    hooksecurefunc(editBox, "ClearHistory", function()
        -- Blizzard clears native history when reusing chat windows; retain the character's saved messages.
        state.historyIndex, state.historyDraft = nil, nil
        state.current, state.draft = nil, nil
    end)
    hooksecurefunc(editBox, "SendMessage", function()
        state.historyIndex, state.historyDraft = nil, nil
        state.current, state.draft = nil, nil
    end)
end

function module.IsAvailable()
    return initialized
end

function module.SetOption(key, value)
    MinnTinkersWoWFDB.chat[key] = value and true or false
    if not initialized then return end
    for editBox, state in pairs(boxes) do
        if key == "arrowHistory" then
            editBox:SetAltArrowKeyMode(not value and state.altArrows or false)
            state.historyIndex, state.historyDraft = nil, nil
        elseif key == "preserveDraft" and not value then
            state.current, state.draft = nil, nil
        end
    end
end

function module.Initialize()
    if initialized or not (ChatFrameUtil and ChatFrameUtil.OpenChat and ChatFrameUtil.ChooseBoxForSend
        and ChatFrameUtil.GetChatFocusOverride and hooksecurefunc and canaccessvalue and CHAT_FRAMES) then return end
    local saved = MinnTinkersWoWFCharDB.chatHistory
    history = {}
    if type(saved) == "table" then
        for index = math.max(1, #saved - 31), #saved do
            local text = saved[index]
            if canaccessvalue(text) and type(text) == "string" and text ~= "" and text ~= history[#history] then
                history[#history + 1] = text
            end
        end
    end
    MinnTinkersWoWFCharDB.chatHistory = history
    for _, name in ipairs(CHAT_FRAMES) do
        local chat = _G[name]
        if chat then Attach(chat.editBox) end
    end
    if FCF_OpenNewWindow then hooksecurefunc("FCF_OpenNewWindow", function()
        for _, name in ipairs(CHAT_FRAMES) do local chat = _G[name]; if chat then Attach(chat.editBox) end end
    end) end
    if FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", function()
        for _, name in ipairs(CHAT_FRAMES) do local chat = _G[name]; if chat then Attach(chat.editBox) end end
    end) end
    hooksecurefunc(ChatFrameUtil, "OpenChat", function(text, chatFrame)
        if not MinnTinkersWoWFDB.chat.preserveDraft or ChatFrameUtil.GetChatFocusOverride() then return end
        local editBox = ChatFrameUtil.ChooseBoxForSend(chatFrame)
        Attach(editBox)
        local state = boxes[editBox]
        if not state or not state.draft then return end
        if not canaccessvalue(text) or text and text ~= "" then
            state.current, state.draft = nil, nil
            return
        end
        local draft = state.draft
        state.draft = nil
        editBox:SetChatType(draft.chatType)
        editBox:SetTellTarget(draft.target)
        editBox:SetAttribute("channelTarget", draft.channel)
        editBox:ResetChatType()
        editBox:UpdateHeader()
        -- OpenChat queues its text for the native edit box update; restore through the same path.
        editBox.text, editBox.setText = draft.text, 1
    end)
    initialized = true
end
