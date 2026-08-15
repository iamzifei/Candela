---
title: "Candela、BetterDisplay、Lunar 对比（2026）"
description: "三款 macOS 显示器工具的诚实对比：各自多少钱、免费版扣了什么、HiDPI 缩放与 DDC 亮度该选哪一个。"
---

# Candela、BetterDisplay、Lunar 对比

**先给结论：** BetterDisplay 功能最全，但大多数人真正想要的那几项在 21.99 美元的 Pro 里。
Lunar 的强项是**自动**亮度——环境光、地理位置、跟随内置屏——终身授权 23 美元。
Candela 把前两者的核心功能都做了，全部以 MIT 免费给出，代价是刻意做窄：
只支持 macOS 26 与 Apple 芯片，没有自动化引擎。

三个都值得装。选哪个，取决于你是在为「功能深度」付费、为「自动化」付费，还是都不付。

## 一览

| | Candela | BetterDisplay | Lunar |
|---|---|---|---|
| 价格 | **免费，全功能** | 免费版 + Pro 21.99 美元 | 免费版 + Pro 23 美元 |
| 开源 | 是，MIT | 源码在 GitHub | 是 |
| 灵活 HiDPI 缩放 | <span class="yes">免费</span> | 仅 Pro | <span class="no">—</span> |
| DDC 亮度／音量 | <span class="yes">免费</span> | <span class="yes">免费</span> | 免费版每天上限 100 次 |
| 虚拟／自定义屏幕 | <span class="yes">免费</span> | 仅 Pro | <span class="no">—</span> |
| 断开显示器 | <span class="yes">免费</span> | 仅 Pro | <span class="no">—</span> |
| 亮度键重定向 | <span class="yes">免费</span> | 仅 Pro（高级快捷键） | <span class="yes">免费</span> |
| 环境光／自动亮度 | <span class="no">—</span> | 有 | **看家本领** |
| 跟随内置屏 | 有 | 有 | **看家本领** |
| 系统要求 | macOS 26，Apple 芯片 | macOS 13+，Intel 与 Apple 芯片 | macOS 11+，Intel 与 Apple 芯片 |

价格于 2026 年 8 月核对自各项目官网，不同地区可能有差异。

## 免费版到底扣了什么

对比表最容易含糊的就是这一段，所以直接说清楚。

**BetterDisplay** 的免费版是真能用——DDC 亮度、音量、EDID 都在。Pro 解锁的是它官网自己列出的那些：
灵活 HiDPI 缩放、XDR/HDR 亮度提升、自定义虚拟屏、HDR 虚拟屏、断开与重连显示器、高级自定义快捷键。
如果你是冲着「让 1440p 显示器上的字变清晰」来的，那一项恰好是付费功能。

**Lunar** 的免费版不是砍功能，是限次数：每天 100 次亮度调节、100 次动作调用。
手动拖几下滑条完全够；但对「自动」场景就很紧——而自动正是 Lunar 的价值所在。
Sync 模式、传感器模式、位置模式、XDR 亮度、快捷指令自动化都属于 Pro。

**Candela** 没有分级。没有需要解锁的东西，也不会在第 101 次调节时停下来。

## 各自真正更强的地方

**选 BetterDisplay**：如果你用 Intel Mac 或较旧的 macOS，或者需要 EDID 覆写、画中画、
显示器串流，以及它多年积累下来的那一长串选项。三者里它功能最全，差距不小，21.99 美元买断很公道。

**选 Lunar**：如果你要的其实是「亮度自己管自己」。它的环境光传感器模式、跟随内置屏、
基于地理位置的曲线，在 macOS 上没有对手，快捷指令集成还让亮度变得可脚本化。
Candela 没有自动化引擎，也不假装有。

**选 Candela**：如果你要的是日常那几件事——亮度、清晰缩放、亮度键、预设——
并且不想做购买决策，机器也是较新的 Mac。另外，如果你希望能读到那段正在通过 I2C
和你的显示器对话的代码，这对一个会往硬件写数据的软件来说是个合理的要求。

## Candela 不只是更便宜

**让多块屏「看起来一样」，而不只是「一起动」。** 这三个 app 都能把同一个百分比发给两块显示器。
但那不等于它们看起来一样：面板在满亮度下的输出不同，背光下降的响应曲线也不同，
而 macOS 不提供任何可用于归一化的绝对亮度值。可见的失败发生在最低端——
走 DDC 调光的显示器背光有下限，到 0 依然亮着；靠软件调光的那块则接近全黑。
Candela 让你用眼睛给每块屏校一次这个下限，之后合并滑条就能让它们保持一致。
[原理与做法 →](sync-brightness-multiple-monitors-mac.html)

![Candela 中某块显示器的详情页，包含合并亮度下限的校准控件。](shots/panel-display.png)

**它会告诉你亮度是不是「假的」。** 如果显示器拒绝 DDC——确实有这种机型，
也有不透传该通道的 USB-C 扩展坞——Candela 会改为调暗画面而不是背光，
并在那块屏的滑条上标出 **Software**。静默降级正是「亮度能调但看着不对」拖成一小时排查的起点。

**是面板，不是设置窗口。** 控件分组在各自的圆角面上、用下钻页面组织，
和控制中心一致，而不是一长串可折叠的分区。

## Candela 做不到的

明说，因为只列优点的对比就是广告：

- **不支持 Intel，且只支持 macOS 26。** 它基于 macOS 26 SDK 构建，DDC 走的是 Apple 芯片的路径。
  如果你在 Ventura 或 Intel Mac 上，这个 app 不适合你，该用 BetterDisplay。
- **没有环境光自动化。** 没有传感器模式、没有位置曲线、没有日落跟随。这块是 Lunar 的。
- **没有 EDID 覆写、画中画、显示器串流。**
- **踩过的坑更少。** BetterDisplay 从 2021 年起就在处理各种奇怪的显示器和扩展坞。
  Candela 是新的，新软件见过的显示器更少。

## 常见问题

**Candela 是真免费，还是「暂时免费」？**
MIT 许可，代码在 GitHub。已经发布出去的源码，未来的版本无法追溯性地收回，任何人都可以 fork。

**能同时装多个吗？**
亮度上不行。两个 app 同时往同一块显示器写 DDC 会互相打架，亮度会肉眼可见地来回跳。
亮度只留一个，其他功能可以共存。

**为什么我的显示器完全不响应亮度？**
它的 DDC/CI 没开，或者链路上有东西没透传这个通道。先查显示器自己的 OSD 菜单——
通常在 *Settings* 或 *Other Settings* 下——然后试试把它直连 Mac，绕开扩展坞或 hub。

**USB-C 或雷雳能用吗？**
线材或扩展坞透传 DDC 通道时可以。直连最稳；显示器有画面但亮度调不动时，
廉价 hub 是最常见的原因。

---

[下载 Candela](https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg) ·
[BetterDisplay](https://betterdisplay.pro/) ·
[Lunar](https://lunar.fyi/)
