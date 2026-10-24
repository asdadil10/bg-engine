#!/usr/bin/env python3
"""
NerveCenter Icon Resolver
Discovers installed system/user icon packs and resolves icon names
to exact SVG/PNG file paths for independent wallpaper theme selection.
"""
import sys
import os
import json
import hashlib

CACHE_DIR = os.path.expanduser("~/.cache/nervecenter")
THEME_SEARCH_PATHS = [
    os.path.expanduser("~/.local/share/icons"),
    "/usr/share/icons"
]

def ensure_cache_dir():
    os.makedirs(CACHE_DIR, exist_ok=True)

def get_installed_themes():
    themes = ["System Default"]
    seen = {"hicolor", "default", "locolor", "breeze_cursors"}
    
    for base in THEME_SEARCH_PATHS:
        if not os.path.exists(base):
            continue
        try:
            entries = sorted(os.listdir(base))
        except OSError:
            continue
        for d in entries:
            if d in seen or d.endswith(".png") or d.endswith(".svg"):
                continue
            tdir = os.path.join(base, d)
            idx = os.path.join(tdir, "index.theme")
            if os.path.isfile(idx):
                # Verify it has app or scalable icons
                try:
                    sub = os.listdir(tdir)
                    if any(x in sub for x in ['apps', 'scalable', '48x48', '32x32', '24x24', '16x16', 'categories', 'actions']):
                        seen.add(d)
                        themes.append(d)
                except OSError:
                    continue
    return themes

def find_theme_dir(theme_name):
    if theme_name == "System Default":
        return None
    for base in THEME_SEARCH_PATHS:
        candidate = os.path.join(base, theme_name)
        if os.path.isdir(candidate):
            return candidate
    return None

def resolve_icons(theme_name, icon_names):
    if not theme_name or theme_name == "System Default":
        return {name: name for name in icon_names}
    
    theme_dir = find_theme_dir(theme_name)
    if not theme_dir:
        return {name: name for name in icon_names}

    ensure_cache_dir()
    cache_key = hashlib.md5((theme_name + ":" + ",".join(sorted(icon_names))).encode("utf-8")).hexdigest()
    cache_file = os.path.join(CACHE_DIR, f"icons_{cache_key}.json")
    if os.path.exists(cache_file):
        try:
            with open(cache_file, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass

    resolved = {}
    target_names = set(icon_names)
    
    for root, dirs, files in os.walk(theme_dir):
        for f in files:
            base, ext = os.path.splitext(f)
            if ext in ('.svg', '.png') and base in target_names:
                score = 0
                if 'scalable' in root: score += 10
                if 'apps' in root: score += 8
                if '48' in root or '48x48' in root: score += 6
                if '64' in root or '64x64' in root: score += 5
                if '32' in root or '32x32' in root: score += 4
                if ext == '.svg': score += 20
                
                if base not in resolved or score > resolved[base][0]:
                    resolved[base] = (score, "file://" + os.path.join(root, f))
    
    result = {}
    for name in icon_names:
        if name in resolved:
            result[name] = resolved[name][1]
        else:
            result[name] = name  # Fallback to system name
            
    try:
        with open(cache_file, "w", encoding="utf-8") as f:
            json.dump(result, f)
    except Exception:
        pass
        
    return result

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Missing command argument"}))
        return
        
    cmd = sys.argv[1]
    if cmd == "list":
        themes = get_installed_themes()
        print(json.dumps(themes))
    elif cmd == "resolve":
        if len(sys.argv) < 3:
            print(json.dumps({}))
            return
        theme_name = sys.argv[2]
        icons = sys.argv[3:]
        result = resolve_icons(theme_name, icons)
        print(json.dumps(result))
    else:
        print(json.dumps({"error": "Unknown command"}))

if __name__ == "__main__":
    main()
