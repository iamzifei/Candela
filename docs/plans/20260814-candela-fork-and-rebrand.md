---
project: Candela
status: in-progress
created: 2026-08-14
owner: James (Zifei Gong)
repo: /Users/james/Dev/candela
upstream: https://github.com/didriksg/Crisp (MIT, Didrik Galteland)
---

# Candela — macOS 26 显示器控制 menubar app

## Goal

把 MIT 协议的 Crisp fork 成 **Candela**：一个只支持 macOS 26+ 的常驻 menubar app，
控制所有显示器（内置 / 外接 / 虚拟）的分辨率、亮度、排列与色彩，全面采用 macOS 26
Liquid Glass 设计语言，以开源免费形式发布。

## 已锁定的决策（2026-08-14，不要重开）

| 项 | 决定 | 依据 |
|---|---|---|
| 代码起点 | Fork Crisp 全量改造，保留 Services/Models | 私有 API 逆向成果占项目 80% 工作量，重做无收益 |
| 定位 | 开源免费发布（GitHub + Homebrew tap） | 用户选择 |
| 最低系统 | **macOS 26.0**，不做向下兼容 | 可直接用原生 Liquid Glass API，代码更干净 |
| 名字 | **Candela**（亮度 SI 基本单位） | .app / .dev 域名实测均未注册（RDAP 直连 Google Registry 查证） |
| Bundle ID | `com.candela.app` | 对齐上游 `com.crisp.app` 形制；不使用法律实体名 |
| 上游关系 | 保留 `upstream` remote，定期 merge | 上游活跃（最后提交 2026-08-14，371 commits） |

## NON-goals（明确不做）

- ❌ 不做付费墙 / License key / Stripe —— 免费开源，不挤占其他产品线的 GTM 时间
- ❌ 不支持 macOS 25 及以下 —— 不写 `#available` 兼容分支
- ❌ 不支持 Intel Mac —— 只做 Apple Silicon（DDC 走 IOAVService，本就是 AS-only 路径）
- ❌ 不重写 Services 层的私有 API 封装 —— 那是 fork 的全部价值所在
- ❌ 不做 iOS/iPadOS 端

## 基线（实测，2026-08-14）

- 环境：MacBook Pro Mac17,9 / M5 Pro / macOS 26.6.1 (25G76) / Xcode 26.6 / Swift 6.3.3
- 测试显示器：Gigabyte M28U（5120×2880，UI 2560×1440@60）、VX1622-4K（3840×2160，UI 1920×1080@60）
- **`make compile` 33 秒通过，零警告** ← 改造的基线，任何一步之后都必须保持
- 工具链：xcodegen ✅ / gh ✅ / Icon Composer ✅（在 Xcode 26 内）/ swiftlint ❌ 待装 / create-dmg ❌ 待装
- 签名：`Developer ID Application: Orris Technology Pty Ltd (K9YT36SP4B)` 可用

## 上游已经做掉的事（不要重复投入）

盘查后确认，Crisp 并非「macOS 14 老风格」，它已经部分 macOS 26 感知：

- `AppDelegate.swift:444` 已用原生 `NSGlassEffectView` 做面板背景（带 macOS 15 回退分支）
- `MenuBarView.swift:6` 的图标 chip 明确按 macOS 26 控制中心规范做
- `ScreenEffectsView.swift:4` 按 macOS 26 系统显示器面板的按钮行做
- `generate-icon.swift` 已是「macOS-26-style gradient squircle」

**所以「UI 现代化」的真实剩余工作是「收窄 + 原生化 + 换品牌」，不是「重写」。**

---

## Phase 1 — 仓库与品牌骨架 ✅ 完成 2026-08-14（commit b03244d）

**做什么**
- [x] 目录/文件重命名：`Crisp/` → `Candela/`，`CrispTests/` → `CandelaTests/`，
      `Crisp-Bridging-Header.h` → `Candela-Bridging-Header.h`
- [x] 262 处 `Crisp` 字样替换（代码 / project.yml / Makefile / dev.sh / scripts/）
- [x] Bundle ID `com.crisp.app` → `com.candela.app`；Logger subsystem、DispatchQueue label 同步
- [x] UserDefaults key 前缀 `crisp.` → `candela.`，迁移函数改为遍历 legacy 前缀列表
- [x] LICENSE 双版权行；ACKNOWLEDGMENTS.md 说明 fork 关系并把想要成熟版的人指回 Crisp
- [x] `UpdateService.swift` 指向 iamzifei 仓库
- [x] 版本号重置为 `0.1.0`，build 号 `1`

**验收标准（实测结果）**
- ✅ `make compile` 33 秒通过，零警告（与基线一致）
- ✅ 品牌字样只剩 LICENSE / ACKNOWLEDGMENTS 的归属声明与 README 待重写的站点链接
- ✅ 保留上游 371 条历史，`upstream` remote 在位
- ✅ `make build` 产出 0.1.0 签名 DMG；装到 /Applications 启动常驻，菜单栏图标在位
- ✅ defaults 落在 `candela.*` 命名空间；`candela.volumeCapableDisplays` 已填入显示器 UUID
- ✅ **DDC 往返实测（VX1622-4K）**：读 100 → 写 75 → 回读 75 → 还原 100 → 回读 100
- ⏳ 面板 UI 级回归（打开面板看到两台屏、拖滑块）→ 见 HUMAN QUEUE #7

### Phase 1 过程中的实测发现（不要重新推导）

1. **M28U 不响应 DDC**。对 VCP 0x10 返回 `6E 80 BE 00…`（null message），地址回显与
   checksum 均合法 → 显示器在 I2C 总线上活着，但拒绝 DDC/CI 命令。两次独立运行一致
   （含/不含 Candela 运行）。**推断**是 OSD 里 DDC/CI 关着；**若判断错，最可能错在**
   它是经 Anker Prime Dock（Thunderbolt 5，已确认在位）接入而 DDC 未透传。
   → HUMAN QUEUE #8
2. **Ice 会隐藏 Candela 的菜单栏图标**。开发期"图标没出来"的头号误判来源。
   诊断法：退出 Ice 后截图即可看到 `sparkles.tv` 图标。**注意 macOS 26 上第三方状态项
   不再以自己的进程出现在 CGWindowList 层 25**（层 25 只剩 Control Centre），
   所以用 CGWindowList 判断"状态项存不存在"会得到假阴性。
3. **zsh 不做默认分词**：`for f in $FILES` 会把整个列表当成一个文件名。批量改文件用
   `grep -rl … | while IFS= read -r f`，不要用 `xargs -0` 配 BSD grep 的 `-Z`（不产生 NUL）。
4. 排查"哪些 `crisp` 是英文形容词"时，`grep -rn … | grep -v Crisp` 会因为**路径里含
   `Crisp/`** 而过滤掉该目录下的每一行。必须只对内容部分做判断。

---

## Phase 2 — 收窄到 macOS 26 ✅ 完成 2026-08-14（commit 817555c）

**做了什么**
- [x] deploymentTarget 14.0 → 26.0，`LSMinimumSystemVersion` 同步
- [x] 删除全部 4 处向下兼容分支：面板背景直取 `NSGlassEffectView`、
      `topAnchoredScroll` 直用 role-scoped anchor、boost tint 直用 `Color.mix`、
      `LaunchService` 去掉 3 个 `#available(macOS 13)`
- [x] **改为 arm64-only**（原为 universal）。理由：DDC 走 IOAVService＝Apple Silicon
      专有路径，x86_64 切片能编能启动但控不了外接屏背光，发出去只会误导 Intel 用户
- [x] Makefile / dev.sh / release.sh 全部钉到 `arm64-apple-macos26.0`
- [x] 顺带带入试 Swift 6 时暴露出的并发修正（在 Swift 5 下同样正确，且更好）

**验收结果（实测）**
- ✅ `#available` 零残留
- ✅ `make compile` 零警告
- ✅ **52/52 单元测试通过**
- ✅ arm64-only DMG，`LSMinimumSystemVersion = 26.0`
- ✅ 删掉 defaults 域后重启，显示器枚举与 DDC 能力探测**从零重建成功**，无崩溃报告

## Phase 2b — Swift 6 语言模式（已拆出，不阻塞任何后续 Phase）

试过一遍，**故意没做完**。记录状态以免重新推导：

- 起点 2 个错误 → 修完 8 处后仍在冒新错，长尾没有收敛迹象
- 已修掉并**已合入**的：`kAXTrustedCheckOptionPrompt` 换成字面量（值实测＝
  `AXTrustedCheckOptionPrompt`）· `BoostTintModifier` 的 `@MainActor Animatable`
  conformance 隔离 · `BadgeHeightKey.defaultValue` 改 `let` ·
  `CGDisplayMode: @retroactive @unchecked Sendable` · `CGHelpers` 用 `Mutex`
  替代 NSLock+captured var · 两处 Timer 回调把 Timer 留在 `assumeIsolated` 外 ·
  DDC completion 标 `@Sendable` · `FrameSpring` 标 `@MainActor`
- **卡住的两处**：①`PanelCanvas` 的 CADisplayLink 弹簧（vsync 时序最敏感的代码）
  ②`AppDelegate` 里 NSMenu 通知观察者——`Notification`/`NSMenu` 都不是 Sendable，
  `assumeIsolated` 也算捕获跨界。剩下的路只有 `nonisolated(unsafe)` 消音、
  或重构通知观察模式

**为什么停**：这两处都在动显示/动画管线，而 fork 的全部价值就是那条管线是好的。
为一个编译标志去改它，风险收益比不成立。**要做的话单开一次会话专做这件事**，
且必须配真机动画回归（面板开合掉不掉帧，编译器验不出来）。

**注意**：`project.yml` 里 `SWIFT_VERSION: "6.0"` 但 `SWIFT_STRICT_CONCURRENCY: minimal`
——这是上游原样，Makefile 的 xcodebuild 调用用 `SWIFT_VERSION=5` 覆盖。看起来矛盾，
但不是遗漏，Phase 2b 一并理顺。

---

## ⚠ 贯穿所有重构的取舍（2026-08-14 James 追加「重构优化」需求后写下）

上游 **每天都在提交**（371 commits，最后一条 2026-08-14）。**每一处重构都在给
Phase 6 的合并加成本。** 因此排序原则：

1. **优先做上游也会接受的改动**（真 bug、无障碍缺陷、明确的规范偏离）——将来可以
   反向提 PR，冲突自然消解
2. **纯风格偏好的改动集中在少数文件**，不要全库铺开
3. **不碰 Services 层的算法与私有 API 调用序**——那是 fork 的全部价值，且是
   逆向出来的、注释里写满了"为什么必须这样"的代码。**改它等于把资产变成负债**

James 的 CLAUDE.md 里那条 78 文件批量加类型、炸出 126 个 TS 错误、最后整体回滚的
教训，就是这一节存在的理由。**每片 5–10 个文件，每片跑 compile + test，绿了再下一片。**

## Phase 3a — 代码质量（证据驱动，切片执行）

**基线（实测 2026-08-14）**：`swiftlint --strict` 用项目自带配置是 **0 违规**——
但那是把阈值调宽换来的（配置注释自己承认「较大的文件早于 lint 存在，放宽阈值以减少
噪音」：`file_length 1400` / `type_body_length 700` / `function_body_length 175` /
`cyclomatic_complexity 15`）。

**用 SwiftLint 默认阈值重跑：69 个文件里 46 处违规。**
审计配置留在 `.swiftlint-audit.yml`，随时可复现：`swiftlint lint --config .swiftlint-audit.yml`

| 规则 | 数量 | 最严重的几处 |
|---|---|---|
| file_length | 12 | `DisplayModeListView` 906 · `AppDelegate` 1005 · `BrightnessService` 933 · `PanelCanvas` 753 · `DDCService` 736 |
| function_body_length | 10 | `AppDelegate:512` **162 行**（上限 100）· `AppDelegate:89` 65 行 |
| cyclomatic_complexity | 8 | `PanelCanvas:518` 13 · `BrightnessKeyService:227` 13 |
| type_body_length | 7 | `AppDelegate` 类体 617 行 · `BrightnessService` 505 · `DDCService` 473 |
| large_tuple | 7 | `ArrangementService` ×3 · `GammaService` ×2 · `VirtualDisplayView` ×2 |
| function_parameter_count | 2 | `BrightnessHUDService:18` 7 个 · `PresetService:74` 7 个 |

**切片顺序**（每片独立提交，绿了才进下一片）：

- [x] **切片 1 · large_tuple（7 → 0）** ✅ commit 5be20b3
      `(id:x:y:)` → `ArrangementService.DisplayOrigin`（含 `translated(dx:dy:)`）·
      `(r:g:b:)` → `GammaService.RGBGains`（含 `normalized(against:)`）·
      `(label:width:height:)` → `VirtualDisplayView.SizePreset`
- [x] **切片 2 · function_parameter_count（2 → 1）** ✅ commit 5be20b3
      `editPreset` / `captureCurrentState` 的三个 `include*` 布尔 → `Set<PresetCapture>`
      （枚举本来就存在，是给预设行的 ⋯ 菜单用的），`DisplayPreset` 新增 `captures`
      计算属性。**剩下那 1 处不能改**：`OSDUIHelperProtocol.showImage` 的 7 个参数是
      Apple 私有 XPC 的签名，收窄会断绑定
- [x] **切片 3 · AppDelegate 面板构建抽取** ✅ commit dd3b265
      162 行的 `rebuildBlocksIfNeeded` → 20 行 + `PanelBlockFactory`
      （`displayBlocks` = header + `modeBlocks` + `colorBlocks`，
      `globalBlocks` 把 Tools 交给 `toolsBlocks`）。类体 **617 → 473 行**。
      ⚠️ **factory 放在 AppDelegate.swift 内，没有新建文件**——上游经常改面板，
      跨文件搬代码会把每一次上游改动都变成冲突。文件超长的违规值不了这个价钱。
      纯代码搬移：块、id、顺序、open 判据全未变，真机截图与重构前逐项一致
- [ ] **切片 4 · 视图层文件拆分**：`DisplayModeListView` 906 行 →
      按「模式列表 / 平滑缩放 / 行渲染」拆
- [ ] **切片 5 · 收紧 `.swiftlint.yml` 阈值**到实际达成的水平，让新增代码不能再退化

**明确不做**：`DDCService` / `BrightnessService` / `ResolutionService` 的内部逻辑重排。
文件长是因为注释密度高（上游把逆向结论都写进注释了），拆它收益低风险高。

**验收标准**
- 每片结束：`make compile` 零警告 + 52/52 测试通过 + 真机面板能开
- 全部结束：`.swiftlint.yml` 的阈值不再高于 SwiftLint 默认值的 1.5 倍
- 未引入任何新的 `// swiftlint:disable`

## Phase 3b — UI / UX 对齐 macOS 26

**证据基础（实测 2026-08-14，Candela 面板与系统控制中心并排截图）**
截图：`/private/tmp/.../scratchpad/panel.png` 与 `cc.png`

已观察到的三处差异：

1. **分组容器**：控制中心把每组控件包在**独立的圆角玻璃卡片**里（Wi-Fi/蓝牙/AirDrop
   是胶囊，Display/Sound 是带标题的宽卡片）；Candela 是一整块平面 + 细分隔线。
   这是 macOS 26 控制中心布局最显著的特征，也是最大的一处偏离
2. **滑条上下文**：控制中心的滑条在卡片内、**上方有标题**（"Display" / "Sound"）；
   Candela 的滑条是裸行。⚠️ 但**滑条本身的形制是一致的**（细轨 + 两端字形），
   我原以为 26 会用 iOS 那种高胶囊滑条，截图否掉了这个预期
3. **图标 chip 配色**：控制中心开启态是**白底 + 彩色字形**；Candela 是
   **彩色底 + 白色字形**。⚠️ 但 Candela 的 Dark Mode 开启态恰好是白底黑标，与系统
   一致——所以不是全错，是**内部不统一**

**置信度**：n=1 单次截图，且只覆盖控制中心默认模块。⚠️ **下"必须改"的结论前**，
还要看系统设置里的「显示器」面板——上游 `ScreenEffectsView.swift:4` 的注释说那一行
按钮就是照它做的，若照的是那个而非控制中心，则差异 3 不成立。

### 已完成（2026-08-14）

- [x] **减弱动态（Reduce Motion）** → commit 73b3b69。全项目**原本零处理**。
      `FrameSpring.animate` 直接落到目标，`Animation.respectingReduceMotion`
      把曲线压成瞬时。29 处 `withAnimation` **全部**走这条路（原有 5 处硬编码
      曲线绕过了 `panelResize`：排列拖拽/布局沉降、图像调整高亮、预设保存）。
      `spring.animate` 只有一个调用点，两处即可覆盖面板。
      ⏳ **未在设置真开启的情况下验证**——`com.apple.universalaccess` 域受保护，
      改不了。需人工去「辅助功能 → 显示 → 减弱动态」开一次看面板是否变成瞬时
- [x] **软件调光徽章提到顶层** → commit 73b3b69 + 43d4154。
      原本徽章只在展开详情里显示（顶层用 compact 模式），
      而"这块屏在用软件调光"恰恰是需要主动告知的。改为**只在异常态显示**
      （非内建 + 已回退软件），DDC 正常的屏不占空间
- [x] **不依赖颜色区分**：圆点改成按模式区分的字形（DDC=闪电，软件=画笔）。
      原来绿/橙两色是唯一信号，在「不使用颜色区分」下会消失
- [x] **可用性判定不再只靠写**（43d4154）：读到连续 3 次明确拒绝就判定，
      不必等用户拖滑条。⚠️ 仍**只对"明确拒绝"生效**，普通读失败依然不判定
      （有些显示器只支持写不支持读）

**降低透明度（Reduce Transparency）不做**：背景是 `NSGlassEffectView`，
系统材质自己响应该设置。**待确认而非假定**，但不值得预先覆盖。

## Phase 3c — 面板改为逐级页面（2026-08-14 James 拍板，方案 A）

### 为什么不是"重绘"

James 的原话：「够用，但是**折叠层级太多**，视觉上和系统风格不够统一。但如果折叠数量
减少的话，很多选项会加重面板默认长度。」

**这两端在"内联展开"这个机制里无解**：展开越多面板越长，折叠越多层级越深。
实测当前有 **11 个独立展开状态**，最深 3 次点击（显示器→详情→分辨率→全部列表；
Tools→虚拟屏→行；Settings→亮度键→目标）。

系统不用这个机制解。控制中心点 Wi-Fi 是**整页替换 + 返回箭头**，深度恒为 1。

### 方案

导航栈 `[PanelRoute]`，每页都短：

- **根页**：显示器行（名称 + 亮度 +（音量））· Combined · 深色/夜览 · 预设 ·
  工具 › · 设置 › · 退出。**高度固定，不再被展开撑长**
- **显示器页**：返回头 + 分辨率 / 刷新率 / 颜色 / 图像调整 / 断开此屏
- **全部分辨率**：唯一需要再深一层的（列表很长），单独成页

### 可行性（已确认，不是估计）

`PanelCanvas.setBlocks(_:footer:)` 本来就支持整批换块，弹簧已会动画高度变化。
换页 = 换一份 block 列表 + 一个导航状态，**不是重写画布**。
之前抽出的 `PanelBlockFactory` 正好是落点。

### 切片（每片 compile + test + 真机开面板，绿了再下一片）

- [ ] **切片 1 · 导航基建 + 根页/显示器页**：`PanelRoute` 栈、
      `blocksSignature` 纳入路由、`PanelBlockFactory.blocks(for:)`、返回头组件。
      最大的一块收益（砍掉最深的三层）
- [ ] **切片 2 · Tools 页**（含虚拟屏 / iPad / 排列各自成页）
- [ ] **切片 3 · Settings 页**
- [ ] **切片 4 · 视觉统一**：分组玻璃卡片、滑条分组标题、
      与「系统设置 > 显示器」并排对照

### ⚠ 风险

面板构建是**上游最常改的地方**，这一片会显著推高合并成本。
UPSTREAM.md 里已记：`AppDelegate.swift` 属于"跟随重命名但内容必冲突"那一类。
**收益（解掉 James 每天都在碰的层级问题）值这个代价，但不要再往外扩。**

### 未做（视觉，切片 4 之后）

- [ ] 「系统设置 > 显示器」对照截图 → 决定图标 chip 配色改不改
- [ ] 四种辅助功能设置下逐一截图
- [ ] 真 VoiceOver 逐控件走查

### ✅ 无障碍：折叠区块被 VoiceOver 读出 — 已修（commit cefefd5）

**现象**：面板「先渲染再裁剪」（那正是 120Hz 不掉帧的原因），所以折叠区块虽然看不见
但完整存在。VoiceOver 会念出整个图像调整组、分辨率列表、平滑缩放说明等。

**修法**：在 `layoutNow()` 里按块的显示高度，在 `[]` 和 `[host]` 之间切换
clip 的 accessibility children，且只在状态变化时写（那是每帧跑的热路径）。

**⚠️ 三个都试过才找到唯一可行的写法，不要重走**：
| 写法 | 结果 |
|---|---|
| clip 上 `setAccessibilityHidden` | **无效**——内部宿主视图是独立元素，仍可达 |
| host 上 `setAccessibilityHidden` / `setAccessibilityElement` | **也无效**，SwiftUI 自己的元素还在树里（实测滑条从 4 条变 8 条） |
| clip 的 children 在 `[]` / `[host]` 间切换 | ✅ 唯一有效 |

**⚠️ 恢复必须显式写 `[host]`，不能用 `nil`**：实测 `setAccessibilityChildren(nil)`
是把 nil 存成覆盖值，不是恢复默认（一个有 2 个可访问子视图的 view：2 → 0 → nil）。
**用 nil 恢复的话，任何折叠过一次的区块整个会话都不再可读**——差点就这么发出去。
显式 `[host]` 的往返实测为 1 → 0 → 1 → 0 → 1。

**验收**：折叠内容从 AX 树消失；4 条可见滑条仍在。
⏳ 真 VoiceOver 的逐控件走查仍未做。

**验收标准**
- 四种辅助功能设置各一张截图，均不塌陷
- VoiceOver 逐控件走查通过
- 无硬编码颜色，全部走 semantic color

## Phase 7 — 多语言：简体 / 繁体 / 英文（2026-08-14 James 追加）

**现状（实测）**：`Localizable.xcstrings` 199 个 key，仅 `en` + `zh-Hans`。
zh-Hans 已译 191 条，"缺"的 8 条是 `%lld` / `×` / `∞` / `DDC` / 版本号这类不需翻译的
——**即简中实际是完整的**。

**要做**：新增 `zh-Hant`（繁体中文）191 条。

🚫 **不得用简繁字符转换（OpenCC 之类）糊弄。** 转换出来的是"用繁体字写的大陆用语"，
台港用户一眼假。显示器领域的实际差异：

| 英文 | zh-Hans | zh-Hant |
|---|---|---|
| Resolution | 分辨率 | **解析度** |
| Refresh rate | 刷新率 | **更新率** |
| Screen | 屏幕 | **螢幕** |
| Settings | 设置 | **設定** |
| Default | 默认 | **預設** |
| Preset | 预设 | ⚠️ **不能用「預設」**（那是 default），要用「組合」/「設定組合」 |
| Software | 软件 | **軟體** |
| Shortcut key | 快捷键 | **快速鍵** |
| Menu bar | 菜单栏 | **選單列** |
| Mirror | 镜像 | 鏡像 |
| Virtual | 虚拟 | 虛擬 |

- [x] `project.yml` 的 `knownRegions` 加 `zh-Hant`
- [x] 191 条逐条译，术语按上表
- [x] `check-translations.py` → `All strings translated for: zh-Hans, zh-Hant`
- [x] `make loc-check` 通过（198 个 key 全在目录里）
- [x] `xcstrings-compile.py` 编出 `zh-Hant.lproj`（191 条）

### ✅ 完成 2026-08-14（commit 7dd44f8）

**实现方式（重要，将来改翻译走这条路）**
- 译文单独放 `/Users/james/Dev/candela/scripts/zh-Hant.json`，当散文审阅，不用
  在 xcstrings 的 JSON 脚手架里读
- `/Users/james/Dev/candela/scripts/add-zh-Hant.py` 合并进 String Catalog。
  ⚠️ **它按文本插入，不走 `json.dumps` 往返**——Xcode 的格式（`"key" : value`
  冒号前有空格、空对象包一个空行、自己的 key 排序、文件末尾无换行）经 Python
  序列化会整文件重排 1200 行，**那样每次 `git merge upstream/main` 这个文件必冲突**，
  而上游经常加新字符串。现在 diff 是 **1147 增 / 1 删**
- 幂等：整块重建 `localizations` 对象而不是就地补逗号（第一版就地补逗号，跑第二次
  产生尾随逗号、JSON 失效——这是实际踩到的坑）
- 双向漂移检查：zh-Hans 有而 zh-Hant 没有 → 报错；zh-Hant 有而目录里没这个 key
  （上游改名/删除）→ 也报错。**任一方向静默跳过都会发出一个"报告为完整、实际回退
  英文"的语言**
- 已挂进 `make check`（新增 `make hant-check` 目标）

**验收结果**
- ✅ 切到 `AppleLanguages=(zh-Hant)` 启动，面板显示：合併亮度 / 深色模式·開 /
  夜覽·關 / 預設組合 / 新增預設組合 / 工具 / 設定 / **結束 Candela**
- ✅ 构建产物 `.strings` 抽查深层字符串全部正确（解析度 / 更新頻率 / 拷貝顯示器名稱 /
  隱藏瀏海區域 / 顏色描述檔 / 影像調整 / 中斷顯示器連線 / 原彩顯示 / 軟體 /
  「輔助使用」權限…）
- ✅ `make check` 端到端通过
- 截图：`panel.png`（英文）· `panel-hant.png`（繁体）· `cc.png`（系统控制中心对照）
- ⏳ 简体截图尚未存档

---

## Phase 4 — App Icon ✅ 主体完成 2026-08-14（commit 52d799e）

**选定方案：B「亮度弧」** —— 刻度弧从暗扫到亮，环绕中心光源。Candela 是亮度单位，
所以画的是「测量」而不是「屏幕」。轮廓恰好是个 C。

5 个候选（三外观 × 512/64/32）留在 `/Users/james/Dev/candela/design/icon-candidates/`。
**小尺寸那两列决定了结果**：
- A 光锥在大尺寸读成「山 + 太阳」
- D 光度极坐标大尺寸最独特，**32pt 糊成一团**——这正是加小尺寸列的原因
- C 发光屏能用但与 BetterDisplay / Lunar / MonitorControl 撞脸
- E 烛焰词源对、产品错（读成冥想 app，暖橙与界面冷色调打架）

- [x] `scripts/generate-icon.py` 取代 `generate-icon.swift`，**输出 SVG**
      （macOS 26 分层 `.icon` 的图层就是 SVG，将来直接复用不用重画）
- [x] 三种外观：light 饱和靛蓝 / dark 近黑 / mono 代表 `ISAppearanceTintable`
- [x] 菜单栏 template 图标换成同一个弧，AppKit 按 18pt 自有网格绘制
- [x] Dock / Finder 实测：四角透明、无白卡

### ⚠️ 两个必须记住的坑

1. **几何按实测，不按 Big Sur 规格**。量了 macOS 26 的 Notes.app（256pt）：
   形状占画布 **0.836**（Big Sur 是 0.805），圆角 ≈ 0.225×边长，且**上留白比下多 4pt**
   （给系统投影让位）
2. **`qlmanage -t` 会把 SVG 合成到不透明白底**。第一版 iconset 每张四角都是纯白，
   Dock 直接画成一张白卡垫在图案后面。改用 `scripts/rasterize-svg.swift`
   （NSImage 原生读 SVG，保留矢量与 alpha，逐尺寸原生渲染而非从 1024 缩放）。
   重复生成字节一致

### ⏳ 剩余：分层 `.icon` 打包（低优先级，不阻塞发布）

已查清格式：`.icon` conforms to `com.apple.package`，是**目录包**；清单键为
`groups` / `layers` / `fill` / `image-name` / `glass` / `specular` / `translucency` /
`blur-material` / `shadow` / `supported-platforms`，资源放 `assets/`，图层是 SVG。
编译产物是 `Assets.car` 里的 `IconImageStack`（三外观：`NSAppearanceNameAqua` /
`NSAppearanceNameDarkAqua` / `ISAppearanceTintable`）+ `IconGroup`。
⚠️ **系统 app 仍然只 ship `.icns`，`.icon` 是创作源格式** —— 我之前说「做 .icon
而不是 .icns」是错的，已更正。

**当前发布路径 ship 的是扁平 `.icns`（light 外观），完全可用。** 要拿到 Liquid Glass
的分层折射与高光，需用 Icon Composer（GUI，无法无头驱动）导入
`/Users/james/Dev/candela/design/candela-icon-{light,dark,mono}.svg`。
→ HUMAN QUEUE #9

**验收标准**
- [x] Dock / Finder 显示正常，无白卡
- [x] 菜单栏图标浅色/深色菜单栏都清晰（template 反色正常）
- [ ] Launchpad、系统设置两处未逐一确认
- [ ] 「明晰（clear）」外观未做（需分层 .icon）

---

## Phase 5 — 发布基建

**做什么**
- [ ] `brew install swiftlint create-dmg`，恢复 `make check` 全绿
- [ ] `scripts/release.sh` 的环境变量改名（`CRISP_SIGN_ID` → `CANDELA_SIGN_ID` 等）
- [ ] 配置 notarytool keychain profile，跑通签名 + 公证 + stapler
- [ ] 建 GitHub 仓库，推送，配 CI（沿用上游 `.github/workflows/ci.yml` 改造）
- [ ] 中英双语 Localizable.xcstrings 检查（`make loc-check`）
- [ ] README（中英）、GitHub Pages 落地页
- [ ] Homebrew tap

**验收标准**
- `make check` 全绿（lint + tests + loc-check）
- 从 DMG 全新安装 → 双击直接打开，无 Gatekeeper 拦截（公证生效的实证）
- `xcrun stapler validate` 通过

---

## Phase 6 — 上游同步机制 ✅ 完成 2026-08-14

- [x] `/Users/james/Dev/candela/docs/UPSTREAM.md`
- [x] **实际演练过一次合并**（上游当前 0 条新提交，所以造了四类代表性改动来演练）

### 演练的真实结果（不是预测）

| 类别 | 结果 |
|---|---|
| 已被 git 识别为重命名的文件（如 `DDCService.swift`） | 跟随重命名，只在双方都改的行上产生内容冲突 ✅ |
| **改动超过相似度阈值、未被识别为重命名的** | `CONFLICT (modify/delete)`，上游版本被留在**旧路径** `Crisp/...` 下，必须手工搬运 |
| `project.yml` | 版本号必冲突 |
| **`Localizable.xcstrings`** | **干净自动合入，零冲突** ✅ |

**当前处于「未识别为重命名」名单的**：`Services/CGHelpers.swift`、
`Services/LaunchService.swift`。这个名单会随着重写更多文件而变长，
UPSTREAM.md 里给了查询命令。

### 最有价值的一条验证

**`Localizable.xcstrings` 干净合入，证明了当初「按文本插入、不做 JSON 往返」
那个决定是对的。** 如果 `add-zh-Hant.py` 用 `json.dumps` 重排了 1200 行，
这次演练里它就会变成整文件冲突——而上游经常加新字符串。
**不要把那个脚本"整理"成普通的 JSON load-and-dump。**

---

## 🐛 真机用出来的 bug（2026-08-14 James 报告，全部已修）

### 1. M28U 调不了亮度 → commit b2b797d

- **实测**：M28U 对每次 Get VCP 都回 `6E 80 BE` —— DDC/CI **null message**，
  校验和合法（`0x50^0x6E^0x80`），含义是「收到了，但我不答」。同机 VX1622 正常
- **缺陷**：`ddcAvailable` 按「写是否成功」判定，而 `IOAVServiceWriteI2C` 只要字节
  上总线就返回成功 → 显示器忽略命令、写照样"成功" → **永远不退到软件调光**
- **修法**：把 null message 与"乱码"分开。乱码不能说明什么（有些显示器只支持写不
  支持读），但 null message 是显示器明确表态，连续 3 次就信它。
  规则抽到 `Candela/Models/DDCReply.swift`，用两台屏的真实字节写了测试
- ⚠️ **M28U 是间歇性的**——中途成功答过一次（50/100，校验和合法）

### 2. 快捷键调不了亮度 → commit b2b797d + a7c3f2c

**这条查了很久，根因不在代码里。**

- 系统设置里 Candela 的开关**显示为开**，但 app 日志里 TCC 的实际回复是
  `auth_value=0 / result=false / auth_reason=5`（**拒绝**）
- **原因**：第一次安装是 ad-hoc 签名，TCC 按 cdhash 绑定了记录；之后换成
  Developer ID 签名，UI 那一行还在（按 bundle id 显示）但代码要求已对不上。
  **用户点开的是一条失效的旧记录**
- **解法**：`tccutil reset Accessibility com.candela.app`（执行时打印了 4 次，
  说明确实存在多条陈旧记录），然后用**当前签名**重新授权
- 🔴 **开发期铁律**：**dev 构建必须用 Developer ID 签名**，不要用 ad-hoc。
  ad-hoc 每次构建 cdhash 都变，TCC 授权留不住，会反复出现"授权了但不生效"

**同时修掉的两个代码问题**：
- 启动时若未授权，原来只在 1s / 3s 各查一次就放弃。而 app 的提示恰恰把用户送去
  系统设置——在那里授权远超 3 秒。→ `armWhenTrusted()` 持续轮询
  （`AXIsProcessTrusted()` 不弹窗，`CGEvent.tapCreate` 才弹）
- 加了 arming 诊断日志。**arming 失败没有任何可见症状**（按键继续走系统默认，
  与"没装这个 app"无法区分）。查法：
  `log show --predicate 'subsystem == "com.candela.app"' --last 10m --info`
  ⚠️ **不加 `--info` 什么都看不到**，Logger.info 默认不落盘

### 3. 多屏统一调节时亮度不一致 → commit a7c3f2c

- **实测算出来的**：软件调光缩放的是 gamma 表输出的**信号**，显示器随后要应用
  自己的 EOTF（≈γ2.2），所以信号缩放 k 倍 → **亮度变成 k^2.2 倍**。
  而 DDC 的背光值与亮度大致线性。两条路径完全不在一条曲线上：

  | 滑条 | DDC 屏 | 软件屏（旧） |
  |---|---|---|
  | 50% | ≈50% 亮度 | 0.50^2.2 = **22%** |
  | 20% | ≈20% 亮度 | 0.20^2.2 = **2.9%** |

- **修法**：`SoftwareDimming.transferFactor` 做 EOTF 反补偿（`p^(1/2.2)`）
- ⚠️ **>100 必须原样透传**——那是 EDR boost 区间，`BrightnessBoostService` 把它
  当原始倍率用，加修正或钳到 1.0 会**直接搞坏 Extra Brightness**（共用这个函数）
- **诚实边界**：这修的是**响应曲线的形状，不是绝对亮度**。两块屏在"50%"仍会因
  最大亮度和真实 EOTF 不同而有差异，那需要色度计才能校准。它保证的是
  **两块屏一起动、不会一块黑了另一块还亮着**

### 4. Sidecar 连上 iPad 后其他两块外接屏黑屏 → commit bca6f19

**这是我造成的，而且是"把推断当结论发出去"的直接后果。**

- 我把 `configureDisplayExclusiveMode = true` 当作"扩展而非镜像"，理由是名字含义 +
  Sidecar 的行为。**"exclusive" 是字面意思**：Sidecar 屏独占，其他屏全灭
- 我在代码注释里标了这是推断、在汇报里也标了"唯一没法自己验证的地方"——**但那不够**。
  验证的代价由 James 承担，而失败模式是"所有屏黑掉"，那时他**没法用这个 app 去断开**

**修法**：
- 永不设置该标志；声明处写死警告
- **扩展/镜像根本不是 Sidecar 的设置**。连上后 iPad 就是一块普通 CGDisplay，
  系统设置里的 "Mirror for <display>" 就是 `CGConfigureDisplayMirrorOfDisplay`，
  项目里已有 `MirrorService`。改为连接**之后**用普通镜像机制施加偏好；
  显示器 ID 从 `configForDevice:` 取（连上后才非 nil，这也是连接时的 config
  必须自己构造的原因）
- 加了恢复保险：连接 2.5 秒后若原本活动的显示器有消失，自动断开并报错

**教训（比这个 flag 本身重要）**：
**失败模式是破坏性的推断，不能靠"在注释里标明是推断"就发出去。**
要么留到能测再做，要么绕开它——本次的镜像方案就是绕开。

### 5. 镜像开关对已连接的会话不生效 → commit 1c6fc87

- 偏好只在**连接那一刻**被读取，所以连上后再翻开关，开关动了屏幕不动
- **修法**：镜像不是 Sidecar 会话的一部分（是普通显示器镜像，系统设置里改是实时的），
  所以改成实时应用 + 连接时应用，两条路共用 `sidecarDisplayID(forDeviceID:)`
  和 `applyMirroring(toDisplay:)`，且都幂等
- ✅ **在硬件上实测双向**：连接 → 切镜像 → 切回扩展，三步全过

**查错时两个把人带偏的东西（重要，会再遇到）**：
1. **macOS 按显示器记住上次的排列**。前一个探针把 iPad 设成镜像后，下一次连接
   直接继承了镜像——探针显示"成功"，但那是系统记住的，不是代码干的。
   **差点据此判定代码没问题**
2. 一度怀疑 `offersAdditionalDisplay` 连上后变 false（那样设备会从过滤列表里消失）。
   **实测推翻**：连接后仍为 true，设备同时在 `devices` 和 `connectedDevices` 里

**边栏/触控栏确实不能实时生效**（SidecarCore 只在会话打开时读配置），
所以 UI 上加了一行说明——否则是同一类"开关动了没反应"的问题。

### 这一轮的方法论转变（值得保留）

前两次 Sidecar 崩溃我是「改完装 app → 崩 → 看崩溃报告」。第三次起改成
**用同一份 bridging header 编独立小程序逐步打印**，一次定位一个坑。
后面所有的发现（NSUUID、`id` vs `id<Protocol>`、镜像双向验证、
`offersAdditionalDisplay` 假设的证伪）都是这么来的。

**凡是要在真机上验证的破坏性操作，先在独立进程里跑通，再进 app。**

### Phase 3c — 视觉重绘（完成 2026-08-15）

用户诉求原文：「现在这个面板其实够用，但是折叠层级太多，而且视觉上还是和系统风格不够统一。
但是如果折叠数量减少的话，很多选项会加重面板默认长度」——两个约束互相拉扯，所以拆成两步解。

| 切片 | 做了什么 | 结果 |
|---|---|---|
| 1 | 折叠改抽屉页（`PanelRoute`），11 个 flag 减到 4 个 | 默认面板不再承担所有展开项的高度 |
| 2 | 返回头 `PanelBackHeader` + 推入行 `PanelPushRow` | 层级从「就地展开」变成 Control Centre 的下钻模型 |
| 3 | `MenuItemIcon` 反转为白底彩字 | 之前是彩底白字，和系统反的 |
| 4 | `PanelCard` 分面 + 内外边距收紧 | 面板高度 588 → 698 → **654** |

**高度是有代价的，写下来免得以后忘**：卡片间距承担了原先分割线的分组作用，净涨 +66pt。
页面化省下来的空间被花掉了一部分。若日后还要压，第一刀应该砍卡片外边距而不是砍分组。

**顺带修掉一个真缺陷（不是重绘引入的，是重绘让它显形）**：
DDC/Software 徽章原先只在滑条视图出现时读一次状态，而显示器的拒绝要连续 3 个读周期才判定得出来
——徽章总是在「该说话的那一刻」还是空的，要等用户拖过滑条才出现。
改为 `BrightnessService` 在模式变化时发 `.candelaDDCAvailabilityChanged`，滑条订阅。
**实测**：M28U 上徽章自行出现，全程没碰滑条。

**仍未验证（不要当成已完成）**：
- 合成点击进不了这个面板的 SwiftUI 命中区（坐标点击 / System Events click / AXPress 全部失败），
  **任何交互路径的确认都必须由 James 手动做**——下钻、返回、卡片内的滑条都没被点过。
- Reduce Motion / Reduce Transparency 打开状态下的样子没截过图（`com.apple.universalaccess` 是受保护域）。
- Control Centre 的**下钻子页**始终没截到，切片 1-2 的版式参考只有根面板那一张截图。

### 坑：ad-hoc 签名会伪装成「授权已开但功能是死的」（2026-08-15 第二次踩到）

**这是同一个坑的第二次**。第一次修的是 TCC 里的僵尸记录，但没修产生僵尸记录的原因，
所以它长回来了。

`dev.sh` 找一个叫 `Candela Dev` 的自签名证书，找不到就**静默**走 ad-hoc 分支——
而那张证书从来没被创建过，钥匙串里躺着的 Developer ID 一次都没被用上。

**症状不指向签名**：ad-hoc 每次构建换 cdhash，TCC 认的是旧的，于是
系统设置里 Candela 的开关**显示是开的**，而 `AXIsProcessTrusted()` 对当前跑的二进制返回 false。
用户看到的是「权限给了、功能是死的、app 自己的开关还打不开」。

修法不是再 reset 一次，是让 dev 构建用**稳定身份**：
优先 `CANDELA_SIGN_ID` → 任意 Developer ID Application → 自签名 `Candela Dev` → ad-hoc（并大声警告）。
用 release 的同一张证书还有个附带好处：dev 构建拿到的授权能延续到正式发布版，
不会被第一次 release 作废。

**实测**：修复后 `/Applications/Candela.app` 的 `TeamIdentifier=K9YT36SP4B`（原先 `Signature=adhoc`）。

**未定**：系统设置 Privacy 列表里 Candela 没有图标。bundle 里 `AppIcon.icns` 是在的（Dock 渲染正常），
`release.sh` 手工组装 bundle、没有编译过的 Assets.car，所以加 `CFBundleIconName` 解析不了、不是解法。
**推断**是僵尸 TCC 记录解析不到 bundle 所致，重新授权后应自行恢复。
**如果我错了，最可能错在**：Privacy 列表可能只认 asset catalog 图标、根本不从裸 .icns 渲染，
那样重新授权后图标仍然空白，真正的解法是让 release.sh 产出 Assets.car。
判据就是重新授权后看那一眼。

### 多屏亮度一致：能做到什么、做不到什么（2026-08-15）

诉求：「多个屏幕一起调整时，实际亮度需要一致」。

**先说做不到的那部分，因为它决定了方案形状。**
**实测**：`NSScreen` 对 M28U 和 VX1622-4K 都只报 EDR=1.0、reference EDR=0.0，
即「SDR，无绝对亮度值」。macOS 不提供任何 nit 数据，**自动对齐绝对亮度没有依据可用**。
不要再冒出「自动校准」的方案，那需要色度计。

**已有的（更早做的）**：`SoftwareDimming` 用 EOTF(2.2) 反校正，把软件调光的**响应曲线形状**
拉回和 DDC 硬件调光一致。解决的是「同样降 20%，一个降一点一个几乎全黑」。

**这次新增**：`CombinedMapping` —— 每块屏一个**合并下限**，
即「合并滑条拉到最低时这块屏停在哪」。用眼睛校一次，之后所有合并调节都经过它。
- 顶端故意不校准：满亮度 = 各自面板的最大值。压低亮屏去迁就暗屏是在扔掉买来的亮度。
- 未校准 = 下限 0 = 和旧行为逐点相同，已经配好的桌面不会因为升级变差。
- 按 `displayUUID` 存，重新插拔后还在；只有接了 >1 块屏时才显示这张卡片。
- Combined 滑条和 `.combined` 快捷键模式**读和写都经过各自下限**——
  少了反向映射，被校准的屏会把共享滑块拽离它刚被设定的位置。

根因链条（DDC 显示器背光有下限、软件调光能到接近全黑）写在 `CombinedMapping` 的文档注释里。

### 坑：测试目标一直在拿 DerivedData 里的陈旧 module 编译

`CandelaTests` 里写着 `@testable import Candela`，但 project.yml **没有声明对 app target 的依赖**。
之前一直能过，靠的是 DerivedData 里恰好留着上次构建的 `Candela.swiftmodule`。
删掉 DerivedData（或像 CI 那样全新 checkout）**整个测试套件编译不过**。
已补依赖；**实测**：清空 DerivedData 后全套通过。

顺带：新加的纯模型文件必须同时加进 `CandelaTests.sources` 白名单，
否则符号链接不上（测试目标是把模型文件编译进自己，不链接 app）。

### 坑：不要在别的任务里顺手「补全」私有 API 头文件的 nullability

修上面那条时，测试目标的 `-Wnullability-completeness`（warnings-as-errors）开始报错。
我做了「正确」的修法：全文件 `NS_ASSUME_NONNULL` + 逐个标注。**编译干净，然后启动即崩**
——SIGTRAP 在 `DDCService.buildAVServiceMapByProximity()` 的 IOAVService 路径上。

**实测确定因果**：只把 header 还原、其余改动全部保留 → 不崩；换回新 header → 崩。
**机制没查清**（崩溃报告只到函数级，-O 内联后看不到具体 trap 点）。

选择：在头文件里 `#pragma clang diagnostic ignored "-Wnullability-completeness"`，
Swift 导入类型一个字节不变，零运行时风险。**没有把「猜出来的 nullability」写进代码。**
真要审计这个头文件，应该单独做一次改动，前后都在真实硬件上跑 DDC 路径。

**未验证**：合并下限的**端到端行为**（拖校准滑条、看两块屏在最低点是否一致）
必须由 James 手动做——合成点击进不了这个面板的命中区。数学部分有 11 个单元测试覆盖。

## HUMAN QUEUE（只有 James 能做）

| # | 事项 | 卡住了什么 | 状态 |
|---|---|---|---|
| 1 | ~~决定是否接受签名证书显示~~ **"Orris Technology Pty Ltd"** —— Developer ID 证书主体是法律实体名，用户在 Gatekeeper 和 `codesign -dv` 里会看到。全局规则「客户邮件不提 Orris」不覆盖代码签名，但开源项目会暴露实体名，需要你确认接受 | Phase 5 公证 | ✅ 2026-08-14 已同意 |
| 2 | 注册域名 `candela.app`（实测未注册）—— 或决定只用 GitHub Pages 不买域名 | Phase 5 落地页 | ⏳ 待决 |
| 3 | 创建 GitHub 仓库（public），决定仓库名 `candela` 还是 `Candela` | Phase 5 | ⏳ 待做 |
| 4 | `xcrun notarytool store-credentials <profile> --apple-id <id> --team-id K9YT36SP4B --password <app 专用密码>` —— 交互式。之后发布时 `CANDELA_NOTARY_PROFILE=<profile>` | **`--publish` 现在会硬性拒绝没有公证的发布**（未公证的 Developer ID 包 Gatekeeper 直接拦，实测 `spctl` 判 `Unnotarized Developer ID`） | ⏳ 待做 |
| 5 | 建 Homebrew tap 仓库 `iamzifei/homebrew-tap`（空的 public 仓库即可，cask 首发时会自动种进去） | 发布前置检查会拒绝 tap 不存在的发布 | ⏳ 待做 |
| 6 | App icon 视觉方向拍板 | Phase 4 | ✅ 2026-08-14 选定 B 亮度弧 |
| 9 | **（可选）用 Icon Composer 做分层 `.icon`** —— GUI 无法无头驱动。打开 Icon Composer（在 Xcode 里：`/Applications/Xcode.app/Contents/Applications/Icon Composer.app`），导入 `/Users/james/Dev/candela/design/candela-icon-{light,dark,mono}.svg` 作为三个外观的图层，导出 `.icon` 放进仓库。收益＝Liquid Glass 的分层折射/高光/「明晰」外观。**不做也能发布**，现在 ship 的扁平 icns 完全可用 | Phase 4 收尾 | ⏳ 可选 |
| 7 | **面板 UI 回归**：点菜单栏 Candela 图标（在 Ice 隐藏区里），确认两台屏都列出、拖亮度滑块 VX1622 会变、切分辨率正常 | Phase 1 收尾 | ⏳ 待做，2 分钟 |
| 8 | **M28U 的 OSD 菜单里找 DDC/CI 并打开**（Gigabyte M 系列一般在 Settings → Other Settings）。若菜单里本来就是开的，那问题在 Anker Prime Dock 不透传 DDC，需换直连 Mac 的线再测 | 主屏硬件亮度控制 | ⏳ 待做 |

## Phase 5 进展（2026-08-15）

**已做完、且实测验证过的：**

| 事项 | 验证方式 |
|---|---|
| 发布包用 Developer ID + hardened runtime 签名 | 干跑后 `codesign -dv`：`flags=0x10000(runtime)`、`TeamIdentifier=K9YT36SP4B`、satisfies its Designated Requirement |
| `dev.sh` / `release.sh` 都不再静默降级 ad-hoc | 两个脚本改为自动发现钥匙串里的 Developer ID；`release.sh --publish` 无证书直接报错退出 |
| `--publish` 无公证时拒绝发布 | 未公证包 `spctl` 实测判 `rejected / source=Unnotarized Developer ID` |
| 所有会失败的检查前移到 `gh release create` 之前 | 原先 tap 更新在建 release 之后，首发必 404，留下半个已公开的 release |
| 首发时自动种 cask | `packaging/candela.rb`，tap 里没有就用它建 |
| cask 能被 Homebrew 正确解析 | 建临时本地 tap 实测：`brew info` 解析出 `arm64 architecture, macOS >= 26` |
| 裸符号 `:tahoe` = 「26 或更新」而非「恰好 26」 | 实测两种写法 `brew info` 都输出 `macOS >= 26`；写错会导致 macOS 27 装不上 |
| 中英繁三语翻译完整 | `check-translations.py`：`All strings translated for: zh-Hans, zh-Hant` |

**剩下的全部是 HUMAN QUEUE 里的三件事**：建 GitHub 仓库、建 tap 仓库、跑 `notarytool store-credentials`。
代码侧没有已知阻塞项。

## 回归测试清单（每个 Phase 结束后手测）

真机上必须逐条过，编译通过不等于能用：

1. 两台外接显示器都出现在面板里，名字正确
2. DDC 亮度：单屏调节生效（看得见背光变化，不是软件调暗）
3. DDC 亮度：全屏同步调节
4. 亮度快捷键（F1/F2）按配置的目标生效
5. 分辨率切换：HiDPI 模式列表出现，切换后不掉刷新率
6. 排列：拖拽改变位置，系统设置里同步
7. 虚拟显示器：创建 + 删除
8. 预设：保存 + 应用
9. 面板开合动画不掉帧
