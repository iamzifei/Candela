#!/usr/bin/env python3
"""Fail if any translatable string lacks a 'translated' unit in a used language.

Run in the release (--publish) path, NOT on PRs: adding an English string is a
fine PR, but shipping a build where zh-Hans silently falls back to English is not.
Mark genuinely English-only strings with "shouldTranslate": false to exclude them.

Usage: check-translations.py [Localizable.xcstrings]
"""
import json
import sys


def main(path: str) -> int:
    data = json.load(open(path, encoding="utf-8"))
    source = data.get("sourceLanguage", "en")
    strings = data.get("strings", {})

    # Languages the catalog actually uses (declared by at least one string).
    langs = set()
    for entry in strings.values():
        langs.update(entry.get("localizations", {}).keys())
    langs.discard(source)

    missing = []  # (key, lang, state)
    for key, entry in strings.items():
        if not key or entry.get("shouldTranslate") is False:
            continue
        for lang in sorted(langs):
            unit = entry.get("localizations", {}).get(lang, {}).get("stringUnit")
            state = unit.get("state") if unit else None
            if state != "translated":
                missing.append((key, lang, state or "missing"))

    if missing:
        print(f"{len(missing)} untranslated string(s):", file=sys.stderr)
        for key, lang, state in missing:
            shown = key if len(key) <= 60 else key[:57] + "..."
            print(f"  [{lang}] ({state}) {shown!r}", file=sys.stderr)
        return 1

    print(f"All strings translated for: {', '.join(sorted(langs)) or '(none)'}")
    return 0


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "Candela/Resources/Localizable.xcstrings"
    sys.exit(main(path))
