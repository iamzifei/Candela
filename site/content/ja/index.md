---
title: "Candela — macOS のディスプレイ設定を無料で取り戻す"
description: "外部モニタのための macOS メニューバーアプリ（オープンソース）: くっきりした HiDPI スケーリング、DDC によるハードウェア輝度、複数ディスプレイの輝度同期、プリセットと仮想ディスプレイ。すべて無料で、Pro 版はありません。"
schema: |
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"SoftwareApplication","name":"Candela",
   "operatingSystem":"macOS 26","applicationCategory":"UtilitiesApplication",
   "offers":{"@type":"Offer","price":"0","priceCurrency":"USD"},
   "url":"{{SITE}}/ja/",
   "downloadUrl":"https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg",
   "screenshot":"{{SITE}}/shots/panel-root.webp",
   "softwareLicense":"https://github.com/iamzifei/Candela/blob/main/LICENSE",
   "isAccessibleForFree":true}
  </script>
---

<div class="hero">

# macOS が隠しているディスプレイ設定を、1 つのメニューバーパネルに

macOS が内蔵ディスプレイのためだけに残している機能を、机の上のすべてのモニタへ —— DDC による
実際の輝度調整、くっきりした HiDPI スケーリング、そしてどこでも効く輝度キー。

<div class="actions">
<a class="btn btn-dl" href="https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg">macOS 版をダウンロード</a>
<a class="btn btn-kofi" href="https://ko-fi.com/james_ai/tip" rel="noopener">Ko-fi で支援</a>
</div>

<p class="note">macOS 26 · Apple シリコン · MIT ライセンス · Pro 版なし、ライセンスキーなし</p>
</div>

<figure class="film">
<video class="film-frame" poster="../video/poster.webp" width="1920" height="1080"
       autoplay muted loop playsinline preload="none"
       aria-label="Candela を実際に使っている 60 秒の無音録画: メニューバーからパネルを開き、1 台ずつ、次に全ディスプレイ一括で輝度を動かし、HiDPI 解像度の全リスト、輝度キーの対象、ツールページ、そしてシステム全体のダークモード切り替え。">
<source src="../video/hero-1080.webm" type="video/webm">
<source src="../video/hero-1080.mp4" type="video/mp4">
</video>
<figcaption>60 秒、無音。すべて実際に配布しているアプリの、実際の机の上の映像です。</figcaption>
</figure>

<div class="sect-label">01 · macOS が用意しないもの</div>

## 3 つのことが動かなくなる

<p class="sect-lede">Mac にモニタをつなぐと、輝度キーは何も変えられず、解像度リストはぼやけた選択肢をいくつか出す
だけで、くっきりしたモードは隠されます。しかも全ディスプレイをまとめて動かす方法がありません。
Candela はその 3 つを取り戻します。環境設定のウインドウではなく、コントロールセンターのように
ふるまうパネルとして。</p>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-root.webp" alt="Candela のパネル: 接続中の各ディスプレイの輝度スライダーと、すべてを動かす合成スライダー" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>バックライトまで届く輝度</h3>

- 映像ケーブル経由の DDC/CI —— モニタ本体のボタンが使うのと同じ経路
- DDC に応じないディスプレイはガンマ調光にフォールバックし、*Software* と表示されます
- 応答するモニタなら音量も同じパネルから

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-settings.webp" alt="Candela の設定。輝度キーの行と現在の対象が表示されている" width="1380" height="934" loading="lazy" decoding="async"></figure>
<div>
<h3>どのディスプレイでも効く輝度キー</h3>

- ポインタを追う、全ディスプレイを動かす、あるいはすべてを 1 つとして動かす
- 選んだディスプレイだけに効かせて、テレビや色にシビアなパネルは除外することも
- 必要なのは「アクセシビリティ」の許可 1 つだけ。再起動は不要

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-allResolutions.webp" alt="Candela に表示された 1 台分の全解像度リスト。くっきりしたモードに印が付いている" width="1380" height="1708" loading="lazy" decoding="async"></figure>
<div>
<h3>どのモニタでも、くっきり HiDPI</h3>

- サードパーティ製ディスプレイで macOS が隠している 2× レンダリングのモード
- 1440p や 4K のパネルが、読みやすさと解像感のどちらかではなく両方を得られます
- リフレッシュレートも同じページ。スケーリングのせいで気づかぬうちに 60 Hz に落ちることがありません

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-display.webp" alt="Candela の 1 台分のページ。合成輝度の下限設定がある" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>互いに揃うディスプレイ</h3>

- 机全体を 1 本のスライダーで
- さらにディスプレイごとに目で合わせる下限値を —— 同じパーセントでも 2 枚のパネルが同じ明るさで
  光るとは限らないからです
- 隣がまだ点いているのに片方だけ真っ暗、ということが起きません

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-tools.webp" alt="Candela のツールページ: 配置、仮想ディスプレイ、Sidecar" width="1380" height="624" loading="lazy" decoding="async"></figure>
<div>
<h3>プリセット、配置、仮想ディスプレイ</h3>

- 解像度・輝度・配置を含む机の状態をまるごと保存し、ワンクリックで復元
- システム設定を開かずにディスプレイの位置をドラッグで変更
- 収録用の仮想ディスプレイを作る、あるいは Sidecar で iPad をつなぐ

</div>
</div>

<div class="sect-label">02 · 価格について</div>

## 無料で、上位版もありません

Pro 版もライセンスキーも 1 日あたりの回数制限もなく、出し惜しみしている機能もありません。
アプリ全体が MIT ライセンスで、ソースは GitHub にあります。役に立ったなら [Ko-fi] がありますが、
一度も押さなくてもアプリの動作は何ひとつ変わりません。

これが他の選択肢との一番の違いです。[BetterDisplay] は無料版もよくできていますが、柔軟な HiDPI
スケーリング、仮想ディスプレイ、ディスプレイの切断、高度なショートカットは 21.99 ドルの Pro 向けに
残しています。[Lunar] はオープンソースで買い切り 23 ドル、無料版は輝度調整が 1 日 100 回までです。
どちらも良いソフトウェアです。「どの機能が使えるのか」という問いに対する Candela の答えは、
単に「全部」です。

[詳しい比較を読む →](../candela-vs-betterdisplay.html)（英語）

<div class="sect-label">03 · ガイド</div>

## まずはここから

以下のガイドは現在、英語と簡体字中国語で提供しています:

- [外部モニタのにじみを直す](../fix-blurry-external-monitor-macos.html) —— 1440p や 4K でテキストが甘く見える理由と、実際に効く対処
- [Mac で HiDPI を有効にする](../enable-hidpi-mac.html) —— HiDPI とは何か、macOS が提示してくれないディスプレイでどう有効化するか
- [外部モニタで輝度キーを効かせる](../mac-brightness-keys-external-monitor.html) —— どのディスプレイでも F1・F2 を使うために必要な許可
- [複数モニタの輝度を同期する](../sync-brightness-multiple-monitors-mac.html) —— 机全体を 1 本のスライダーで、そして本当に揃える方法

<div class="sect-label">04 · インストール</div>

## 2 つの方法

DMG をダウンロードして Candela を「アプリケーション」にドラッグするか、Homebrew を使います:

```
brew install --cask iamzifei/tap/candela
```

Candela は Developer ID で署名され Apple の公証を受けているので、右クリックでの回避操作なしに開きます。

<div class="sect-label">05 · 動作条件</div>

## 必要なもの

- macOS 26 以降
- Apple シリコン
- 輝度キーには「アクセシビリティ」の許可が 1 つ必要です。機能を初めて有効にするときに macOS が尋ねます
- 外部ディスプレイのハードウェア輝度には、モニタ側の OSD メニューで DDC/CI が有効になっている
  必要があります。多くのモニタは初期状態で有効ですが、一部の機種や USB-C ドックは通しません

<div class="sect-label">06 · 私のもう 2 つのアプリ</div>

## 同じメニューバーのもう 2 つ

<a class="sibling" href="https://audioswitch.dev" rel="noopener">
<img src="../audioswitch.png" width="44" height="44" alt="" loading="lazy" decoding="async">
<span class="sibling-text">
<span class="sibling-name">AudioSwitch</span>
<span class="sibling-desc">すべてのオーディオ入力と出力を 1 つのパネルに —— デバイスの切り替え、音量、ミュート、リアルタイムのマイクレベルメーター、マイクの完全オフスイッチ。無料、MIT、Apple シリコンネイティブ。</span>
</span>
<svg class="sibling-go" width="18" height="18" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3.5 10.5 8 6 12.5"/></svg>
</a>

<a class="sibling" href="https://getclipstack.app" rel="noopener">
<img src="../clipstack.png" width="44" height="44" alt="" loading="lazy" decoding="async">
<span class="sibling-text">
<span class="sibling-name">ClipStack</span>
<span class="sibling-desc">コピーしたものはすべて残ります。⇧⌘V で開く検索可能なクリップボード履歴 —— テキストも画像もファイルも、よく使うものはピン留めできます。Mac の外には出ません。無料、MIT、Apple シリコンネイティブ。</span>
</span>
<svg class="sibling-go" width="18" height="18" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3.5 10.5 8 6 12.5"/></svg>
</a>

[Ko-fi]: https://ko-fi.com/james_ai/tip
[BetterDisplay]: https://betterdisplay.pro/
[Lunar]: https://lunar.fyi/
