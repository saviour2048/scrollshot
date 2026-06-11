# Moments（时刻）

随手记录想法、照片、视频和语音，自动打时间标签 + 自定义标签，用漂亮的时间轴回看。

> 与仓库根部的 macOS `ScrollShot`（截图工具）是两个独立项目。

## 技术栈
SwiftUI · SwiftData（本地持久化）· iCloud / CloudKit（多设备同步）· iOS 17+ · XcodeGen

## 跑起来
```bash
brew install xcodegen          # 没装的话
cd Moments
xcodegen generate              # 由 project.yml 生成 Moments.xcodeproj
open Moments.xcodeproj
```
在 Xcode 里：
1. `project.yml` 的 `DEVELOPMENT_TEAM` 填你的 Team ID（或在 Signing & Capabilities 里选 Team）。
2. 想换 Bundle ID 的话，同步改 `Moments/Resources/Moments.entitlements` 里的 `iCloud.<bundleid>`。
3. 选模拟器或真机 Run。iCloud 同步需登录 iCloud 账户并联网。

详见 [SPEC.md](SPEC.md)。

## 当前功能（M1 + M2）
- 按天分组的时间轴，左侧时间线 + 卡片，顶部搜索（文字/标签名）
- 浮动「+」快速记录：文字 + 照片/视频（PhotosPicker）+ 语音录制 + 标签（可即时新建），自动时间戳
- 标签筛选 + 标签管理页（改名 / 改色 / 合并 / 删除）
- 详情：大图、视频播放（AVKit）、语音播放条；编辑、删除
- 首次启动预置「想法 / 生活 / 工作 / 心情」标签
