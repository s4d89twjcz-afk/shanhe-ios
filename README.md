# 山河足迹 iOS 1.3 · 地点与时光

原生 SwiftUI 应用工程，最低 iOS / iPadOS 17.0，包含风景图标、无文字风景封面、启动图、中国离线地图、同地点多次到访、独立照片与随笔、收藏标签、搜索筛选、删除撤销、ZIP 备份和单篇 HTML / TXT 分享。

**交付状态：源码工程，当前没有生成 IPA。** 当前工作区为 Windows，没有 Xcode 或连接的 Mac，也没有实际执行 GitHub 云编译、XCTest、模拟器或真机安装。已提供可手动触发的云编译配置、Mac 打包脚本及测试源码；工程资源与 Windows 测试备份通过本机静态检查。

## Windows + iPhone 用户

打开同目录 `Windows-iPhone免费安装教程.html`：解压工程 → 用 GitHub 网页上传 → 手动运行 Actions → 下载 IPA → 使用免费 Sideloadly 签名安装。云端 macOS 运行器负责 Xcode 编译，不需要自备 Mac。

工作流为 `.github/workflows/build-ios.yml`，可手动运行，也会在 main 分支的工程代码和构建配置更新后自动构建。它无需 Apple 密码、证书或其他 Secrets。公开仓库的标准运行器可免费使用；私有仓库按 GitHub 账户免费额度与账单规则处理。

## Mac 开发与打包

安装完整 Xcode，打开 `Shanhe.xcodeproj`，选择 Shanhe scheme 与具体 iOS 17+ 模拟器。⌘R 运行，⌘U 执行 XCTest。真机开发需要设置自己的 Team 与唯一 Bundle ID。

生成供第三方安装器签名的真机 IPA：

```bash
bash build-ipa-mac.sh
```

输出位于 `build/IPA/Shanhe-unsigned.ipa`。这是未签名真机包，需要 Sideloadly / AltStore 为用户账户重新签名后才能安装。不是模拟器 App，也没有用于 App Store 分发的签名。

同时运行模拟器测试：

```bash
RUN_TESTS=true bash build-ipa-mac.sh
```

也可以用 `bash verify-mac.sh` 只检查模拟器编译，或传入模拟器 UDID 执行已有验证脚本。

## 更新内容与兼容性

每条记录增加与 Windows v1.2 / v1.3 一致的 `LocationId`、`VisitTitle`、`Time` 字段，保留 Version 1。旧记录没有这些字段时，作为独立地点载入；新记录按地点身份组成时间线。改地点名称和省市会更新同地点的共享信息，各次照片、日期、随笔独立。

地图统计按独立地点计数。详情支持追加到访、长按记录操作、编辑、收藏、删除本次记录、归入同城另一个地点。完整 ZIP 保留关联、时间、照片与封面。包中附有合成 Windows v1.1 和 v1.3 备份、对应 XCTest；原生跨端往返仍待云端或 Mac 运行验证。

所有资料保存在 App 的 Documents/Shanhe。卸载或删除 App 会删除本地资料，请先备份。免费个人账户签名需定期刷新；同一 Apple 账户与 Bundle ID 的覆盖安装用于续签，操作前仍建议导出 ZIP。

## 工程内容

| 文件 | 用途 |
| --- | --- |
| `Shanhe.xcodeproj` | 应用、XCTest target 和共享 scheme |
| `Shanhe` | SwiftUI 页面、地图、资料库、ZIP 与风景资源 |
| `ShanheTests` | 旧格式、时间线、保存与备份测试及合成 Windows 备份 |
| `.github/workflows/build-ios.yml` | Windows 浏览器可触发的 macOS 云编译 |
| `build-ipa-mac.sh` | 真机未签名 IPA 打包，可选 XCTest |
| `Windows-iPhone免费安装教程.html` | 云编译、第三方官方下载、安装与续签说明 |
| `使用说明.html` | App 操作与数据保护 |
| `static-check-report.json` | 本机检查结果，明确列出未执行项目 |

## 当前限制

地图按城市中心放标记，自定义地区按省份中心，暂无 GPS、导航、账号或自动云同步。新增照片转换为最长边 2400 像素 JPEG。完整 ZIP 与解压总量均限制 256 MB，单张输入照片限制 80 MB，不支持加密 ZIP / ZIP64。

图库、启动图、手机屏幕布局、性能及第三方签名安装没有在本工作区原生运行验证。请先完成教程中的测试记录验收，再迁移正式资料。
