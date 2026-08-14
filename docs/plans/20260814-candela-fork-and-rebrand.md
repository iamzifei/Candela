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

## Phase 1 — 仓库与品牌骨架

**做什么**
- [ ] 目录/文件重命名：`Crisp/` → `Candela/`，`CrispTests/` → `CandelaTests/`，
      `Crisp-Bridging-Header.h` → `Candela-Bridging-Header.h`
- [ ] 262 处 `Crisp` 字样替换（代码 / project.yml / Makefile / dev.sh / scripts/）
- [ ] Bundle ID `com.crisp.app` → `com.candela.app`；Logger subsystem、DispatchQueue label 同步
- [ ] UserDefaults key 前缀 `crisp.` → `candela.`，**复用上游已有的
      `didMigrateLegacyDefaults` 机制写一次性迁移**（否则老 Crisp 用户切过来会丢全部设置）
- [ ] LICENSE 保留原 MIT + 追加 Candela 的版权行；ACKNOWLEDGMENTS.md 明确标注 fork 自 Crisp
- [ ] `UpdateService.swift` 的 repoOwner/repoName 指向自己的仓库
- [ ] 版本号重置为 `0.1.0`，build 号 `1`

**验收标准**
- `make compile` 通过且**零警告**（与基线一致）
- `grep -ri crisp Candela/ scripts/ *.yml Makefile dev.sh` 只剩 ACKNOWLEDGMENTS / LICENSE 的归属声明
- `git log` 保留上游 371 条历史；`git remote -v` 有 upstream
- 在真机上跑起来，两台外接显示器都能识别、能调亮度（回归验证，不是编译验证）

---

## Phase 2 — 收窄到 macOS 26

**做什么**
- [ ] `project.yml` deploymentTarget 14.0 → 26.0；`SWIFT_VERSION` 5 → 6，
      `SWIFT_STRICT_CONCURRENCY` minimal → complete（分步做，可能暴露并发问题）
- [ ] 删除所有 `#available(macOS 26.0, *)` 的 else 分支（AppDelegate 的
      NSVisualEffectView 回退等），代码直取新 API
- [ ] 审掉为旧系统写的兼容代码路径（`AutoBrightnessService` 里已标注在 26 上失效的
      CoreDisplay 回退等）
- [ ] Makefile / dev.sh 的 swiftc flags 同步更新

**验收标准**
- 零 `#available(macOS` 判断残留（除非确有 26.x 小版本差异，且写明原因）
- `make compile` 零警告
- 真机回归：分辨率切换、DDC 亮度、虚拟屏创建、排列拖拽，四项逐一手测通过

**⚠ 风险**：`SWIFT_STRICT_CONCURRENCY: complete` 可能引出大量 Sendable 报错
（Services 层大量 `@unchecked Sendable` 单例）。若一次改不完，**独立成 Phase 2b，
不阻塞后续**，先只做 deploymentTarget 收窄。

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
