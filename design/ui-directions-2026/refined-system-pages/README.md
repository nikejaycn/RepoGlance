# RepoGlance · Refined System 页面设计

本组设计以 `02-refined-system.png` 为唯一视觉基准，对应 RepoGlance 当前 SwiftUI 功能范围。主项目搜索与悬停预览沿用基准稿，其余独立页面和关键空状态收录在本目录。

## 视觉规范

- macOS 26 原生窗口与控件，不引入自定义网页式组件。
- 浅灰侧栏、白色内容面、克制的系统材质与轻微透明度。
- 1 px 冷灰分隔线，适中的圆角与柔和窗口阴影。
- 主要文字接近黑色，次要信息使用冷灰色。
- 交互焦点、选中态和主按钮统一使用系统蓝。
- 设置窗口固定为五个栏目：通用、项目来源、打开方式、剪贴板、数据与关于。
- Markdown 链接首期只展示，不提供点击能力。

## 页面索引

| 文件 | 页面 / 状态 | 对应实现 |
| --- | --- | --- |
| `../02-refined-system.png` | 项目搜索 + 嵌套仓库 + 悬停预览 | `SearchPanelView`、`ProjectPreviewView` |
| `06-clipboard-panel.png` | 剪贴板历史快速面板 | `SearchPanelView.clipboardContent` |
| `07-first-run-empty.png` | 未添加扫描目录的首次使用状态 | `SearchPanelView.projectContent` |
| `08-settings-general.png` | 设置 · 通用 | `GeneralSettingsView` |
| `09-settings-project-sources.png` | 设置 · 扫描目录与排除项目 | `ScanRootsSettingsView` |
| `10-settings-opening.png` | 设置 · 打开方式与编辑器发现 | `EditorSettingsView` |
| `11-settings-clipboard.png` | 设置 · 剪贴板 | `ClipboardSettingsView` |
| `12-settings-data-about.png` | 设置 · 数据、索引与关于 | `IndexSettingsView` |
| `13-project-editor.png` | 编辑项目信息与受限 Markdown 预览 | `ProjectEditorView` |

## 实现提示

- 快速面板保持现有紧凑宽度；空状态不扩展为多步骤向导。
- 设置窗口维持 `NavigationSplitView`，不要照设计图增加新的设置栏目。
- 项目来源页的展开详情仍由 `DisclosureGroup` 承载。
- 项目编辑窗口保持固定尺寸和双栏 Markdown 编辑/预览结构。
- 图片中的示例项目、路径、数量和时间仅用于展示；数据结构与业务逻辑以代码为准。
