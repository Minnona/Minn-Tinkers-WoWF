local _, addon = ...
local module = {}
addon.AutoSellJunk = module
local events = CreateFrame("Frame")
local handled = false
local active = false
local pending, expiry, waiting

local function StopWork()
    if pending then pending:Cancel(); pending = nil end
    if expiry then expiry:Cancel(); expiry = nil end
    waiting = nil
    active = false
    events:UnregisterEvent("ITEM_LOCK_CHANGED")
    events:UnregisterEvent("BAG_UPDATE_DELAYED")
    events:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
end

function module.SetEnabled(value)
    MinnTinkersWoWFDB.autoSellJunk = value and true or false
    if not value then StopWork() end
end

function module.IsAvailable()
    return type(C_Container) == "table" and type(C_Container.GetContainerNumSlots) == "function"
        and type(C_Container.GetContainerItemInfo) == "function"
        and type(C_Container.UseContainerItem) == "function"
        and type(C_Container.GetBackpackSellJunkDisabled) == "function"
        and type(C_Container.GetBagSlotFlag) == "function"
        and type(NUM_TOTAL_EQUIPPED_BAG_SLOTS) == "number" and Enum.BagIndex and Enum.ItemQuality
        and Enum.BagSlotFlags and Enum.BagSlotFlags.ExcludeJunkSell
        and MerchantFrame and C_Timer and C_Timer.NewTimer
        and type(issecretvalue) == "function"
end

local function CanSell()
    return active and MinnTinkersWoWFDB.autoSellJunk and not IsShiftKeyDown()
        and MerchantFrame and MerchantFrame:IsShown()
end

local function BagAllowed(bag)
    local excluded
    if bag == Enum.BagIndex.Backpack then
        excluded = C_Container.GetBackpackSellJunkDisabled()
    else
        excluded = C_Container.GetBagSlotFlag(bag, Enum.BagSlotFlags.ExcludeJunkSell)
    end
    return not issecretvalue(excluded) and excluded == false
end

local function SellSlot(bag, slot, item)
    if not item or issecretvalue(item.quality) or issecretvalue(item.isLocked)
        or issecretvalue(item.hasNoValue) then return end
    if (item.quality ~= nil and item.quality ~= Enum.ItemQuality.Poor) or item.hasNoValue == true then return end
    if item.quality == nil or item.isLocked ~= false or item.hasNoValue ~= false then
        -- Drop slots whose item ID changes before a retry.
        if not issecretvalue(item.itemID) and type(item.itemID) == "number" then return item.itemID end
        return
    end
    C_Container.UseContainerItem(bag, slot)
end

local function RetryJunk()
    pending = nil
    if not CanSell() then StopWork(); return end
    if not waiting then return end
    for bag, slots in pairs(waiting) do
        if BagAllowed(bag) then
            for slot, id in pairs(slots) do
                if not CanSell() then StopWork(); return end
                local item = C_Container.GetContainerItemInfo(bag, slot)
                slots[slot] = nil
                if item and not issecretvalue(item.itemID) and item.itemID == id then
                    slots[slot] = SellSlot(bag, slot, item)
                end
                if not waiting then return end
            end
            if not next(slots) then waiting[bag] = nil end
        else
            waiting[bag] = nil
        end
    end
    if not next(waiting) then StopWork() end
end

local function SellJunk()
    pending = nil
    if not MinnTinkersWoWFDB.autoSellJunk or IsShiftKeyDown() then StopWork(); return end
    if not CanSell() then return end
    waiting = {}
    for bag = Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        if BagAllowed(bag) then
            local count = C_Container.GetContainerNumSlots(bag)
            if not issecretvalue(count) then
                for slot = count, 1, -1 do
                    if not CanSell() then StopWork(); return end
                    local id = SellSlot(bag, slot, C_Container.GetContainerItemInfo(bag, slot))
                    if not waiting then return end
                    if id then
                        waiting[bag] = waiting[bag] or {}
                        waiting[bag][slot] = id
                    end
                end
            end
        end
    end
    if not next(waiting) then StopWork(); return end
    events:RegisterEvent("ITEM_LOCK_CHANGED")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    expiry = C_Timer.NewTimer(3, StopWork)
end

function module.Initialize()
    if not module.IsAvailable() then return end
    MerchantFrame:HookScript("OnShow", function()
        if active and not pending and not waiting then pending = C_Timer.NewTimer(0, SellJunk) end
    end)
    events:RegisterEvent("MERCHANT_SHOW")
    events:RegisterEvent("MERCHANT_CLOSED")
    events:SetScript("OnEvent", function(_, event, bag, slot)
        if event == "MERCHANT_CLOSED" then
            StopWork()
            handled = false
        elseif event == "MERCHANT_SHOW" then
            if handled then return end
            handled = true
            if not MinnTinkersWoWFDB.autoSellJunk or IsShiftKeyDown() then return end
            active = true
            -- Let Blizzard finish opening the merchant before using bag items.
            pending = C_Timer.NewTimer(0, SellJunk)
        elseif waiting and not pending then
            if event == "ITEM_LOCK_CHANGED" and not (waiting[bag] and waiting[bag][slot]) then return end
            pending = C_Timer.NewTimer(0, RetryJunk)
        end
    end)
end
