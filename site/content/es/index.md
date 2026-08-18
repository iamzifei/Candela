---
title: "Candela — control de pantalla gratuito para macOS"
description: "Una app de código abierto para la barra de menús de macOS pensada para monitores externos: escalado HiDPI, brillo por DDC, brillo sincronizado entre pantallas, ajustes guardados y pantallas virtuales. Todo gratis, sin versión Pro."
schema: |
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"SoftwareApplication","name":"Candela",
   "operatingSystem":"macOS 26","applicationCategory":"UtilitiesApplication",
   "offers":{"@type":"Offer","price":"0","priceCurrency":"USD"},
   "url":"{{SITE}}/es/",
   "downloadUrl":"https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg",
   "screenshot":"{{SITE}}/shots/panel-root.webp",
   "softwareLicense":"https://github.com/iamzifei/Candela/blob/main/LICENSE",
   "isAccessibleForFree":true}
  </script>
---

<div class="hero">

# Todos los controles de pantalla que macOS esconde, en un panel de la barra de menús

Todo lo que macOS reserva para la pantalla integrada, devuelto a cada monitor de tu escritorio
— brillo real por DDC, escalado HiDPI nítido y teclas de brillo que funcionan en cualquier parte.

<div class="actions">
<a class="btn btn-dl" href="https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg">Descargar para macOS</a>
<a class="btn btn-kofi" href="https://ko-fi.com/james_ai/tip" rel="noopener">Apoyar en Ko-fi</a>
</div>

<p class="note">macOS 26 · Apple silicon · licencia MIT · sin versión Pro, sin clave de licencia</p>
</div>

<figure class="film">
<video class="film-frame" poster="../video/poster.webp" width="1920" height="1080"
       autoplay muted loop playsinline preload="none"
       aria-label="Una grabación muda de sesenta segundos de Candela en uso: el panel abriéndose desde la barra de menús, los deslizadores de brillo moviendo una pantalla y luego todas a la vez, la lista completa de resoluciones HiDPI, los destinos de las teclas de brillo, la página de herramientas y el modo oscuro aplicado a todo el sistema.">
<source src="../video/hero-1080.webm" type="video/webm">
<source src="../video/hero-1080.mp4" type="video/mp4">
</video>
<figcaption>Sesenta segundos, sin sonido. Cada fotograma es la app que se distribuye, en un escritorio real.</figcaption>
</figure>

<div class="sect-label">01 · Lo que macOS deja fuera</div>

## Tres cosas dejan de funcionar

<p class="sect-lede">Conecta un monitor a un Mac y las teclas de brillo no ajustan nada, la lista de resoluciones
ofrece un puñado de opciones borrosas y oculta las nítidas, y no hay forma de mover todas las
pantallas a la vez. Candela devuelve las tres, en un panel que se comporta como el Centro de
Control y no como una ventana de ajustes.</p>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-root.webp" alt="El panel de Candela: cada pantalla conectada con su propio deslizador de brillo y un deslizador combinado que las mueve todas" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>Brillo que llega a la retroiluminación</h3>

- DDC/CI por el cable de vídeo — el mismo canal que usan los botones del propio monitor
- Las pantallas que rechazan DDC pasan a atenuación por gamma, marcada como *Software*
- También el volumen, en los monitores que responden

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-settings.webp" alt="Los ajustes de Candela, con la fila de las teclas de brillo y su destino actual" width="1380" height="934" loading="lazy" decoding="async"></figure>
<div>
<h3>Teclas de brillo en cualquier pantalla</h3>

- Que sigan al puntero, que muevan cada pantalla o que las muevan todas como una
- O solo las pantallas que elijas, dejando en paz un televisor o un panel calibrado
- Un permiso de accesibilidad, sin reiniciar

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-allResolutions.webp" alt="La lista completa de resoluciones de una pantalla en Candela, con los modos nítidos marcados" width="1380" height="1708" loading="lazy" decoding="async"></figure>
<div>
<h3>HiDPI nítido en cualquier monitor</h3>

- Los modos renderizados a 2× que macOS oculta en pantallas de terceros
- Un panel de 1440p o 4K se vuelve legible *y* nítido, en vez de una cosa o la otra
- La frecuencia de refresco está en la misma página, así un modo escalado no puede costarte
  60 Hz sin que te enteres

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-display.webp" alt="La página propia de una pantalla en Candela, con el mínimo del brillo combinado" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>Pantallas que se igualan entre sí</h3>

- Un deslizador para todo el escritorio
- Más un mínimo que calibras a ojo, pantalla por pantalla, porque el mismo porcentaje no hace
  que dos paneles emitan la misma luz
- Nada se apaga del todo mientras su vecina sigue encendida

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-tools.webp" alt="La página de herramientas de Candela: disposición, pantallas virtuales y Sidecar" width="1380" height="624" loading="lazy" decoding="async"></figure>
<div>
<h3>Ajustes guardados, disposición, pantallas virtuales</h3>

- Guarda un escritorio entero —resoluciones, brillo, disposición— y restáuralo con un clic
- Coloca las pantallas arrastrándolas sin abrir Ajustes del Sistema
- Crea una pantalla virtual para grabar, o conecta un iPad por Sidecar

</div>
</div>

<div class="sect-label">02 · Cuánto cuesta</div>

## Nada, y no hay una segunda edición

No hay versión Pro, ni clave de licencia, ni límite diario, ni funciones reservadas. La app
entera está bajo licencia MIT y el código está en GitHub. Si te resulta útil, ahí está [Ko-fi];
en la app no cambia nada si nunca lo pulsas.

Esa es la diferencia principal con las alternativas. [BetterDisplay] regala una versión gratuita
muy capaz, pero deja el escalado HiDPI flexible, las pantallas virtuales, la desconexión de
pantallas y los atajos avanzados para la Pro de 21,99 $. [Lunar] es de código abierto y cuesta
23 $ en licencia de por vida, con la versión gratuita limitada a 100 ajustes de brillo al día.
Ambos son buen software. La respuesta de Candela a «¿qué funciones me llevo?» es simplemente
«todas».

[Leer la comparativa completa →](../candela-vs-betterdisplay.html) (en inglés)

<div class="sect-label">03 · Guías</div>

## Empieza aquí

Estas guías están por ahora en inglés y en chino simplificado:

- [Arreglar un monitor externo borroso en macOS](../fix-blurry-external-monitor-macos.html) — por qué el texto se ve blando en un panel de 1440p o 4K, y qué lo afila de verdad
- [Cómo activar HiDPI en un Mac](../enable-hidpi-mac.html) — qué es HiDPI y cómo activarlo en una pantalla a la que macOS no se lo ofrece
- [Hacer que las teclas de brillo funcionen en un monitor externo](../mac-brightness-keys-external-monitor.html) — F1 y F2 en cualquier pantalla, y el permiso que lo hace posible
- [Sincronizar el brillo de varios monitores](../sync-brightness-multiple-monitors-mac.html) — un deslizador para todo el escritorio, y cómo lograr que los paneles coincidan

<div class="sect-label">04 · Instalación</div>

## Dos formas

Descarga el DMG y arrastra Candela a Aplicaciones, o usa Homebrew:

```
brew install --cask iamzifei/tap/candela
```

Candela está firmada con un Developer ID y notarizada por Apple, así que se abre sin avisos ni
clic derecho.

<div class="sect-label">05 · Requisitos</div>

## Qué necesitas

- macOS 26 o posterior
- Apple silicon
- Para las teclas de brillo: un permiso de accesibilidad, que macOS pide la primera vez que
  activas la función
- Para el brillo por hardware en una pantalla externa: DDC/CI activado en el menú en pantalla
  del propio monitor. La mayoría vienen con él activado; unos pocos, y algunos docks USB-C, no
  lo dejan pasar

<div class="sect-label">06 · También mío</div>

## La otra app de la barra de menús

<a class="sibling" href="https://audioswitch.dev" rel="noopener">
<img src="../audioswitch.png" width="44" height="44" alt="" loading="lazy" decoding="async">
<span class="sibling-text">
<span class="sibling-name">AudioSwitch</span>
<span class="sibling-desc">Todas las entradas y salidas de audio en un panel — cambiar de dispositivo, volumen, silencio, un medidor de nivel del micrófono en vivo y un interruptor para apagar el micrófono del todo. Gratis, MIT, Apple silicon.</span>
</span>
<svg class="sibling-go" width="18" height="18" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3.5 10.5 8 6 12.5"/></svg>
</a>

[Ko-fi]: https://ko-fi.com/james_ai/tip
[BetterDisplay]: https://betterdisplay.pro/
[Lunar]: https://lunar.fyi/
