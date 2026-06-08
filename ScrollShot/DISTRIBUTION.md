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
