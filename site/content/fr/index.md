---
title: "Candela — contrôle d'affichage gratuit pour macOS"
description: "Une app macOS open source pour la barre des menus, pensée pour les moniteurs externes : mise à l'échelle HiDPI, luminosité DDC, luminosité synchronisée entre les écrans, préréglages et écrans virtuels. Tout est gratuit, sans version Pro."
schema: |
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"SoftwareApplication","name":"Candela",
   "operatingSystem":"macOS 26","applicationCategory":"UtilitiesApplication",
   "offers":{"@type":"Offer","price":"0","priceCurrency":"USD"},
   "url":"{{SITE}}/fr/",
   "downloadUrl":"https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg",
   "screenshot":"{{SITE}}/shots/panel-root.webp",
   "softwareLicense":"https://github.com/iamzifei/Candela/blob/main/LICENSE",
   "isAccessibleForFree":true}
  </script>
---

<div class="hero">

# Tous les réglages d'écran que macOS cache, dans un panneau de la barre des menus

Tout ce que macOS réserve à l'écran intégré, rendu à chaque moniteur de votre bureau — la
vraie luminosité via DDC, une mise à l'échelle HiDPI nette et des touches de luminosité qui
fonctionnent partout.

<div class="actions">
<a class="btn btn-dl" href="https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg">Télécharger pour macOS</a>
<a class="btn btn-kofi" href="https://ko-fi.com/james_ai/tip" rel="noopener">Soutenir sur Ko-fi</a>
</div>

<p class="note">macOS 26 · Apple silicon · licence MIT · pas de version Pro, pas de clé de licence</p>
</div>

<figure class="film">
<video class="film-frame" poster="../video/poster.webp" width="1920" height="1080"
       autoplay muted loop playsinline preload="none"
       aria-label="Un enregistrement muet de soixante secondes de Candela en usage : le panneau qui s'ouvre depuis la barre des menus, les curseurs de luminosité qui déplacent un écran puis tous à la fois, la liste complète des résolutions HiDPI, les cibles des touches de luminosité, la page des outils et le mode sombre appliqué à tout le système.">
<source src="../video/hero-1080.webm" type="video/webm">
<source src="../video/hero-1080.mp4" type="video/mp4">
</video>
<figcaption>Soixante secondes, sans son. Chaque image montre l'app telle qu'elle est distribuée, sur un vrai bureau.</figcaption>
</figure>

<div class="sect-label">01 · Ce que macOS laisse de côté</div>

## Trois choses cessent de fonctionner

<p class="sect-lede">Branchez un moniteur sur un Mac et les touches de luminosité ne règlent plus rien, la liste des
résolutions propose une poignée d'options floues en masquant les nettes, et rien ne permet de
déplacer tous les écrans d'un coup. Candela remet les trois en place, dans un panneau qui se
comporte comme le Centre de contrôle plutôt que comme une fenêtre de réglages.</p>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-root.webp" alt="Le panneau de Candela : chaque écran connecté avec son propre curseur de luminosité, et un curseur combiné qui les pilote tous" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>Une luminosité qui atteint le rétroéclairage</h3>

- DDC/CI par le câble vidéo — le canal qu'utilisent les boutons du moniteur lui-même
- Les écrans qui refusent le DDC basculent sur un assombrissement gamma, signalé *Software*
- Le volume aussi, sur les moniteurs qui y répondent

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-settings.webp" alt="Les réglages de Candela, avec la ligne des touches de luminosité et sa cible actuelle" width="1380" height="934" loading="lazy" decoding="async"></figure>
<div>
<h3>Les touches de luminosité, sur n'importe quel écran</h3>

- Suivre le pointeur, piloter chaque écran, ou les piloter tous comme un seul
- Ou seulement les écrans que vous choisissez, en laissant tranquille un téléviseur ou une
  dalle calibrée
- Une autorisation d'accessibilité, sans redémarrage

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-allResolutions.webp" alt="La liste complète des résolutions d'un écran dans Candela, les modes nets étant signalés" width="1380" height="1708" loading="lazy" decoding="async"></figure>
<div>
<h3>Un HiDPI net sur tout moniteur</h3>

- Les modes rendus en 2× que macOS masque sur les écrans tiers
- Une dalle 1440p ou 4K devient lisible *et* nette, au lieu de l'un ou l'autre
- La fréquence de rafraîchissement est sur la même page : un mode mis à l'échelle ne peut pas
  vous coûter 60 Hz en silence

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-display.webp" alt="La page dédiée à un écran dans Candela, avec le plancher de luminosité combinée" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>Des écrans qui s'accordent</h3>

- Un seul curseur pour tout le bureau
- Plus un plancher que vous calez à l'œil, écran par écran : le même pourcentage ne fait pas
  émettre la même lumière à deux dalles
- Rien ne s'éteint pendant que son voisin est encore allumé

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-tools.webp" alt="La page des outils de Candela : disposition, écrans virtuels et Sidecar" width="1380" height="624" loading="lazy" decoding="async"></figure>
<div>
<h3>Préréglages, disposition, écrans virtuels</h3>

- Enregistrez tout un bureau — résolutions, luminosité, disposition — et restaurez-le en un clic
- Déplacez les écrans sans ouvrir les Réglages Système
- Créez un écran virtuel pour un enregistrement, ou connectez un iPad via Sidecar

</div>
</div>

<div class="sect-label">02 · Ce que ça coûte</div>

## Rien, et il n'y a pas de second palier

Pas de version Pro, pas de clé de licence, pas de limite quotidienne, aucune fonction gardée de
côté. Toute l'app est sous licence MIT et le code est sur GitHub. Si elle vous sert, [Ko-fi] est
là ; rien ne change dans l'app si vous n'y cliquez jamais.

C'est la différence principale avec les alternatives. [BetterDisplay] offre une version gratuite
très capable, mais réserve la mise à l'échelle HiDPI flexible, les écrans virtuels, la
déconnexion d'écran et les raccourcis avancés à la version Pro à 21,99 $. [Lunar] est open
source et coûte 23 $ en licence à vie, la version gratuite étant plafonnée à 100 réglages de
luminosité par jour. Ce sont deux bons logiciels. À la question « quelles fonctions ai-je ? »,
la réponse de Candela est simplement « toutes ».

[Lire le comparatif complet →](../candela-vs-betterdisplay.html) (en anglais)

<div class="sect-label">03 · Guides</div>

## Commencez ici

Ces guides existent pour l'instant en anglais et en chinois simplifié :

- [Corriger un moniteur externe flou sur macOS](../fix-blurry-external-monitor-macos.html) — pourquoi le texte paraît mou sur une dalle 1440p ou 4K, et ce qui le rend vraiment net
- [Activer le HiDPI sur un Mac](../enable-hidpi-mac.html) — ce qu'est le HiDPI et comment l'activer pour un écran auquel macOS ne le propose pas
- [Faire marcher les touches de luminosité sur un moniteur externe](../mac-brightness-keys-external-monitor.html) — F1 et F2 sur n'importe quel écran, et l'autorisation qui rend cela possible
- [Synchroniser la luminosité de plusieurs moniteurs](../sync-brightness-multiple-monitors-mac.html) — un curseur pour tout le bureau, et comment faire coïncider les dalles

<div class="sect-label">04 · Installation</div>

## Deux méthodes

Téléchargez le DMG et glissez Candela dans Applications, ou passez par Homebrew :

```
brew install --cask iamzifei/tap/candela
```

Candela est signée avec un Developer ID et notarisée par Apple : elle s'ouvre sans avertissement
ni clic droit.

<div class="sect-label">05 · Prérequis</div>

## Ce qu'il vous faut

- macOS 26 ou ultérieur
- Apple silicon
- Pour les touches de luminosité : une autorisation d'accessibilité, que macOS demande la
  première fois que vous activez la fonction
- Pour la luminosité matérielle d'un écran externe : le DDC/CI activé dans le menu du moniteur.
  La plupart des moniteurs sortent d'usine avec ; quelques-uns, et certains docks USB-C, ne le
  transmettent pas

<div class="sect-label">06 · Également de moi</div>

## Les deux autres apps de la barre des menus

<a class="sibling" href="https://audioswitch.dev" rel="noopener">
<img src="../audioswitch.png" width="44" height="44" alt="" loading="lazy" decoding="async">
<span class="sibling-text">
<span class="sibling-name">AudioSwitch</span>
<span class="sibling-desc">Toutes les entrées et sorties audio dans un seul panneau — changer d'appareil, régler le volume, couper le son, suivre le niveau du micro en direct et couper le micro pour de bon. Gratuite, MIT, Apple silicon.</span>
</span>
<svg class="sibling-go" width="18" height="18" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3.5 10.5 8 6 12.5"/></svg>
</a>

<a class="sibling" href="https://getclipstack.app" rel="noopener">
<img src="../clipstack.png" width="44" height="44" alt="" loading="lazy" decoding="async">
<span class="sibling-text">
<span class="sibling-name">ClipStack</span>
<span class="sibling-desc">Tout ce que vous avez copié reste là et se retrouve, en ⇧⌘V — textes, images et fichiers, avec vos favoris épinglés. Rien ne quitte le Mac. Gratuit, MIT, Apple silicon.</span>
</span>
<svg class="sibling-go" width="18" height="18" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3.5 10.5 8 6 12.5"/></svg>
</a>

[Ko-fi]: https://ko-fi.com/james_ai/tip
[BetterDisplay]: https://betterdisplay.pro/
[Lunar]: https://lunar.fyi/
