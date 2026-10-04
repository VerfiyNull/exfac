# Publish EXFac to GitHub (one-time)

This agent cannot create the GitHub repo (API blocked). On your PC or GitHub:

1. Create an **empty** private repo named **exfac** under VerfiyNull (no README).
2. Then either:

### From this cloud copy (after you create the empty repo)
```bash
cd /workspace
git remote add origin https://github.com/VerfiyNull/exfac.git
git push -u origin main
```

### Or clone / unzip on your PC
```bat
git clone https://github.com/VerfiyNull/exfac.git
cd exfac
REM project.godot must be in this folder (repo root)
```

Then always: open this folder in Godot 4.3, or double-click `launch.bat`.
