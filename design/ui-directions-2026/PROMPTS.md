# 生成 Prompt 集

五张设计稿均使用 OpenAI 内置图像生成工具独立生成。

## 共享 Prompt

```text
Use case: ui-mockup
Asset type: high-fidelity shippable macOS 26+ menu bar utility UI direction
Primary request: RepoGlance is a native macOS menu bar app for finding local Git repositories. Show one realistic desktop screenshot with the macOS menu bar at the top, a compact search popover anchored below the RepoGlance menu bar icon, and a separate hover-preview panel floating immediately to its right with a narrow gap. These are two independent floating panels, not a fixed split view and not a normal app window.
Information architecture: the left popover has a centered segmented control with “项目” selected and “剪贴板” unselected; a search field; section headers “最近使用” and “收藏”; project rows named “RepoGlance”, “EasyMoney”, “Web App”, and an indented nested child repository “API” under “Web App”; the “API” row is selected; concise paths and editor badges; bottom status “128 个项目 · 已更新” plus refresh and settings icons. The right hover panel previews “API”, path “~/Projects/WebApp/api”, parent relationship “父项目：Web App”, tags “Swift” and “Backend”, segmented tabs “自定义说明” and “README”, a short description, and bottom actions “打开”, “其他方式”, “编辑项目信息…”.
Exact Chinese text to render where visible: “项目”, “剪贴板”, “搜索项目、路径、说明或标签…”, “最近使用”, “收藏”, “RepoGlance”, “EasyMoney”, “Web App”, “API”, “子仓库”, “128 个项目 · 已更新”, “父项目：Web App”, “自定义说明”, “README”, “本地 API 服务，负责认证和项目数据同步。”, “打开”, “其他方式”, “编辑项目信息…”.
Composition/framing: landscape 16:10 design presentation, straight-on screenshot, two panels centered with generous desktop context; left panel around 560x620 logical points, right panel around 420x520; realistic menu-bar anchoring and shadows; all typography readable.
Typography: Apple-style system sans serif for names and Chinese, system monospaced font for paths, precise hierarchy.
Constraints: same practical layout across all variants; immediately understandable parent-child repository hierarchy; native macOS controls and SF-Symbol-like icons; correct RepoGlance spelling; no people, no phone, no browser chrome, no giant title, no marketing copy, no watermark, no fake logo, no terminal-only interface, no decorative illustration, no extra panels.
```

## 01 · Native Utility

```text
Direction 1 of 5 — Native Utility.
Style/medium: closest possible to stock macOS AppKit and SwiftUI, restrained and trustworthy, light appearance.
Scene/backdrop: a quiet neutral macOS desktop wallpaper in pale cool gray.
Color palette: system white and light gray, graphite text, standard macOS blue selection.
Materials/textures: mostly opaque system surfaces with only subtle native vibrancy in the title/search areas, 1px separators, standard corner radii, compact native row spacing and conservative shadows.
Mood: functional, calm, instantly familiar.
Avoid: glassmorphism, colored gradients, floating cards inside panels, custom brand styling, excessive transparency, futuristic visuals.
```

## 02 · Refined System

```text
Direction 2 of 5 — Refined System.
Style/medium: premium first-party macOS utility, polished like Spotlight and a modern Finder inspector while staying recognizably native.
Scene/backdrop: soft blue-gray macOS desktop wallpaper with gentle tonal variation.
Color palette: cool neutral whites, graphite, muted system blue accent.
Materials/textures: lightly translucent sidebar material, layered but subtle elevation, refined selection capsule, clearer spacing, thin luminous edge highlights, soft realistic shadows.
Mood: precise, elegant, productive.
Avoid: heavy glass, strong blur, neon, oversized cards, non-native web-dashboard styling.
```

## 03 · Soft Frost

```text
Direction 3 of 5 — Soft Frost.
Style/medium: balanced frosted-glass macOS interface, readable and practical, halfway between opaque native UI and transparent glass.
Scene/backdrop: abstract macOS wallpaper with muted ocean blue and lavender shapes visible softly through the panels.
Color palette: frosted pearl, cool gray, graphite, restrained blue-violet accent.
Materials/textures: medium translucency with controlled background blur, subtle inner highlights, semi-opaque list rows, selected row with a blue translucent tint, clear separators and strong text contrast.
Mood: contemporary, calm, tactile.
Avoid: illegible text, excessive glow, rainbow gradients, sci-fi HUD, glass stacked inside every row.
```

## 04 · Liquid Glass

```text
Direction 4 of 5 — Liquid Glass.
Style/medium: sophisticated macOS 26 Liquid Glass interpretation, fluid optical depth but still shippable as a productivity tool.
Scene/backdrop: colorful yet restrained macOS wallpaper with deep blue, cyan, and soft violet gradients that demonstrate refraction.
Color palette: clear cool glass, white and graphite adaptive text, luminous system blue accent.
Materials/textures: highly polished translucent panels, realistic edge refraction, specular rim highlights, gentle lensing, selected row as a raised liquid-glass capsule, floating controls with restrained glass depth; preview panel visually related but independent.
Mood: vivid, premium, forward-looking.
Avoid: unreadable transparency, fantasy concept art, bubbles, jelly toy UI, neon cyberpunk, excessive glow, decorative orbs.
```

## 05 · Spatial Clear

```text
Direction 5 of 5 — Spatial Clear.
Style/medium: ultra-transparent spatial macOS interface inspired by optical glass and visionOS, minimal structure, maximum desktop integration while preserving desktop productivity density.
Scene/backdrop: detailed dark-to-light aurora macOS wallpaper clearly visible through the panels, with enough contrast variation to prove adaptive readability.
Color palette: almost-clear neutral glass, adaptive white/graphite text, icy blue focus accent.
Materials/textures: very high transparency, strong background blur only behind text zones, razor-thin bright glass borders, subtle caustic highlights, floating translucent row surfaces, layered depth and precise shadows; no opaque panel fill except tiny readability scrims.
Mood: airy, spatial, experimental, luxurious.
Avoid: low contrast, invisible boundaries, holographic sci-fi HUD, neon outlines, floating 3D objects, excessive glow, playful bubbles.
```
