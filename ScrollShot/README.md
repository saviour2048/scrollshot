# ScrollShot

macOS 滚动长截图 App。需求与整体方案见仓库根目录的 [`SPEC.md`](../SPEC.md)。

## 构建 & 运行

```bash
brew install xcodegen          # 仅首次
cd ScrollShot
xcodegen generate             # 由 project.yml 生成 ScrollShot.xcodeproj
open ScrollShot.xcodeproj
```

在 Xcode 选择 **My Mac** 运行。首次截图会触发系统的「屏幕录制」授权：
到 系统设置 ▸ 隐私与安全性 ▸ 屏幕录制 勾选 ScrollShot，然后重开 App。

> 要求 macOS 13+（Ventura）。`SCScreenshotManager` 在 macOS 14+ 使用，
> macOS 13 自动回退到一次性 `SCStream` 抓帧。

## 进度

### M1 ✅ 权限流程 + 屏幕录制 + 框选区域 + 单帧截图保存
- `Capture/ScreenCapturer.swift`：ScreenCaptureKit 权限检查/请求与单帧区域截图。
- `Selection/RegionSelectorWindow.swift`：覆盖全部显示器的框选浮层（Esc 取消）。
- `Models/CaptureSession.swift`：状态机，坐标换算（AppKit ↔ ScreenCaptureKit），保存/复制。
- `Views/`：`PermissionView`（授权引导）、`MainView`（工具栏 + 状态栏）、`PreviewView`（预览）。
- 导出：保存 PNG（NSSavePanel）/ 复制到剪贴板。

### 后续里程碑
- M2：手动滚动连续抓帧 + 实时预览。
- M3：拼接算法（重叠检测）+ 导出长图（`Stitch/FrameStitcher.swift`）。
- M4：窗口模式、固定头尾处理、快捷键、菜单栏图标。
- M5：自动滚动模式（辅助功能权限）。

## 目录结构

```
ScrollShot/
  App/         ScrollShotApp.swift, AppConfig.swift
  Capture/     ScreenCapturer.swift
  Stitch/      ImageUtils.swift            (FrameStitcher 见 M3)
  Selection/   RegionSelectorWindow.swift
  Views/       MainView.swift, PreviewView.swift, PermissionView.swift
  Models/      CaptureSession.swift
  Resources/   Assets.xcassets, Info.plist, ScrollShot.entitlements
  project.yml
```
