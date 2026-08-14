# Homebrew cask for Candela.
#
# This is the seed copy. The tap's own Casks/candela.rb is the live one, and
# scripts/release.sh rewrites its `version` and `sha256` on every release — so once
# the tap exists, edit it there, not here. This file is what the first release
# uploads when the tap has no cask yet.
#
# Keep the two in sync when anything other than version/sha256 changes.
cask "candela" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/OWNER/REPO/releases/download/v#{version}/Candela.dmg"
  name "Candela"
  desc "Menu bar control for display brightness, resolution, and arrangement"
  homepage "https://github.com/OWNER/REPO"

  # Candela is macOS 26 only: it is built against the macOS 26 SDK and uses
  # NSGlassEffectView and other APIs that do not exist earlier. `tahoe` is
  # Homebrew's symbol for 26 (Library/Homebrew/macos_version.rb). The bare symbol
  # means "26 or newer", not "exactly 26" — checked by loading this cask in a real
  # tap, where `brew info` resolves it to "macOS >= 26". The `">= :tahoe"` string
  # form resolves the same way but is deprecated.
  depends_on macos: :tahoe
  # Apple silicon only. DDC brightness runs through IOAVService, which is the
  # Apple-silicon path; there is no Intel build to install.
  depends_on arch: :arm64

  app "Candela.app"

  zap trash: [
    "~/Library/Application Support/Candela",
    "~/Library/Preferences/com.candela.app.plist",
  ]
end
