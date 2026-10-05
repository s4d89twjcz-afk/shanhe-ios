# Windows + iPhone 免费安装教程

适用：山河足迹 iOS 1.3 工程；iPhone / iPad 系统需为 17.0 或更新。核实日期：2026 年 10 月 5 日。

**当前交付是源码工程与云编译配置，没有现成 IPA。** 当前 Windows 工作区没有运行 Xcode，也没有登录你的 GitHub 账户启动云编译。下面的流程是在你的账户中生成 IPA，再安装到手机；源码 ZIP 本身不是手机安装包。

## 1. 你需要准备什么

| 准备项 | 用途 |
| --- | --- |
| Windows 电脑、浏览器和网络 | 上传工程，下载云编译结果 |
| GitHub 账户 | 使用 macOS 云端运行器编译 iOS 工程 |
| 本次 iOS 工程 ZIP | 包含源码、地图、风景图片和云编译配置 |
| iPhone、数据线和自己的 Apple Account | 通过 Sideloadly 签名并安装 |
| Sideloadly 官方客户端 | 免费下载，支持免费 Apple 账户安装 IPA |

GitHub 的公开仓库使用标准托管运行器可免费运行 Actions；私有仓库使用账户包含的免费额度，超额处理取决于账户账单设置。本文选择公开仓库与标准 `macos-latest` 运行器，产物只保留 7 天；公开仓库中的工程代码与图片可以被他人查看。工程包不含你的打卡数据。规则见 [GitHub Actions 计费说明](https://docs.github.com/en/billing/concepts/product-billing/github-actions)。

Sideloadly 支持免费 Apple 账户并免费提供下载。见 [Sideloadly 官网](https://sideloadly.io/)。

## 2. 解压工程并创建仓库

1. 下载“山河足迹-iOS-v1.3-工程.zip”，在 Windows 中解压。
2. 打开解压后的工程目录，确认能看到 `Shanhe`、`ShanheTests`、`Shanhe.xcodeproj` 和 `build-ipa-mac.sh`。
3. 用浏览器登录 GitHub，新建仓库，名称可以为 `shanhe-ios`，选择 Public，初始化 README。
4. 在仓库页面使用 **Add file → Upload files**，把工程目录里面的文件和文件夹上传到仓库根目录，完成 Commit changes。
5. 确认仓库根目录直接包含 `Shanhe.xcodeproj` 和 `build-ipa-mac.sh`，与解压工程里的结构相同。

云编译不用 Apple 账户、证书或密码。Apple 登录只在后面的 Sideloadly 客户端中进行。

## 3. 添加云编译配置

Windows 浏览器上传隐藏目录时，可以用下面的明确步骤单独创建工作流：

1. 在 GitHub 仓库点 **Add file → Create new file**。
2. 文件名称填写 `.github/workflows/build-ios.yml`。
3. 用 Windows 文本编辑器打开工程中的同名文件，把完整内容复制进去。
4. 直接提交到默认分支，通常是 `main`。

工程已包含这份配置，不需要自己填写证书。它采用手动运行，读取源码、构建 iPhone 真机版本、打包未签名 IPA 并上传下载产物。

仓库结构应类似：

```text
.github/workflows/build-ios.yml
Shanhe.xcodeproj/project.pbxproj
Shanhe.xcodeproj/xcshareddata/xcschemes/Shanhe.xcscheme
Shanhe/...
ShanheTests/...
build-ipa-mac.sh
README.md
```

## 4. 运行云编译并下载 IPA

1. 打开仓库 **Actions** 页面。
2. 左侧选择 **Build iOS IPA**，点 **Run workflow**。
3. 选择默认分支。第一次可以保持 `run_tests` 为 false；它控制是否额外运行模拟器 XCTest。
4. 开始运行，等待这一条记录出现绿色成功标记。具体时间取决于 GitHub 排队与当前 Xcode 环境。
5. 打开该次运行的详情，在 **Artifacts** 区域下载 **Shanhe-iOS-IPA**。
6. 解压下载的产物 ZIP，得到 `Shanhe-unsigned.ipa`。这个 IPA 还需要 Sideloadly 签名，不能直接在“文件”应用中点击安装。

手动运行要求工作流文件位于默认分支，操作入口见 [GitHub 手动运行工作流](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)。产物下载需要登录且拥有仓库读取权限，见 [GitHub 下载构建产物](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts)。

如果结果为红色，打开 **Build unsigned device IPA** 查看第一个编译错误，或下载 **Shanhe-iOS-build-logs**。构建没有成功时不会提供“成功生成”的 IPA。当前交付没有实际执行这一步，云编译与原生端测试仍需由该流程确认。

## 5. 下载 Sideloadly 并准备设备连接

1. 打开 [Sideloadly 官方下载页面](https://sideloadly.io/)，选择 Windows 客户端并安装。
2. 按官网 **Before you install** 部分准备 Apple 网页版 iTunes 与 iCloud；使用官网指向的 Apple 下载链接。
3. 用数据线连接 iPhone，解锁手机，按提示信任这台电脑。
4. 确认电脑能识别手机，再打开 Sideloadly。

这些前置要求与客户端入口来自 [Sideloadly 官网](https://sideloadly.io/)。本教程没有替你安装驱动、删除现有 Apple 软件或登录账户；按客户端官网针对当前系统的提示处理。

## 6. 签名安装山河足迹

1. 在 Sideloadly 选择连接的 iPhone。
2. 将 `Shanhe-unsigned.ipa` 拖入客户端的 IPA 区域。
3. 填写自己的 Apple Account，点击安装 / Start，按客户端提示完成账户验证。
4. 等待安装完成，在手机中找到“山河足迹”。

Sideloadly 用你的账户给 IPA 签名并安装，操作流程见 [官方首页](https://sideloadly.io/)。不要把 GitHub 下载得到的外层产物 ZIP 当作 IPA 导入。

如果手机提示未受信任开发者，在“设置 → 通用 → VPN 与设备管理”中信任用于安装的账户。如果提示需要开发者模式，按“设置 → 隐私与安全性 → 开发者模式”操作并完成系统要求的重启确认。不同 iOS 版本的入口名称可能略有差异。来源：[Sideloadly 官方常见问题](https://sideloadly.io/faq)、[Apple 开发者模式说明](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)。

## 7. 免费安装的期限与续签

免费 Personal Team 的安装描述文件通常在签发后 7 天到期，同一设备可安装的免费开发 App 数量受限。Apple 当前说明为最多 3 个 App / 设备，并需定期重新部署。见 [Apple 开发者账户说明](https://developer.apple.com/help/account/basics/about-your-developer-account)。

可以在 Sideloadly 中启用自动刷新，并保证电脑后台客户端运行、设备能通过 USB 或已配好的 Wi-Fi 连接。到期后也可用同一 IPA、同一 Apple 账户和相同 Bundle ID 再安装。覆盖安装前先在山河足迹中导出完整 ZIP；不要通过删除 App 来续签，否则本地资料可能被删除。见 [Sideloadly 续签与覆盖安装说明](https://sideloadly.io/faq)。

免费安装不意味着无需续签，也不会把这个 App 自动上架 App Store。GitHub 只负责产生 IPA，Sideloadly 负责账户签名和手机安装。

## 8. AltStore Classic 备用方式

如果选择 AltStore Classic，可从 [AltStore 官网](https://altstore.io/) 获取 AltServer，并按 [Windows 官方安装教程](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) 在电脑准备 iTunes / iCloud、连接信任手机，然后通过 AltServer 的 Install AltStore 安装 AltStore。再使用 AltStore 的个人 IPA 导入入口安装云编译得到的 IPA。

这里使用的是 AltStore Classic。它依赖 AltServer；免费签名也需要定期刷新，并且 AltStore 自身会占用一个免费开发 App 名额。具体当前入口与刷新规则请以 [AltStore 官方文档](https://faq.altstore.io/) 为准。

## 9. 首次打开后的验证

1. 新建一个测试地点，添加两张照片、日期、时间和随笔。
2. 在地点详情点“追加一段时光”，填写另一时间，确认旧照片与随笔保留。
3. 导出完整 ZIP，重新打开 App 检查记录，再用测试备份确认恢复。
4. 正式迁移 Windows 数据前，先在 Windows 导出完整备份，保留原始副本。

版本最低要求是 iOS 17。安装器支持更老系统，也不会改变本 App 的实际系统要求。签名到期或工具版本变化时，请重新检查官网说明。
