---
title: "Candela — macOS 免费显示器控制工具"
description: "开源的 macOS 菜单栏工具：外接显示器的 HiDPI 清晰缩放、DDC 硬件亮度、多屏亮度同步、预设与虚拟显示器。全部功能免费，没有 Pro 版。"
schema: |
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"SoftwareApplication","name":"Candela",
   "operatingSystem":"macOS 26","applicationCategory":"UtilitiesApplication",
   "offers":{"@type":"Offer","price":"0","priceCurrency":"USD"},
   "url":"{{SITE}}/zh/",
   "downloadUrl":"https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg",
   "screenshot":"{{SITE}}/shots/panel-root.webp",
   "softwareLicense":"https://github.com/iamzifei/Candela/blob/main/LICENSE",
   "isAccessibleForFree":true}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"VideoObject",
   "name":"Candela 六十秒演示",
   "description":"六十秒无声录屏：从菜单栏拉出 Candela 面板，调整单块显示器与全部显示器的 DDC 硬件亮度，展开完整 HiDPI 分辨率列表，设置亮度键作用目标，打开工具页并切换深色模式。",
   "thumbnailUrl":"{{SITE}}/video/poster.jpg",
   "contentUrl":"{{SITE}}/video/hero-1080.mp4",
   "uploadDate":"2026-08-16","duration":"PT1M"}
  </script>
---

<div class="hero">

# macOS 藏起来的显示器设置

macOS 只留给内置屏幕的那些控制，还给桌上的每一块显示器：真正的 DDC 硬件亮度、
清晰的 HiDPI 缩放，以及在任意屏幕上都管用的亮度键。

<div class="actions">
<a class="btn btn-dl" href="https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg">下载 macOS 版</a>
<a class="btn btn-kofi" href="https://ko-fi.com/james_ai/tip" rel="noopener">在 Ko-fi 支持</a>
</div>

<p class="note">macOS 26 · Apple 芯片 · MIT 许可 · 没有 Pro 版，不需要激活码</p>
</div>

<figure class="film">
<video class="film-frame" poster="../video/poster.webp" width="1920" height="1080"
       autoplay muted loop playsinline preload="none"
       aria-label="六十秒无声录屏：从菜单栏拉出面板，拖动单块显示器的亮度滑条，再用合并滑条同时调整所有屏幕，展开完整的 HiDPI 分辨率列表，切换亮度键的作用目标，打开工具页，最后切换深色模式。">
<source src="../video/hero-1080.webm" type="video/webm">
<source src="../video/hero-1080.mp4" type="video/mp4">
</video>
<figcaption>六十秒，无声。每一帧都是已发布版本在真实桌面上的样子。</figcaption>
</figure>

<div class="sect-label">01 · macOS 没给你的</div>

## 有三件事立刻不正常

<p class="sect-lede">把显示器插到 Mac 上：亮度键按下去毫无反应；分辨率列表只给几个发虚的选项，
把清晰的那些藏了起来；想把整张桌子调暗，只能一块屏一块屏地拖。
Candela 把这三件事补回来，而且做成一个像控制中心那样的面板，不是一个设置窗口。</p>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-root.webp" alt="Candela 面板：每块显示器各自的亮度滑条，以及驱动全部屏幕的合并滑条" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>调的是背光，不是画面</h3>

- 走视频线上的 DDC/CI，和显示器自己的按键是同一条通道
- 拒绝 DDC 的屏幕退回软件调光，并标出 *Software*，让你知道现在是哪一种
- 支持 DDC 音量的显示器，音量也一起管

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-settings.webp" alt="Candela 的设置页，显示亮度键一行及其当前作用目标" width="1380" height="934" loading="lazy" decoding="async"></figure>
<div>
<h3>亮度键作用于任意屏幕</h3>

- 跟随鼠标、作用于全部屏幕，或把所有屏幕当成一个整体
- 也可以只作用于你指定的那几块，放过电视或色彩基准屏
- 只需一个「辅助功能」权限，不用重启

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-allResolutions.webp" alt="Candela 中某块显示器的完整分辨率列表，清晰档位已标出" width="1380" height="1708" loading="lazy" decoding="async"></figure>
<div>
<h3>任意显示器都能上 HiDPI</h3>

- 放出 macOS 对第三方显示器隐藏的 2× 渲染档位
- 1440p 或 4K 面板可以既看得清、又足够锐利，而不是二选一
- 刷新率就在同一页，缩放档不会悄悄把 60 Hz 吃掉

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-display.webp" alt="Candela 中某块显示器的详情页，含合并亮度下限校准" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>让多块屏真的看起来一样</h3>

- 一条滑条管住整张桌子
- 再加上每块屏用眼睛校一次的下限——同一个百分比并不会让两块面板发出同样的光
- 不会出现一块还亮着、另一块已经全黑

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-tools.webp" alt="Candela 的工具页：排列、虚拟显示器与 Sidecar" width="1380" height="624" loading="lazy" decoding="async"></figure>
<div>
<h3>预设、排列、虚拟屏</h3>

- 把整套配置——分辨率、亮度、排列——存下来，一键恢复
- 拖动显示器改变位置，不用打开系统设置
- 建一块虚拟屏用于录制，或者把 iPad 接成扩展屏

</div>
</div>

<div class="sect-label">02 · 它要多少钱</div>

## 不要钱，也没有第二档

没有 Pro 版，没有激活码，没有每日次数上限，也没有留一手的功能。整个 app 以 MIT 开源，
代码在 GitHub 上。觉得有用的话 [Ko-fi] 在那儿；你永远不点，app 也不会有任何变化。

这也是和同类工具最主要的区别。[BetterDisplay] 的免费版相当能打，但把灵活 HiDPI 缩放、
虚拟屏、断开显示器、高级快捷键留给了 21.99 美元的 Pro。[Lunar] 同样开源，
终身授权 23 美元，免费版限制为每天 100 次亮度调节。两个都是好软件。
Candela 对「我能用到哪些功能」的回答就一个字：全部。

[看完整对比 →](candela-vs-betterdisplay.html)

<div class="sect-label">03 · 指南</div>

## 从这里开始

- [外接显示器发虚怎么修](fix-blurry-external-monitor-macos.html) —— 1440p / 4K 上字为什么糊，真正管用的是哪几步
- [Mac 如何开启 HiDPI](enable-hidpi-mac.html) —— HiDPI 到底是什么，以及怎么给 macOS 不肯给的显示器打开它
- [让亮度键能控制外接显示器](mac-brightness-keys-external-monitor.html) —— F1／F2 作用于任意屏幕，以及那一个必需的权限
- [多块显示器亮度同步](sync-brightness-multiple-monitors-mac.html) —— 一条滑条管全部，以及怎么让不同面板真的看起来一致

<div class="sect-label">04 · 安装</div>

## 两种方式

下载 DMG 拖进「应用程序」，或者用 Homebrew：

```
brew install --cask iamzifei/tap/candela
```

Candela 使用 Developer ID 签名并经过 Apple 公证，打开时不会有「无法验证开发者」的拦截。

<div class="sect-label">05 · 系统要求</div>

## 你需要什么

- macOS 26 或更新
- Apple 芯片
- 亮度键需要一个「辅助功能」权限，第一次启用该功能时 macOS 会主动询问
- 外接显示器的硬件亮度需要显示器自身的 OSD 菜单里开启 DDC/CI。
  多数显示器出厂即开启；少数机型以及部分 USB-C 扩展坞不会透传这个通道

<div class="sect-label">06 · 我的另一个</div>

## 同一条菜单栏上的另一个 App

<a class="sibling" href="https://audioswitch.dev" rel="noopener">
<img src="../audioswitch.png" width="44" height="44" alt="" loading="lazy" decoding="async">
<span class="sibling-text">
<span class="sibling-name">AudioSwitch</span>
<span class="sibling-desc">所有音频输入和输出在同一个面板里：切换设备、调音量、静音、实时麦克风电平，还有一个麦克风硬开关。免费、MIT、Apple 芯片原生。</span>
</span>
<svg class="sibling-go" width="18" height="18" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3.5 10.5 8 6 12.5"/></svg>
</a>

[Ko-fi]: https://ko-fi.com/james_ai/tip
[BetterDisplay]: https://betterdisplay.pro/
[Lunar]: https://lunar.fyi/
