# RepoGlance App Icon

## 设计概念

图标采用“项目定位器”概念：三个层叠文件夹代表多个项目和嵌套 Git 仓库，前景聚焦环代表快速搜索并定位目标项目。蓝灰色圆角底板延续产品已经确定的 macOS 原生克制风格。

图标不使用文字、Git 商标、终端提示符或代码括号，确保在 Finder、Spotlight 和较小尺寸中仍保持清晰轮廓。

## 文件

- `DevSearch-AppIcon.png`：1024 × 1024、透明背景的最终母版。
- `devsearch-icon-chroma.png`：图像生成工具输出的键控背景源文件。
- `DevSearch-AppIcon-1024.png`：去背前的原始分辨率透明源文件。
- `../../DevSearch/Assets.xcassets/AppIcon.appiconset/`：Xcode 使用的 16–1024 px 完整 macOS 图标尺寸集。

## 生成方式

使用 OpenAI 内置图像生成工具生成主方案；随后把圆角底板外侧改为纯洋红键控背景，并使用图像生成技能自带的本地去背工具生成透明 PNG。各 AppIcon 尺寸由 1024 px 母版等比缩放。

核心生成提示：

```text
Create a polished native macOS app icon for RepoGlance. Combine three subtly layered project folders with one integrated circular focus ring selecting the front folder. Use a quiet system-blue and deep blue-gray palette, gentle dimensionality, a strong silhouette, and a centered macOS rounded-square tile. The icon must remain recognizable at 16 px. No text, letters, Git logo, code brackets, terminal prompt, Finder face, tiny details, mockup, scene, or watermark.
```
