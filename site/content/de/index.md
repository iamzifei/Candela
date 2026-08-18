---
title: "Candela — kostenlose Display-Steuerung für macOS"
description: "Eine quelloffene macOS-Menüleisten-App für externe Monitore: HiDPI-Skalierung, DDC-Helligkeit, synchrone Helligkeit über mehrere Displays, Presets und virtuelle Bildschirme. Alles kostenlos, ohne Pro-Version."
schema: |
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"SoftwareApplication","name":"Candela",
   "operatingSystem":"macOS 26","applicationCategory":"UtilitiesApplication",
   "offers":{"@type":"Offer","price":"0","priceCurrency":"USD"},
   "url":"{{SITE}}/de/",
   "downloadUrl":"https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg",
   "screenshot":"{{SITE}}/shots/panel-root.webp",
   "softwareLicense":"https://github.com/iamzifei/Candela/blob/main/LICENSE",
   "isAccessibleForFree":true}
  </script>
---

<div class="hero">

# Jede Display-Einstellung, die macOS versteckt, in einem Menüleisten-Panel

Alles, was macOS dem eingebauten Bildschirm vorbehält, zurückgegeben an jeden Monitor auf
Ihrem Schreibtisch — echte Helligkeit über DDC, scharfe HiDPI-Skalierung und
Helligkeitstasten, die überall funktionieren.

<div class="actions">
<a class="btn btn-dl" href="https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg">Für macOS laden</a>
<a class="btn btn-kofi" href="https://ko-fi.com/james_ai/tip" rel="noopener">Auf Ko-fi unterstützen</a>
</div>

<p class="note">macOS 26 · Apple Silicon · MIT-Lizenz · keine Pro-Version, kein Lizenzschlüssel</p>
</div>

<figure class="film">
<video class="film-frame" poster="../video/poster.webp" width="1920" height="1080"
       autoplay muted loop playsinline preload="none"
       aria-label="Eine sechzig Sekunden lange stumme Aufnahme von Candela im Einsatz: das Panel öffnet sich aus der Menüleiste, Helligkeitsregler bewegen erst ein Display und dann alle zugleich, die vollständige HiDPI-Auflösungsliste, die Ziele der Helligkeitstasten, die Werkzeugseite und der Dunkelmodus für das ganze System.">
<source src="../video/hero-1080.webm" type="video/webm">
<source src="../video/hero-1080.mp4" type="video/mp4">
</video>
<figcaption>Sechzig Sekunden, ohne Ton. Jedes Bild zeigt die ausgelieferte App auf einem echten Schreibtisch.</figcaption>
</figure>

<div class="sect-label">01 · Was macOS auslässt</div>

## Drei Dinge hören auf zu funktionieren

<p class="sect-lede">Schließen Sie einen Monitor an einen Mac an, und die Helligkeitstasten regeln nichts mehr,
die Auflösungsliste bietet eine Handvoll unscharfer Optionen und verbirgt die scharfen, und
es gibt keine Möglichkeit, alle Displays zugleich zu bewegen. Candela gibt alle drei zurück,
in einem Panel, das sich wie das Kontrollzentrum verhält und nicht wie ein
Einstellungsfenster.</p>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-root.webp" alt="Candelas Panel: jedes angeschlossene Display mit eigenem Helligkeitsregler und ein kombinierter Regler für alle" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>Helligkeit, die die Hintergrundbeleuchtung erreicht</h3>

- DDC/CI über das Videokabel — derselbe Kanal, den die Tasten des Monitors benutzen
- Displays, die DDC verweigern, fallen auf Gamma-Dimmen zurück, gekennzeichnet als *Software*
- Bei Monitoren, die darauf antworten, auch die Lautstärke

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-settings.webp" alt="Candelas Einstellungen mit der Zeile für die Helligkeitstasten und ihrem aktuellen Ziel" width="1380" height="934" loading="lazy" decoding="async"></figure>
<div>
<h3>Helligkeitstasten, auf jedem Display</h3>

- Dem Zeiger folgen, jedes Display steuern oder alle als eines
- Oder nur die Displays, die Sie auswählen — ein Fernseher oder ein farbkritisches Panel
  bleibt unangetastet
- Eine Bedienungshilfen-Berechtigung, kein Neustart

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-allResolutions.webp" alt="Candelas vollständige Auflösungsliste für ein Display, die scharfen Modi markiert" width="1380" height="1708" loading="lazy" decoding="async"></figure>
<div>
<h3>Scharfes HiDPI auf jedem Monitor</h3>

- Die 2×-gerenderten Modi, die macOS bei Fremdherstellern verbirgt
- Ein 1440p- oder 4K-Panel wird lesbar *und* scharf, statt nur eines von beidem
- Die Bildwiederholrate steht auf derselben Seite, damit ein skalierter Modus Sie nicht
  klammheimlich 60 Hz kostet

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-display.webp" alt="Die eigene Seite eines Displays in Candela, mit der Untergrenze für die kombinierte Helligkeit" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>Displays, die zueinander passen</h3>

- Ein Regler für den ganzen Schreibtisch
- Dazu eine Untergrenze, die Sie pro Display nach Augenmaß einstellen — derselbe Prozentwert
  bringt zwei Panels nicht dazu, gleich viel Licht abzugeben
- Nichts wird schwarz, während der Nachbar noch leuchtet

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-tools.webp" alt="Candelas Werkzeugseite: Anordnung, virtuelle Displays und Sidecar" width="1380" height="624" loading="lazy" decoding="async"></figure>
<div>
<h3>Presets, Anordnung, virtuelle Bildschirme</h3>

- Einen ganzen Schreibtisch sichern — Auflösungen, Helligkeit, Anordnung — und mit einem
  Klick wiederherstellen
- Displays anordnen, ohne die Systemeinstellungen zu öffnen
- Einen virtuellen Bildschirm für Aufnahmen erzeugen oder ein iPad über Sidecar verbinden

</div>
</div>

<div class="sect-label">02 · Was es kostet</div>

## Nichts, und es gibt keine zweite Stufe

Es gibt keine Pro-Version, keinen Lizenzschlüssel, kein Tageslimit und keine zurückgehaltene
Funktion. Die ganze App steht unter MIT-Lizenz, der Quellcode liegt auf GitHub. Wenn sie
nützlich ist, gibt es [Ko-fi]; in der App ändert sich nichts, wenn Sie nie darauf klicken.

Das ist der wesentliche Unterschied zu den Alternativen. [BetterDisplay] verschenkt eine
leistungsfähige Gratisstufe, behält aber flexible HiDPI-Skalierung, virtuelle Bildschirme,
das Trennen von Displays und erweiterte Kurzbefehle der Pro-Version für 21,99 $ vor. [Lunar]
ist quelloffen und kostet 23 $ für eine lebenslange Lizenz, wobei die kostenlose Fassung auf
100 Helligkeitsänderungen pro Tag begrenzt ist. Beides ist gute Software. Candelas Antwort auf
„Welche Funktionen bekomme ich?" lautet schlicht: „alle".

[Den vollständigen Vergleich lesen →](../candela-vs-betterdisplay.html) (auf Englisch)

<div class="sect-label">03 · Anleitungen</div>

## Hier anfangen

Die folgenden Anleitungen gibt es derzeit auf Englisch und auf vereinfachtem Chinesisch:

- [Unscharfen externen Monitor unter macOS beheben](../fix-blurry-external-monitor-macos.html) — warum Text auf einem 1440p- oder 4K-Display weich aussieht und was ihn wirklich schärft
- [HiDPI auf einem Mac aktivieren](../enable-hidpi-mac.html) — was HiDPI ist und wie man es für ein Display einschaltet, dem macOS es nicht anbietet
- [Helligkeitstasten am externen Monitor zum Laufen bringen](../mac-brightness-keys-external-monitor.html) — F1 und F2 auf jedem Display und die Berechtigung, die das möglich macht
- [Helligkeit über mehrere Monitore synchronisieren](../sync-brightness-multiple-monitors-mac.html) — ein Regler für den ganzen Schreibtisch und wie Panels wirklich zusammenpassen

<div class="sect-label">04 · Installation</div>

## Zwei Wege

Laden Sie das DMG und ziehen Sie Candela in „Programme", oder nehmen Sie Homebrew:

```
brew install --cask iamzifei/tap/candela
```

Candela ist mit einer Developer ID signiert und von Apple notarisiert und öffnet sich daher
ohne Rechtsklick-Umweg.

<div class="sect-label">05 · Voraussetzungen</div>

## Was Sie brauchen

- macOS 26 oder neuer
- Apple Silicon
- Für die Helligkeitstasten: eine Bedienungshilfen-Berechtigung, nach der macOS beim ersten
  Aktivieren der Funktion fragt
- Für Hardware-Helligkeit an einem externen Display: DDC/CI muss im OSD-Menü des Monitors
  aktiviert sein. Die meisten Monitore werden so ausgeliefert; einige wenige und manche
  USB-C-Docks reichen den Kanal nicht durch

<div class="sect-label">06 · Auch von mir</div>

## Die beiden anderen Menüleisten-Apps

<a class="sibling" href="https://audioswitch.dev" rel="noopener">
<img src="../audioswitch.png" width="44" height="44" alt="" loading="lazy" decoding="async">
<span class="sibling-text">
<span class="sibling-name">AudioSwitch</span>
<span class="sibling-desc">Alle Audioein- und -ausgänge in einem Panel — Geräte wechseln, Lautstärke, Stummschaltung, eine Live-Mikrofonanzeige und ein harter Aus-Schalter fürs Mikrofon. Kostenlos, MIT, Apple Silicon.</span>
</span>
<svg class="sibling-go" width="18" height="18" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3.5 10.5 8 6 12.5"/></svg>
</a>

<a class="sibling" href="https://getclipstack.app" rel="noopener">
<img src="../clipstack.png" width="44" height="44" alt="" loading="lazy" decoding="async">
<span class="sibling-text">
<span class="sibling-name">ClipStack</span>
<span class="sibling-desc">Alles Kopierte bleibt erhalten und durchsuchbar, per ⇧⌘V — Text, Bilder und Dateien, häufig Gebrauchtes angeheftet. Nichts verlässt den Mac. Kostenlos, MIT, Apple Silicon.</span>
</span>
<svg class="sibling-go" width="18" height="18" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3.5 10.5 8 6 12.5"/></svg>
</a>

[Ko-fi]: https://ko-fi.com/james_ai/tip
[BetterDisplay]: https://betterdisplay.pro/
[Lunar]: https://lunar.fyi/
