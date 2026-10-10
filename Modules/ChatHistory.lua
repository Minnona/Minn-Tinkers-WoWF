local _, addon = ...
local module = {}
addon.ChatHistory = module
local initialized = false
local limit = 200

local function Message(text, r, g, b)
    if not canaccessvalue(text, r, g, b) or type(text) ~= "string" or text == "" then return end
    r, g, b = r or 1, g or 1, b or 1
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number"
        or not (r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1) then return end
    return {text, r, g, b}
end

local function ForEachChat(callback)
    FCF_IterateActiveChatWindows(function(chat)
        if chat and chat ~= ChatFrame2 and not chat.isCombatLog and not chat.isTemporary
            and chat.GetNumMessages and chat.GetMessageInfo and chat.BackFillMessage
            and chat.GetMaxLines and chat.SetMaxLines then
            local name = chat:GetName()
            if canaccessvalue(name) and type(name) == "string" then callback(chat, name) end
        end
    end)
end

local function Prepare(chat)
    local maximum = chat:GetMaxLines()
    if canaccessvalue(maximum) and type(maximum) == "number" and maximum < limit then
        chat:SetMaxLines(limit)
    end
end

local function Restore()
    if not MinnTinkersWoWFDB.chat.saveHistory then return end
    ForEachChat(function(chat, name)
        Prepare(chat)
        local lines = MinnTinkersWoWFCharDB.chatMessages[name]
        if type(lines) ~= "table" then return end
        -- Backfill keeps new login messages and bypasses AddMessage/unread hooks.
        for index = #lines, math.max(1, #lines - limit + 1), -1 do
            local entry = lines[index]
            if type(entry) == "table" then
                local line = Message(entry[1], entry[2], entry[3], entry[4])
                if line then chat:BackFillMessage(unpack(line)) end
            end
        end
    end)
end

local function Save()
    if not MinnTinkersWoWFDB.chat.saveHistory then return end
    local history = {}
    ForEachChat(function(chat, name)
        local count = chat:GetNumMessages()
        if not canaccessvalue(count) or type(count) ~= "number" then
            history[name] = MinnTinkersWoWFCharDB.chatMessages[name]
            return
        end
        local lines = {}
        for index = math.max(1, count - limit + 1), count do
            local line = Message(chat:GetMessageInfo(index))
            if line then lines[#lines + 1] = line end
        end
        history[name] = lines
    end)
    MinnTinkersWoWFCharDB.chatMessages = history
end

function module.IsAvailable()
    return initialized
end

function module.SetEnabled(value)
    MinnTinkersWoWFDB.chat.saveHistory = value and true or false
    if initialized and value then ForEachChat(Prepare) end
end

function module.Initialize()
    if initialized or not (FCF_IterateActiveChatWindows and canaccessvalue) then return end
    if type(MinnTinkersWoWFCharDB.chatMessages) ~= "table" then MinnTinkersWoWFCharDB.chatMessages = {} end
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_LOGOUT")
    events:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            self:UnregisterEvent(event)
            Restore()
        else
            -- SavedVariables are written after PLAYER_LOGOUT, including /reload.
            Save()
        end
    end)
    if FCF_OpenNewWindow then hooksecurefunc("FCF_OpenNewWindow", function()
        if MinnTinkersWoWFDB.chat.saveHistory then ForEachChat(Prepare) end
    end) end
    initialized = true
end
