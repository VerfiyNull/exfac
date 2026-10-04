# EXFac

Solo extraction shooter. **Standalone** — not UltraSim.

| Field | Value |
|-------|--------|
| Engine | **Godot 4.3** |
| Window | 1280×720 |
| Field map | **4800×3200** (camera follows you) |

## Run on your PC

1. `git pull origin main` — then open the **repo root** (the folder that contains `project.godot`, not an old unzip nested folder).
2. In Godot: **Project → Reload Current Project** (or close + reopen) so scripts aren't stale.
3. **F5** → title → **Continue / Begin** → **Base** → deploy.
4. Punch check: HUD should read `FISTS  <stamina>` (a number, not a lone `·` under FISTS), and the field tip should say `Punch build: click · stamina · no shove`.

## Loop

- **Title** → **Base** (locker / kit / skills) → **Field** → back
- Local **save** between sessions (Continue / New run on title)
- Territory **claims are offline** for now
- Die → lose equipped gear; locker safe
- Get out → loot + influence + **skill point** bank to base
- Enemies / crates only draw if inside your vision and line-of-sight

## Controls

### Title
Enter / Continue · New run asks once when a save exists · Esc cancels confirm

### Base
Esc menu · W/S locker · E equip · X sell · F auto-kit · 1/2/3 filter · Tab focus · Enter deploy (guns optional)

### Field
WASD · Mouse aim · LMB shoot/punch · RMB brace · Ctrl crouch · **R reload (manual)** · E loot · Q med · F equip · G decoy · T intel · V flare · stand in OUT · Esc pause

## Headless

```bash
godot --headless --path . -s res://scripts/smoke_headless.gd
```

## Code

Systems live under `scripts/systems/` — see `scripts/systems/RULES.md`.

## Publish

See `PUSH_TO_GITHUB.md` once for creating `VerfiyNull/exfac` and pushing `main`.
