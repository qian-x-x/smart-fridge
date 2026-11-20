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

## Blender 场景

可编辑源文件为 [fridge_scene.blend](../../docs/design/realistic-fridge/fridge_scene.blend)。Web 从 `web/fridge3d/assets/fridge-scene.glb` 加载冰箱和两侧台面。Three.js 按源文件的部件名称绑定双门和两个抽屉，并在打开时显示内衬及库存。Android 首页和登录背景使用同一场景渲染的参考图。

修改 Blender 源文件后，在仓库根目录用 Blender 5.3 重新导出。可将命令中的 `blender` 替换为本机可执行文件路径。导出脚本在内存中加工内腔并写入 GLB，保留源文件以便继续编辑。

```powershell
blender --background --factory-startup --disable-autoexec docs/design/realistic-fridge/fridge_scene.blend --python-exit-code 1 --python scripts/Export-FridgeScene.py
node --test scripts/tests/fridge3d.test.mjs
```

## 目录

- `lib/core`：配置、网络、会话、主题和路由。
- `lib/features/auth`：真实登录、注册与本地会话。
- `lib/features/fridge`：Flutter 响应式首页、Three.js WebGL 真 3D 冰箱和食材详情。
- `lib/features/recipe`：菜谱推荐页面。
- `lib/features/profile`：家庭协作与账号退出。
- `lib/shared`：主导航布局。

## 当前功能范围

支持登录注册、家庭与成员管理、食材管理及临期查看、操作记录撤销与恢复、18 道菜谱与做饭扣减。冰箱分为冷藏、变温和冷冻，含五个默认容器。冷藏使用双门正面视角，选择冷冻或变温时只打开选中的抽屉，俯视画面保留抽屉四边和四角。Web 使用 Three.js 实时镜头，Android 使用来自同一场景的参考图。点击分区时两端均以 400 毫秒过渡。家庭数据通过重新加载同步，临期阈值由服务端统一配置。

家庭页只提供已接入的家庭与账号操作。完整目录和范围见 [项目目录](../../docs/项目目录.md)。
