# ClassHUD

**ClassHUD** is a minimalist and customizable _class HUD_ for World of Warcraft. It brings your most important resources and cooldowns to the center of the screen, giving you better combat awareness without having to look down at your action bars.

✨ **Main Features:**

- **Resource bars** – HP, primary resource (mana/energy/rage), and class-specific power (e.g. combo points).
- **Castbar** – compact castbar with icon and timer placed directly in the HUD.
- **Top/Bottom bars for spells & buffs** – track cooldowns and buffs in a clean layout, with the option to link spells to buffs (e.g. “show buff on this cooldown”).
- **Buff tracking** – always see uptime for your most important buffs/debuffs.
- **Full configuration** via options – adjust fonts, textures, spacing, borders, and which spells/buffs to show.
- **No external dependencies** – Ace3 and LibSharedMedia are embedded, so you don’t need to install anything extra.

🎯 **Goal:** Provide a clean and functional HUD that helps you focus on gameplay and reactions, instead of staring at action bars.

---

## 🔧 Installation

1. Download the latest release from [Releases](../../releases).
2. Extract into your WoW `_retail_/Interface/AddOns/` folder.
3. Make sure the folder is named **ClassHUD**.
4. Launch WoW and enable **ClassHUD** in the AddOns menu.

---

## 🛠 Usage

- Open options with `/chud`.
- Refresh the Blizzard snapshot (if needed) from **Snapshot → Refresh Snapshot**.
- Configure which utility cooldowns appear on each bar under **Spells & Buffs → Utility Placement**.
- Toggle tracked buffs and manage buff links under **Spells & Buffs**.
- Move the anchor by unlocking the frame in **General**.

## 🗂 Architecture

The addon is organised into lightweight modules:

| File                            | Responsibility                                                                   |
| ------------------------------- | -------------------------------------------------------------------------------- |
| `ClassHUD.lua`                  | Core addon lifecycle, events, saved variables, snapshot management.              |
| `ClassHUD_Utils.lua`            | Shared helpers for profile access, snapshot lookup, formatting, and aura search. |
| `ClassHUD_Bars.lua`             | Anchor frame creation, cast/resource/health bar layout and updates.              |
| `ClassHUD_Classbar.lua`         | Class-specific special power/segment handling.                                   |
| `ClassHUD_Spells.lua`           | Snapshot-driven spell frame creation, cooldown/aura updates, tracked buff bar.   |
| `ClassHUD_Options.lua`          | Ace3 configuration rebuilt around the snapshot cache.                            |
| `ClassHUD_SpellSuggestions.lua` | Optional pre-filled spell suggestions (data only).                               |

### Suggested future structure

To keep modules focused as the addon grows, consider grouping files under folders:

- `core/` for bootstrap (`ClassHUD.lua`, `ClassHUD_Utils.lua`).
- `ui/` for bars, spell frames, and any future UI widgets.
- `config/` for options and suggestion data.
- `modules/` for optional trackers (e.g., interrupt tracker, class-specific extras).

## 🦴 Todo

- [ ] Add optional sound notifications.
- [ ] Extend spell suggestions for remaining specs.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
