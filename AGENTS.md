# ClassHUD Architecture & Contributor Guide

## Overview
ClassHUD is an Ace3-based World of Warcraft addon that provides a consolidated heads-up display for class gameplay. It centralizes spell cooldowns, buff uptimes, resource tracking, and class mechanics in configurable frames anchored near the player. Core features include:

- **Spell tracking:** Builds per-spec spell frames, applies cooldowns, highlights, and suggestion logic. (See `ClassHUD_Spells.lua`.)
- **Buff tracking:** Dedicated tracked-buff icons and bars, including wild imp and summon tracking for Warlocks. (See `ClassHUD_Spells.lua` and `ClassHUD_Tracking.lua`.)
- **Summon/totem management:** Monitors summon durations, wild imp counts, and totem slots with reusable UI primitives. (See `ClassHUD_Tracking.lua`.)
- **Primary resource & class bars:** Health, mana/energy, and class-specific power bars (combo points, runes, essence, eclipse, etc.). (See `ClassHUD_Bars.lua` and `ClassHUD_Classbar.lua`.)
- **Options UI:** Snapshot-driven configuration surfaced through AceConfig with dynamic refreshes. (See `ClassHUD_Options.lua`.)
- **Utility helpers:** Shared data accessors, profile walkers, snapshot storage, and UI helpers. (See `ClassHUD_Utils.lua`.)

## Core Modules
### `ClassHUD.lua`
- **Role:** Central addon entry point that wires AceAddon lifecycle, saved variables, slash commands, and event dispatch.
- **Responsibilities:**
  - Initialize and migrate profiles via AceDB (`OnInitialize`, `EnsureActiveSpecProfile`).
  - Schedule full rebuilds (`FullUpdate`, `BuildFramesForSpec`) and snapshot updates (`UpdateCDMSnapshot`).
  - Route gameplay events to submodules (health/resource updates, aura/cooldown events, combat log).
  - Provide global helpers (`GetActiveSpellID`, `CreateStatusBar`, `OpenOptions`, etc.).
- **Key functions exposed:** `FullUpdate`, `BuildFramesForSpec`, `UpdateAllFrames`, `RequestUpdate`, `Layout`, `ApplyBarSkins`, `UpdateHP`, `UpdatePrimaryResource`, `EvaluateClassBarVisibility`, `UpdateSpecialPower`, `RegisterOptions`, `OpenOptions`, `GetActiveSpellID`, `GetSnapshotForSpec`.

### `ClassHUD_Spells.lua`
- **Role:** Builds and updates spell frames, tracked buff icons, summon display bars, and cooldown overlays.
- **Responsibilities:**
  - Maintain spell frame pools and active maps (`BuildFramesForSpec`, `UpdateAllFrames`).
  - Populate icon/buff visuals via helpers (`PopulateBuffIconFrame`, `CreateBuffFrame`).
  - Trigger ActionButton-style alerts, glow thresholds, and sound throttling.
  - Coordinate tracked buff frame layout and persistence of aura selections.
- **Key functions exposed:** `BuildFramesForSpec`, `UpdateAllFrames`, `UpdateAllSpellFrames`, `RebuildTrackedBuffFrames`, `CreateBuffFrame`, `PopulateBuffIconFrame`, `RefreshSpellFrameVisibility`, `GetSpellFrameForSpellID`.

### `ClassHUD_Tracking.lua`
- **Role:** Handles real-time summon, totem, and wild imp tracking with supporting cooldown logic.
- **Responsibilities:**
  - Register and process combat log events for summon creation/expiration (`HandleCombatLogEvent`).
  - Maintain wild imp GUID maps, schedule expiry checks, and update indicators (`ScheduleWildImpExpiryCheck`, `UpdateWildImpBuffFrame`).
  - Update totem slots, durations, and overlay effects (`UpdateTotemSlot`, `RefreshAllTotems`).
  - Share buff icon rendering by reusing `PopulateBuffIconFrame` from the spell module.
- **Key functions exposed:** `HandleCombatLogEvent`, `ResetSummonTracking`, `ResetTotemTracking`, `RefreshAllTotems`, `UpdateTotemSlot`, `UpdateWildImpBuffFrame`, `HideWildImpBuffFrame`, `IsWildImpTrackingEnabled`.

### `ClassHUD_Bars.lua`
- **Role:** Creates and updates the anchor, cast bar, health bar, and primary resource bar frames.
- **Responsibilities:**
  - Build top-level frames (`CreateAnchor`, `CreateCastBar`, `CreateHPBar`, `CreateResourceBar`).
  - Apply textures/fonts via LibSharedMedia fetchers (`FetchFont`, `FetchStatusbar`).
  - Process cast/channel events (`UNIT_SPELLCAST_*` handlers) and throttle updates.
  - Recompute status bar layout and respond to resource updates (`Layout`, `UpdateHP`, `UpdatePrimaryResource`).
- **Key functions exposed:** `CreateAnchor`, `CreateCastBar`, `CreateHPBar`, `CreateResourceBar`, `Layout`, `ApplyBarSkins`, `UpdateHP`, `UpdatePrimaryResource`, `UNIT_SPELLCAST_START/STOP`, `UNIT_SPELLCAST_CHANNEL_START/STOP`.

### `ClassHUD_Classbar.lua`
- **Role:** Manages class-specific resource widgets (combo points, runes, essences, eclipse states) attached to the HUD.
- **Responsibilities:**
  - Resolve class/spec support and settings (`PlayerHasClassBarSupport`, `IsClassBarSpecSupported`, `IsClassBarEnabledForSpec`).
  - Create and update segmented resource frames (`CreatePowerContainer`, `UpdateSpecialPower`, `UpdateRunes`, `UpdateSegmentsAdvanced`, `UpdateEssenceSegments`).
  - React to spec changes and shapeshifts (`EvaluateClassBarVisibility`, `HandleEclipseEvent`).
- **Key functions exposed:** `PlayerHasClassBarSupport`, `IsClassBarEnabledForSpec`, `CreatePowerContainer`, `UpdateSpecialPower`, `UpdateSegmentsAdvanced`, `UpdateEssenceSegments`, `UpdateRunes`, `HandleEclipseEvent`.

### `ClassHUD_Options.lua`
- **Role:** Defines the AceConfig-driven options UI, seeded from cooldown viewer snapshots and live addon state.
- **Responsibilities:**
  - Guarded refresh helpers (`SafeRefreshOptions`, `EnsureAddonOptionsRefreshWrapper`).
  - Build options tree (`ClassHUD_BuildOptions`) with layout, spell tracking, buff tracking, and summon/totem panels.
  - Normalize user input (spell IDs, placement enums) and reflect AceDB changes back into live frames.
  - Drive LibSharedMedia pickers, color selectors, and per-spec toggles.
- **Key functions exposed:** `ClassHUD_BuildOptions` (global builder), `SafeRefreshOptions`, `GetSpellInfoSafe`, `GetSpellDisplayName`.

### `ClassHUD_Utils.lua`
- **Role:** Shared utility layer for profile access, snapshot storage, aura queries, and UI helpers.
- **Responsibilities:**
  - Provide class/spec resolution and profile traversal (`GetPlayerClassSpec`, `GetProfileTable`).
  - Manage cooldown snapshot data keyed by class/spec (`GetSnapshotRoot`, `GetSnapshotForSpec`, `ResetSnapshotFor`).
  - Normalize tracked buff configuration (colors, icon/bar toggles).
  - Expose aura lookup helpers and formatting utilities consumed by spells/tracking modules.
- **Key functions exposed:** `GetPlayerClassSpec`, `GetProfileTable`, `GetSnapshotRoot`, `GetSnapshotForSpec`, `ResetSnapshotFor`, `GetSnapshotEntry`, `NormalizeTrackedConfig`, `FormatAuraDuration`, `ShouldShowCooldownNumbers`, `CreateBuffFrame` (shared creator).

## Interaction Model
### Module Collaboration
- `ClassHUD.lua` owns lifecycle and event routing. It calls into `ClassHUD_Spells.lua` to build frames (`BuildFramesForSpec`) and triggers periodic updates (`UpdateAllFrames`).
- Spell and tracking modules share UI helpers from `ClassHUD_Utils.lua`, notably `PopulateBuffIconFrame` reused by summon/totem trackers.
- `ClassHUD_Bars.lua` provides the anchor and base bars; other modules attach frames under `ClassHUD.UI` once `CreateAnchor` has run.
- `ClassHUD_Classbar.lua` attaches class resource frames to the anchor while `ClassHUD_Bars.lua` handles health/resource bars.
- Options changes propagate through `ClassHUD_Options.lua` which updates AceDB, then triggers `ClassHUD:RefreshRegisteredOptions()` and `ClassHUD:FullUpdate()` from the root module.

### Event Flow
1. **`PLAYER_ENTERING_WORLD`:** `ClassHUD.lua` seeds profiles, resets tracking, applies anchor placement, updates snapshots, rebuilds frames, refreshes options, and syncs totems.
2. **Frame Construction:** `ClassHUD_Bars.lua` builds anchor/cast/resource bars; `ClassHUD_Classbar.lua` creates class power containers if supported; `ClassHUD_Spells.lua` builds per-spec spell frames.
3. **Spell Tracking Loop:** Combat log and aura events (`COMBAT_LOG_EVENT_UNFILTERED`, `UNIT_AURA`, cooldown events) trigger `ClassHUD:RequestUpdate()` and `UpdateAllFrames`, which cascade to spell and buff updates.
4. **Resource Updates:** `UNIT_POWER_*`, rune events, and shapeshifts update primary and class bars, and may queue spell frame refreshes.
5. **Tracking Maintenance:** Summon/totem events flow through `ClassHUD_Tracking.lua`, updating shared buff frames and counters.

### Options Feedback
- User changes in the AceConfig UI write to AceDB; `ClassHUD_Options.lua` invokes `SafeRefreshOptions` to rebuild the option tree.
- Root callbacks (`OnProfileChanged`, manual refresh) call `FullUpdate`, `BuildFramesForSpec`, and `RefreshRegisteredOptions`, so layout, spell frames, and tracked buffs update live without reloads.

## Customization Hooks
- **Supported tweaks:**
  - Update tracked buffs/spells through the options UI or by editing snapshot seeds in `ClassHUD_Spells.lua` data tables.
  - Adjust layout (positions, sizes, fonts, textures) via AceDB profile settings exposed in options.
  - Extend summon/totem lists by editing `SUMMON_SPELLS`, `WILD_IMP_*` tables in `ClassHUD_Spells.lua` and `ClassHUD_Tracking.lua`.
- **Areas to avoid modifying:**
  - Core rendering and event wiring in `ClassHUD.lua`, `ClassHUD_Bars.lua`, and `ClassHUD_Classbar.lua` (these provide shared infrastructure and expect stable APIs).
  - Utility helpers in `ClassHUD_Utils.lua` that upstream modules depend on; modify with caution and ensure signatures remain stable.
  - AceConfig wrappers in `ClassHUD_Options.lua`—prefer extending the options builder rather than changing refresh plumbing.

## Future-Proofing Notes
- **`GetActiveSpellID` handling:** The root module normalizes spell IDs by consulting base and override IDs and `C_Spell.GetOverrideSpell` to stay compatible with future override mechanics.
- **Spell mixin migration:** Spell handling is being structured to support Blizzard's upcoming spell mixins; keep new functionality encapsulated so mixins can wrap spell frames without reworking the event bus.
- **Overlay API:** The addon now uses `ActionButtonSpellAlertManager` for glows instead of the deprecated overlay API; future contributions should keep compatibility with this manager and avoid legacy `ActionButton_ShowOverlayGlow` calls.
