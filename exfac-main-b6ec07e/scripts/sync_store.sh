#!/usr/bin/env bash
# Sync canonical /workspace/exfac → store EXFac/ (byte copy; skips .git).
set -euo pipefail
WS="${1:-/workspace/exfac}"
ST="${2:-/cursor/stores/self/EXFac}"
python3 - "$WS" "$ST" <<'PY'
import os, sys, shutil
ws, st = sys.argv[1], sys.argv[2]
assert os.path.isdir(ws), ws
os.makedirs(st, exist_ok=True)
for rel in ("scripts", "scenes", "autoload"):
    dst = os.path.join(st, rel)
    if os.path.isdir(dst):
        shutil.rmtree(dst)
for root, dirs, files in os.walk(ws):
    dirs[:] = [d for d in dirs if d not in (".git",)]
    rel = os.path.relpath(root, ws)
    if rel.startswith(".godot") and rel != ".godot":
        pass
    dest = os.path.join(st, rel) if rel != "." else st
    os.makedirs(dest, exist_ok=True)
    for f in files:
        if f.endswith(".import"):
            continue
        if rel.startswith(".godot") and f != "global_script_class_cache.cfg":
            continue
        open(os.path.join(dest, f), "wb").write(open(os.path.join(root, f), "rb").read())
for stray in ("hideout.gd", "hideout.tscn", "scripts/raid_sim.gd", "scripts/sim"):
    p = os.path.join(st, stray)
    if os.path.isdir(p):
        shutil.rmtree(p)
    elif os.path.exists(p):
        os.remove(p)
print("SYNC_OK", ws, "->", st)
PY
