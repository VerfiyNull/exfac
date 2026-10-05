# EXFac

Solo extraction shooter. **Standalone** — not UltraSim.

| Field | Value |
|-------|--------|
| Engine | **Godot 4.3** |
| Window | 1280×720 |
| Field map | **4800×3200** (camera follows you) |

## Run on your PC

Latest on GitHub `main`: **v0.3.3** (https://github.com/VerfiyNull/exfac).

```bat
git clone https://github.com/VerfiyNull/exfac.git
cd exfac
```

1. Open the **repo root** (the folder that contains `project.godot` — not a nested unzip like `exfac-main\exfac-main`).
2. In Godot: **Project → Reload Current Project** (or close + reopen) so scripts aren't stale. Or use `launch.bat`.
3. **F5** → title screen bottom-right should show **`v0.3.3`**. If that string is missing, you are not on this build.
4. Punch check: HUD should read **`FISTS`** (not mag/reserve / AMMO), click-only swing, stamina cost, no shove.

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
