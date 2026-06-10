# 分发 ScrollShot（直接分发 / Developer ID + 公证）

适合像 CleanShot、Rectangle 这样的工具:**自己签名 + Apple 公证 → 别人双击就能用**,不上 App Store(自动滚动用了辅助功能,沙盒/审核会卡)。

## 一次性准备

1. **加入 Apple Developer Program**（¥688/年）：<https://developer.apple.com/programs/>
2. **拿 Developer ID 证书**：Xcode ▸ Settings ▸ Accounts ▸ 选账号 ▸ Manage Certificates ▸ 左下 **+** ▸ **Developer ID Application**。
3. **存公证凭据**（用 App 专用密码，去 <https://appleid.apple.com> ▸ 登录与安全 ▸ App 专用密码 生成）：
   ```bash
   xcrun notarytool store-credentials scrollshot-notary \
     --apple-id "zhangtongwei@gmail.com" --team-id 5QZY8FV25Y
   ```

## 生成图标（首次 / 改图标时）

```bash
cd ScrollShot
swift scripts/make_icon.swift     # 写入 Assets.xcassets/AppIcon.appiconset
```

## 一键出包

```bash
cd ScrollShot
chmod +x scripts/build_notarize.sh   # 仅首次
./scripts/build_notarize.sh
```

完成后得到:
- `build/export/ScrollShot.app` —— 已签名 + 已公证 + 已装订
- `build/ScrollShot.dmg` —— **把这个发给别人**,双击拖入「应用程序」即可

## 别人首次使用

双击打开(因为已公证,不会被 Gatekeeper 拦)。首次截图/自动滚动时,各授权一次:
- 系统设置 ▸ 隐私与安全性 ▸ **屏幕录制** → 勾选 ScrollShot
- （要用自动滚动才需要）**辅助功能** → 勾选 ScrollShot
- 授权后退出重开一次。

## 验证

```bash
spctl -a -vvv build/export/ScrollShot.app     # 应显示 accepted / Developer ID
xcrun stapler validate build/export/ScrollShot.app
```

## 升级版本

改 `project.yml` 里的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`,再跑一次 `build_notarize.sh`。

---

## 还没公证就想先发?（应急,可用）

公证只决定"对方打开时弹不弹警告"。App 只要**已 Developer ID 签名**(`codesign -dvv` 能看到 `Developer ID Application: …`),就可以现在先发。

**只打包、不公证**(跳过 notarytool/staple):
```bash
cd ScrollShot
hdiutil create -volname ScrollShot -srcfolder build/export/ScrollShot.app -ov -format UDZO build/ScrollShot.dmg
```

**对方首次打开**(因为没公证,要绕一下 Gatekeeper):
1. 双击 DMG,把 ScrollShot 拖进「应用程序」。
2. 第一次打开若被拦:**系统设置 ▸ 隐私与安全性** → 底部"已阻止 ScrollShot" → **仍要打开**;或在「应用程序」里**右键 → 打开**。
3. 之后正常双击,再授屏幕录制(+自动滚动需辅助功能)。

> ⚠️ 新开发者账号的**首次**公证可能卡 In Progress 很久(数小时~1 天),偶尔要发工单(开发与技术 ▸ 代码签名)让 Apple 推进。等首次公证开通后,以后 `build_notarize.sh` 出的包就**双击零提示**了。

