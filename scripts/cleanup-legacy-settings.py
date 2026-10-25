#!/usr/bin/env python3
"""Remove orphaned NerveCenter keys from the shared plasmashell.conf.

NerveCenter stores panel-local state in ``kde.org/plasmashell.conf`` through
QtCore's ``Settings`` component.  That file is shared with other plasmashell
components, so this script is deliberately conservative:

* it edits the file as text and never re-serializes it (KConfig tools rewrite
  every value and can change escaping);
* it only removes keys and groups that no current NerveCenter code path reads;
* it keeps the ``[Layout]`` style/effect mirrors, because the one-time KConfig
  migration still reads them for users upgrading from older versions.

Usage:
    python3 scripts/cleanup-legacy-settings.py [--file PATH] [--dry-run]

Run it with plasmashell stopped to avoid racing a config write.
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path

# Keys that no current code path reads.  Verified against the QML sources.
ORPHAN_KEYS = {"effectHex", "effectGraticule", "showRightAIPanel"}
# Sections that no current code path reads.
ORPHAN_GROUPS = {"Presets"}
# Only remove the orphan keys from NerveCenter's own layout section.
KEY_SECTION = "Layout"


def default_config_path() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "kde.org" / "plasmashell.conf"


def cleanup(path: Path, dry_run: bool = False) -> tuple[bool, list[str]]:
    """Remove orphaned entries. Returns (changed, removed_lines)."""
    text = path.read_text(encoding="utf-8")
    out: list[str] = []
    removed: list[str] = []
    section: str | None = None

    for line in text.splitlines(keepends=True):
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped[1:-1]

        if section in ORPHAN_GROUPS:
            removed.append(line.rstrip("\r\n"))
            continue

        if section == KEY_SECTION and "=" in line:
            key = line.split("=", 1)[0].strip()
            if key in ORPHAN_KEYS:
                removed.append(line.rstrip("\r\n"))
                continue

        out.append(line)

    new_text = "".join(out)
    changed = new_text != text
    if changed and not dry_run:
        backup = path.with_name(path.name + ".nervecenter-bak")
        if not backup.exists():
            shutil.copy2(path, backup)
        tmp = path.with_name(path.name + ".nervecenter-tmp")
        tmp.write_text(new_text, encoding="utf-8")
        os.replace(tmp, path)

    return changed, removed


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", type=Path, default=default_config_path(),
                        help="config file to clean (default: %(default)s)")
    parser.add_argument("--dry-run", action="store_true",
                        help="report what would be removed without writing")
    args = parser.parse_args(argv)

    path: Path = args.file
    if not path.exists():
        print(f"  · {path} not found; nothing to clean")
        return 0

    try:
        changed, removed = cleanup(path, dry_run=args.dry_run)
    except OSError as exc:
        print(f"  ✗ could not clean {path}: {exc}", file=sys.stderr)
        return 1

    if not changed:
        print("  ✓ no legacy NerveCenter settings found")
        return 0

    verb = "would remove" if args.dry_run else "removed"
    print(f"  ✓ {verb} {len(removed)} legacy line(s) from {path}:")
    for line in removed:
        print(f"      - {line}")
    if not args.dry_run:
        print(f"    backup: {path.with_name(path.name + '.nervecenter-bak')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
