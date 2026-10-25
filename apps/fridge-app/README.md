# 小满冰箱 Flutter 用户端

Android 与 Flutter Web/PWA 共用同一代码库。

## 启动

```powershell
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

Android 模拟器：

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

未启动 Gateway 时，可以在登录页选择“先用演示数据看看”。

## 验证与构建

```powershell
flutter analyze
flutter test
flutter build web --release
flutter build apk --release
```

Windows 中文路径可能触发 Gradle 或 Dart AOT 的路径限制。仓库根目录的 `scripts/Build-Flutter.ps1` 会自动使用纯 ASCII Junction 执行完整检查与构建。

当前 Android release 包使用模板 debug 签名，只用于开发验收；正式签名在交付阶段注入。

## 目录

- `lib/core`：配置、网络、会话、主题和路由。
- `lib/features/auth`：真实登录、注册与本地会话。
- `lib/features/fridge`：Flutter 响应式首页、Three.js WebGL 真 3D 冰箱和食材详情。
- `lib/features/recipe`：菜谱推荐页面。
- `lib/features/profile`：家庭、设置和退出。
- `lib/shared`：主导航布局。
