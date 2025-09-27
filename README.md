# ClassHUD

ClassHUD is a lightweight Ace3-based heads-up display for World of Warcraft®. It adds a compact stack of bars near your character so you can monitor casting progress, health, and primary resources without looking away from combat.

## Features
- Integrated cast, health, and primary resource bars that resize and restack automatically.
- Live AceConfig options for width, spacing, bar heights, visibility toggles, and debug logging.
- Safe integration with Blizzard's Cooldown Manager so future spell tracking can build on normalized game data.

## Installation
1. Download the latest release archive or clone this repository.
2. Copy the `ClassHUD` folder into your `_retail_/Interface/AddOns/` directory so the final path is `_retail_/Interface/AddOns/ClassHUD`.
3. Launch or restart World of Warcraft and enable **ClassHUD** from the AddOns list on the character select screen.

## Usage
- Type `/chud` in chat to open the in-game options panel.
- Adjust width, spacing, and individual bar toggles—the HUD updates instantly.
- Enable `/chud debug on` only when you need verbose logging for troubleshooting.

## Resetting Configuration
If you want to return to the default settings:

- **In game:** run `/run ClassHUDDB2 = nil ReloadUI()` to clear the saved profile and reload the UI.
- **Out of game:** exit WoW and delete `WTF/Account/<AccountName>/SavedVariables/ClassHUD.lua`. The addon will recreate a fresh profile the next time it loads.

## Support
Bugs and feature requests are welcome through issues or pull requests on the repository.
