<p align="center">
  <img src="design/app-icon/DevSearch-AppIcon.png" width="144" height="144" alt="RepoGlance App Icon">
</p>

<h1 align="center">RepoGlance</h1>

<p align="center">
  <strong>Find the right local repo at a glance.</strong><br>
  像 Spotlight 一样搜索本机 Git 项目，预览说明，然后用喜欢的编辑器打开。
</p>

<p align="center">
  macOS 14+ · SwiftUI + AppKit · Local-first
</p>

## 为什么需要 RepoGlance

项目逐渐散落在 `~/dev`、`~/projects`、工作目录和外接磁盘后，真正麻烦的往往不是项目不存在，而是已经记不清它叫什么、放在哪里、当初用来做什么。

RepoGlance 是一款原生 macOS 菜单栏工具。添加几个扫描目录后，它会在本机发现其中的 Git 仓库，并建立可搜索索引。你可以通过名称、路径、标签、说明或 README 找到项目，悬停确认内容，再用指定编辑器打开。

所有索引和说明都保存在本机；核心功能不需要账号、云服务或网络连接。

## 功能

- **多目录自动索引**：扫描多个开发目录，发现普通、嵌套和 worktree Git 仓库。
- **快速模糊搜索**：搜索项目名称、路径、标签、自定义说明及有限 README 内容。
- **悬停预览**：无需打开项目即可查看自定义说明或 README 摘要。
- **嵌套仓库关系**：以父子层级展示仓库，并支持排除单个项目或整个子树。
- **自定义项目资料**：设置别名、标签、受限 Markdown 说明和默认编辑器。
- **多种打开方式**：支持 VS Code、Xcode、其他已发现编辑器、Finder 和终端。
- **菜单栏与键盘优先**：菜单栏快速唤起，可配置全局快捷键并使用键盘完成搜索和打开。
- **本地优先**：不上传项目路径、README、说明或代码内容。
- **原生 macOS 体验**：跟随浅色、深色、强调色、增加对比度和减少动态效果设置。

## 工作方式

```text
添加扫描目录
      ↓
发现 Git 仓库与嵌套关系
      ↓
搜索名称、路径、标签、说明或 README
      ↓
悬停确认项目内容
      ↓
用编辑器、Finder 或终端打开
```

README 只读取开头 20 KiB 用于本地搜索和预览。Markdown 使用受限渲染，链接在 V0.1 中保持不可点击。

## 系统要求

- macOS 14.0 或更高版本
- Apple Silicon 或 Intel Mac

## 安装

### 从 DMG 安装

当前 V0.1 提供本机使用包。将 `DevSearch.app` 拖入“应用程序”文件夹即可。

目前安装包使用完整的 ad-hoc 签名，但尚未使用 Developer ID 签名和 Apple 公证。首次启动时：

1. 在“应用程序”中按住 Control 单击应用。
2. 选择“打开”。
3. 在系统确认窗口中再次选择“打开”。

如果仍被 Gatekeeper 阻止，可前往“系统设置”→“隐私与安全性”，仅在确认安装包来源可信时选择“仍要打开”。

正式 GitHub Release 发布前，还会补充 Developer ID 签名与 Apple 公证。

## 快速开始

1. 启动应用，在菜单栏打开 RepoGlance。
2. 选择一个或多个 `dev`、`projects` 或其他项目目录。
3. 等待首次扫描；已发现的项目会立即进入搜索结果。
4. 输入项目名称、路径片段、标签或说明。
5. 悬停结果查看预览，按 `Enter` 或单击项目打开。

默认全局快捷键为 `⌥ Space`，可以在设置中修改或关闭。

## 隐私与安全

RepoGlance 默认完全离线运行：

- 不上传目录结构、仓库内容、README 或自定义说明。
- 不要求 GitHub、GitLab 或其他远程平台账号。
- 不执行项目中的代码、脚本或 Git 命令。
- 使用文件 URL 直接调用编辑器、Finder 和终端，不通过 shell 拼接项目路径。
- README 仅索引有限文本，并使用不可点击的受限 Markdown 预览。

应用数据保存在当前用户的 Application Support 目录中。

## 从源码构建

### 环境

- Xcode 26+（包含 macOS 26 SDK）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### 生成工程并运行测试

```sh
xcodegen generate
xcodebuild test \
  -project DevSearch.xcodeproj \
  -scheme DevSearch \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

### 生成本机安装包

```sh
zsh scripts/package-local.sh
```

脚本会生成最低支持 macOS 14、同时包含 `arm64` 与 `x86_64` 的 ZIP 和 DMG，并为完整 App bundle 添加 ad-hoc 完整性签名。

> RepoGlance 是产品名称；当前 Xcode target、scheme 和应用包内部名称仍保留为 `DevSearch`，后续可以单独完成无破坏迁移。

## 项目结构

```text
DevSearch/          应用源码与资源
DevSearchTests/     单元和集成测试
DevSearchUITests/   macOS UI 自动化测试
design/             界面探索与 App Icon
docs/               产品、界面、发布和验收文档
scripts/            本机打包与正式发布脚本
project.yml         XcodeGen 工程定义
```

## 文档

- [产品需求文档](docs/PRD.md)
- [原生界面与交互规格](docs/UI-SPEC.md)
- [验收记录](docs/ACCEPTANCE.md)
- [本机打包与正式发布](docs/RELEASE.md)
- [App Icon 设计说明](design/app-icon/README.md)

## 项目状态

V0.1 已完成核心 MVP：本地扫描、嵌套仓库、搜索、悬停预览、自定义项目资料、排除规则、多编辑器打开和设置持久化。当前重点是完善 GitHub 发布资料，以及后续 Developer ID 签名与 Apple 公证。

## 参与贡献

欢迎通过 GitHub Issues 提交问题、可复现步骤和功能建议。准备代码改动前，建议先创建 Issue 说明使用场景和预期行为，避免重复实现。

UI 自动化首次运行前，需要为 Xcode/XCTRunner 授予 macOS 自动化与辅助功能权限。

## License

仓库目前尚未添加开源许可证。在正式选择并提交 `LICENSE` 文件前，默认保留全部权利。
