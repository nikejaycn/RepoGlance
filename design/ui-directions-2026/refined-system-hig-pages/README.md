# RepoGlance · Refined System HIG 修订版

本组设计以 `02 · Refined System` 为基础，进一步按 macOS 26 人机界面指南统一搜索、材质、卡片层级和原生控件。原设计稿保留，本目录为后续实现采用的版本。

## Apple HIG 依据

- [Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields)：macOS 常见搜索应位于工具栏尾部；过滤侧栏导航时，应放在侧栏顶部；行内搜索应位于它所搜索的列表上方。
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)：材质用于表达层级与保持环境上下文；文字密集的弹窗、侧栏应采用能保证可读性的 regular 材质，不能只追求透明。
- [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)：侧栏用于平级导航，并在 macOS 新设计体系中浮于内容之上。
- [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables)：列表项保持连续、可扫描；不要把每一行都处理成互不相关的浮动卡片。

## 设计规则

### 半透明背景

- 快速面板、预览浮层、设置侧栏使用系统 regular 半透明材质。
- 允许桌面颜色轻微透入，但正文区域必须保持稳定对比度。
- 不使用固定 RGBA 模拟玻璃，不依赖某张壁纸决定材质颜色。
- 支持“降低透明度”和“增强对比度”辅助功能状态。

### 圆角卡片

- 一个语义分组对应一张卡片，例如“扫描目录”“已排除项目”。
- 卡片内部使用系统分隔线组织行，不给每一行单独套卡片。
- 建议圆角 12–14 pt，卡片间距 16 pt，内部边距 12–16 pt。
- 避免卡片嵌套和多层阴影；层级主要由材质、间距和分隔线表达。

### 原生搜索栏

- 项目快速面板：顶部 `NSSearchField`，搜索项目、路径、说明和标签。
- 剪贴板快速面板：顶部 `NSSearchField`，搜索剪贴板文本。
- 设置窗口：侧栏顶部 `NSSearchField`，过滤五个设置栏目及其关键词。
- 首次使用页：保留顶部搜索位置但设为不可用，避免首次添加目录前出现无效交互。
- 项目编辑窗口：不放搜索栏，因为该窗口是单一对象编辑表单，没有可搜索集合。强行加入搜索会违反 HIG 的功能相关性原则。

## 页面索引

| 文件 | 页面 / 状态 | 搜索位置 |
| --- | --- | --- |
| `02-project-search-preview.png` | 项目搜索、嵌套仓库与悬停预览 | 项目列表顶部 |
| `06-clipboard-panel.png` | 剪贴板历史快速面板 | 历史列表顶部 |
| `07-first-run-empty.png` | 首次使用空状态 | 顶部保留、不可用 |
| `08-settings-general.png` | 设置 · 通用 | 侧栏顶部 |
| `09-settings-project-sources.png` | 设置 · 项目来源 | 侧栏顶部 |
| `10-settings-opening.png` | 设置 · 打开方式 | 侧栏顶部 |
| `11-settings-clipboard.png` | 设置 · 剪贴板 | 侧栏顶部 |
| `12-settings-data-about.png` | 设置 · 数据与关于 | 侧栏顶部 |
| `13-project-editor.png` | 编辑项目信息 | 不适用 |

## 原生实现建议

- 项目与剪贴板搜索优先沿用 `NSSearchField` 封装，启用输入即搜索和系统清除按钮。
- 设置搜索可在 `NavigationSplitView` 侧栏顶部放置 `SearchField`，只过滤设置导航和关键词，不搜索用户项目。
- SwiftUI 分组卡片优先使用 `GroupBox`、`Form`、`List` 和系统背景；不要使用网页风格的自绘卡片组件。
- 半透明窗口使用系统 material / `NSVisualEffectView`，根据用途选择 blending mode，并验证浅色、深色、复杂壁纸和辅助功能。
- 选中态、开关、主按钮使用系统强调色，不固定为自定义蓝色。
