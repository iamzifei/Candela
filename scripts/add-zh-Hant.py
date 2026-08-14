#!/usr/bin/env python3
"""Merge scripts/zh-Hant.json into Candela/Resources/Localizable.xcstrings.

Works on the file as TEXT, inserting a zh-Hant block after each zh-Hans one and
leaving every other byte alone. That is deliberate: Xcode writes String Catalogs
with `"key" : value` (space before the colon), empty objects as a brace pair
around a blank line, its own key collation, and no trailing newline. Round-
tripping through json.dumps reformats all ~1200 lines, which turns every future
`git merge upstream/main` on this file into a conflict. Upstream edits this file
in Xcode and ships new strings regularly, so keeping the diff to pure additions
is worth more than the simpler implementation.

Idempotent: an existing zh-Hant block is replaced in place, so the JSON file
stays the one place the wording is edited.

Refuses to run on drift in either direction — a zh-Hans string with no zh-Hant
translation, or a translation for a key the catalog no longer has. Skipping
either would ship a half-translated language that still reports as complete.

Usage:  python3 scripts/add-zh-Hant.py [--check]

  --check  report what would change and exit non-zero, without writing (CI)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Candela/Resources/Localizable.xcstrings"
TRANSLATIONS = ROOT / "scripts/zh-Hant.json"
LANG = "zh-Hant"
# Reference language: any key it translates is a key that needs translating.
REFERENCE = "zh-Hans"

# A string key sits at indent 4, its "localizations" object at 6, each language at 8.
KEY_RE = re.compile(r'^    ("(?:[^"\\]|\\.)*") : \{$')
LOCALIZATIONS_RE = re.compile(r'^      "localizations" : \{$')
LANG_RE = re.compile(r'^        "([A-Za-z-]+)" : \{$')


def load_translations():
    raw = json.loads(TRANSLATIONS.read_text(encoding="utf-8"))
    # Keys starting with "_" are notes to the reader (terminology rules), not strings.
    return {k: v for k, v in raw.items() if not k.startswith("_")}


def json_string(value):
    """Encode as Xcode does: real UTF-8, only the mandatory escapes."""
    return json.dumps(value, ensure_ascii=False)


def block_for(code, value):
    """The lines of one language block, without any trailing comma."""
    return [
        f'        "{code}" : {{',
        '          "stringUnit" : {',
        '            "state" : "translated",',
        f'            "value" : {json_string(value)}',
        '          }',
        '        }',
    ]


def consume_braced(lines, start):
    """Returns the index just past the brace-balanced region beginning at `start`.

    Counts braces rather than matching on indentation so a translated value
    containing one cannot end the region early.
    """
    depth = 0
    i = start
    while i < len(lines):
        depth += lines[i].count("{") - lines[i].count("}")
        i += 1
        if depth == 0:
            break
    return i


def rebuild_localizations(body, translation):
    """Rewrites one "localizations" object's inner lines with zh-Hant applied.

    The whole object is taken apart and re-emitted rather than patched in place:
    patching has to reason about which sibling currently carries the trailing
    comma, which is the thing that broke when the script was run twice. Emitting
    every block from one list makes the comma a property of position, so running
    this on its own output is a no-op.
    """
    blocks = {}
    i = 0
    while i < len(body):
        match = LANG_RE.match(body[i])
        if not match:
            i += 1
            continue
        end = consume_braced(body, i)
        block = list(body[i:end])
        block[-1] = block[-1].rstrip(",")
        blocks[match.group(1)] = block
        i = end

    if translation is None:
        blocks.pop(LANG, None)
    else:
        blocks[LANG] = block_for(LANG, translation)

    out = []
    # Xcode orders language codes alphabetically; zh-Hans sorts before zh-Hant.
    for index, code in enumerate(sorted(blocks)):
        block = list(blocks[code])
        if index < len(blocks) - 1:
            block[-1] += ","
        out.extend(block)
    return out


def transform(lines, translations):
    """Returns (new_lines, keys_that_have_a_reference_translation, changed_count)."""
    out = []
    seen = set()
    changed = 0
    current_key = None
    i = 0
    while i < len(lines):
        line = lines[i]

        match = KEY_RE.match(line)
        if match:
            current_key = json.loads(match.group(1))

        if not LOCALIZATIONS_RE.match(line):
            out.append(line)
            i += 1
            continue

        end = consume_braced(lines, i)
        body = lines[i + 1:end - 1]
        has_reference = any(LANG_RE.match(l) and LANG_RE.match(l).group(1) == REFERENCE
                            for l in body)
        if has_reference:
            seen.add(current_key)
        # Only translate what the reference language translated; keys it skips are
        # format specifiers and symbols that are identical in every language.
        translation = translations.get(current_key) if has_reference else None

        rebuilt = rebuild_localizations(body, translation)
        if rebuilt != body:
            changed += 1
        out.append(lines[i])
        out.extend(rebuilt)
        out.append(lines[end - 1])
        i = end

    return out, seen, changed


def main():
    check_only = "--check" in sys.argv
    original = CATALOG.read_text(encoding="utf-8")
    lines = original.split("\n")
    translations = load_translations()

    new_lines, needed, changed = transform(lines, translations)

    missing = sorted(needed - translations.keys())
    orphaned = sorted(translations.keys() - needed)
    if missing:
        print(f"error: {len(missing)} string(s) translated in {REFERENCE} but not {LANG}:")
        for key in missing:
            print(f"  {key!r}")
    if orphaned:
        print(f"error: {len(orphaned)} {LANG} translation(s) for keys not in the "
              f"catalog (renamed or removed upstream?):")
        for key in orphaned:
            print(f"  {key!r}")
    if missing or orphaned:
        return 1

    updated = "\n".join(new_lines)
    # Parse before writing: a malformed insert must not reach the working tree.
    try:
        parsed = json.loads(updated)
    except json.JSONDecodeError as error:
        print(f"error: transform produced invalid JSON: {error}")
        return 1
    count = sum(1 for v in parsed["strings"].values()
                if LANG in v.get("localizations", {}))
    if count != len(translations):
        print(f"error: expected {len(translations)} {LANG} entries, catalog has {count}")
        return 1

    if check_only:
        print(f"{LANG}: {count} translations, "
              f"{'up to date' if updated == original else 'OUT OF DATE'}")
        return 0 if updated == original else 1

    if updated != original:
        CATALOG.write_text(updated, encoding="utf-8")
    print(f"{LANG}: {count} translations, {changed} block(s) written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
