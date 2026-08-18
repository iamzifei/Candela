# Candela 自动更新（Sparkle）

status: done
created: 2026-08-18

## Goal

给 Candela 加上和 AudioSwitch / ClipStack 同一套自动更新：后台每日检查、
EdDSA 签名校验、面板里一个「检查更新」入口。

## 现状（实测）

- AudioSwitch ✅ Sparkle + appcast + SUPublicEDKey，feed 200
- ClipStack   ✅ 同上（共用同一把 EdDSA 密钥）
- Candela     ❌ 完全没有：无 Sparkle、无 appcast、无 SUFeedURL

## 难点：Candela 不是 SPM 工程

`scripts/release.sh` 用 **裸 swiftc** 编译（只依赖 Command Line Tools，不需要 Xcode），
所以不能像另外两个 app 那样在 Package.swift 里加依赖。需要：

1. vendor Sparkle 的 XCFramework（下载 + 校验 SHA-256，进 .gitignore）
2. swiftc 加 `-F vendor -framework Sparkle -rpath @executable_path/../Frameworks`
3. 把 Sparkle.framework 拷进 `Contents/Frameworks/`，并**由内向外签名**
   （XPCServices → Updater.app → Autoupdate → framework → app）
4. Info.plist 加 SUFeedURL / SUPublicEDKey / SUEnableAutomaticChecks / SUScheduledCheckInterval
5. release.sh 出 DMG 后生成并签名 appcast.xml

## 阶段

- [x] 阶段 1：`scripts/fetch-sparkle.sh`（下载 + SHA-256 校验 + 顺带 vendor sign_update），
      dev.sh 与 release.sh 都加了 `-F vendor -framework Sparkle` 和 rpath
- [x] 阶段 2：`UpdaterService`（SPUStandardUpdaterController 包装）+ 设置面板
      「检查更新…」行；原有的 GitHub 版本横幅改成点一下就走 Sparkle 安装
- [x] 阶段 3：`scripts/update_appcast.py`（从 audioswitch 移植）+ release.sh 发布后
      自动签名、提交并推送 appcast.xml
- [x] 阶段 4：**实测**跑通 —— 本地起一个 appcast（99.0.0）→ 应用启动后自动
      GET /appcast.xml（服务器访问日志为证），说明 updater 真的在跑且用的是配置里的 feed
- [x] 干签名验证：`vendor/bin/sign_update Candela.dmg -p` 用钥匙串里的私钥直接出签名

## 实测记录

- dry-run 发布通过：Sparkle 由内向外签名（XPCServices → Updater.app → Autoupdate
  → framework → app），`codesign --verify --deep --strict` 通过
- `otool -L` 显示 `@rpath/Sparkle.framework/.../Sparkle`，Info.plist 四个键齐全
- 测试用的 SUFeedURL 等 defaults 已从 com.candela.app 清干净

## 已关闭的决策

- 复用与 AudioSwitch / ClipStack 相同的 EdDSA 密钥对：私钥在同一个钥匙串里，
  一个人签三个 app，多一把钥匙只是多一个可丢的东西。
- feed 用 raw.githubusercontent 而不是 getcandela.app：站点由 site/build.py 生成，
  往 docs/ 里放一个生成器不认识的文件会让 `--check` 报不一致。
