# 小易冰箱 Flutter 用户端

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

Windows 中文路径可能触发 Gradle 或 Dart AOT 的路径限制。仓库根目录的 `scripts/Build-Flutter.ps1` 会在原工程执行检查与 Web 构建，再使用纯 ASCII 源码副本构建 Android。

当前 Android release 包使用模板 debug 签名，只用于开发验收；正式签名在交付阶段注入。

## 目录

- `lib/core`：配置、网络、会话、主题和路由。
- `lib/features/auth`：真实登录、注册与本地会话。
- `lib/features/fridge`：Flutter 响应式首页、Three.js WebGL 真 3D 冰箱和食材详情。
- `lib/features/recipe`：菜谱推荐页面。
- `lib/features/profile`：家庭协作与账号退出。
- `lib/shared`：主导航布局。

## 当前功能范围

保留登录注册、家庭与成员管理、食材管理及临期查看、操作记录撤销/恢复、18 道菜谱与做饭扣减。Web 提供 Three.js 实时三维厨房，Android 使用厨房参考图及相同业务表单。家庭数据通过重新加载同步，冰箱使用默认四区与六个容器，临期阈值由服务端统一配置。

家庭页只提供已接入的家庭与账号操作。完整目录和范围见 [项目目录](../../docs/项目目录.md)。
