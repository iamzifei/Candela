# Candela 站点与发布素材

**目标**：把 `docs/` 从「Crisp 的站点」改造成 Candela 自己的双语站点，配齐 SEO 文章与真实素材，
并让 README 有 banner / demo。

**非目标**：不注册 `candela.app`（站点走已有的 `zifei.info`）；不做 blog 系统；
不为 SEO 写凑数的长尾页。

---

## 起点事实（2026-08-15 实测）

- `docs/` 下 6 个 HTML **全部 100% Crisp 品牌，0 处 Candela**。Phase 1 的改名从未触及 `docs/*.html`。
- 站点本身质量不低：OG tags、JSON-LD（SoftwareApplication + VideoObject）、hreflang、canonical 都齐。
  **结构可以学，正文必须重写。**
- `docs/` 里的 `screenshot.png`、`demo.mp4`、`demo-*.gif` 是 **Crisp 的旧界面**，
  和 Candela 现在的卡片式面板完全不同，全部作废重拍。
- JSON-LD 里 `author` 是 Didrik Galteland。MIT 允许 fork 修改，但**不得冒名**，
  且上游署名要保留在 README。

## 三条已定的判断（不再重开）

1. **下载链接用 Candela 自己的**：`https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg`。
   用户原话给的是 Crisp 的 DMG，是笔误——放上去会把用户送去另一个 app。
2. **文章重写，不做查找替换**。Crisp 的站点已被索引，改名版构成近似重复内容，
   是 SEO 上最坏的结果（两个站互相稀释，且新站没有权重打不过老站）。
3. **每种语言独立 URL**（`/` 与 `/zh/`），配 hreflang。
   单页 JS 切换会让搜索引擎只看到一种语言，等于放弃另一半流量。

## 阶段

### S1 — 基建（✅ 2026-08-15 完成）
- [x] `gh repo create Candela --public` → https://github.com/iamzifei/Candela
- [x] `gh repo create homebrew-tap --public`
- [x] `notarytool store-credentials candela-notary`（**实测** Credentials validated）
- [x] 代码推送 main

### S2 — 素材（截图 / 录屏）✅ 完成
合成点击进不了面板的 SwiftUI 命中区（本项目已多次实测），所以：
- [x] 加一个调试用的初始路由环境变量，让每个页面都能被无头截图
- [x] 逐页截图：根面板、显示器详情页、全部分辨率、Tools、Settings、Sidecar
- [x] banner 图（README 顶部）
- [x] demo GIF：由路由切换序列合成（能表现下钻导航；**滑条拖动这类需要真人**）
- [x] OG card（1200×630）英文 + 中文

**验收**：每张图里出现的是 Candela 当前的卡片式面板，不是 Crisp 旧界面。

### S3 — 站点骨架 ✅ 完成
- [x] 样式表**重写**（`site/styles.css`），没有沿用上游的视觉
- [x] `docs/index.html` 重写（EN）
- [x] `docs/zh/index.html`（简中）
- [x] 语言切换：顶部切换链接 + 首访 `navigator.language` 自动跳转（**默认英文**；
      跳转结果写 localStorage，手动选择后不再自动跳，否则用户永远回不到英文页）
- [x] 顶部固定：下载按钮 + Ko-fi（https://ko-fi.com/iamzifei）
- [x] `sitemap.xml`、`robots.txt`、canonical、hreflang 全部指向 **zifei.info/Candela**（见下方域名说明）

### S4 — 文章 ✅ 完成（6 页 × 2 语言 = 12 页）
| # | slug | 目标关键词 |
|---|---|---|
| 1 | `candela-vs-betterdisplay.html` | betterdisplay alternative / lunar alternative / free |
| 2 | `fix-blurry-external-monitor-macos.html` | blurry external monitor mac |
| 3 | `enable-hidpi-mac.html` | enable hidpi mac / mac hidpi scaling |
| 4 | `mac-brightness-keys-external-monitor.html` | brightness keys external monitor mac |
| 5 | `sync-brightness-multiple-monitors-mac.html` | sync brightness multiple monitors mac |

**每篇的验收标准**（不满足不算完成）：
- 单一主关键词，出现在 title / H1 / URL / 首段 / 至少一个 H2
- title ≤ 60 字符，meta description 120–158 字符
- 有 H2/H3 层级，可被摘要成 featured snippet 的直答段落
- 至少 2 张真实截图，`alt` 描述内容而非堆关键词
- 内链到其他文章与首页；外链到权威来源（Apple 文档、VESA DDC/CI 规范）
- 不写 Candela 做不到的事；**竞品对比只写可验证的事实**（价格、许可、是否开源）

### S5 — README ✅ 完成
- [x] banner 图 / demo
- [x] 中英切换（`README.md` + `README.zh-Hans.md`，顶部互链）
- [x] 修掉 `macOS 14+` 徽章（**实际是 macOS 26 only**，现在是错的）
- [x] 保留对上游 Crisp 的署名

## 上线状态（2026-08-15 实测）

- 仓库：https://github.com/iamzifei/Candela （public）
- tap：https://github.com/iamzifei/homebrew-tap （空，首发时自动种 cask）
- 公证凭据：钥匙串 profile `candela-notary`，**实测** `Credentials validated`
- **站点已上线**：https://zifei.info/Candela/ 返回 200

⚠️ **站点域名不是 github.io。** 账号主站 `iamzifei.github.io` 的 CNAME 是 `zifei.info`，
所以项目页服务于 `https://zifei.info/Candela/`，github.io 地址会 301 跳过来。
canonical / hreflang / og:url / JSON-LD 全部已指向 zifei.info——
拿一个会跳转的地址当 canonical，等于告诉搜索引擎每一页的家都在错的地方。

### 已在真实浏览器里验证并修掉的三件事

1. 导航栏下载按钮是**深灰字配蓝底**——`.nav-links > a` 的选择器优先级压过了 `.btn-dl`。
   本地看文件看不出来。
2. 首屏截图**占满整个视口**，全部文字被推到折叠线以下。面板截图是竖长的，
   只按宽度约束不够，要按高度。
3. `styles.css` **没有缓存失效机制**，修好的样式对老访客不可见。已改为内容哈希查询串。

### S6 — 发布（未做）

- [ ] `CANDELA_NOTARY_PROFILE=candela-notary ./scripts/release.sh v0.1.0 notes.md --publish`
- [ ] 验证 `spctl` 判 accepted、`brew install --cask iamzifei/tap/candela` 能装

## HUMAN QUEUE

| # | 事项 | 卡住什么 |
|---|---|---|
| 1 | **撤销并重发 app 专用密码**（appleid.apple.com）——它出现在 2026-08-15 的对话记录里 | 安全，非阻塞 |
| 2 | **录一段真人操作的 demo**（拖亮度滑条、切分辨率、下钻返回）——合成事件进不了面板命中区。已有的 `docs/tour.gif` 是页面序列合成的，能表现结构但没有真实交互 | README / 首页的动态素材 |
| 3 | 决定要不要注册 `candela.app` 域名 | 只影响 canonical，Pages 可先上 |
