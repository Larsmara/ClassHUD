# ClassHUD

A customizable World of Warcraft HUD addon with bars and spell tracking.  
Built with [Ace3](https://www.wowace.com/projects/ace3) and LibSharedMedia.

---

## ✨ Features

- Cast, HP, primary resource, and special power bars that adapt per class/spec.
- Snapshot-driven spell layout sourced from Blizzard's Cooldown Viewer API.
- Automatic glow, cooldown, and aura stack handling for tracked spells and buffs.
- Configurable utility placement (top/bottom/left/right) with per-spec persistence.
- Simplified Ace3 options panel (`/chud`) with snapshot refresh, tracked buff toggles, and buff→spell link editing.

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

| File | Responsibility |
| ---- | -------------- |
| `ClassHUD.lua` | Core addon lifecycle, events, saved variables, snapshot management. |
| `ClassHUD_Utils.lua` | Shared helpers for profile access, snapshot lookup, formatting, and aura search. |
| `ClassHUD_Bars.lua` | Anchor frame creation, cast/resource/health bar layout and updates. |
| `ClassHUD_Classbar.lua` | Class-specific special power/segment handling. |
| `ClassHUD_Spells.lua` | Snapshot-driven spell frame creation, cooldown/aura updates, tracked buff bar. |
| `ClassHUD_Options.lua` | Ace3 configuration rebuilt around the snapshot cache. |
| `ClassHUD_SpellSuggestions.lua` | Optional pre-filled spell suggestions (data only). |

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
