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
- [ ] **切片 3 · AppDelegate 拆分**：类体 617 行、单函数 162 行。把
      `setupStatusItem` / 面板构建 / 通知订阅拆成 extension 或独立类型。
      ⚠️ 这是全项目最高冲突面，放在切片 3 而不是切片 1 就是这个原因
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
- [ ] 无障碍：VoiceOver 能读出每个滑条的标签与当前值（当前未验证）

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

## Phase 4 — App Icon（macOS 26 规范）

**做什么**
- [ ] 用 **Icon Composer**（Xcode 26 内置）做分层 `.icon`，而非 Crisp 的扁平 `.icns`
- [ ] 视觉母题：Candela = 亮度单位 → 发光体 / 光强刻度。需支持 Liquid Glass 的
      分层折射、高光、深色/浅色/单色/明晰四种外观
- [ ] 弃用 `scripts/generate-icon.swift`（或改造为生成 .icon 的源素材）
- [ ] 菜单栏图标（template image）单独设计，16pt 下必须可读

**验收标准**
- Dock、Launchpad、Finder、系统设置四处显示正常
- 浅色/深色/单色/明晰四种外观各截一张图确认
- 菜单栏图标在浅色和深色菜单栏下都清晰

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

## HUMAN QUEUE（只有 James 能做）

| # | 事项 | 卡住了什么 | 状态 |
|---|---|---|---|
| 1 | 决定是否接受签名证书显示 **"Orris Technology Pty Ltd"** —— Developer ID 证书主体是法律实体名，用户在 Gatekeeper 和 `codesign -dv` 里会看到。全局规则「客户邮件不提 Orris」不覆盖代码签名，但开源项目会暴露实体名，需要你确认接受 | Phase 5 公证 | ⏳ 待决 |
| 2 | 注册域名 `candela.app`（实测未注册）—— 或决定只用 GitHub Pages 不买域名 | Phase 5 落地页 | ⏳ 待决 |
| 3 | 创建 GitHub 仓库（public），决定仓库名 `candela` 还是 `Candela` | Phase 5 | ⏳ 待做 |
| 4 | `xcrun notarytool store-credentials` —— 需要 Apple ID + app-specific password，交互式 | Phase 5 公证 | ⏳ 待做 |
| 5 | 建 Homebrew tap 仓库 `homebrew-tap` | Phase 5 分发 | ⏳ 待做 |
| 6 | App icon 视觉方向拍板（我出候选，你选） | Phase 4 | ⏳ 待做 |
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
