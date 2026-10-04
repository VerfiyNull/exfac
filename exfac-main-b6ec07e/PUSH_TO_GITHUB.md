# Publish EXFac to GitHub (one-time)

This agent cannot create the GitHub repo (API blocked). On your PC or GitHub:

1. Create an **empty** private repo named **exfac** under VerfiyNull (no README).
2. Then either:

### From this cloud copy (after you create the empty repo)
```bash
cd /workspace/exfac
git remote add origin https://github.com/VerfiyNull/exfac.git
git push -u origin main
```

### Or unzip EXFac.zip on your PC
```bat
mkdir C:\Users\%USERNAME%\src\exfac
cd C:\Users\%USERNAME%\src\exfac
REM unzip EXFac.zip here so project.godot is in this folder
git init -b main
git add .
git commit -m "feat: EXFac Godot product"
git remote add origin https://github.com/VerfiyNull/exfac.git
git push -u origin main
```

Then always: open folder → double-click `launch.bat` (with Godot 4.3 installed).
