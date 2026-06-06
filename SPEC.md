# ScrollShot — macOS 滚动长截图 App · 需求与技术方案 v1

## 目标
一个 macOS 桌面 App：框选屏幕上一块区域（或一个窗口），用户滚动内容时连续抓帧，
自动把这些帧拼接成一张完整的长图，可保存 PNG / 复制到剪贴板。

## 平台 & 技术栈
- macOS 13+（Ventura，ScreenCaptureKit 截图 API 更完善）
- Swift + SwiftUI（主界面）+ AppKit（窗口/全局快捷键/区域选择浮层）
- ScreenCaptureKit：屏幕/窗口捕获（需"屏幕录制"权限）
- CoreGraphics / Accelerate(vImage)：帧对齐与拼接（像素级、快）
- 工程用 XcodeGen（project.yml 生成 .xcodeproj）
- 无后端、无网络、全本地

## MVP 功能
1. 选择捕获范围：① 框选屏幕一块矩形区域；② 或选择某个窗口。
2. 滚动捕获（手动模式，先做这个）：点"开始" → 用户手动向下滚动 → App 按节奏抓帧并实时显示已拼接预览 → 点"结束"输出长图。
3. 自动拼接：相邻帧检测垂直重叠量，只把新增部分接到长图下方。
4. 导出：保存 PNG（可选 PDF）/ 复制到剪贴板 / 拖拽到其他 App。

## 拼接算法（核心）
- 相邻两帧 A（先）、B（后，向下滚动了）：求竖直偏移 dy，使 A 底部与 B 顶部最匹配。
- 方法：灰度 + 缩小后，对一条横向像素带做 SAD（绝对差之和）/ 互相关，取误差最小的 dy。
- 只把 B 中 dy 以下的新内容追加到输出长图。
- 边界处理（v2）：识别固定的页头/页尾（滚动时不动的区域）避免重复。

## 权限
- 屏幕录制（必需）：首次捕获触发系统授权；引导用户到 系统设置▸隐私与安全性▸屏幕录制 勾选本 App。
- 辅助功能：仅"自动滚动"模式（v2，用 CGEvent 发滚动事件）才需要。

## 工程结构（建议）
```
ScrollShot/
  App/         ScrollShotApp.swift, AppConfig.swift
  Capture/     ScreenCapturer.swift
  Stitch/      FrameStitcher.swift, ImageUtils.swift
  Selection/   RegionSelectorWindow.swift
  Views/       MainView.swift, PreviewView.swift, PermissionView.swift
  Models/      CaptureSession.swift
  Resources/   Assets.xcassets, Info.plist(生成)
project.yml
```

## 里程碑
- M1：权限流程 + 屏幕录制 + 框选区域 + 单帧截图保存。
- M2：手动滚动连续抓帧 + 实时预览。
- M3：拼接算法（重叠检测）+ 导出长图。
- M4：窗口模式、固定头尾处理、快捷键、菜单栏图标。
- M5（可选）：自动滚动模式（辅助功能权限）。

## 构建 & 运行
1. 装 xcodegen（brew install xcodegen）。
2. cd ScrollShot && xcodegen generate && open ScrollShot.xcodeproj。
3. Xcode 选 My Mac 运行；首次按提示授予"屏幕录制"权限后重开。

## 分发（以后）
- 自己用：本地 Xcode 跑即可。
- 给别人：需 Developer ID 签名 + 公证（notarize）。
