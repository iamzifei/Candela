# Merging from Crisp

Candela is a fork of [Crisp](https://github.com/didriksg/Crisp), which is
actively maintained. Its display-control layer is the reason this fork exists, so
staying close to it is worth the merge cost rather than something to avoid.

```sh
git fetch upstream --no-tags
git log --oneline HEAD..upstream/main     # what's new
git merge upstream/main
```

`--no-tags` matters. Crisp tags its releases `v1.0.0` through `v1.4.1`, and a
plain `git fetch upstream` copies all of them into this repository, where they
name commits that were never a Candela release. Candela's own versions start at
`v0.1.0` and will reach `v1.0.0` eventually — at which point an inherited tag of
the same name is not just noise but a collision. The twelve that came across with
the original fork have been deleted; keep the flag so they stay gone. There is
also `git config remote.upstream.tagOpt --no-tags`, which makes it the default,
but that is per-clone and does not travel with the repository.

The conflicts below are not hypothetical — this is the result of a rehearsal,
merging synthetic upstream changes representing each category into the fork and
recording what git actually did.

## What conflicts, and what to do about it

### The `Crisp/` → `Candela/` rename

Git follows the rename for most files, so an upstream change to
`Crisp/Services/DDCService.swift` lands in `Candela/Services/DDCService.swift`
as an ordinary content conflict, only where both sides touched the same lines.

**Except for files this fork rewrote past git's similarity threshold.** Those
appear as `CONFLICT (modify/delete)`, and upstream's version is left in the tree
at the *old* path:

```
CONFLICT (modify/delete): Crisp/Services/CGHelpers.swift deleted in HEAD and
modified in upstream-sim. Version upstream-sim left in tree.
```

Resolve by hand:

```sh
# read what upstream changed
git diff HEAD...upstream/main -- Crisp/Services/CGHelpers.swift
# port it into Candela/Services/CGHelpers.swift, then
git rm Crisp/Services/CGHelpers.swift
```

Currently in that category:

| File | Why it diverged |
|---|---|
| `Services/CGHelpers.swift` | `Mutex` instead of NSLock-around-a-var, plus the `CGDisplayMode: Sendable` conformance |
| `Services/LaunchService.swift` | every `#available(macOS 13)` removed |

Check before merging — the list grows as files are rewritten:

```sh
git diff --diff-filter=A --name-only upstream/main..HEAD -- 'Candela/*'
```

Anything listed there that also exists under `Crisp/` upstream is a
modify/delete waiting to happen.

### `project.yml`

Always conflicts on the version, and on any build setting the fork changed:
deployment target 26.0, arm64-only, bundle identifier, the test target's file
list. Take ours for identity and platform, take theirs for anything genuinely
new, and never take their `MARKETING_VERSION`.

### `Makefile`, `dev.sh`, `scripts/release.sh`

Conflict on the brand strings and on the compiler flags (`-target
arm64-apple-macos26.0`). Mechanical: keep ours, fold in any new step they added.

### `Localizable.xcstrings` — merges cleanly, and must keep doing so

The rehearsal confirmed a new upstream string auto-merges with no conflict.

**This is the payoff for `scripts/add-zh-Hant.py` editing the catalog as text.**
Round-tripping it through `json.dumps` reformats all ~1200 lines — Xcode writes
`"key" : value` with a space before the colon, empty objects around a blank line,
its own key collation, and no trailing newline — and every future merge of this
file becomes one large conflict instead of a clean insert.

Do not "tidy up" that script into a normal JSON load-and-dump.

After merging new upstream strings:

```sh
python3 scripts/add-zh-Hant.py --check   # fails if any lack a zh-Hant translation
# add them to scripts/zh-Hant.json, then
python3 scripts/add-zh-Hant.py
```

### Files with no upstream counterpart

Never conflict: `Models/DDCReply.swift`, `Models/SoftwareDimming.swift`,
`Models/CombinedBrightnessLevel.swift`, `Services/SidecarService.swift`,
`Views/SidecarView.swift`, `scripts/add-zh-Hant.py`, `scripts/zh-Hant.json`,
`scripts/generate-icon.py`, `scripts/rasterize-svg.swift`, the probe scripts, and
the new test files.

## Changes worth sending back

Some of the divergence is bug fixes upstream would want, and every one accepted
upstream is one that stops conflicting here:

- **`Models/DDCReply.swift` and the refusal handling in `DDCService`.** A monitor
  answering with DDC/CI null messages is treated as DDC-capable because writes
  "succeed" at the I2C layer, so the app never falls back to software dimming and
  its brightness slider does nothing, permanently.
- **`Models/SoftwareDimming.swift`.** Software dimming scales the gamma table's
  signal, and the panel's EOTF makes luminance fall as roughly the 2.2 power, so
  a software-dimmed display races far ahead of a DDC one on the combined slider.
- **`BrightnessKeyService.armWhenTrusted`.** Accessibility granted in System
  Settings is not noticed, because launch only re-checks at 1s and 3s.

## After any merge

```sh
make check          # lint, tests, localization keys, zh-Hant sync
make build          # arm64 DMG
```

Then run the app and check the panel opens with every display listed — the merge
can compile cleanly and still break panel construction, which is AppKit and
SwiftUI code no test covers.
