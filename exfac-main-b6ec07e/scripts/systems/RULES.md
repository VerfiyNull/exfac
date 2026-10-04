# EXFac systems — code rules

## Layout

| Script | Owns |
|--------|------|
| `items.gd` | Catalog, stacks, loot rolls |
| `meta.gd` | Credits, locker, loadout, requisition |
| `skills.gd` | Skill ranks and raid modifiers |
| `raid.gd` | Pure field sim (no nodes) |
| `save.gd` | Local JSON persistence |
| `ui_style.gd` | Quiet washes / button chrome |

Scenes and `GameSession` call these; they do not own UI nodes.

## Rules

1. **Intent comments** — explain *why*, not the obvious *how*.
2. **Fail loud** — return clear status strings / `false`; no silent empty catches.
3. **No scattered literals** — shared constants live on the owning system (`k*` / `const`).
4. **Hot paths** — raid step avoids allocations where practical; prefer reuse.
5. **Naming** — `snake_case` funcs, `class_name` PascalCase, ids `snake_case`.
6. **De-clone** — no Tarkov/scav/PMC/flea phrasing in UI or docs.
7. **Combat** — manual reload only; never auto-reload on empty mag.
