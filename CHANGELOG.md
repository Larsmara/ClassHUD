## [v1.1.0] - 2025-09-22

### Added

- Buff icons are now dynamic: start centered and grow outwards
- Ordering of spells in Top/Bottom bars via options
- Out-of-range coloring (red via vertexColor) in combat when target is out of range

### Fixed

- Harmful DoTs now default to grey and only become colored when aura is active
- Non-DoT harmful spells no longer forced grey
- Range checks are now event-driven (SPELL_RANGE_CHECK_UPDATE, combat/target change) instead of OnUpdate polling

### Changed

- New util `IsHarmfulAuraSpell` and updated `GetAuraCandidatesForEntry` unify handling of snapshot vs manually added DoTs

## [v1.1.0] - 2025-09-22

Summary

Added a debounced update queue backed by AceTimer and selective UNIT_AURA filtering so spell and buff refreshes only fire when tracked data actually changes, reducing redundant work.

Centralized ticking for cooldown texts and tracked buff bars keeps timer overlays in sync without bespoke OnUpdate handlers on every frame.

Introduced tracked buff icons and bars that auto-discover snapshot entries, lay out into dedicated attachments, and rebuild with aura-aware updates for both icon grids and timer bars.

Folded a Balance Druid Eclipse bar into the class resource system with spec-aware toggles, reusable visuals, and event-driven activation/resets.

Rebuilt the options UI around snapshot data, adding inline editors for tracked buffs/bars and placements so users can add, order, and recolor entries directly.

Spell frame updates now reconcile GCD overlays, aura swipes, harmful DoT glow timing, resource/range checks, and cooldown text refreshes before rendering, improving responsiveness and clarity.

Class resource segments were generalized to handle partial resources, charged combo points, rune colors, and spec-specific toggles to better reflect each class’ mechanics.
Fixed

Cooldown text tickers clear GCD-only overlays and hide stale numbers once timers finish, preventing leftover countdown text after casts.

Harmful DoT glows now watch aura expiration and re-trigger highlights near their threshold instead of sticking or flickering when the debuff falls off.

## [v1.4.0] - 2025-09-25

## 🚀 New Features

- Expanded the linked-buff system to support multi-spell bindings with per-spell ordering, icon swapping, stack counts, and glow overlays directly on tracked spells.
- Added arrow controls to reorder tracked spells and adjust their placement directly from the options tree.
- Introduced per-spell target tracking with a DoT state machine, pandemic highlight, and configurable sound alerts for top bar spells.
- Added profile export/import strings and a `/classhudwipe` command to reset the entire database when needed.
- Expanded summon and totem tracking with UI toggles, wild-imp display modes, and seeded defaults for major classes.
- Integrated the Balance Druid eclipse bar into the class resource system for consistent power tracking.

## ✨ Improvements

- Reorganized spell management options into grouped placement, utility, and tracked-buff sections with dynamic rebuilds for cleaner navigation.
- Refreshed class resource color palettes for combo points, chi, runes, and other powers to improve visual clarity.
- Debounced and centralized frame updates to cut redundant refreshes across aura, cooldown, and target concerns.
- Improved cooldown and totem overlays so GCD text, implosion counters, and totem timers stay synchronized during combat.

## 🐞 Bug Fixes

- Hardened options lookups against missing spell data and prevented deleting the currently active profile by mistake.
- Resolved buff link glow and GCD text regressions so cooldown swipes, pandemic highlights, and DoT desaturation update correctly.
- Stabilized wild imp and totem tracking by pruning expired summons and honoring duration toggles.
- Ensured class bar visibility checks respect class and specialization toggles, fixing Balance Druid visibility issues.

## 🔧 Refactors / Internal

- Normalized buff link metadata tables to reuse configuration across spells and specs, reducing duplicate state handling.
- Added profile serialization/deserialization helpers and Cooldown Manager seeding hooks to streamline database migrations.
- Broke out summon and totem tracking into a dedicated module backed by shared state tables for easier maintenance.
