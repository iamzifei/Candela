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

## Phase 3 — Liquid Glass 原生化

**做什么**
- [ ] SwiftUI 层用原生 `glassEffect(_:in:)` / `GlassEffectContainer` /
      `.buttonStyle(.glass)` 替换手搓的材质与 chip（`MenuItemIcon`、`PanelBlocks`、
      `ScreenEffectsView` 的圆形按钮行）
- [ ] 滑块（亮度/分辨率/音量）改用 macOS 26 规范的控件形制
- [ ] 用 `GlassEffectContainer` 统一面板内多个玻璃元素，避免各自为政的折射
- [ ] 检查深浅色、强调色、增强对比度、减弱动态四种系统设置下的表现

**验收标准**
- 面板截图与系统「控制中心」并排对比，材质、圆角、间距、字重一致
- 四种辅助功能设置下均不塌陷（尤其「减弱动态」要关掉玻璃动画）
- 无自定义颜色硬编码，全部走 semantic color

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
