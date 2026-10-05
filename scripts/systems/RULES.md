# EXFac systems — code rules

## Layout

| Script | Owns |
|--------|------|
| `items.gd` | Catalog, stacks, loot rolls |
| `meta.gd` | Credits, locker, loadout, requisition |
| `skills.gd` | Skill ranks and raid modifiers |
| `raid.gd` | Pure field sim hub (no nodes) — tunables + sections bannered in-file |
| `raid_roamers.gd` | Roamer / enforcer AI states (host-bridges back into `raid.gd`) |
| `raid_assets.gd` | Kenney tile/character path map (renderer-only; not sim) |
| `save.gd` | Local JSON persistence |
| `ui_style.gd` | Quiet washes / button chrome |

Presentation: `scripts/raid_view.gd` (scene-owned Node2D) reads sim state; never mutate world from the view.

Scenes and `GameSession` call these; they do not own UI nodes.

Cross-system calls use **explicit `preload()`** at the top of the caller (same pattern as `scenes/raid.gd`). Do not rely on global `class_name` alone — headless smoke on a fresh clone has no `.godot` class cache.

`raid_roamers.gd` mirrors a few `RaidSim` tunables (`EXTRACT_ALARM_RADIUS`, etc.) so AI stays typed without host lookups — **keep those values identical**.

## Rules

1. **Intent comments** — explain *why*, not the obvious *how*.
2. **Fail loud** — return clear status strings / `false`; no silent empty catches.
3. **No scattered literals** — shared constants live on the owning system (`k*` / `const`).
4. **Hot paths** — raid step avoids allocations where practical; prefer reuse.
5. **Naming** — `snake_case` funcs, `class_name` PascalCase, ids `snake_case`.
6. **De-clone** — no Tarkov/scav/PMC/flea phrasing in UI or docs.
7. **Combat** — manual reload only; never auto-reload on empty mag.
8. **Preload deps** — systems/scenes that call another system preload it; keeps `-s` smoke green without editor import.
