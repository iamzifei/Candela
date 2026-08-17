---
project: Candela
status: done
created: 2026-08-16
owner: James (Zifei Gong)
repo: /Users/james/Dev/candela
supersedes-decision: notes/plans/20260815-candela-site-and-launch.md 的「非目标：不注册域名」
---

# Candela 独立域名 + 官网 v2（视频 hero + 新截图）

## Goal

给 Candela 一个自己的域名和一版重做的官网：hero 放 1 分钟产品演示视频，features 区块
用同风格截图（都要带 menu bar），手机友好、加载极快、符合 macOS app 的设计规范。

## 已锁定的决策（2026-08-16，用户确认，不要重开）

| 项 | 决定 | 依据 |
|---|---|---|
| 域名 | **getcandela.app**（$9.99/年，Vercel 注册商） | candela.app/.dev/.tools/.design 实测均已注册；.app 强制 HTTPS + HSTS preload，语义上就是「这是个 app」 |
| 部署 | **继续 GitHub Pages**，新域名设为 Candela 仓库的 Pages 自定义域名 | GitHub 会自动把 zifei.info/Candela/* 301 到新域名，是保住已收录 SEO 权重最干净的路径 |
| 视频形式 | **无人声 + 字卡/字幕**，hero 里 muted autoplay loop | 自动播放必须静音，旁白等于白做；改文案不用重录；中英双语共用一条视频 |
| 站点生成 | 沿用 `site/build.py` → `docs/`，不引入前端框架 | 静态 HTML 是「速度极快」的最短路径，现有流水线已验证 |

## 起点事实（2026-08-16 实测）

- 现有站点在线：https://zifei.info/Candela/ ，双语 EN + zh，6 页 × 2 语言。
- 现有截图（`docs/shots/panel-*.webp`）**已经包含 menu bar**，但底衬是一片灰绿渐变，
  暗面板压在暗背景上，对比度弱；菜单栏里混着微信等第三方图标。→ 重拍。
- `scripts/capture-screenshots.sh` 已能按路由无头逐页截图，两个坑（用二进制启动而非
  `open -a`、按 window ID 而非屏幕矩形截图）已在脚本注释里记录，**复用不重写**。
- 录屏可行：`screencapture -V` **实测**产出 3600×2338 @ ~25.8fps 的 h264，权限已授予。
- 工具链齐：ffmpeg / magick / cliclick / gh / vercel CLI 均在。
- 已安装 app 版本 0.1.1。

## ⚠️ 一条被推翻的旧结论

`20260814-candela-fork-and-rebrand.md` 写着「.app / .dev 域名实测均未注册（RDAP 直连
Google Registry 查证）」。**这条是错的。** 那次查的是 `www.registry.google/rdap/...`，
该主机根本不提供 RDAP，返回的 404 是「路径不存在」，被读成了「域名可注册」。
正确 endpoint 是 `pubapi.registry.google/rdap/...`（或走 rdap.org bootstrap），
实测 candela.app 已注册在 GoDaddy 名下。**判定「不存在」之前先确认查的是对的地方。**

## 阶段

### P0 — 域名与 DNS ✅ 完成 2026-08-17
- [x] **getcandela.app 已注册**（Vercel，Orris team，2027-08-17 到期，续费 $15/年）
- [x] DNS：apex 4×A + 4×AAAA 指 GitHub Pages，`www` CNAME → `iamzifei.github.io`（`vercel dns add`）
- [x] Pages 自定义域名 + Enforce HTTPS（`gh api`），证书 `approved`
- [x] 全站 URL 迁移 + 两个 README 的链接
- [x] **实测**：新域名及 /zh/、文章页、视频、截图、sitemap 全部 200；
      `zifei.info/Candela/*` **逐页** 301 到对应新 URL；`www` 与 `http` 均 301 到 apex；
      线上 mp4 的 sha256 与本地产物逐位一致

⚠️ **agent 不能代购域名**（本次实测）：MCP token 报权限不足；`vercel domains buy` 直接返回
`purchase_requires_user` —— *"Agents must not purchase domains on behalf of a user"*。
这是 Vercel 的产品策略，不是可配置项。**购买必须 James 本人交互执行**；
买完之后 `vercel dns add` 与 `gh api ... /pages` 都可由 agent 完成。

顺带发现：Vercel 新建 zone 的默认 CAA 已包含 `letsencrypt.org`，
所以 GitHub Pages 签证书没被挡——**若 CAA 少了这条，HTTPS 会静默签不出来**。

### P1 — 素材（视频 + 截图）✅ 完成 2026-08-16
- [x] `scripts/record-demo.sh`：受控底衬 + AX 定位 + 真实鼠标事件，6 段素材
- [x] `scripts/candela-ax.py`：按无障碍标签定位面板控件（新增）
- [x] ChatCut 剪成 **60.0 秒整**（1800 帧 @30fps），8 段字卡 + 片尾
- [x] web 版：`hero-1080.mp4` 2.09 MB / `hero-1080.webm` 1.22 MB / `hero-720.mp4` 1.10 MB / `poster.webp` 40 KB
- [x] 全套截图重拍（7 张 × 3 档 WebP），含 menu bar，与视频同底衬同显示器

**素材路径**（全部在仓库内）:
- 视频成品：`/Users/james/Dev/candela/assets/video/hero-1080.mp4`（及 `.webm` / `hero-720.mp4` / `poster.webp`）
- 母版：`/Users/james/Dev/candela/assets/video/candela-hero-60s.mp4`（12.6 MB，1920×1080）
- 原始素材：`/Users/james/Dev/candela/assets/footage/*.mp4`
- 截图：`/Users/james/Dev/candela/docs/shots/panel-*.webp`
- ChatCut 工程：https://app.chatcut.io/editor/6b794fdc-3a15-45bd-a82f-d0645a47df6c

⚠️ **片尾字卡里写死了 `getcandela.app`**。若最终换域名，改 End card 资产的 `domain` 属性后重新导出即可（约 5 分钟），不必重录。

#### 这一步踩到并已修掉的四个坑（都写进了脚本注释）
1. **面板关闭后不会离开窗口列表**——仍报 `IsOnscreen=True`，只是 alpha=0；无障碍树还会继续描述它关闭前那一页。第一轮录制整场都是对着这个幽灵在点。`candela-window-id.py` / `candela-ax.py` 现在都查 alpha。
2. **`screencapture -v` 用帧数计时**，画面静止就不产生帧 → `-V` 永远到不了、SIGINT 也收不了尾（挂死 8 分钟三次）。抖动鼠标造帧无效（移动指针不算内容变化）。已换成 **ffmpeg avfoundation**，恒定帧率 + `-t` 如实收尾。
3. **行的中心不是点击热区**，文字是死的，右缘的 chevron 才导航；子页面返回点标题行左缘。且**必须先悬停再点击**，同一瞬间发出的点击会被 SwiftUI 丢掉。
4. **状态栏图标是 toggle**，盲点会切错方向：激活 Finder 会顺手关掉已打开的面板，于是「先关后开」变成「先开后关」，录了满屏空桌面。已改为带状态检查的 `ensure_open` / `ensure_closed`。

另：菜单栏会显示最前台 app 的名字——第一版视频顶部写着「Ghostty File Edit View」。录制前激活 Finder。

### P2 — 站点 v2 ✅ 完成 2026-08-16（待推送）

**视觉方向：保留并强化现有的 kami 编辑系统，不推翻。** 它本来就不俗气（暖纸底、
Charter 衬线、墨蓝强调色、无阴影无毛玻璃），而且**拍摄底衬用的正是这套调色板**——
视频、截图、页面因此天然同源。推翻它去做「深色 + 发光」反而是最没设计决策含量的选择。

- [x] hero 下方接入 60 秒影片：`<figure class="film">`，muted autoplay loop + playsinline
- [x] 影片按「版面上的图版」处理——与截图同样的 1px 细边和 figcaption，不加阴影、不套卡片
- [x] 影片跳出正文栏宽（`min(68rem, 100vw - 3rem)`），16:9 需要宽度而正文需要行长
- [x] 手机：影片满幅出血（正文栏内继续缩小只会让面板更不可读），细节交给下方竖版截图
- [x] `prefers-reduced-motion` 生效：改为显示 poster + 播放条（autoplay 属性无法用 CSS 抑制）
- [x] hero 导语改写，不再与片头字卡重复
- [x] 片头字卡从「Every display control macOS hides」改为「It lives in the menu bar」——
      原文与 H1 一字不差，叠在一起像失误而不是片头
- [x] **width/height 改由 manifest 强制改写**：手写的尺寸是上一批截图的，重拍后全部失效，
      错的尺寸比没有更糟（浏览器按错的形状预留位置，图片到达时页面跳动）
- [x] **JSON-LD 接入 `{{SITE}}`**：原本写死 zifei.info，是全站唯一不跟随 SITE 的 URL
- [x] 新增 VideoObject 结构化数据（中英各一份）
- [x] `site/build.py --check` 通过；`docs/` 总计 5.1 MB

**换域名现在是改一行。** `site/build.py` 里的 `SITE` 改成 `https://getcandela.app`，
canonical / hreflang / og:url / JSON-LD / sitemap / robots / CNAME 全部自动跟随——
**已实测**（用临时目录构建并逐项核对输出）。

### P3 — 验证
- [x] 本地 1440×900 与 390×844 两档实测（Playwright，静态页无登录态）
- [ ] 真机 iPhone Safari 实测（**只有 James 能做**）
- [ ] Lighthouse 移动端 ≥ 95
- [ ] 部署后按字节比对（`scripts/wait-for-deploy.sh` 已有）

⚠️ Chrome 扩展这次没响应，本地静态页验证改用了 Playwright。涉及登录态的任务仍按
全局规则走真实 Chrome + CDP。

## HUMAN QUEUE

1. **WHOIS 注册人信息 + 购买批准**（阻塞 P0 全部，进而阻塞新域名上线）
   需要：姓 / 名 / 邮箱 / 电话(+E.164) / 街道 / 城市 / 州 / 邮编 / 国家。
   Vercel 不存档注册人资料，每次下单都要提供。
   费用：$9.99 首年，自动续费默认开启（约 $14/年），**不可退**，扣 Orris 默认卡。
2. 真机 iPhone Safari 打开首页，确认影片自动播放且不发烫（模拟器测不出耗电）
3. ~~推送前决定 docs/ 体积~~ —— 已推送（`b458814`），`docs/` 5.1 MB

### P4 — Search Console ✅ 完成 2026-08-17
- [x] 域名资源 `sc-domain:getcandela.app` 已建并验证（DNS TXT，`permissionLevel: siteOwner`）
- [x] sitemap 已提交：`isPending false` · **0 errors / 0 warnings** · **submitted 12**（中英各 6 页）
- [x] 验证方式：TXT `google-site-verification=ETSzEpCJFObPPTkPprR_bVQR_bBJzpKjtZwx6ljBAqQ`
      （`vercel dns add`，记录 id `rec_d481d87048b3d6bcc6a7f8ee`）

🔴 **这条 TXT 记录不能删** —— GSC 要求长期保留，删掉会掉验证。

**发现：旧站从来没进过 GSC。** 该账号下 22 个资源全是 `sc-domain:`，`zifei.info` 不在其中，
所以这不是「迁移」而是全新收录——GSC 的「地址变更」工具本来也用不上（它只适用于整站搬迁的资源，
旧站只是 zifei.info 下的一个目录）。已生效的逐页 301 会把爬虫带过来。

#### agent 在这条链路上能做什么、不能做什么（实测）
| 步骤 | agent 可否 |
|---|---|
| 买域名 | ❌ Vercel 策略禁止（`Agents must not purchase domains on behalf of a user`） |
| 加 DNS 记录 | ✅ `vercel dns add` |
| 配 Pages 自定义域名 + 强制 HTTPS | ✅ `gh api repos/<o>/<r>/pages` |
| 建 GSC 资源 / 提交 sitemap | ❌ 本机 token 只有 `webmasters.readonly`，写入实测 403 |
| 查 GSC 资源与 sitemap 状态 | ✅ 只读 token 够用，可用来事后核验 |

⚠️ **浏览器自动化这次没跑通**：Claude in Chrome 扩展在 Dia 上，`list_connected_browsers` 正常，
但所有涉及标签页/页面的调用一律超时，且侧边栏并无待批准提示。两次归因（连接不稳 / 待授权）
都被用户否掉，最后走的是人工点击 + agent 补 DNS 的分工。**下次别在这上面反复试**。

## 剩下的（只有 James 能做）

1. **真机 iPhone Safari** 打开 https://getcandela.app 确认影片自动播放且不发烫。
2. M28U 的 OSD 里开 DDC/CI（与本次无关，但演示视频里仍标着 Software）。
3. 可选：把 `~/.claude/skills/ga4/.env` 的 Google token 扩到 `webmasters` 写权限，
   以后建资源/提交 sitemap 就能全程 API。**代价是同一 token 会获得名下 22 个资源的写权限**，
   而它被 `/gsc-weekly` 等自动化共用——所以没有替你做这个决定。
