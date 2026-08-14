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

- [ ] 先补这一张对照截图，再决定差异 3 改不改
- [ ] 引入分组玻璃卡片（差异 1），用 `GlassEffectContainer` 统一折射
- [ ] 滑条加分组标题（差异 2）
- [ ] 四种系统设置下逐一截图验证：深色/浅色 · 增强对比度 · **减弱动态**（必须关掉
      玻璃动画）· 大字体
- [ ] 无障碍：VoiceOver 能读出每个滑条的标签与当前值

### 🔴 已发现的无障碍问题（2026-08-14 实测，待修）

**折叠区块的内容仍在 AX 树里。** 面板收起状态下遍历 accessibility 树，能读到
「Contrast / Gamma / Gain / Color Temp / Quantization / Gamma R·G·B」这些
**属于已折叠的显示器详情**的标签与值。

- **推断**：VoiceOver 会念出用户看不见的内容。根因是这个面板「先渲染再裁剪」
  （`PanelCanvas` 把内容按自然高度渲染一次，再用 clip 层做动画——那正是它
  120Hz 不掉帧的原因），不是条件渲染，所以块一直存在
- **如果我错了，最可能错在**：clip 层可能已设 `accessibilityElementsHidden`，
  而 System Events 的遍历绕过了它。**修之前先用真 VoiceOver 验一遍**
- 修法方向：给 clip 的 host view 设 `accessibilityElementsHidden = !isOpen`，
  在 `PanelCanvas` 更新 target 时同步。⚠️ 不要改成条件渲染，那会毁掉整个动画方案

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

## Phase 6 — 上游同步机制

**做什么**
- [ ] 写 `docs/UPSTREAM.md`：如何 `git merge upstream/main`、哪些文件必然冲突
      （project.yml / Makefile / 品牌字符串）、冲突解法
- [ ] 首次演练一次 merge

**验收标准**
- 文档写完并实际演练过一次，合并后 `make compile` 仍零警告

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

## HUMAN QUEUE（只有 James 能做）

| # | 事项 | 卡住了什么 | 状态 |
|---|---|---|---|
| 1 | 决定是否接受签名证书显示 **"Orris Technology Pty Ltd"** —— Developer ID 证书主体是法律实体名，用户在 Gatekeeper 和 `codesign -dv` 里会看到。全局规则「客户邮件不提 Orris」不覆盖代码签名，但开源项目会暴露实体名，需要你确认接受 | Phase 5 公证 | ⏳ 待决 |
| 2 | 注册域名 `candela.app`（实测未注册）—— 或决定只用 GitHub Pages 不买域名 | Phase 5 落地页 | ⏳ 待决 |
| 3 | 创建 GitHub 仓库（public），决定仓库名 `candela` 还是 `Candela` | Phase 5 | ⏳ 待做 |
| 4 | `xcrun notarytool store-credentials` —— 需要 Apple ID + app-specific password，交互式 | Phase 5 公证 | ⏳ 待做 |
| 5 | 建 Homebrew tap 仓库 `homebrew-tap` | Phase 5 分发 | ⏳ 待做 |
| 6 | App icon 视觉方向拍板 | Phase 4 | ✅ 2026-08-14 选定 B 亮度弧 |
| 9 | **（可选）用 Icon Composer 做分层 `.icon`** —— GUI 无法无头驱动。打开 Icon Composer（在 Xcode 里：`/Applications/Xcode.app/Contents/Applications/Icon Composer.app`），导入 `/Users/james/Dev/candela/design/candela-icon-{light,dark,mono}.svg` 作为三个外观的图层，导出 `.icon` 放进仓库。收益＝Liquid Glass 的分层折射/高光/「明晰」外观。**不做也能发布**，现在 ship 的扁平 icns 完全可用 | Phase 4 收尾 | ⏳ 可选 |
| 7 | **面板 UI 回归**：点菜单栏 Candela 图标（在 Ice 隐藏区里），确认两台屏都列出、拖亮度滑块 VX1622 会变、切分辨率正常 | Phase 1 收尾 | ⏳ 待做，2 分钟 |
| 8 | **M28U 的 OSD 菜单里找 DDC/CI 并打开**（Gigabyte M 系列一般在 Settings → Other Settings）。若菜单里本来就是开的，那问题在 Anker Prime Dock 不透传 DDC，需换直连 Mac 的线再测 | 主屏硬件亮度控制 | ⏳ 待做 |

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
