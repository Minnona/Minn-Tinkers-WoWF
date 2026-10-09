# Minn Tinkers WoWF design

Implemented layout selected from the portrait-window proposal.

- Title and folder: Minn Tinkers WoWF.
- Native ButtonFrameTemplate window, initially 700 x 480 UI units, frog portrait, native close button, movable and clamped to screen. A native PanelResizeButtonTemplate grip supports 560 x 420 through 1100 x 800 and remembers the size.
- Native PanelTabButtonTemplate category tabs below the window. Universal is first; UI is second. Each tab has its own content page.
- Universal > Looting > Fast autoloot, using UICheckButtonTemplate and GameTooltip. Tooltip responds over the checkbox and label.
- The frog minimap button and /minn share addon.ToggleOptions. Create the button at login, using the native minimap background, tracking-border gold ring and zoom-button highlight textures with the existing frog icon, matching ClassicForever_Bots. Left-drag updates the saved minimapAngle with scaled cursor coordinates; OnUpdate exists only during dragging, and positioning uses the actual minimap radius plus five units. Remember the selected category name in lastTab; unknown saved names fall back to Universal.
- Open with /minn; close using X or Escape. Create UI only on first use; save changes immediately.
- Default fastAutoloot is true to preserve the prior addon behavior. Store one account-wide boolean in MinnTinkersWoWFDB. Preserve existing values.
- Core handles initialization and setting changes. Modules/FastLoot.lua owns the loot event lifecycle. UI/Options.lua owns the window and controls. No generic module framework or libraries.
- Active-session changes are deferred until LOOT_CLOSED. The native loot window remains in charge when the module is disabled.
- UI > Action-bar text contains three native MinimalSliderTemplate controls for independent keybind, item-count and macro-name font increases of 0–12 units. Zero restores the original size; the default adds nothing.
- Modules/ActionBarFonts.lua applies changes to registered Blizzard action buttons, preserving each text region's font and outline. It securely hooks native button registration and keybinding updates. It adjusts text-region height so larger keybind labels are not constrained to the native fixed height. Slider changes apply only the affected category; keybinding hooks apply only HotKey text. Changes are deferred in combat until PLAYER_REGEN_ENABLED.
- Slider rows use 32-unit heights with 34-unit spacing, label left, flexible slider center and value right. A small shared UI helper builds the camera and font controls, including read-only programmatic refresh and native tooltips.
- Universal > Camera has a maximum-distance slider (1.0–4.0 in 0.1 increments). Modules/CameraDistance.lua owns CVar availability checks, supported writes and readback. First installation preserves the current game value; explicit choices are saved and reapplied at login. Accepted-value readback is not clamped to the slider range; its 4.0 ceiling reflects the tested client setting and does not establish the beta engine limit. No polling or forced zoom.

- Universal > Questing uses three independent saved booleans under questing: autoAccept=true, autoTurnIn=true, vendorReward=false. Modules/Questing.lua handles native gossip/greeting/detail/progress/reward events; unlimited repeatables are excluded, daily/weekly quests eligible. Shift latches a manual conversation; native interaction-state checks preserve it across transitions. Reward lookup waits on item events with a three-second cancellation timer and uses native reward highlighting. A secure post-hook of native QuestInfo_ShowRewards restores active suggestions after reward refreshes, while manual clicks cancel them and quest-log displays are ignored. Background item updates cannot start a session. Vendor selection only suggests an item; any fixed or choice item reward requires manual completion. Only quests without items auto-complete, preserving native money confirmations.
- Labelled horizontal rules separate Looting, Camera, Questing and Action-bar text. Checkbox pairs share rows; reward selection occupies a full row. Minimum height420 keeps controls visible without a scroll container.

- UI > Combat indicator uses Modules/CombatIndicator.lua with three saved values: enabled=true, opacity=25 and width=20. An owned mouse-disabled background frame has four native gradient textures fading inward to transparent. PLAYER_REGEN_DISABLED/ENABLED control persistent visibility, with login combat state initialized from InCombatLockdown. Controls update only this overlay, including in combat; no polling or native warning-frame modifications.

- Universal > NPC interaction uses Modules/GossipSkip.lua and one saved boolean skipSingleGossip=true. GOSSIP_SHOW selects a sole available option only with no quest entries. Selection waits for native frame visibility when needed, with pending work cancelled on Shift, close or disable. Shift bypasses the interaction. Attempted option IDs are tracked until GOSSIP_CLOSED to prevent repeated selection loops. C_GossipInfo.SelectOption receives only the option ID, preserving native confirmations.

- Universal > NPC interaction also contains Modules/AutoSellJunk.lua, controlled by autoSellJunk=true. MERCHANT_SHOW schedules one zero-delay timer so native merchant opening completes first. A carried-bag pass uses C_Container.UseContainerItem only for unlocked poor-quality items with vendor value; Blizzard bag/backpack junk-selling exclusions are respected. Secret metadata is skipped. Locked/uncached slots with matching item IDs retry only on ITEM_LOCK_CHANGED, BAG_UPDATE_DELAYED or GET_ITEM_INFO_RECEIVED, bounded by a three-second timer; completed requests are never repeated. Native OnShow covers merchant opening after the first deferred callback. MERCHANT_CLOSED cancels pending work and resets the visit; Shift or disabling also cancels pending work. Shift bypasses the entire visit. No dependency on the native bulk-junk feature or polling. The checkbox shares the gossip row to preserve compact spacing.

Native template/API references were checked against the Forever branch of the Blizzard UI source mirror. Runtime rendering and restrictions still require testing in the installed beta.

## References

- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXML/PortraitFrame.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/LootDocumentation.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButton.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXML/Shared/Slider/MinimalSlider.xml
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Camelot/ControlsOverrides.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/CVarDocumentation.lua
- https://github.com/LihvoDruida/Max-Camera-Distance/blob/main/Compat.lua

- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/GossipInfoDocumentation.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestFrame.lua
- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestInfo.lua
