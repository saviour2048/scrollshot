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
1. **时间轴主界面**：按天分组、倒序，左侧竖直时间线 + 时间点，右侧记录卡片（文字 + 照片缩略图 + 标签）。
2. **快速记录**：浮动「+」打开记录页 —— 写文字、`PhotosPicker` 加多张照片、选/新建标签；
   保存时**自动写入当前时间戳**。
3. **标签**：彩色标签，可在记录页即时新建；时间轴顶部可按标签筛选。
4. **详情 / 编辑 / 删除**：点卡片进详情，可看大图、编辑文字与标签、增删照片、删除整条。
5. 首次启动**预置几个常用标签**（想法 / 生活 / 工作 / 心情）方便上手。

> 视频、语音录制留到 v2（数据模型已用 `MediaKind` 预留 `.video / .audio`）。

## 数据模型（SwiftData，CloudKit 友好）
CloudKit 约束：所有属性给默认值或可选、所有关系可选且有反向、不用唯一约束。

- **Entry（一条记录）**：`id, text, createdAt, updatedAt`，关系 `media: [MediaItem]?`（级联删除）、`tags: [Tag]?`。
- **MediaItem（媒体）**：`id, kindRaw(photo/video/audio), order, createdAt, data: Data?`（外部存储），反向 `entry`。
- **Tag（标签）**：`id, name, colorHex, createdAt`，反向 `entries: [Entry]?`。

## 工程结构
```
Moments/
  project.yml                       XcodeGen 配置（iOS app）
  SPEC.md  README.md
  Moments/
    App/MomentsApp.swift            @main，配置带 CloudKit 的 ModelContainer
    Models/Entry.swift  Tag.swift  MediaItem.swift
    Features/
      Timeline/TimelineView.swift  TimelineRowView.swift
      Compose/ComposeView.swift     快速记录 / 编辑
      Detail/EntryDetailView.swift
    Components/FlowLayout.swift  TagChip.swift  Color+Hex.swift  DateFormatting.swift
    Support/TagSeeder.swift
    Resources/Info.plist  Moments.entitlements  Assets.xcassets
```

## 构建 & 运行
1. 安装 XcodeGen：`brew install xcodegen`
2. `cd Moments && xcodegen generate && open Moments.xcodeproj`
3. 在 `project.yml` 把 `DEVELOPMENT_TEAM` 改成你的 Apple 开发者 Team ID；
   如需改 Bundle ID，记得同步改 `Moments.entitlements` 里的 iCloud 容器名（`iCloud.<bundleid>`）。
4. Xcode 选真机或模拟器运行。iCloud 同步需登录 iCloud 账户并联网。

## 里程碑
- **M1（本次）**：数据模型 + 时间轴 + 快速记录（文字/照片/标签）+ 详情/编辑/删除 + CloudKit 配置。
- **M2**：语音录制 + 视频；标签管理页（改色/改名/合并）；搜索。
- **M3**：地图/地点标签、心情图标、Widget、回忆（去年今日）。
