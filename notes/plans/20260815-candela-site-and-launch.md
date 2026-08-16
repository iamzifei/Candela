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

### S6 — 发布

**除了最后一步，全部实测跑通（2026-08-15）：**

| 检查 | 结果 |
|---|---|
| Apple 公证 | `status: Accepted` |
| 票据装订 | `The staple and validate action worked!` |
| `spctl`（构建产物） | **accepted · source=Notarized Developer ID** |
| `spctl`（DMG 里取出的那份） | **accepted** |
| hardened runtime | `flags=0x10000(runtime)` |
| DMG | 2.2 MB |

发布说明草稿：`/Users/james/Dev/candela/notes/releases/v0.1.0.md`

- [x] **v0.1.0 已发布**（2026-08-16）：https://github.com/iamzifei/Candela/releases/tag/v0.1.0
- [x] 真机功能回归由 James 完成（含语言切换）
- [x] 发布后实测（**用真实下载链路，不是本地产物**）：
      DMG sha256 与 cask 记录逐位一致；`spctl` 判 **accepted · Notarized Developer ID**；
      `brew fetch --cask iamzifei/tap/candela` 通过（tap 解析、URL、校验和均正确）

### 发布时抓到的一个严重隐患

`gh release create` 没带 `--repo`，而 gh 会从 git remote 解析仓库——
这个工作副本有 `upstream` 指向 fork 来源，**gh 解析到的是 `didriksg/Crisp`**
（`gh repo view` 实测返回上游）。也就是说发布步骤一直在试图把 Candela 的 release
**发到别人的仓库上**。是没有写权限救了这一次；gh 报的是「可能缺 workflow scope」，
那是猜测，还把排查方向带偏了。

前置检查本来就从 `origin` 算出了正确仓库，只是发布命令没用它。已改为显式 `--repo`。

### 发布目录的清理（2026-08-15）

`docs/` 既是开发文档目录又是 Pages 根目录，于是设计文档、构建指南、**以及我的计划文件**
全部可被公开访问（实测均为 200）。已移到 `notes/`，线上现在全部 404。
**扫描确认没有任何凭据外泄**，但计划文件里确实讨论了「有哪些凭据」。

⚠️ **这与全局约定「计划放 `<项目>/docs/plans/`」冲突**——冲突来自 Pages 的目录占用，
不是偏好。若日后改用可指定目录的 Pages workflow，`docs/` 腾出来就能搬回去。
理由写在 `notes/README.md`。

顺带修掉：`BUILDING.md` 里的编译命令引用 `Crisp/Crisp-Bridging-Header.h`，
**那个路径不存在，照着敲会直接失败**。

## S7 — 视觉方向改为 kami + 杂志编排（2026-08-15 下午）

参考 [mole.fit](https://mole.fit/) 与 kami（紙）设计系统。**版面语言按 kami，
苹果规范只取行为与无障碍那部分**——两者争的不是同一件事。

| 做了什么 | 为什么 |
|---|---|
| 浮动药丸导航（sticky、纯色纸底 + 细边） | kami 禁 `backdrop-filter`；纸上的报头本来就是不透明的 |
| 编号栏目标签 `01 ·` | craft floor 允许「序列本身带信息」的编号；长页面上它告诉读者位置 |
| 图文左右交替行 + 带 ❖ 的分隔线 | 原来是整墙散文；证据挨着主张，交替避免六条变成一个可以直接划过去的图案 |
| 正文改短条目 | 同上 |
| 截图转 WebP（1.6MB → 44K，37×） | 首屏那张是 LCP，原先还标了 lazy，导致最重要的图最后才到 |

### 三个必须记住的技术坑

1. **中文栈里宋体在前 → 拉丁字母是宋体渲染的**（细、小）。「macOS」比旁边的汉字小一号就是这个原因。
   拉丁字体必须排在 CJK 前面，并 `size-adjust: 112%`——
   CJK 字形填满 em 框，拉丁只占 x-height + ascender，同样字号下视觉上就是小。
2. **`ch` 是「0」的宽度，是拉丁单位。** 用它给中文标题设 measure，会把标题压成窄窄的四行。
   中文要用 `em`。
3. **Markdown 里单独一行的图片仍是 inline**，mistune 会把 `<figure>` 包进 `<p>`。
   这是无效 HTML（浏览器会强行断开），并且**静默地让所有针对 figure 的兄弟选择器失效**。

### 一个流程坑（害我误判两次）

「轮询 URL 直到出现某字符串」在**字符串本来就在**时会立刻通过。
只改了 HTML 时去等 CSS 哈希 → 循环秒过 → 下一张截图拍的是上一次部署。
据此我先后判定「某条 CSS 规则没生效」和「某个选择器没匹配」，**两条都是错的**。
已改为 `scripts/wait-for-deploy.sh`，按 commit SHA 等 Actions 的 Pages 部署。
（注意：**不能用 `repos/*/pages/builds/latest`**，那是旧的分支构建 API，
在走 Actions 部署的仓库上会一直报上一个 commit；也不能用
`--workflow "pages build and deployment"`，那个动态 workflow 在仓库里没有文件。）

### 已验证 / 未验证

**实测**：`.hero + .shot` 匹配成功、`max-height` 计算值 623.76px = 46vh；
下载按钮 `44px` 高（苹果触控目标）；桌面两栏 `420px 420px`；
浅色最低对比度 4.92:1、深色 5.54:1；CI 已转绿。

✅ **已验证（2026-08-16）**。`resize_window` 始终无效（`innerWidth` 恒为 2323），
改用**页面内固定宽度的 iframe**——媒体查询按 iframe 宽度求值，是真实的响应式计算，
而且可截图。实测 390 / 430 / 320 三种宽度：导航 54px 单行、语言与下载按钮都在、
触控目标 44px、无横向滚动、行内图单栏、页脚 5 个链接兜底；
`heroSrc` 取到 `panel-root-480.webp`，说明 srcset 生效。

## S8 — 手机端（2026-08-15）

**终于能真的看到手机宽度了**：`resize_window` 一直无效，改用**页面内 390px iframe**
——媒体查询按 iframe 宽度求值，是真实的响应式计算，且可截图。

### 修掉的

| 症状 | 实测 | 根因 |
|---|---|---|
| 导航悬浮且被撑大 | 390px 下 **3 行、160px 高**（844px 屏的 19%） | `flex-wrap: wrap` + 每项 `min-height:44px` + `radius:999px`。放不下就长高，而不是舍弃内容 |
| `.hide-sm` 从未生效 | 「指南」在任何宽度都在 | `.nav-links > a`（0,1,1）压过 `.hide-sm`（0,1,0）。**和下载按钮变深灰是同一个陷阱** |
| 手机上下载按钮消失 | `navItems` 只剩语言 | 我用 `[href^="https://github.com"]` 藏 GitHub 链接，而**下载地址也是 github.com**。把页面唯一的行动藏了 |
| 中文标题断词 | 32px 在 335px 栏里每行只装 10 字 | CSS 无法阻止中文在词中断行。解法是**把标题写短**，不是继续调参数 |
| 手机下载整幅原图 | 无 `srcset` | 1380×1482 ≈ 200 万像素、解码后约 8MB，首页 6 张 |

**现状（实测）**：导航 54px 单行、语言 + 下载都在、触控 44px、320px 无横向滚动、
页脚 5 个链接兜底；手机取 `panel-root-480.webp`（13.7KB / 480px）。

### 一个我自己犯的判断错误

我一度断定「480px 变体是坏的」——依据是 iframe 里 `naturalWidth: 0`。
**那是离屏 iframe 不解码图片的假象。** 直接 `new Image()` 加载测试：
480×515、960×1031、1380×1482 全部正常。**测量位置的产物，不是世界的状态。**

### `wait-for-deploy` 的第三版

前两版都以「给出错误结论」而非「报错」的方式失败：
1. 轮询字符串——字符串本来就在时秒过；
2. 等 GitHub 的部署记录——GitHub 会合并连续推送，内容已上线的 commit 可能永远不出现在
   deployments API 里。**实测**：线上 CSS 与本地逐字节一致，而 API 仍报上一个 commit。

第三版改为**逐字节比对** styles.css + 两种语言的首页。字节不会「提前为真」，也不会「滞后为假」。

**未验证**：`text-wrap: balance` 那次中文标题均分两行的**视觉结果**——
浏览器渲染进程在那一轮反复冻结。数值上标题是 2 行 28px、无横向滚动。

## HUMAN QUEUE

| # | 事项 | 卡住什么 |
|---|---|---|
| 1 | **撤销并重发 app 专用密码**（appleid.apple.com）——它出现在 2026-08-15 的对话记录里 | 安全，非阻塞 |
| 2 | **录一段真人操作的 demo**（拖亮度滑条、切分辨率、下钻返回）——合成事件进不了面板命中区。已有的 `docs/tour.gif` 是页面序列合成的，能表现结构但没有真实交互 | README / 首页的动态素材 |
| 3 | 决定要不要注册 `candela.app` 域名 | 只影响 canonical，Pages 可先上 |
| 4 | **用手机打开 https://zifei.info/Candela/ 看一眼**——我这边窗口缩不下去，手机版式始终没验到 | 移动端 |
