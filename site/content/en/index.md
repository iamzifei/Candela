---
title: "Candela — free display control for macOS"
description: "A free, open-source menu bar app for external monitors on macOS: HiDPI scaling, DDC brightness, synced brightness across displays, presets and virtual displays. No Pro tier."
schema: |
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"SoftwareApplication","name":"Candela",
   "operatingSystem":"macOS 26","applicationCategory":"UtilitiesApplication",
   "offers":{"@type":"Offer","price":"0","priceCurrency":"USD"},
   "url":"{{SITE}}/",
   "downloadUrl":"https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg",
   "screenshot":"{{SITE}}/shots/panel-root.webp",
   "softwareLicense":"https://github.com/iamzifei/Candela/blob/main/LICENSE",
   "isAccessibleForFree":true}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"VideoObject",
   "name":"Candela — a sixty-second tour",
   "description":"A silent sixty-second recording of Candela on macOS: opening the panel from the menu bar, DDC brightness on one display and then all of them at once, the full HiDPI resolution list, brightness-key targets, tools, and Dark Mode.",
   "thumbnailUrl":"{{SITE}}/video/poster.jpg",
   "contentUrl":"{{SITE}}/video/hero-1080.mp4",
   "uploadDate":"2026-08-16","duration":"PT1M"}
  </script>
---

<div class="hero">

# Every display control macOS hides, in one menu bar panel

Everything macOS keeps for the built-in screen, given back to every monitor on your
desk — real brightness over DDC, sharp HiDPI scaling, and brightness keys that work
anywhere.

<div class="actions">
<a class="btn btn-dl" href="https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg">Download for macOS</a>
<a class="btn btn-kofi" href="https://ko-fi.com/iamzifei" rel="noopener">Support on Ko-fi</a>
</div>

<p class="note">macOS 26 · Apple silicon · MIT licence · no Pro tier, no licence key</p>
</div>

<figure class="film">
<video class="film-frame" poster="video/poster.webp" width="1920" height="1080"
       autoplay muted loop playsinline preload="none"
       aria-label="A sixty-second silent recording of Candela in use: the panel opening from the menu bar, brightness sliders moving one display and then every display at once, the full HiDPI resolution list, the brightness-key targets, the tools page, and Dark Mode switching the whole system.">
<source src="video/hero-1080.webm" type="video/webm">
<source src="video/hero-1080.mp4" type="video/mp4">
</video>
<figcaption>Sixty seconds, no sound. Every frame is the shipping app on a real desk.</figcaption>
</figure>

<div class="sect-label">01 · What macOS leaves out</div>

## Three things stop working

<p class="sect-lede">Plug a monitor into a Mac and the brightness keys adjust nothing, the resolution
list offers a handful of blurry options and hides the sharp ones, and there is no way
to move every display at once. Candela puts all three back, in a panel that behaves
like Control Centre rather than a preferences window.</p>

<div class="row">
<figure class="row-figure"><img src="shots/panel-root.webp" alt="Candela's panel: each connected display with its own brightness slider, and a Combined slider driving all of them" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>Brightness that reaches the backlight</h3>

- DDC/CI over the video cable — the same channel the monitor's own buttons use
- Displays that refuse DDC fall back to gamma dimming, marked *Software* so you know
- Volume too, on monitors that answer for it

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="shots/panel-settings.webp" alt="Candela's settings, showing the brightness-key row and its current target" width="1380" height="934" loading="lazy" decoding="async"></figure>
<div>
<h3>Brightness keys, on any display</h3>

- Follow the pointer, drive every display, or drive them all as one
- Or only the displays you pick, leaving a TV or a colour-critical panel alone
- One Accessibility permission, no restart

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="shots/panel-allResolutions.webp" alt="Candela's full resolution list for one display, with the sharp modes marked" width="1380" height="1708" loading="lazy" decoding="async"></figure>
<div>
<h3>Sharp HiDPI on any monitor</h3>

- The 2×-rendered modes macOS hides on third-party displays
- A 1440p or 4K panel becomes readable *and* sharp, instead of one or the other
- Refresh rate on the same page, so a scaled mode cannot quietly cost you 60 Hz

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="shots/panel-display.webp" alt="A display's own page in Candela, with the combined-brightness floor control" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>Displays that match each other</h3>

- One slider for the whole desk
- Plus a floor you calibrate by eye, per display, because the same percentage does
  not make two panels emit the same light
- Nothing goes black while its neighbour is still lit

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="shots/panel-tools.webp" alt="Candela's tools page: arrangement, virtual displays and Sidecar" width="1380" height="624" loading="lazy" decoding="async"></figure>
<div>
<h3>Presets, arrangement, virtual screens</h3>

- Save a whole desk — resolutions, brightness, arrangement — and restore it in a click
- Drag displays into position without opening System Settings
- Create a virtual screen for recording, or connect an iPad over Sidecar

</div>
</div>

<div class="sect-label">02 · What it costs</div>

## Nothing, and there is no second tier

There is no Pro tier, no licence key, no daily limit, and no feature held back. The
whole app is MIT-licensed and the source is on GitHub. If it is useful, [Ko-fi] is
there; nothing in the app changes if you never click it.

That is the main difference from the alternatives. [BetterDisplay] gives away a
capable free tier but keeps flexible HiDPI scaling, virtual screens, display
disconnect and advanced shortcuts for Pro at $21.99. [Lunar] is open source and $23
for a lifetime licence, with the free build capped at 100 brightness adjustments a
day. Both are good software. Candela's answer to "which features do I get" is simply
"all of them".

[Read the full comparison →](candela-vs-betterdisplay.html)

<div class="sect-label">03 · Guides</div>

## Start here

- [Fix a blurry external monitor on macOS](fix-blurry-external-monitor-macos.html) — why text looks soft on a 1440p or 4K display, and what actually sharpens it
- [How to enable HiDPI on a Mac](enable-hidpi-mac.html) — what HiDPI is, and how to turn it on for a display macOS will not offer it to
- [Make the brightness keys work on an external monitor](mac-brightness-keys-external-monitor.html) — F1 and F2 on any display, and the permission that makes it possible
- [Sync brightness across multiple monitors](sync-brightness-multiple-monitors-mac.html) — one slider for the whole desk, and how to make panels actually match

<div class="sect-label">04 · Installing</div>

## Two ways

Download the DMG and drag Candela to Applications, or use Homebrew:

```
brew install --cask iamzifei/tap/candela
```

Candela is signed with a Developer ID and notarised by Apple, so it opens without
right-click warnings.

<div class="sect-label">05 · Requirements</div>

## What you need

- macOS 26 or later
- Apple silicon
- For brightness keys: one Accessibility permission, which macOS asks for the first
  time you enable the feature
- For hardware brightness on an external display: DDC/CI enabled in the monitor's own
  on-screen menu. Most monitors ship with it on; a few, and some USB-C docks, do not
  pass it through

<div class="sect-label">06 · Also from me</div>

## The other menu bar app

<a class="sibling" href="https://audioswitch.dev" rel="noopener">
<img src="audioswitch.png" width="44" height="44" alt="" loading="lazy" decoding="async">
<span class="sibling-text">
<span class="sibling-name">AudioSwitch</span>
<span class="sibling-desc">Every audio input and output in one panel — switch devices, set volume, mute, watch a live microphone meter, and kill the mic outright. Free, MIT, Apple silicon.</span>
</span>
<svg class="sibling-go" width="18" height="18" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3.5 10.5 8 6 12.5"/></svg>
</a>

[Ko-fi]: https://ko-fi.com/iamzifei
[BetterDisplay]: https://betterdisplay.pro/
[Lunar]: https://lunar.fyi/
