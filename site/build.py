#!/usr/bin/env python3
"""Build the Candela website from Markdown into docs/, which GitHub Pages serves.

Why a generator rather than hand-written HTML: every page needs the same eleven
head tags to be right, and the ones that matter most for search are the ones
nobody notices when they drift — canonical, hreflang, og:url. Ten pages in two
languages is eighty chances to leave a stale URL in a <link>. Here each of those
is computed from the page's slug and language, so a page cannot disagree with
itself about where it lives.

Usage:  python3 site/build.py [--check]
        --check builds into a temporary directory and diffs, so CI can fail on a
        docs/ that was edited by hand instead of through the source.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

import mistune
import yaml

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "site" / "content"
OUT = ROOT / "docs"

# Candela's own domain, registered 2026-08-17. It replaces the previous address,
# https://zifei.info/Candela — a path under the account's personal Pages site.
# Setting the same name in the repository's Pages settings makes GitHub 301-redirect
# every old address to the matching new one, which is what carries the pages that
# were already indexed across rather than starting them again from zero.
SITE = "https://getcandela.app"

# Moving to Candela's own domain is this one line, plus setting the same name in the
# repository's Pages settings. Everything else follows: canonical, hreflang, og:url,
# JSON-LD, the sitemap and robots.txt are all computed from SITE, and the CNAME file
# below is written whenever SITE is an apex domain rather than a path under someone
# else's site. GitHub then 301-redirects the old zifei.info/Candela/* addresses to
# the new domain by itself, which is what carries the existing search results across.
CUSTOM_DOMAIN = re.match(r"https://([^/]+)$", SITE)
REPO = "https://github.com/iamzifei/Candela"
DOWNLOAD = f"{REPO}/releases/latest/download/Candela.dmg"
KOFI = "https://ko-fi.com/iamzifei"
UPSTREAM = "https://github.com/didriksg/Crisp"
# The other menu bar app. Someone who liked one is the likeliest person to want the
# other, so each site carries a link to its sibling.
SIBLING = "https://audioswitch.dev"

# Language codes are BCP 47 because that is what hreflang takes; the directory for
# the default language is the site root, so its URLs have no prefix at all.
LANGS = {
    "en": {"hreflang": "en", "dir": "", "label": "English", "locale": "en_US"},
    "zh": {"hreflang": "zh-Hans", "dir": "zh/", "label": "简体中文", "locale": "zh_CN"},
    "zh-Hant": {"hreflang": "zh-Hant", "dir": "zh-Hant/", "label": "繁體中文", "locale": "zh_TW"},
    "ja": {"hreflang": "ja", "dir": "ja/", "label": "日本語", "locale": "ja_JP"},
    "ko": {"hreflang": "ko", "dir": "ko/", "label": "한국어", "locale": "ko_KR"},
    "de": {"hreflang": "de", "dir": "de/", "label": "Deutsch", "locale": "de_DE"},
    "fr": {"hreflang": "fr", "dir": "fr/", "label": "Français", "locale": "fr_FR"},
    "es": {"hreflang": "es", "dir": "es/", "label": "Español", "locale": "es_ES"},
}
DEFAULT_LANG = "en"

# The long guides stay in English and Simplified Chinese. Everywhere else the
# language has a home page and nothing more, so a link to a guide has to fall
# back rather than 404 — see `link_to`.
FULL_LANGS = ("en", "zh")

UI = {
    "en": {
        "download": "Download for macOS",
        "kofi": "Support on Ko-fi",
        "nav_compare": "Compare",
        "nav_guides": "Guides",
        "nav_github": "GitHub",
        "nav_sibling": "AudioSwitch",
        "free": "Free and open source",
        "requires": "Requires macOS 26 · Apple silicon",
        "footer_built": "Candela is free software under the MIT licence.",
        "footer_fork": "Forked from Crisp, which is also MIT.",
        "toc": "On this page",
        "updated": "Updated",
    },
    "zh": {
        "download": "下载 macOS 版",
        "kofi": "在 Ko-fi 支持",
        "nav_compare": "对比",
        "nav_guides": "指南",
        "nav_github": "GitHub",
        "nav_sibling": "AudioSwitch",
        "free": "免费且开源",
        "requires": "需要 macOS 26 · Apple 芯片",
        "footer_built": "Candela 是 MIT 许可下的自由软件。",
        "footer_fork": "Fork 自同为 MIT 许可的 Crisp。",
        "toc": "本页内容",
        "updated": "更新于",
    },
    "zh-Hant": {
        "download": "下載 macOS 版",
        "kofi": "在 Ko-fi 支持",
        "nav_compare": "比較",
        "nav_guides": "指南",
        "nav_github": "GitHub",
        "nav_sibling": "AudioSwitch",
        "free": "免費且開源",
        "requires": "需要 macOS 26 · Apple 晶片",
        "footer_built": "Candela 是 MIT 授權下的自由軟體。",
        "footer_fork": "Fork 自同為 MIT 授權的 Crisp。",
        "toc": "本頁內容",
        "updated": "更新於",
    },
    "ja": {
        "download": "macOS 版をダウンロード",
        "kofi": "Ko-fi で支援",
        "nav_compare": "比較",
        "nav_guides": "ガイド",
        "nav_github": "GitHub",
        "nav_sibling": "AudioSwitch",
        "free": "無料・オープンソース",
        "requires": "macOS 26 · Apple シリコンが必要",
        "footer_built": "Candela は MIT ライセンスの自由ソフトウェアです。",
        "footer_fork": "同じく MIT の Crisp からの派生です。",
        "toc": "このページの内容",
        "updated": "更新日",
    },
    "ko": {
        "download": "macOS용 다운로드",
        "kofi": "Ko-fi에서 후원",
        "nav_compare": "비교",
        "nav_guides": "가이드",
        "nav_github": "GitHub",
        "nav_sibling": "AudioSwitch",
        "free": "무료 오픈 소스",
        "requires": "macOS 26 · Apple 실리콘 필요",
        "footer_built": "Candela는 MIT 라이선스의 자유 소프트웨어입니다.",
        "footer_fork": "같은 MIT 라이선스의 Crisp에서 갈라져 나왔습니다.",
        "toc": "이 페이지의 내용",
        "updated": "업데이트",
    },
    "de": {
        "download": "Für macOS laden",
        "kofi": "Auf Ko-fi unterstützen",
        "nav_compare": "Vergleich",
        "nav_guides": "Anleitungen",
        "nav_github": "GitHub",
        "nav_sibling": "AudioSwitch",
        "free": "Kostenlos und quelloffen",
        "requires": "Erfordert macOS 26 · Apple Silicon",
        "footer_built": "Candela ist freie Software unter der MIT-Lizenz.",
        "footer_fork": "Abgeleitet von Crisp, das ebenfalls MIT-lizenziert ist.",
        "toc": "Auf dieser Seite",
        "updated": "Aktualisiert",
    },
    "fr": {
        "download": "Télécharger pour macOS",
        "kofi": "Soutenir sur Ko-fi",
        "nav_compare": "Comparatif",
        "nav_guides": "Guides",
        "nav_github": "GitHub",
        "nav_sibling": "AudioSwitch",
        "free": "Gratuit et open source",
        "requires": "Nécessite macOS 26 · Apple silicon",
        "footer_built": "Candela est un logiciel libre sous licence MIT.",
        "footer_fork": "Dérivé de Crisp, également sous MIT.",
        "toc": "Sur cette page",
        "updated": "Mis à jour",
    },
    "es": {
        "download": "Descargar para macOS",
        "kofi": "Apoyar en Ko-fi",
        "nav_compare": "Comparativa",
        "nav_guides": "Guías",
        "nav_github": "GitHub",
        "nav_sibling": "AudioSwitch",
        "free": "Gratis y de código abierto",
        "requires": "Requiere macOS 26 · Apple silicon",
        "footer_built": "Candela es software libre bajo licencia MIT.",
        "footer_fork": "Derivado de Crisp, también con licencia MIT.",
        "toc": "En esta página",
        "updated": "Actualizado",
    },
}


@dataclass
class Page:
    lang: str
    slug: str          # "index" or an article slug, without .html
    meta: dict
    body_md: str

    @property
    def path(self) -> str:
        """URL path relative to the site root."""
        prefix = LANGS[self.lang]["dir"]
        return prefix if self.slug == "index" else f"{prefix}{self.slug}.html"

    @property
    def url(self) -> str:
        return f"{SITE}/{self.path}"

    @property
    def out_file(self) -> Path:
        prefix = LANGS[self.lang]["dir"]
        name = "index.html" if self.slug == "index" else f"{self.slug}.html"
        return OUT / prefix / name

    @property
    def depth(self) -> int:
        """How many directories deep, so relative asset links resolve."""
        return 1 if LANGS[self.lang]["dir"] else 0


class Renderer(mistune.HTMLRenderer):
    """Adds the three things the stock renderer does not do for this site."""

    def __init__(self, depth: int = 0, **kw):
        super().__init__(**kw)
        # Pages in a language subdirectory reach shared assets one level up. Doing
        # this here means the Markdown says `shots/panel-root.webp` in every
        # language, instead of each translator having to remember a `../`.
        self.depth = depth
        self.image_count = 0

    def heading(self, text: str, level: int, **attrs) -> str:
        # Slugged ids so headings can be linked to, and so the table of contents
        # has something to point at.
        slug = re.sub(r"[^a-z0-9一-鿿]+", "-", text.lower()).strip("-")
        return f'<h{level} id="{slug}">{text}</h{level}>\n'

    def image(self, text: str, url: str, title=None) -> str:
        # Every screenshot is a figure with its alt text as the caption. Search
        # engines read the caption, and a reader who cannot see the image gets the
        # same sentence either way.
        self.image_count += 1
        dims = IMAGE_SIZES.get(url.rsplit("/", 1)[-1])
        if self.depth and not url.startswith(("http://", "https://", "/", "../")):
            url = "../" * self.depth + url
        alt = html.escape(text or "")
        cap = f'<figcaption>{alt}</figcaption>' if alt else ""
        # Intrinsic size on every image, so the box is reserved before the picture
        # arrives and the text below it does not jump.
        size = f' width="{dims[0]}" height="{dims[1]}"' if dims else ""
        # The first image on a page is usually the one above the fold, and marking
        # the largest paint on the page as lazy is how it ends up arriving late and
        # leaving a hole where the picture should be.
        loading = ('loading="eager" fetchpriority="high"' if self.image_count == 1
                   else 'loading="lazy"')
        return (f'<figure class="shot"><img src="{url}" alt="{alt}"{size} '
                f'{loading} decoding="async">{cap}</figure>')

    def paragraph(self, text: str) -> str:
        # A figure is block-level, but an image alone on a line is still an inline in
        # Markdown, so mistune wrapped every screenshot in a <p>. That is invalid —
        # the browser closes the paragraph before the figure and opens another after
        # it — and it silently breaks any sibling selector aimed at the figure, which
        # is how a rule sizing the picture under the hero turned out to match nothing.
        stripped = text.strip()
        if stripped.startswith("<figure") and stripped.endswith("</figure>"):
            return stripped + "\n"
        return f"<p>{text}</p>\n"

    def block_code(self, code: str, info=None) -> str:
        return f'<pre><code>{html.escape(code)}</code></pre>\n'


def make_markdown(depth: int):
    return mistune.create_markdown(
        renderer=Renderer(depth=depth, escape=False),
        plugins=["table", "strikethrough"],
    )


def read_image_sizes() -> dict[str, tuple[int, int]]:
    """Intrinsic sizes of the screenshots, written by scripts/capture-screenshots.sh.

    Read from a manifest rather than measured here, so building the site needs no
    image tooling — CI checks the site without ImageMagick installed.
    """
    manifest = OUT / "shots" / "manifest.txt"
    if not manifest.exists():
        return {}
    sizes = {}
    for line in manifest.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) >= 3:
            sizes[parts[0]] = (int(parts[1]), int(parts[2]),
                               [int(w) for w in parts[3:]])
    return sizes


IMAGE_SIZES: dict[str, tuple[int, int, list[int]]] = {}


# Applied to the finished HTML rather than at the point each image is written,
# because the screenshots arrive two ways: the hero and the article figures come
# through Markdown, and the home page's alternating rows are hand-written <img>
# tags. One pass over the output covers both and cannot get them out of step.
IMG_TAG = re.compile(r'<img ([^>]*?)src="([^"]*shots/([^"/]+))"([^>]*?)>')
# Strips a hand-written width/height so the manifest's can replace it.
SIZE_ATTR = re.compile(r'\s*(?:width|height)="\d+"')


def add_srcset(html_text: str) -> str:
    def repl(m: re.Match) -> str:
        before, src, name, after = m.groups()
        entry = IMAGE_SIZES.get(name)
        if not entry:
            return m.group(0)
        width, height, variants = entry

        # Intrinsic size is taken from the manifest and overwrites whatever the page
        # said, rather than trusting the hand-written attributes. Those go stale
        # silently: re-shooting the screenshots changed every panel's height, the
        # numbers in the Markdown still described the old batch, and a wrong
        # width/height pair is worse than none at all — the browser reserves a box
        # of the wrong shape and the page jumps when the real picture lands.
        before = SIZE_ATTR.sub("", before)
        after = SIZE_ATTR.sub("", after)
        before = f'width="{width}" height="{height}" ' + before.lstrip()

        if not variants:
            return f'<img {before}src="{src}"{after}>'
        base = src[: -len(".webp")]
        candidates = [f"{base}-{w}.webp {w}w" for w in variants]
        candidates.append(f"{src} {width}w")
        # Two layouts, two answers. A row image sits in one half of a two-column
        # grid on a wide screen and fills the column on a narrow one; everything
        # else is a single figure in the text column. Telling the browser 900px for
        # a picture that renders at 420 makes it fetch twice the image it needs.
        in_row = 'data-row=' in before or 'data-row=' in after
        sizes = ("(max-width: 760px) 92vw, 420px" if in_row
                 else "(max-width: 760px) 92vw, 900px")
        return (f'<img {before}src="{src}" srcset="{", ".join(candidates)}" '
                f'sizes="{sizes}"{after}>')

    return IMG_TAG.sub(repl, html_text)


def read_pages() -> list[Page]:
    pages: list[Page] = []
    for lang in LANGS:
        for md in sorted((CONTENT / lang).glob("*.md")):
            raw = md.read_text(encoding="utf-8")
            if not raw.startswith("---"):
                sys.exit(f"{md}: missing front matter")
            _, front, body = raw.split("---", 2)
            pages.append(Page(lang, md.stem, yaml.safe_load(front) or {}, body.strip()))
    return pages


def link_to(slug: str, page: Page, by_slug: dict) -> str:
    """URL for `slug` in the reader's language, falling back to English.

    Only English and Simplified Chinese carry the long guides. A German reader
    following "Anleitungen" should land on the English guide rather than a 404,
    so the fallback is a real page in another language, addressed absolutely
    because it lives in a different directory depth.
    """
    target = by_slug.get((page.lang, slug))
    if target:
        up = "../" if page.depth else ""
        return f"{up}{LANGS[page.lang]['dir']}{slug}.html"
    fallback = by_slug.get((DEFAULT_LANG, slug))
    return f"{SITE}/{fallback.path}" if fallback else f"{SITE}/"


def lang_picker(page: Page, by_slug: dict, css_class: str) -> str:
    """Every language, each pointing at this page or that language's home.

    Written as links rather than a <select>: they are crawlable, they work
    without JavaScript, and the footer copy of the list is what tells a search
    engine the other languages exist.
    """
    items = []
    for lang, meta in LANGS.items():
        if lang == page.lang:
            items.append(f'<span class="lang-current">{meta["label"]}</span>')
            continue
        target = by_slug.get((lang, page.slug)) or by_slug.get((lang, "index"))
        if not target:
            continue
        items.append(
            f'<a class="lang" href="{SITE}/{target.path}" hreflang="{meta["hreflang"]}"'
            f' data-lang="{lang}">{meta["label"]}</a>'
        )
    return f'<nav class="{css_class}" aria-label="Language">' + "".join(items) + "</nav>"


def nav(page: Page, by_slug: dict) -> str:
    t = UI[page.lang]
    up = "../" if page.depth else ""
    home = up if page.depth else "./"
    return f"""<header class="nav">
  <div class="nav-inner">
    <a class="wordmark" href="{home}"><img src="{up}icon.png" alt="" width="26" height="26"><span>Candela</span></a>
    <nav class="nav-links">
      <a class="nav-secondary" href="{link_to('candela-vs-betterdisplay', page, by_slug)}">{t['nav_compare']}</a>
      <a class="nav-secondary" href="{link_to('fix-blurry-external-monitor-macos', page, by_slug)}">{t['nav_guides']}</a>
      <a class="nav-secondary" href="{REPO}" rel="noopener">{t['nav_github']}</a>
      <details class="lang-menu">
        <summary aria-label="Language">{LANGS[page.lang]['label']}</summary>
        {lang_picker(page, by_slug, "lang-menu-list")}
      </details>
      <a class="btn btn-kofi" href="{KOFI}" rel="noopener">{t['kofi']}</a>
      <a class="btn btn-dl" href="{DOWNLOAD}">{t['download']}</a>
    </nav>
  </div>
</header>"""


def css_version() -> str:
    """Short content hash of the stylesheet, appended to its URL.

    Without it a returning visitor keeps whatever CSS their browser cached, which
    is how a fixed style stays broken for exactly the people who have been here
    before. Hashing the file means the URL changes when the file does, and only
    then.
    """
    data = (ROOT / "site" / "styles.css").read_bytes()
    return hashlib.sha256(data).hexdigest()[:8]


def head(page: Page, by_slug: dict) -> str:
    m = page.meta
    up = "../" if page.depth else ""
    title = html.escape(m["title"])
    desc = html.escape(m["description"])
    og = m.get("og", "og-card.png" if page.lang == "en" else "og-card-zh.png")
    alts = "\n".join(
        f'<link rel="alternate" hreflang="{LANGS[l]["hreflang"]}" href="{p.url}">'
        for (l, s), p in sorted(by_slug.items()) if s == page.slug
    )
    default = by_slug.get((DEFAULT_LANG, page.slug))
    # The JSON-LD block is written in the page's front matter, so it is the one
    # place a URL can still be typed by hand — and it was: every schema block
    # carried a literal zifei.info address, which a change of domain would have
    # left pointing at the old site while every other tag moved. {{SITE}} is
    # substituted here so the structured data cannot disagree with the canonical.
    schema = m.get("schema", "").replace("{{SITE}}", SITE)
    return f"""<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{desc}">
<link rel="canonical" href="{page.url}">
{alts}
<link rel="alternate" hreflang="x-default" href="{default.url if default else page.url}">
<meta property="og:type" content="website">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{desc}">
<meta property="og:url" content="{page.url}">
<meta property="og:image" content="{SITE}/{og}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:locale" content="{LANGS[page.lang]['locale']}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{title}">
<meta name="twitter:description" content="{desc}">
<meta name="twitter:image" content="{SITE}/{og}">
<link rel="icon" href="{up}icon.png">
<link rel="stylesheet" href="{up}styles.css?v={css_version()}">
{schema}"""


# Sends a first-time visitor to the page in their own language, and never again
# after that. Without the memory it would fight anyone who deliberately picks
# English: they would land on English and be bounced straight back.
LANG_REDIRECT = """<script>
(function () {
  try {
    if (localStorage.getItem('candela-lang')) return;
    var urls = LANG_URLS;
    var wanted = navigator.languages || [navigator.language || ''];
    for (var i = 0; i < wanted.length; i++) {
      var tag = String(wanted[i]).toLowerCase();
      var pick = null;
      if (tag.indexOf('zh') === 0) {
        pick = /hant|tw|hk|mo/.test(tag) ? 'zh-Hant' : 'zh';
      } else {
        pick = tag.split('-')[0];
      }
      if (pick === 'en') return;
      if (urls[pick]) {
        localStorage.setItem('candela-lang', pick);
        location.replace(urls[pick]);
        return;
      }
    }
  } catch (e) {}
})();
</script>"""


ROW_FIGURE = re.compile(r'(<figure class="row-figure">\s*<img )')


def render(page: Page, by_slug: dict) -> str:
    t = UI[page.lang]
    body = make_markdown(page.depth)(page.body_md)
    # Mark the row images so add_srcset can tell them apart; the class lives on the
    # figure, and a regex over <img> alone cannot see its parent.
    body = ROW_FIGURE.sub(r'\1data-row="1" ', body)
    body = add_srcset(body)
    redirect = ""
    if page.lang == DEFAULT_LANG:
        urls = {}
        for lang in LANGS:
            if lang == DEFAULT_LANG:
                continue
            target = by_slug.get((lang, page.slug)) or by_slug.get((lang, "index"))
            if target:
                urls[lang] = f"{SITE}/{target.path}"
        if urls:
            as_js = "{" + ",".join(f'"{k}":"{v}"' for k, v in urls.items()) + "}"
            redirect = LANG_REDIRECT.replace("LANG_URLS", as_js)

    up = "../" if page.depth else ""

    remember = """<script>
document.querySelectorAll('a.lang').forEach(function (a) {
  a.addEventListener('click', function () {
    try { localStorage.setItem('candela-lang', a.getAttribute('hreflang')); } catch (e) {}
  });
});
// The demo autoplays, because a silent hero loop that waits for a click is a hero
// loop nobody watches. Someone who has told their system they want less motion has
// already answered that question, so they get the poster frame and a control bar
// rather than a decision made on their behalf. There is no CSS-only way to do this:
// prefers-reduced-motion cannot suppress the autoplay attribute.
(function () {
  var film = document.querySelector('.film-frame');
  if (!film) return;
  try {
    if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    film.autoplay = false;
    film.removeAttribute('autoplay');
    film.setAttribute('controls', '');
    film.pause();
  } catch (e) {}
})();
</script>"""

    return f"""<!doctype html>
<html lang="{LANGS[page.lang]['hreflang']}">
<head>
{head(page, by_slug)}
{redirect}
</head>
<body>
{nav(page, by_slug)}
<main class="wrap">
{body}
</main>
<footer class="site-footer">
  <nav class="footer-nav">
    <a href="{link_to('candela-vs-betterdisplay', page, by_slug)}">{t['nav_compare']}</a>
    <a href="{link_to('fix-blurry-external-monitor-macos', page, by_slug)}">{t['nav_guides']}</a>
    <a href="{REPO}" rel="noopener">{t['nav_github']}</a>
    <a href="{SIBLING}" rel="noopener">{t['nav_sibling']}</a>
    <a href="{KOFI}" rel="noopener">Ko-fi</a>
  </nav>
  {lang_picker(page, by_slug, "footer-langs")}
  <p>{t['footer_built']} {t['footer_fork']}
     <a href="{REPO}" rel="noopener">GitHub</a> ·
     <a href="{UPSTREAM}" rel="noopener">Crisp</a> ·
     <a href="{KOFI}" rel="noopener">Ko-fi</a></p>
</footer>
{remember}
</body>
</html>
"""


def sitemap(pages: list[Page]) -> str:
    entries = "\n".join(
        f"  <url><loc>{p.url}</loc><changefreq>monthly</changefreq></url>"
        for p in sorted(pages, key=lambda p: p.url)
    )
    return f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{entries}\n</urlset>\n'


def build(out: Path) -> None:
    global IMAGE_SIZES
    IMAGE_SIZES = read_image_sizes()
    pages = read_pages()
    by_slug = {(p.lang, p.slug): p for p in pages}

    missing = [f"{p.lang}/{p.slug}" for p in pages
               if not by_slug.get(("zh" if p.lang == "en" else "en", p.slug))]
    if missing:
        # A page that exists in one language only would emit an hreflang pointing at
        # a 404, which is worse for search than having no translation at all.
        sys.exit("untranslated pages (every page needs both languages): " + ", ".join(missing))

    for p in pages:
        target = out / p.out_file.relative_to(OUT)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(render(p, by_slug), encoding="utf-8")

    # Shared assets live in site/ or are generated into docs/shots by
    # scripts/capture-screenshots.sh. Copying rather than symlinking, because
    # GitHub Pages serves the tree as-is and does not follow links.
    shutil.copyfile(ROOT / "site" / "styles.css", out / "styles.css")
    for asset in ("icon.png", "og-card.png", "og-card-zh.png", "download-macos.png", "audioswitch.png"):
        src = OUT / asset
        if src.exists() and out != OUT:
            shutil.copyfile(src, out / asset)
    if (OUT / "shots").exists() and out != OUT:
        shutil.copytree(OUT / "shots", out / "shots", dirs_exist_ok=True)

    # The hero video. Only the web-ready encodes are published: the 12 MB master and
    # the raw per-segment footage stay in assets/ so the served tree carries nothing
    # a visitor will not download. Copied from assets/ rather than committed twice,
    # so re-exporting the film updates the site by rebuilding it.
    video_out = out / "video"
    video_out.mkdir(parents=True, exist_ok=True)
    for name in ("hero-1080.mp4", "hero-1080.webm", "poster.webp", "poster.jpg"):
        src = ROOT / "assets" / "video" / name
        if src.exists():
            shutil.copyfile(src, video_out / name)

    (out / "sitemap.xml").write_text(sitemap(pages), encoding="utf-8")
    (out / "robots.txt").write_text(
        f"User-agent: *\nAllow: /\nSitemap: {SITE}/sitemap.xml\n", encoding="utf-8")
    # GitHub Pages runs Jekyll by default, which ignores files starting with an
    # underscore and can rewrite things unpredictably. This turns it off.
    (out / ".nojekyll").write_text("", encoding="utf-8")
    # Pages reads the custom domain from this file, and rewrites it if you set the
    # domain in the web UI instead — so it is generated from SITE rather than hand
    # written, and the two cannot drift apart.
    if CUSTOM_DOMAIN:
        (out / "CNAME").write_text(CUSTOM_DOMAIN.group(1) + "\n", encoding="utf-8")
    # A fingerprint of everything published. The deploy-wait compares this one file,
    # which makes it sensitive to any change at all — including a deletion, which is
    # what the previous version missed: it compared three named files, and a commit
    # that only removed pages left all three identical, so the wait passed instantly
    # while the removed pages were still being served.
    digest = hashlib.sha256()
    for path in sorted(out.rglob("*")):
        if path.is_dir() or path.name == "build-id.txt":
            continue
        digest.update(str(path.relative_to(out)).encode())
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    (out / "build-id.txt").write_text(digest.hexdigest() + "\n", encoding="utf-8")

    print(f"built {len(pages)} pages into {out}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="build to a temp dir and diff against docs/")
    args = ap.parse_args()

    if not args.check:
        build(OUT)
        return 0

    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp) / "site"
        # Start from what is committed, then build over it. The check used to build
        # into an empty directory and copy a hand-listed set of assets, which meant
        # anything not on that list — the banner, the tour GIF — was absent from the
        # comparison. Harmless until the fingerprint file arrived: it hashes every
        # published file, so the two trees differed every time and the check failed
        # on a docs/ that was perfectly in sync.
        shutil.copytree(OUT, tmpdir)
        build(tmpdir)
        stale = []
        for built in tmpdir.rglob("*"):
            if built.is_dir():
                continue
            live = OUT / built.relative_to(tmpdir)
            if not live.exists() or live.read_bytes() != built.read_bytes():
                stale.append(str(built.relative_to(tmpdir)))
        if stale:
            print("docs/ is out of date with site/content — run python3 site/build.py")
            for s in stale:
                print("  " + s)
            return 1
    print("docs/ matches site/content")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
