# Moments（时刻）— iOS 个人记录 / 生活时间轴 App · 需求与技术方案 v1

> 注意：本目录与仓库根部的 macOS `ScrollShot`（截图工具）是**完全独立的两个项目**，互不依赖。

## 理念
每个人都有随时想记录的想法、照片、视频和语音。Moments 让你**打开即记**：
随手写一句话、拍/选几张照片，App 自动打上**时间标签**，你也可以加**自定义标签**，
然后用一条**漂亮的时间轴**随时回看这些记录。

核心信条：**记录的摩擦越小越好**——少点几下、少做几个决定，先把内容留住。

## 平台 & 技术栈
- iOS 17+（SwiftData 需要）
- Swift 5.9 + SwiftUI（全部界面）
- **SwiftData** 做本地持久化；开启 **iCloud / CloudKit** 私有库自动同步（多设备共享）
- 照片等媒体以二进制存进 SwiftData 的 `@Attribute(.externalStorage)` 字段，
  这样 CloudKit 会把它们当作 CKAsset 一并同步（而不是只同步文字）
- `PhotosUI` 选图；`Layout` 协议自绘标签流式布局
- 工程用 **XcodeGen**（`project.yml` 生成 `.xcodeproj`），与仓库另一个项目保持一致
- 无自建后端，数据全在用户的 iCloud 私有库

## MVP 范围（v1）
1. **时间轴主界面**：按天分组、倒序，左侧竖直时间线 + 时间点，右侧记录卡片（文字 + 媒体缩略图 + 标签）。
2. **快速记录**：浮动「+」打开记录页 —— 写文字、`PhotosPicker` 加多张照片/视频、录语音、
   选/新建标签；保存时**自动写入当前时间戳**。
3. **标签**：彩色标签，可在记录页即时新建；时间轴顶部可按标签筛选。
4. **详情 / 编辑 / 删除**：点卡片进详情，可看大图/播视频/播语音、编辑文字与标签、增删媒体、删除整条。
5. 首次启动**预置几个常用标签**（想法 / 生活 / 工作 / 心情）方便上手。

## v2 功能（已实现）
- **语音录制**：记录页「语音」按钮 → 录音弹层（AVAudioRecorder，AAC/m4a）→ 详情页播放条
  （播放/暂停 + 进度）。
- **视频**：`PhotosPicker` 同时支持选视频；时间轴/详情异步取首帧做缩略图（NSCache 缓存），
  全屏用 AVKit `VideoPlayer` 播放。
- **标签管理页**：时间轴筛选菜单 →「管理标签…」—— 改名、改色（调色板）、左滑删除、
  **合并到其他标签**（记录挪过去后删除本标签）。
- **搜索**：时间轴顶部搜索框，按文字内容或标签名过滤。

## v3 功能（App 内三块，已实现）
- **心情图标**：记录页可选一个心情（😄🙂😐😔😣，再点取消）；时间轴卡片和详情显示对应 emoji + 颜色。
- **地点标签**：记录页「添加当前位置」用 CoreLocation 一次性定位 + 反查地名；详情页用 MapKit
  小地图展示，点一下用系统地图打开。
- **去年今日**：时间轴顶部出现「去年今日」横幅（往年同月同日的记录），点开按年份回看。
- > 桌面 Widget 留到后续（需要新建 extension target + App Group 共享存储）。

## 数据模型（SwiftData，CloudKit 友好）
CloudKit 约束：所有属性给默认值或可选、所有关系可选且有反向、不用唯一约束。

- **Entry（一条记录）**：`id, text, createdAt, updatedAt, moodRaw?, latitude?, longitude?, placeName?`，
  关系 `media: [MediaItem]?`（级联删除）、`tags: [Tag]?`。
- **MediaItem（媒体）**：`id, kindRaw(photo/video/audio), order, createdAt, data: Data?`（外部存储），反向 `entry`。
- **Tag（标签）**：`id, name, colorHex, createdAt`，反向 `entries: [Entry]?`。

## 工程结构
```
Moments/
  project.yml                       XcodeGen 配置（iOS app）
  SPEC.md  README.md
  Moments/
    App/MomentsApp.swift            @main，配置带 CloudKit 的 ModelContainer
    Models/Entry.swift  Tag.swift  MediaItem.swift  Mood.swift
    Features/
      Timeline/TimelineView.swift  TimelineRowView.swift
      Compose/ComposeView.swift  AudioRecordSheet.swift
      Detail/EntryDetailView.swift
      Tags/TagManagerView.swift
      Memories/MemoriesView.swift
    Components/FlowLayout.swift  TagChip.swift  AudioPlayerView.swift  Color+Hex.swift  DateFormatting.swift
    Support/TagSeeder.swift  AudioRecorder.swift  VideoThumbnailCache.swift  LocationProvider.swift
    Resources/Info.plist  Moments.entitlements  Assets.xcassets
```

## 构建 & 运行
1. 安装 XcodeGen：`brew install xcodegen`
2. `cd Moments && xcodegen generate && open Moments.xcodeproj`
3. 在 `project.yml` 把 `DEVELOPMENT_TEAM` 改成你的 Apple 开发者 Team ID；
   如需改 Bundle ID，记得同步改 `Moments.entitlements` 里的 iCloud 容器名（`iCloud.<bundleid>`）。
4. Xcode 选真机或模拟器运行。iCloud 同步需登录 iCloud 账户并联网。

## 里程碑
- **M1 ✅**：数据模型 + 时间轴 + 快速记录（文字/照片/标签）+ 详情/编辑/删除 + CloudKit 配置。
- **M2 ✅**：语音录制 + 视频；标签管理页（改色/改名/合并）；搜索。
- **M3（App 内三块）✅**：心情图标、地点标签（CoreLocation + MapKit）、去年今日。
- **M3 余项**：桌面 Widget（需新建 extension target + App Group 共享 SwiftData 存储）。
