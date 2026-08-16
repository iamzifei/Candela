# Candela.icon

The layered app icon, in Icon Composer's document format. `icon.json` plus an
`Assets` directory of SVGs; the rounded container, the material, the specular
highlight and the shadow are the system's, which is what separates this from a
flat `.icns`.

Authored by hand rather than in Icon Composer, which is a GUI app. The format is
a package, `ictool` (inside Icon Composer.app) renders any document to a PNG, and
its error messages name every field it rejects — so the schema can be worked out
by making it complain. That is how this file was written.

The background is the `fill`, not a layer: the system needs to own it to light
the layers above it. Layers carry no rounded-corner clip for the same reason.

To see what it looks like in each appearance:

    ictool=/Applications/Xcode.app/Contents/Applications/Icon\ Composer.app/Contents/Executables/ictool
    "$ictool" Candela.icon --export-image --output-file /tmp/icon.png \
      --platform macOS --rendition ClearDark --width 512 --height 512 --scale 1

Renditions: Default, Dark, TintedLight, TintedDark, ClearLight, ClearDark.
