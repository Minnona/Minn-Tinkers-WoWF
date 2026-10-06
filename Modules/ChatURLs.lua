local _, addon = ...
local module = {}
addon.ChatURLs = module
local linkType = "minntinkersurl"
local popupName = "MINNTINKERSWOWF_COPY_URL"
local initialized, filtering = false, false
local events = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

local function IsURL(url)
    if url:find("[%s%c|]") then return false end
    local lower = url:lower()
    local explicit = lower:match("^https?://")
    local address = explicit and url:sub(#explicit + 1) or url
    -- Reject other protocols and email addresses; only link web destinations.
    local authority = address:match("^([^/?#]+)")
    if not authority or authority:find("@", 1, true) then return false end
    local host = authority:match("^(.-):%d+$") or authority
    if not host:match("^[%w.-]+$") or not host:match("^%w") or not host:match("%w$")
        or host:find("..", 1, true) then return false end
    for label in host:gmatch("[^.]+") do
        if #label > 63 or not label:match("^%w") or not label:match("%w$") then return false end
    end
    if explicit then return true end
    local suffix = host:match("%.([^.]*)$")
    return suffix ~= nil and (#suffix >= 2 and suffix:match("^%a+$") ~= nil
        or suffix:match("^xn%-%-[%w-]+$") ~= nil)
end

local function LinkifyPlain(text, restoreColor)
    return (text:gsub("%S+", function(token)
        local prefix = token:match("^[%(%[%{<\"']*")
        local url = token:sub(#prefix + 1)
        while #url > 0 do
            local last = url:sub(-1)
            if last:match("[.,;:!?\"'>]") then
                url = url:sub(1, -2)
            else
                local opening = last == ")" and "(" or last == "]" and "[" or last == "}" and "{"
                if not opening then break end
                local _, opens = url:gsub("%" .. opening, "")
                local _, closes = url:gsub("%" .. last, "")
                if closes <= opens then break end
                url = url:sub(1, -2)
            end
        end
        if not IsURL(url) then return token end
        local suffix = token:sub(#prefix + #url + 1)
        return prefix .. "|cff71d5ff" .. LinkUtil.FormatLink(linkType, url, url)
            .. "|r" .. restoreColor .. suffix
    end))
end

local function FilterMessage(_, _, message, ...)
    if not MinnTinkersWoWFDB.chatURLs or not canaccessvalue(message) or type(message) ~= "string" then
        return false
    end
    if not message:find(".", 1, true) and not message:find("://", 1, true) then return false end
    local parts, position, color = {}, 1, ""
    -- Process plain text only; preserve Blizzard links, textures, atlases and escapes.
    while position <= #message do
        local pipe = message:find("|", position, true)
        if not pipe then
            parts[#parts + 1] = LinkifyPlain(message:sub(position), color)
            break
        end
        if pipe > position then
            parts[#parts + 1] = LinkifyPlain(message:sub(position, pipe - 1), color)
        end
        local tag = message:sub(pipe + 1, pipe + 1)
        local finish
        if tag == "H" then
            local _, first = message:find("|h", pipe + 2, true)
            if first then _, finish = message:find("|h", first + 1, true) end
        elseif tag == "T" or tag == "A" then
            local _, ending = message:find(tag == "T" and "|t" or "|a", pipe + 2, true)
            finish = ending
        elseif tag == "c" then
            local value = message:sub(pipe, pipe + 9)
            if value:match("^|c%x%x%x%x%x%x%x%x$") then
                color, finish = value, pipe + 9
            end
        elseif tag == "r" then
            color = ""
        end
        if (tag == "H" or tag == "T" or tag == "A") and not finish then
            parts[#parts + 1] = message:sub(pipe)
            break
        end
        finish = finish or math.min(pipe + 1, #message)
        parts[#parts + 1] = message:sub(pipe, finish)
        position = finish + 1
    end
    local transformed = table.concat(parts)
    if transformed ~= message then return false, transformed, ... end
    return false
end

function module.IsAvailable()
    return initialized
end

function module.SetEnabled(value)
    MinnTinkersWoWFDB.chatURLs = value and true or false
    if not initialized or filtering == MinnTinkersWoWFDB.chatURLs then return end
    filtering = MinnTinkersWoWFDB.chatURLs
    for _, event in ipairs(events) do
        if filtering then
            ChatFrameUtil.AddMessageEventFilter(event, FilterMessage)
        else
            ChatFrameUtil.RemoveMessageEventFilter(event, FilterMessage)
        end
    end
    if not filtering then StaticPopup_Hide(popupName) end
end

function module.Initialize()
    if initialized then return end
    if not (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter and ChatFrameUtil.RemoveMessageEventFilter
        and LinkUtil and LinkUtil.FormatLink and LinkUtil.RegisterLinkHandler and LinkUtil.IsLinkHandlerRegistered
        and StaticPopupDialogs and StaticPopup_Show and StaticPopup_Hide
        and StaticPopup_StandardEditBoxOnEscapePressed and canaccessvalue) then return end
    if LinkUtil.IsLinkHandlerRegistered(linkType) then return end
    StaticPopupDialogs[popupName] = {
        text = "Copy URL\nPress Ctrl+C, then paste into your browser.",
        button1 = CLOSE,
        hasEditBox = true,
        editBoxWidth = 350,
        maxLetters = 0,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnShow = function(dialog, url)
            local editBox = dialog:GetEditBox()
            editBox:SetText(url)
            editBox:SetFocus()
            editBox:HighlightText()
        end,
        OnHide = function(dialog) dialog:GetEditBox():ClearFocus() end,
        EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
        EditBoxOnEnterPressed = StaticPopup_StandardEditBoxOnEscapePressed,
    }
    LinkUtil.RegisterLinkHandler(linkType, function(_, _, data, context)
        local url = data.options
        if (not context or context.button == "LeftButton") and canaccessvalue(url)
            and type(url) == "string" and IsURL(url) then
            -- Keep existing chat links usable even after detection is disabled.
            StaticPopup_Show(popupName, nil, nil, url)
        end
    end)
    initialized = true
    module.SetEnabled(MinnTinkersWoWFDB.chatURLs)
end
