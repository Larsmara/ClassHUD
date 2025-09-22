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
