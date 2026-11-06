local _, addon = ...
local module = {}
addon.ChatShadow = module
local initialized = false
local frames = {}

local function Apply(chat)
    if not chat or not (chat.GetShadowColor and chat.GetShadowOffset and chat.SetShadowColor and chat.SetShadowOffset) then return end
    local state = frames[chat]
    if not state then
        local r, g, b, a = chat:GetShadowColor()
        local x, y = chat:GetShadowOffset()
        if not canaccessvalue(r, g, b, a, x, y) or type(r) ~= "number" or type(g) ~= "number"
            or type(b) ~= "number" or type(a) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return end
        state = {r = r, g = g, b = b, a = a, x = x, y = y, enabled = false}
        frames[chat] = state
    end
    local enabled = MinnTinkersWoWFDB.chat.enhancedShadow
    if state.enabled == enabled then return end
    if enabled then
        chat:SetShadowColor(0, 0, 0, 1)
        chat:SetShadowOffset(2, -2)
    else
        chat:SetShadowColor(state.r, state.g, state.b, state.a)
        chat:SetShadowOffset(state.x, state.y)
    end
    state.enabled = enabled
end

local function ApplyAll()
    for _, name in ipairs(CHAT_FRAMES) do Apply(_G[name]) end
end

function module.IsAvailable()
    return initialized and next(frames) ~= nil
end

function module.SetEnabled(value)
    MinnTinkersWoWFDB.chat.enhancedShadow = value and true or false
    if initialized then ApplyAll() end
end

function module.Initialize()
    if initialized or not (CHAT_FRAMES and canaccessvalue and hooksecurefunc) then return end
    ApplyAll()
    if FCF_OpenNewWindow then hooksecurefunc("FCF_OpenNewWindow", ApplyAll) end
    if FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", ApplyAll) end
    initialized = true
end
