# EXFac on GitHub

Repo: https://github.com/VerfiyNull/exfac (public)  
Default branch: **main**

## Latest build
- Tag / title marker: **v0.4.0**
- Prior release: https://github.com/VerfiyNull/exfac/releases/tag/v0.3.5

## Clone (correct local layout)

```bat
cd %USERPROFILE%\Documents\code-Projects\Godot
git clone https://github.com/VerfiyNull/exfac.git
cd exfac
git checkout main
git pull origin main
```

Open the folder that contains `project.godot` (this `exfac` folder) in Godot 4.3, or run `launch.bat`.

Do **not** open a nested unzip like `exfac-main\exfac-main\` — that path has no git remote.

Title bottom-right must show **v0.4.0**.

## Headless smoke

```bat
Godot_v4.3-stable_win64.exe --headless --path . -s res://scripts/smoke_headless.gd
```

Systems use explicit `preload()` so smoke works on a fresh clone without an editor `.godot` cache.
