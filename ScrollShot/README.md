# ScrollShot

macOS 截图 / 滚动长截图 App，交互参照 Ubuntu 的 **Flameshot**：
菜单栏后台常驻，全局快捷键唤起，整屏冻结后框选、就地标注，自动存桌面 + 复制剪贴板。
完整需求见仓库根目录的 [`SPEC.md`](../SPEC.md)。

## 构建 & 运行

```bash
brew install xcodegen          # 仅首次
cd ScrollShot
xcodegen generate             # 由 project.yml 生成 ScrollShot.xcodeproj（含 SPM 依赖）
open ScrollShot.xcodeproj
```

在 Xcode 选择 **My Mac** 运行。App 没有 Dock 图标，会出现在**菜单栏**（相机图标）。

- 首次截图触发「屏幕录制」授权：系统设置 ▸ 隐私与安全性 ▸ 屏幕录制 勾选 ScrollShot 后重开。
- 默认快捷键 **⌃⌥A**，可在「偏好设置」里重录。

> 要求 macOS 13+（Ventura）。`SCScreenshotManager` 在 macOS 14+ 使用，
> macOS 13 自动回退到一次性 `SCStream` 抓帧。
> 全局快捷键依赖 SPM 包 [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)，
> 首次 `xcodegen generate` 后 Xcode 会自动拉取。

## 进度

- **M1 ✅** 权限流程 + 屏幕录制 + 框选区域 + 单帧截图（窗口原型）。
- **M2 ✅** 改造为菜单栏后台 App + 全局快捷键 + 偏好设置（可录制快捷键）。
- **M3 ✅** Flameshot 冻结覆盖层：全屏冻结 + 框选 + 选区旁工具条 + 保存桌面/复制剪贴板。
- **M4 ✅** 就地标注：箭头 / 矩形 / 椭圆 / 画笔 / 文字 / 马赛克 + 颜色 + 撤销。
- **M5 ⏳** 滚动截图：实时框选 + 手动滚动抓帧 + 重叠检测拼接长图 + 标注。
- **M6 ⏳** 窗口模式、固定头尾、菜单栏图标打磨。

> ⚠️ 当前环境是 Linux 容器，无法编译 macOS App；以上代码需在 Mac 上用 Xcode 编译验证。

## 流程

1. 按全局快捷键（或菜单栏「截图」）→ 所有显示器立即截图并冻结、变暗。
2. 鼠标拖拽框选区域（选区内亮、外暗，显示尺寸）。
3. 选区下方弹出工具条：
   - 标注工具：**箭头 / 矩形 / 椭圆 / 画笔 / 文字 / 马赛克**，可选颜色与粗细，**撤销**。
   - 选中工具后在选区内拖拽即可画；文字工具点一下输入、回车确认。
   - 动作：**保存**（存桌面 PNG + 复制剪贴板）/ **复制**（仅剪贴板）/ **取消**。
4. Esc 取消，回车保存；在选区外重新拖拽可重选区域。
5. 滚动截图见后续里程碑。

## 目录结构

```
ScrollShot/
  App/         ScrollShotApp.swift（菜单栏+偏好场景）, AppConfig.swift, Shortcuts.swift
  Capture/     ScreenCapturer.swift（全屏/区域截图）, CaptureController.swift（编排）
  Overlay/     OverlayController.swift（每屏一个冻结窗口）, OverlayCanvasView.swift（选区+输出）
  Stitch/      ImageUtils.swift（PNG/剪贴板/存桌面）   （FrameStitcher 见 M5）
  Selection/   RegionSelectorWindow.swift（滚动模式实时框选会复用）
  Preferences/ PreferencesView.swift（快捷键录制 + 权限入口）
  Resources/   Assets.xcassets, Info.plist（LSUIElement）, ScrollShot.entitlements
  project.yml
```
