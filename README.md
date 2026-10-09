[**Download the latest ZIP**](https://github.com/Minnona/Minn-Tinkers-WoWF/releases/latest/download/Minn-Tinkers-WoWF.zip)

# Minn Tinkers WoWF

Quality-of-life settings for **World of Warcraft: Forever**.

Extract the ZIP into `Interface/AddOns/`, keeping the folder named `Minn Tinkers WoWF`. Open settings with **`/minn`** or the frog minimap button.

## Universal

- **Fast autoloot:** skips the automatic loot window, with native fallback when needed.
- **Camera distance:** adjustable maximum zoom-out limit, up to 4.0.
- **Questing:** auto accept and turn in, skipping unlimited repeatables. Zero or one reward choice auto-completes; two or more require manual completion, with optional highest vendor-value preselection. Hold **Shift** to handle quests manually.
- **Gossip:** skip an NPC's sole dialogue option when no quests are listed.
- **Junk selling:** automatically sell grey items, respecting excluded bags.

<img src=".github/screenshots/universal.png" alt="Universal tab: looting, camera, questing and NPC interaction settings" width="560">

## UI

- **Action-bar fonts:** separate sizes for keybinds, item counts and macro names.
- **Combat indicator:** persistent red edge glow with adjustable opacity and width.
- **Pet happiness:** hunter-only option for a thin red/yellow/green happiness reserve bar below pet focus, with native trim and tooltip.
- **Range indicator:** movable target range dot with adjustable size and opacity; choose white or your character's native class color when in range. Select a spell by name or drop it from the spellbook. Includes position reset and per-character settings.

<img src=".github/screenshots/ui.png" alt="UI tab: action-bar fonts, combat glow, pet happiness and range indicator settings" width="560">

Range indicator examples using the hunter class color:

| Out of range (red) | In range (class color) |
| --- | --- |
| <img src=".github/screenshots/range-out-of-range.png" alt="Red range indicator when the target is out of spell range" width="260"> | <img src=".github/screenshots/range-in-range.png" alt="Green hunter-class indicator when the target is in spell range" width="260"> |

## Chat

- **Chat input:** Escape preserves unsent text; Up/Down recalls sent messages, saved per character across reloads and restarts.
- **Chat URLs:** click web addresses, including `discord.gg/invite`, to open a copy popup; press **Ctrl+C**.
- **Copy chat:** toggle a copy window with the button beside chat input; use **Ctrl+A**, then **Ctrl+C**.
- **Unread messages:** a marker helps you return to new messages when scrolled up.
- **Timestamps:** choose Blizzard's native timestamp format for new messages.

<img src=".github/screenshots/chat.png" alt="Chat tab: draft preservation, message history, URLs, copying, unread messages and timestamps" width="560">

Author: **Minnona (Northdale)**. Licensed under [GPLv3](LICENSE) (GPL-3.0-only).
