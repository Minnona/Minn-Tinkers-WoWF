local _, addon = ...
local module = {}
addon.FastLoot = module

local events = CreateFrame("Frame")
local nativeOnEvent
local active, opened, fromItem, fallback, requested, nativeOpened
local timeout
local enabled, desired, inProgress

local function ShowNativeLoot()
    if not active then
        return
    end
    fallback = true
    if timeout then
        timeout:Cancel()
        timeout = nil
    end
    if opened and not nativeOpened then
        nativeOpened = true
        nativeOnEvent(LootFrame, "LOOT_OPENED", false, fromItem)
    end
end

local function RequestLoot()
    if requested or fallback then
        return
    end
    requested = true
    -- Descending indices remain safe if cleared slots disappear immediately.
    for slot = GetNumLootItems(), 1, -1 do
        if not active or fallback then
            break
        end
        if GetLootSlotType(slot) ~= Enum.LootSlotType.None then
            local _, _, _, _, _, locked = GetLootSlotInfo(slot)
            if not locked then
                LootSlot(slot)
            end
        end
    end
end

function module.SetEnabled(value, lootClosed)
    desired = value
    if inProgress or value == enabled then
        return true
    end
    if not value then
        events:UnregisterAllEvents()
        if nativeOnEvent then
            LootFrame:RegisterEvent("LOOT_OPENED")
        end
        enabled = false
        return true
    end
    -- If the beta UI changes or another addon owns this event, leave it alone.
    if not LootFrame or not LootFrame.OnEvent or not LootSlot
        or not GetNumLootItems or not GetLootSlotType or not GetLootSlotInfo
        or not Enum or not Enum.LootSlotType or not C_Timer or not C_Timer.NewTimer
        or type(issecretvalue) ~= "function"
        or not LootFrame:IsEventRegistered("LOOT_OPENED") then
        return false
    end
    -- Do not acquire a loot session already opened by the native UI.
    if not lootClosed and LootFrame:IsShown() then
        inProgress = true
        events:RegisterEvent("LOOT_CLOSED")
        return true
    end
    nativeOnEvent = LootFrame.OnEvent
    LootFrame:UnregisterEvent("LOOT_OPENED")
    events:RegisterEvent("LOOT_READY")
    events:RegisterEvent("LOOT_OPENED")
    events:RegisterEvent("LOOT_CLOSED")
    events:RegisterEvent("LOOT_BIND_CONFIRM")
    events:RegisterEvent("UI_ERROR_MESSAGE")
    enabled = true
    return true
end

events:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "LOOT_READY" then
        inProgress = true
        if not arg1 then
            return
        end
        active = true
        RequestLoot()
    elseif event == "LOOT_OPENED" then
        inProgress = true
        if not arg1 then
            nativeOnEvent(LootFrame, event, arg1, arg2)
            return
        end
        active, opened, fromItem = true, true, arg2
        if fallback then
            ShowNativeLoot()
            return
        end
        RequestLoot()
        if active and not fallback and not timeout then
            -- One watchdog per session, never a delay before requesting loot.
            timeout = C_Timer.NewTimer(1, function()
                timeout = nil
                if not active or fallback then
                    return
                end
                for slot = 1, GetNumLootItems() do
                    if GetLootSlotType(slot) ~= Enum.LootSlotType.None then
                        ShowNativeLoot()
                        return
                    end
                end
            end)
        end
    elseif event == "LOOT_CLOSED" then
        inProgress = false
        active, opened, fromItem, fallback, requested = nil, nil, nil, nil, nil
        nativeOpened = nil
        if timeout then
            timeout:Cancel()
            timeout = nil
        end
        module.SetEnabled(desired, true)
    elseif event == "LOOT_BIND_CONFIRM" then
        ShowNativeLoot()
    elseif event == "UI_ERROR_MESSAGE" and active and not issecretvalue(arg2) and arg2 == ERR_INV_FULL then
        -- Other loot failures still fall back through the one-shot watchdog.
        ShowNativeLoot()
    end
end)
