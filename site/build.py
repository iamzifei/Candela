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
    "en": {"hreflang": "en", "dir": "", "label": "English", "switch": "中文"},
    "zh": {"hreflang": "zh-Hans", "dir": "zh/", "label": "简体中文", "switch": "English"},
}
DEFAULT_LANG = "en"

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


def nav(page: Page, by_slug: dict) -> str:
    t = UI[page.lang]
    up = "../" if page.depth else ""
    home = up if page.depth else "./"
    other = "zh" if page.lang == "en" else "en"
    counterpart = by_slug.get((other, page.slug)) or by_slug.get((other, "index"))
    return f"""<header class="nav">
  <div class="nav-inner">
    <a class="wordmark" href="{home}"><img src="{up}icon.png" alt="" width="26" height="26"><span>Candela</span></a>
    <nav class="nav-links">
      <a class="nav-secondary" href="{up}{LANGS[page.lang]['dir']}candela-vs-betterdisplay.html">{t['nav_compare']}</a>
      <a class="nav-secondary" href="{up}{LANGS[page.lang]['dir']}fix-blurry-external-monitor-macos.html">{t['nav_guides']}</a>
      <a class="nav-secondary" href="{REPO}" rel="noopener">{t['nav_github']}</a>
      <a class="lang" href="{SITE}/{counterpart.path}" hreflang="{LANGS[other]['hreflang']}">{LANGS[page.lang]['switch']}</a>
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
<meta property="og:locale" content="{'en_US' if page.lang == 'en' else 'zh_CN'}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{title}">
<meta name="twitter:description" content="{desc}">
<meta name="twitter:image" content="{SITE}/{og}">
<link rel="icon" href="{up}icon.png">
<link rel="stylesheet" href="{up}styles.css?v={css_version()}">
{schema}"""


# Sends a first-time visitor whose browser is Chinese to the Chinese page, and never
# again after that. Without the memory it would fight anyone who deliberately clicks
# "English": they would land on English and be bounced straight back.
LANG_REDIRECT = """<script>
(function () {
  try {
    if (localStorage.getItem('candela-lang')) return;
    var zh = (navigator.languages || [navigator.language || '']).some(function (l) {
      return /^zh\\b/i.test(l);
    });
    if (zh && !location.pathname.match(/\\/zh\\//)) {
      localStorage.setItem('candela-lang', 'zh');
      location.replace(ZH_URL);
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
    counterpart = by_slug.get(("zh", page.slug)) or by_slug.get(("zh", "index"))
    redirect = ""
    if page.lang == DEFAULT_LANG and counterpart:
        redirect = LANG_REDIRECT.replace("ZH_URL", f"'{SITE}/{counterpart.path}'")

    up = "../" if page.depth else ""
    other = "zh" if page.lang == "en" else "en"
    footer_counterpart = by_slug.get((other, page.slug)) or by_slug.get((other, "index"))

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
    <a href="{up}{LANGS[page.lang]['dir']}candela-vs-betterdisplay.html">{t['nav_compare']}</a>
    <a href="{up}{LANGS[page.lang]['dir']}fix-blurry-external-monitor-macos.html">{t['nav_guides']}</a>
    <a href="{REPO}" rel="noopener">{t['nav_github']}</a>
    <a href="{SIBLING}" rel="noopener">{t['nav_sibling']}</a>
    <a href="{KOFI}" rel="noopener">Ko-fi</a>
    <a class="lang" href="{SITE}/{footer_counterpart.path}" hreflang="{LANGS[other]['hreflang']}">{LANGS[page.lang]['switch']}</a>
  </nav>
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
