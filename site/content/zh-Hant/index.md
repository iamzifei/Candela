---
title: "Candela — macOS 免費顯示器控制工具"
description: "開源的 macOS 選單列工具：外接顯示器的 HiDPI 清晰縮放、DDC 硬體亮度、多螢幕亮度同步、預設集與虛擬螢幕。全部功能免費，沒有 Pro 版。"
schema: |
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"SoftwareApplication","name":"Candela",
   "operatingSystem":"macOS 26","applicationCategory":"UtilitiesApplication",
   "offers":{"@type":"Offer","price":"0","priceCurrency":"USD"},
   "url":"{{SITE}}/zh-Hant/",
   "downloadUrl":"https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg",
   "screenshot":"{{SITE}}/shots/panel-root.webp",
   "softwareLicense":"https://github.com/iamzifei/Candela/blob/main/LICENSE",
   "isAccessibleForFree":true}
  </script>
---

<div class="hero">

# macOS 藏起來的顯示器控制，全都放進一個選單列面板

macOS 只留給內建螢幕的那些能力，還給你桌上的每一塊螢幕 —— 透過 DDC 調真實亮度、
清晰的 HiDPI 縮放，以及在任何螢幕上都有效的亮度鍵。

<div class="actions">
<a class="btn btn-dl" href="https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg">下載 macOS 版</a>
<a class="btn btn-kofi" href="https://ko-fi.com/iamzifei" rel="noopener">在 Ko-fi 支持</a>
</div>

<p class="note">macOS 26 · Apple 晶片 · MIT 授權 · 沒有 Pro 版，也沒有序號</p>
</div>

<figure class="film">
<video class="film-frame" poster="../video/poster.webp" width="1920" height="1080"
       autoplay muted loop playsinline preload="none"
       aria-label="一段六十秒的無聲錄影：從選單列打開面板、先調一塊螢幕再一次調全部螢幕的亮度、完整的 HiDPI 解析度清單、亮度鍵的作用目標、工具頁，以及切換整個系統的深色模式。">
<source src="../video/hero-1080.webm" type="video/webm">
<source src="../video/hero-1080.mp4" type="video/mp4">
</video>
<figcaption>六十秒，沒有聲音。每一格都是實際發行版本，在真實桌面上的樣子。</figcaption>
</figure>

<div class="sect-label">01 · macOS 沒給你的</div>

## 三件事會失效

<p class="sect-lede">把螢幕接上 Mac，亮度鍵什麼都調不動，解析度清單只給你幾個模糊的選項、把清晰的那些藏起來，
而且沒有辦法一次調整所有螢幕。Candela 把這三件事還給你，做成一個行為像控制中心、
而不是像偏好設定視窗的面板。</p>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-root.webp" alt="Candela 面板：每塊螢幕各自的亮度滑桿，以及驅動全部螢幕的合併滑桿" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>真正調到背光的亮度</h3>

- 透過影像線走 DDC/CI —— 和螢幕自己那幾顆按鍵用的是同一條通道
- 不吃 DDC 的螢幕會退回 gamma 調暗，並標記為 *Software*，讓你知道差別
- 會回應的螢幕，連音量也一起管

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-settings.webp" alt="Candela 的設定頁，顯示亮度鍵一列及其目前的作用目標" width="1380" height="934" loading="lazy" decoding="async"></figure>
<div>
<h3>亮度鍵，在任何一塊螢幕上</h3>

- 跟著游標走、驅動每一塊螢幕，或把全部當成一塊來調
- 也可以只作用在你選定的螢幕，放過電視或色彩要求嚴格的那一塊
- 一個「輔助使用」權限，不需要重新開機

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-allResolutions.webp" alt="Candela 中某塊螢幕的完整解析度清單，清晰的檔位已標示" width="1380" height="1708" loading="lazy" decoding="async"></figure>
<div>
<h3>任何螢幕都能清晰 HiDPI</h3>

- macOS 對第三方螢幕藏起來的 2× 算繪模式
- 1440p 或 4K 的螢幕終於可以又大又清晰，而不是二選一
- 更新率就在同一頁，縮放模式不會悄悄讓你掉到 60 Hz 以下

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-display.webp" alt="Candela 裡某塊螢幕自己的頁面，含合併亮度的下限控制" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>讓每塊螢幕彼此對得上</h3>

- 一根滑桿管整張桌子
- 再加上一個你用眼睛校準、逐螢幕設定的下限 —— 同樣的百分比，兩塊面板發出的光並不相同
- 不會有一塊已經全黑、旁邊那塊還亮著的情況

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-tools.webp" alt="Candela 的工具頁：排列、虛擬螢幕與 Sidecar" width="1380" height="624" loading="lazy" decoding="async"></figure>
<div>
<h3>預設集、排列、虛擬螢幕</h3>

- 把整張桌子存起來 —— 解析度、亮度、排列 —— 一鍵還原
- 不必打開系統設定就能拖曳螢幕位置
- 建立一塊虛擬螢幕用來錄影，或用 Sidecar 接上 iPad

</div>
</div>

<div class="sect-label">02 · 它要多少錢</div>

## 不要錢，也沒有第二個版本

沒有 Pro 版、沒有序號、沒有每日次數限制，也沒有任何被扣住的功能。整個 App 以 MIT 授權，
原始碼在 GitHub 上。覺得有用的話，[Ko-fi] 在那裡；你永遠不點，App 裡也不會有任何差別。

這就是和其他選擇最主要的不同。[BetterDisplay] 免費版已經很能打，但把彈性 HiDPI 縮放、
虛擬螢幕、中斷顯示器和進階快速鍵留給 21.99 美元的 Pro。[Lunar] 是開源的、終身授權 23 美元，
免費版每天限制 100 次亮度調整。兩者都是好軟體。Candela 對「我能用到哪些功能」的回答很簡單：
「全部」。

[閱讀完整比較 →](../candela-vs-betterdisplay.html)（英文）

<div class="sect-label">03 · 指南</div>

## 從這裡開始

以下指南目前提供英文與簡體中文：

- [修好模糊的外接螢幕](../fix-blurry-external-monitor-macos.html) —— 為什麼 1440p 或 4K 螢幕上的文字看起來發糊，以及真正能讓它變銳利的做法
- [在 Mac 上啟用 HiDPI](../enable-hidpi-mac.html) —— HiDPI 是什麼，以及怎麼替 macOS 不主動提供的螢幕打開它
- [讓亮度鍵在外接螢幕上生效](../mac-brightness-keys-external-monitor.html) —— 在任何螢幕上用 F1、F2，以及讓這件事成立的那個權限
- [多螢幕亮度同步](../sync-brightness-multiple-monitors-mac.html) —— 一根滑桿管整張桌子，以及怎麼讓不同面板真的對得上

<div class="sect-label">04 · 安裝</div>

## 兩種方式

下載 DMG 把 Candela 拖進「應用程式」，或者用 Homebrew：

```
brew install --cask iamzifei/tap/candela
```

Candela 使用 Developer ID 簽署並經過 Apple 公證，打開時不會有「無法驗證開發者」的攔截。

<div class="sect-label">05 · 系統需求</div>

## 你需要什麼

- macOS 26 或更新版本
- Apple 晶片
- 亮度鍵需要一個「輔助使用」權限，第一次啟用該功能時 macOS 會主動詢問
- 外接螢幕的硬體亮度需要在螢幕自己的 OSD 選單裡開啟 DDC/CI。
  多數螢幕出廠即開啟；少數機型以及部分 USB-C 擴充座不會傳遞這個通道

<div class="sect-label">06 · 我的另一個</div>

## 同一條選單列上的另一個 App

<a class="sibling" href="https://audioswitch.dev" rel="noopener">
<img src="../audioswitch.png" width="44" height="44" alt="" loading="lazy" decoding="async">
<span class="sibling-text">
<span class="sibling-name">AudioSwitch</span>
<span class="sibling-desc">所有音訊輸入與輸出都在同一個面板：切換裝置、調音量、靜音、即時麥克風電平，還有一個麥克風硬開關。免費、MIT、Apple 晶片原生。</span>
</span>
<svg class="sibling-go" width="18" height="18" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3.5 10.5 8 6 12.5"/></svg>
</a>

[Ko-fi]: https://ko-fi.com/iamzifei
[BetterDisplay]: https://betterdisplay.pro/
[Lunar]: https://lunar.fyi/
