#!/usr/bin/env python3
"""Remove Vorbis comment tags from Ogg files (ACID Pro / Sony metadata etc.)."""
from __future__ import annotations

import sys
from pathlib import Path

from mutagen.oggvorbis import OggVorbis
from mutagen.oggopus import OggOpus

ROOT = Path(__file__).resolve().parents[1] / "assets" / "sounds"
TARGET_FOLDERS = ("01-06", "01-08", "02-03", "02-09")


def inspect(path: Path) -> dict:
    out = {"codec": "vorbis", "tags": [], "length": None, "error": None}
    try:
        f = OggVorbis(path)
        out["length"] = f.info.length
        if f.tags:
            out["tags"] = sorted(f.tags.keys())
    except Exception as e1:
        try:
            f = OggOpus(path)
            out["codec"] = "opus"
            out["length"] = f.info.length
            out["error"] = "opus-not-vorbis"
            if f.tags:
                out["tags"] = sorted(f.tags.keys())
        except Exception as e2:
            out["codec"] = "unknown"
            out["error"] = f"{e1}; {e2}"
    return out


def strip_tags(path: Path) -> tuple[bool, list[str]]:
    try:
        f = OggVorbis(path)
    except Exception:
        return False, []
    before = sorted(f.tags.keys()) if f.tags else []
    if not before:
        return False, []
    f.delete()
    f.save()
    return True, before


def main() -> int:
    cleaned = 0
    skipped = 0
    errors: list[str] = []

    for folder in TARGET_FOLDERS:
        d = ROOT / folder
        if not d.is_dir():
            errors.append(f"missing folder: {d}")
            continue
        for path in sorted(d.glob("*.ogg")):
            info = inspect(path)
            if info["error"] == "opus-not-vorbis":
                errors.append(f"{path.name}: Opus container (needs re-encode to Vorbis)")
                continue
            if info["error"]:
                errors.append(f"{path.name}: {info['error']}")
                continue
            ok, removed = strip_tags(path)
            if ok:
                cleaned += 1
                print(f"CLEANED {folder}/{path.name}: removed {removed}")
            else:
                skipped += 1

    print(f"\nDone. cleaned={cleaned} skipped_no_tags={skipped}")
    if errors:
        print("ERRORS:")
        for e in errors:
            print(" ", e)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
