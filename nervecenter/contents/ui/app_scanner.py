#!/usr/bin/env python3
"""
app_scanner.py — Scans all .desktop files and outputs a JSON list of
{ name, icon, cmd } for use in NerveCenter's launcher shortcut picker.
"""
import os, sys, json, glob, re
try:
    import configparser
except ImportError:
    sys.exit("[]")

xdg_data = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
dirs = [d.strip() + "/applications" for d in xdg_data.split(":") if d.strip()]
dirs.append(os.path.expanduser("~/.local/share/applications"))
dirs.append("/var/lib/flatpak/exports/share/applications")
dirs.append("/var/lib/snapd/desktop/applications")

apps = []
seen = set()

for d in dirs:
    for path in glob.glob(os.path.join(d, "**", "*.desktop"), recursive=True):
        try:
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            cp.read(path, encoding="utf-8")
            if "Desktop Entry" not in cp:
                continue
            e = cp["Desktop Entry"]
            if e.get("Type", "") != "Application":
                continue
            if e.get("NoDisplay", "false").lower() == "true":
                continue
            if e.get("Hidden", "false").lower() == "true":
                continue
            name = e.get("Name", "").strip()
            icon = e.get("Icon", "").strip()
            cmd  = e.get("Exec", "").strip()
            if not name or not cmd:
                continue
            # Strip field codes (%u %U %f %F etc.)
            cmd = re.sub(r"\s*%[uUfFdDnNickvm]", "", cmd).strip()
            # Deduplicate by name
            key = name.lower()
            if key in seen:
                continue
            seen.add(key)
            apps.append({"name": name, "icon": icon, "cmd": cmd})
        except Exception:
            continue

apps.sort(key=lambda x: x["name"].lower())
print(json.dumps(apps, ensure_ascii=False))
