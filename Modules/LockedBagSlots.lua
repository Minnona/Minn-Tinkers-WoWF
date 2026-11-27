local _, addon = ...
local module = {}
addon.LockedBagSlots = module

local applied, available
local reloadDialog = "MINNTINKERSWOWF_LOCKED_BAG_SLOTS_RELOAD"

function module.IsAvailable()
    return available == true
end

function module.SetEnabled(enabled)
    enabled = enabled == true
    local db = MinnTinkersWoWFDB
    if enabled == (db.hideLockedBagSlots == true) then return end
    db.hideLockedBagSlots = enabled
    if not available then return end

    if enabled ~= applied then
        StaticPopup_Show(reloadDialog)
    else
        StaticPopup_Hide(reloadDialog)
    end
end

local function ShouldHide()
    if not applied then return false end
    local secured = IsAccountSecured()
    return canaccessvalue(secured) and secured == false
end

local function HideSlots(frame)
    if not ShouldHide() then return end

    local combat = InCombatLockdown()
    local separate = frame == ContainerFrame1 and not combat and not InputUtil.IsGamepadUIEnabled()
    local usable = separate and {} or nil
    local hidden = false
    for _, button in frame:EnumerateValidItems() do
        if button:GetBagID() == Enum.BagIndex.Backpack and button:IsExtended() then
            if not combat or not button:IsProtected() then
                button:Hide()
                hidden = true
            end
        elseif usable then
            usable[#usable + 1] = button
        end
    end

    -- The combined grid already places locked slots after usable slots.
    if hidden and usable then
        AnchorUtil.GridLayout(usable, frame:GetInitialItemAnchor(), frame:GetAnchorLayout())
    end
end

local function ShrinkStockGrid(frame)
    if not ShouldHide() or InCombatLockdown() or InputUtil.IsGamepadUIEnabled() then return end
    local displayed, unlocked = ContainerFrame_GetContainerNumSlots(Enum.BagIndex.Backpack)
    if unlocked <= 0 or displayed <= unlocked then return end

    local slots, columns = frame:GetBagSize(), frame:GetColumns()
    local rows = math.ceil(slots / columns) - math.ceil((slots - displayed + unlocked) / columns)
    if rows <= 0 then return end

    local item, height = frame.Items[1], frame:GetHeight()
    if not item or height ~= frame:CalculateHeight() then return end
    -- Keep any custom bag sizing and the native footer.
    local layout = frame:GetAnchorLayout()
    height = height - rows * (item:GetHeight() + layout.paddingY)
    frame:SetHeight(height)
    NineSliceUtil.UpdateCornerCropping(frame, height)
end

local function HideAddSlotsButton(frame)
    if not ShouldHide() then return end
    local button = frame.AddSlotsButton
    if button and (not InCombatLockdown() or not button:IsProtected()) then button:Hide() end
end

function module.Initialize()
    if available or not (IsAccountSecured and canaccessvalue and ContainerFrame_GetContainerNumSlots
        and Enum.BagIndex and InputUtil and InputUtil.IsGamepadUIEnabled and AnchorUtil and AnchorUtil.GridLayout
        and NineSliceUtil and NineSliceUtil.UpdateCornerCropping and ContainerFrame1 and ContainerFrameCombinedBags
        and StaticPopupDialogs and StaticPopup_Show and StaticPopup_Hide and ReloadUI) then return end

    local frames = {ContainerFrame1, ContainerFrameCombinedBags}
    for _, frame in ipairs(frames) do
        if not (frame.UpdateItemLayout and frame.UpdateFrameSize and frame.UpdateAddSlots) then return end
    end
    applied = MinnTinkersWoWFDB.hideLockedBagSlots == true
    StaticPopupDialogs[reloadDialog] = {
        text = "Reload the UI to apply the locked bag slot setting.",
        button1 = "Reload UI",
        button2 = "Later",
        OnAccept = ReloadUI,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    for _, frame in ipairs(frames) do
        hooksecurefunc(frame, "UpdateItemLayout", HideSlots)
        hooksecurefunc(frame, "UpdateFrameSize", ShrinkStockGrid)
        hooksecurefunc(frame, "UpdateAddSlots", HideAddSlotsButton)
    end
    available = true
end
