# ClassHUD

ClassHUD is a modern World of Warcraft® addon that puts the most important parts of your class kit directly in the center of your screen. It extends Blizzard's classic Cooldown Manager with a more flexible heads-up display so you can watch spells, buffs, summons, and resources without taking your eyes off the action.

## Project Overview
- **Customizable class HUD** that tracks the spells, buffs, and cooldowns you care about for every spec.
- **Resource and class mechanics support** for combo points, eclipse, chi, runes, and other spec-specific bars.
- **Summon awareness** for totems, demons, and the ever-important Wild Imps counter.
- **Blizzard-friendly**: builds on the modern ActionButton overlay system (`ActionButtonSpellAlertManager`) and safe spell override handling via `GetActiveSpellID`.

Whether you just want a cleaner way to watch core cooldowns or a full-featured combat cockpit, ClassHUD delivers a configurable, profile-driven experience that stays true to Blizzard's UI while bringing it into the Dragonflight / The War Within era.

## Features
- **Spell tracking** for essential rotation abilities, utility spells, and tracked buffs.
- **Class bars** for primary resources and spec mechanics (combo points, eclipse, chi, runes, essences, and more).
- **Totem & demon tracking**, including per-slot timers and visual alerts.
- **Wild Imp counter** for Demonology Warlocks with automatic cleanup of expired summons.
- **Options UI** powered by Ace3 that lets you adjust layout, fonts, textures, and visibility in real time.
- **Override-safe spell handling** so base, permanent, and temporary spell overrides stay in sync with your layout.
- **Modern overlay glow system** that mirrors Blizzard's spell alert glows for procs and highlights.

## Installation
### Manual install
1. Download or clone the repository.
2. Copy the `ClassHUD` folder into your `_retail_/Interface/AddOns/` directory so the final path is `_retail_/Interface/AddOns/ClassHUD`.
3. Restart World of Warcraft and enable **ClassHUD** from the AddOns list at the character select screen.

### Release packaging
We plan to publish packaged builds through GitHub Releases and, when ready, on CurseForge/Wago for streamlined updates. Watch this repository for tagged releases.

## Usage
- Open the in-game options with `/classhud` (alias `/chud`).
- Use the **Spells & Buffs** panels to add or remove abilities, reorder them, and toggle tracked buffs or utility spells.
- Enable or disable class bars, buff trackers, and utility rows through the options UI — changes apply immediately.
- Totem, demon, and Wild Imp tracking are configured out of the box with sensible defaults for supported specs.
- Profiles are managed via AceDB, so you can maintain per-spec or per-character layouts.

## Development
- **Dependencies**: Ace3, AceTimer-3.0, AceEvent-3.0, AceConfig-3.0, AceGUI-3.0, AceDB-3.0, LibSharedMedia-3.0 (embedded in `Libs/`).
- **Coding style**: Lua modules structured around AceAddon-3.0 mixins; prefer local functions and tables over globals.
- **Module layout**: Each major system lives in its own file (`ClassHUD.lua`, `ClassHUD_Spells.lua`, `ClassHUD_Bars.lua`, `ClassHUD_Classbar.lua`, `ClassHUD_Tracking.lua`, `ClassHUD_Options.lua`). See `AGENTS.md` for a deeper architecture guide and extension tips.
- **Build/test workflow**: Develop directly in the addon folder or symlink into your WoW AddOns directory for live testing. No external build tooling is required.

## Contributing
We welcome pull requests and issue reports! Before submitting changes:
- Follow the Lua style and module boundaries outlined above and in `AGENTS.md`.
- Keep features modular so they can be toggled or configured through the options UI.
- Describe reproduction steps for bugs and include screenshots or videos when relevant.

## Future Plans
- Migrate spell handling to Blizzard's spell mixin architecture for better compatibility with future patches.
- Expand dynamic buff linking so spell frames automatically pick up spec variants and proc auras.
- Continue modernizing the HUD for Dragonflight and The War Within updates, with ongoing compatibility fixes.

## License
ClassHUD is released under the [MIT License](LICENSE) so you can fork, extend, and share improvements freely.
