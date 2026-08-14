# Candela — convenience wrappers around the existing build scripts.
#
# Fast dev loop (Command Line Tools only, no Xcode):
#   make dev        compile, swap the binary into /Applications/Candela.app, relaunch
#   make compile    compile the binary only (./Candela-bin), no swap — quick build check
#   make test       generate the Xcode project and run unit tests
#   make check      lint + tests + localization keys + zh-Hant sync, everything CI enforces
#                   (auto-run on every push after: git config core.hooksPath .githooks)
#
# Distributable DMG:
#   make build      signed arm64 DMG via scripts/release.sh (dry run)
#   make dmg        DMG via Xcode (scripts/build-dmg.sh; needs full Xcode + xcodegen)
#   make release ARGS="vX.Y.Z notes.md --publish"   full release (see scripts/release.sh)
#
#   make clean      remove build artifacts
#   make help       list targets (default)
#
# The dev target honours dev.sh's CANDELA_APP override, e.g.:
#   make dev CANDELA_APP=/path/to/Candela.app

# Single source of truth for the version: project.yml (used to tag the dry-run DMG).
VERSION := $(shell grep -E '^[[:space:]]*MARKETING_VERSION:' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

# Use Xcode.app's toolchain when installed, even if xcode-select still points at
# the Command Line Tools: xcodebuild (test) and SwiftLint's SourceKit need it.
ifneq (,$(wildcard /Applications/Xcode.app))
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
endif

# swiftc invocation kept in sync with dev.sh's compile step.
SWIFT_SOURCES := Candela/App/*.swift Candela/Models/*.swift Candela/Services/*.swift \
                 Candela/Views/*.swift Candela/Utilities/*.swift
SWIFTC_FLAGS := -O -target arm64-apple-macos26.0 -swift-version 5 -strict-concurrency=minimal -parse-as-library \
                -import-objc-header Candela/Candela-Bridging-Header.h \
                -framework AppKit -framework SwiftUI -framework IOKit -framework CoreAudio \
                -Xlinker -undefined -Xlinker dynamic_lookup

.DEFAULT_GOAL := help
.PHONY: help dev compile test lint loc-check hant-check check build dmg release clean

help:
	@echo "Candela — make targets:"
	@echo "  make dev        compile + swap into /Applications/Candela.app + relaunch (dev.sh)"
	@echo "  make compile    compile ./Candela-bin only, no swap (quick build check)"
	@echo "  make test       generate the Xcode project and run unit tests"
	@echo "  make check      lint + tests + localization keys, everything CI enforces"
	@echo "  make build      signed arm64 DMG, no Xcode (scripts/release.sh v$(VERSION))"
	@echo "  make dmg        DMG via Xcode (scripts/build-dmg.sh)"
	@echo "  make release ARGS=\"vX.Y.Z notes.md --publish\"   full release (scripts/release.sh)"
	@echo "  make clean      remove build artifacts (Candela-bin, build/, Candela.dmg)"

dev:
	./dev.sh

compile:
	@echo "==> Compiling Candela $(VERSION) -> ./Candela-bin"
	swiftc $(SWIFTC_FLAGS) $(SWIFT_SOURCES) -o Candela-bin
	@echo "Done. ./Candela-bin built (not swapped into the app; use 'make dev' for that)."

# Warnings are errors here (the baseline is zero, issue #47), so a PR that
# introduces one fails make check and CI. `make compile` stays permissive for
# mid-iteration builds.
test:
	xcodegen generate
	xcodebuild -quiet test -project Candela.xcodeproj -scheme Candela \
		-destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO \
		SWIFT_VERSION=5 SWIFT_STRICT_CONCURRENCY=minimal \
		SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

lint:
	@command -v swiftlint >/dev/null || { echo "SwiftLint not installed: brew install swiftlint"; exit 1; }
	swiftlint lint --strict --quiet

# Same check as CI's "Check localization keys" step: every key the code uses
# must exist in the String Catalog (missing keys silently fall back to English).
loc-check:
	xcodegen generate
	xcodebuild -quiet -exportLocalizations -project Candela.xcodeproj \
		-localizationPath build/loc CODE_SIGNING_ALLOWED=NO \
		SWIFT_EMIT_LOC_STRINGS=YES SWIFT_VERSION=5 SWIFT_STRICT_CONCURRENCY=minimal
	python3 scripts/check-localization-keys.py build/loc/en.xcloc \
		Candela/Resources/Localizable.xcstrings scripts/i18n-missing-allowlist.txt

# Traditional Chinese lives in scripts/zh-Hant.json and is merged into the String
# Catalog by scripts/add-zh-Hant.py. This fails if the two have drifted — an
# untranslated new string, or a translation for a key that no longer exists —
# so a zh-Hans string added upstream can't silently ship as English to zh-Hant.
# To fix a failure: edit scripts/zh-Hant.json, then run
#   python3 scripts/add-zh-Hant.py
hant-check:
	python3 scripts/add-zh-Hant.py --check

# Everything CI enforces (lint + build + tests + localization keys), locally.
check: lint test loc-check hant-check
	@echo "check passed: lint clean, tests green, localization keys complete"

build:
	./scripts/release.sh v$(VERSION)

dmg:
	./scripts/build-dmg.sh

release:
	./scripts/release.sh $(ARGS)

clean:
	rm -f Candela-bin Candela.dmg
	rm -rf build
	@echo "Cleaned: Candela-bin, Candela.dmg, build/"
