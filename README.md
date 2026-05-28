# 高德地图 Flutter 应用

这是一个基于 Flutter 和高德地图 SDK 开发的地图应用。

## 功能特性

- 🗺️ **地图显示** - 集成高德地图，支持标准、卫星、夜间三种地图类型
- 📍 **定位功能** - 显示当前位置（需要权限）
- 🎯 **标记功能** - 点击地图任意位置添加标记
- 🧭 **指南针** - 显示地图方向
- 📏 **比例尺** - 显示地图比例
- 🔄 **地图切换** - 支持标准、卫星、夜间地图类型切换

## 项目结构

```
amap_map_app/
├── android/              # Android 平台配置
│   └── app/src/main/
│       └── AndroidManifest.xml  # 包含高德地图 API Key 配置
├── ios/                  # iOS 平台配置
├── lib/
│   └── main.dart         # 主程序入口和地图页面
├── pubspec.yaml          # 依赖配置
└── README.md
```

## 配置说明

### 1. 申请高德地图 API Key

在使用本应用之前，你需要先申请高德地图 API Key：

1. 访问 [高德开放平台](https://lbs.amap.com/)
2. 注册并登录账号
3. 进入控制台，创建新应用
4. 为应用添加 Key，选择「Android 平台」和「iOS 平台」
5. 获取 Android Key 和 iOS Key

### 2. 配置 Android API Key

编辑 `android/app/src/main/AndroidManifest.xml`，将 `YOUR_AMAP_API_KEY` 替换为你的 Android Key：

```xml
<meta-data
    android:name="com.amap.api.v2.apikey"
    android:value="你的高德地图 Android API Key" />
```

### 3. 配置 iOS API Key（如需要）

编辑 `ios/Runner/AppDelegate.swift`，添加以下代码：

```swift
import AMapFoundationKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    AMapServices.shared().enableHTTPS = true
    AMapServices.shared().apiKey = "你的高德地图 iOS API Key"
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## 运行应用

### 环境要求

- Flutter SDK >= 3.11.5
- Dart SDK >= 3.11.5
- Android SDK（Android 开发）
- Xcode（iOS 开发，仅限 macOS）

### 安装依赖

```bash
cd amap_map_app
flutter pub get
```

### 运行应用

**Android：**
```bash
flutter run
```

**iOS（需要 macOS）：**
```bash
flutter run -d ios
```

## 使用说明

1. **切换地图类型** - 点击右上角按钮可在标准、卫星、夜间地图之间切换
2. **添加标记** - 点击地图任意位置可添加标记
3. **控制显示选项** - 使用右侧悬浮按钮控制定位、指南针、比例尺的显示
4. **清除标记** - 点击红色清除按钮可移除所有标记
5. **缩放地图** - 双指捏合可缩放地图

## 依赖库

- [amap_flutter_map](https://pub.dev/packages/amap_flutter_map) - 高德地图 Flutter 插件
- [amap_flutter_base](https://pub.dev/packages/amap_flutter_base) - 高德地图基础库

## 官方文档

- [高德地图 Flutter 插件文档](https://lbs.amap.com/api/flutter/guide/map-flutter-plug-in/create-map)
- [高德地图 Flutter 信息窗体](https://lbs.amap.com/api/flutter/guide/map-flutter-plug-in/map-flutter-info)

## 注意事项

1. 请确保已正确配置 API Key，否则地图无法正常显示
2. Android 应用需要网络权限和定位权限
3. iOS 应用需要在 `Info.plist` 中添加定位权限描述
4. 首次运行可能需要下载地图数据，请确保设备网络连接正常

## 许可证

本项目仅供学习参考使用。
