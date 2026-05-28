# Waygo 项目开发规则

## 核心原则

### 1. 代码质量要求
- **禁止交付存在问题的代码**：所有提交的代码必须通过静态分析
- **必须执行 flutter analyze**：在交付任何代码之前，必须运行 `flutter analyze` 直到没有任何错误和警告
- **不自动运行或编译**：不执行 `flutter run`、`flutter build apk` 或其他编译/运行命令，由用户自行操作

### 2. 开发流程

#### 代码修改前
1. 理解现有代码结构和约定
2. 遵循项目现有的代码风格
3. 检查相关文件的 imports 和依赖

#### 代码修改后
1. **必须执行**：`flutter analyze`
2. 修复所有分析出的问题（errors 和 warnings）
3. 重复步骤 1-2 直到 analyze 完全通过
4. 确认无误后再交付代码

### 3. 分析命令

```bash
# 完整项目分析
flutter analyze

# 查看特定文件问题
flutter analyze lib/main.dart
```

### 4. 禁止操作

❌ **不要执行以下命令**：
- `flutter run` - 不运行应用
- `flutter build apk` - 不编译 APK
- `flutter build ios` - 不编译 iOS 版本
- `flutter test` - 不运行测试（除非用户明确要求）
- 其他任何编译或运行命令

### 5. 代码规范

#### 遵循现有约定
- 使用项目已有的代码风格
- 遵循 Dart/Flutter 最佳实践
- 保持命名一致性
- 添加必要的类型注解

#### Lint 规则
项目使用 `package:flutter_lints/flutter.yaml` 作为基础 lint 规则，配置在 [analysis_options.yaml](file:///c:/Users/Administrator/Desktop/Waygo/analysis_options.yaml) 中。

### 6. 交付标准

在交付代码时，必须确保：
- ✅ `flutter analyze` 无错误
- ✅ `flutter analyze` 无警告
- ✅ 代码符合项目现有风格
- ✅ 没有引入未使用的 imports
- ✅ 没有 TODO 或 FIXME 标记（除非用户要求）

### 7. 项目信息

- **项目名称**: amap_map_app
- **主要功能**: 基于高德地图的地图应用
- **SDK 版本**: ^3.11.5
- **主要依赖**:
  - amap_map: 高德地图 Flutter 插件
  - location: 设备定位
  - http: HTTP 请求
  - liquid_glass_easy: 液态玻璃效果
  - shared_preferences: 本地存储

### 8. 项目结构

```
lib/
├── main.dart              # 应用入口和主地图页面
├── search.dart            # 搜索功能
├── setting.dart           # 设置页面
└── liquid_glass_wrapper.dart  # 液态玻璃封装
```

---

**重要提醒**：所有代码修改必须通过 `flutter analyze` 检查后才能交付！
