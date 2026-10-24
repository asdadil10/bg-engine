#!/usr/bin/env python3
"""
icon_scanner.py — Finds every installed icon theme ("pack") and resolves the
requested icon names to real files inside each one.

Usage:  icon_scanner.py name1 name2 ...
Output: {"packs": ["Tela", ...], "map": {"Tela": {"name1": "file:///..."}}}

Works with any layout (Tela: scalable/apps, kora: apps/scalable,
breeze: apps/48, Fluent-dark: 24/actions, ...) by reading size/context from
the folder path, and follows `Inherits=` so small variant themes
(Tela-dark, Tela-circle-dark, ...) fall back to their parent pack.
"""
import os
import re
import sys
import json
import configparser

HOME = os.path.expanduser("~")
EXTS = (".svg", ".png", ".svgz", ".xpm")
SKIP_THEMES = {"hicolor", "default", "locolor"}
TARGET_SIZE = 48

# Lower = preferred. App icons first, then closest alternatives.
CONTEXT_PRIORITY = {
    "apps": 0, "categories": 1, "devices": 2, "places": 3,
    "mimetypes": 4, "actions": 5, "status": 6, "panel": 7,
}


def icon_roots():
    roots = [
        os.path.join(HOME, ".local/share/icons"),
        os.path.join(HOME, ".icons"),
    ]
    xdg = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    for d in xdg.split(":"):
        if d.strip():
            roots.append(os.path.join(d.strip(), "icons"))
    roots += ["/usr/local/share/icons", "/usr/share/icons",
              "/var/lib/flatpak/exports/share/icons"]
    seen, out = set(), []
    for r in roots:
        rp = os.path.realpath(r)
        if rp not in seen and os.path.isdir(rp):
            seen.add(rp)
            out.append(rp)
    return out


def read_index(theme_dir):
    """Return (has_directories, inherits_list) from index.theme."""
    path = os.path.join(theme_dir, "index.theme")
    if not os.path.isfile(path):
        return False, []
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        cp.read(path, encoding="utf-8")
        sect = cp["Icon Theme"]
    except Exception:
        return False, []
    has_dirs = bool(sect.get("Directories", "").strip()
                    or sect.get("ScaledDirectories", "").strip())
    inherits = [x.strip() for x in sect.get("Inherits", "").split(",") if x.strip()]
    return has_dirs, inherits


def score_for(rel_dir):
    """Rank a directory for use as an app icon. Lower tuple = better."""
    parts = [p.lower() for p in rel_dir.replace("\\", "/").split("/") if p]
    if any("symbolic" in p for p in parts):
        return None
    if "cursors" in parts:
        return None
    ctx = 8
    for p in parts:
        if p in CONTEXT_PRIORITY:
            ctx = min(ctx, CONTEXT_PRIORITY[p])
    scalable = "scalable" in parts
    size = TARGET_SIZE if scalable else 0
    if not scalable:
        for p in parts:
            m = re.match(r"^(\d+)(x\d+)?(@\d+x?)?$", p)
            if m:
                size = int(m.group(1))
                break
    # scalable first, then sizes >= target (closest), then smaller ones
    return (ctx, 0 if scalable else 1, 0 if size >= TARGET_SIZE else 1,
            abs(size - TARGET_SIZE))


def index_theme(theme_dir, wanted):
    """Walk one theme and return {name: path} for the wanted names."""
    best = {}
    for dirpath, dirnames, filenames in os.walk(theme_dir):
        rel = os.path.relpath(dirpath, theme_dir)
        if rel == ".":
            continue
        sc = score_for(rel)
        if sc is None:
            dirnames[:] = []  # don't descend into symbolic/cursors
            continue
        for fn in filenames:
            base, ext = os.path.splitext(fn)
            if ext.lower() not in EXTS or base not in wanted:
                continue
            cur = best.get(base)
            if cur is None or sc < cur[0]:
                best[base] = (sc, os.path.join(dirpath, fn))
    return {k: v[1] for k, v in best.items()}


def main():
    wanted = {a for a in sys.argv[1:] if a and not a.startswith("/")}

    # theme name -> dir (earlier roots win, so ~/.local overrides /usr)
    themes = {}
    for root in icon_roots():
        try:
            entries = sorted(os.listdir(root))
        except OSError:
            continue
        for name in entries:
            d = os.path.join(root, name)
            if name in SKIP_THEMES or name in themes or not os.path.isdir(d):
                continue
            has_dirs, inherits = read_index(d)
            if not has_dirs:
                continue
            themes[name] = (d, inherits)

    indexes = {}

    def idx(name):
        if name not in indexes:
            indexes[name] = index_theme(themes[name][0], wanted) if name in themes else {}
        return indexes[name]

    def lookup(theme, icon, seen):
        if theme in seen or theme not in themes:
            return None
        seen.add(theme)
        hit = idx(theme).get(icon)
        if hit:
            return hit
        for parent in themes[theme][1]:
            hit = lookup(parent, icon, seen)
            if hit:
                return hit
        return None

    result = {}
    for theme in themes:
        found = {}
        for icon in wanted:
            p = lookup(theme, icon, set())
            if p:
                found[icon] = "file://" + p
        if found:
            result[theme] = found

    packs = sorted(result.keys(), key=lambda s: s.lower())
    print(json.dumps({"packs": packs, "map": result}, ensure_ascii=False))


if __name__ == "__main__":
    main()
