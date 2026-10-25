# WebGL 真 3D 用户端视觉验收

## 视觉基准

- Figma：<https://www.figma.com/design/dBXCo4YNTagNNs5cnvONEq>
- 桌面关门概念：[01-home-closed.jpg](webgl-concepts/01-home-closed.jpg)
- 左门开启概念：[02-left-door-open.jpg](webgl-concepts/02-left-door-open.jpg)
- 抽屉开启概念：[03-drawer-open.jpg](webgl-concepts/03-drawer-open.jpg)
- 移动端概念：[04-mobile-closed.jpg](webgl-concepts/04-mobile-closed.jpg)

概念图由 Figma `generate_image` 的低成本模型生成。实现不使用概念图作为页面背景，冰箱、门、抽屉、层架和食材均由 Three.js 实时几何渲染。

## 实现截图

- 桌面首页：[desktop-home.png](implementation/desktop-home.png)
- 桌面左门开启：[desktop-left-door-open.png](implementation/desktop-left-door-open.png)
- 桌面变温抽屉开启：[desktop-variable-drawer-open.png](implementation/desktop-variable-drawer-open.png)
- 移动端首页：[mobile-home.png](implementation/mobile-home.png)
- 移动端抽屉开启：[mobile-variable-drawer-open.png](implementation/mobile-variable-drawer-open.png)

## 保真核对

| 对比点 | 概念基准 | 浏览器实现 | 结论 |
| --- | --- | --- | --- |
| 冰箱结构 | 上方左右双门，中部变温抽屉，下部冷冻抽屉 | Three.js 中以四个独立可动组件构建，铰链和滑轨可见 | 通过 |
| 颜色与材质 | 香槟米色家电、深可可色把手、米白环境 | PBR 金属材质、程序化拉丝纹理、可可色五金、鼠尾草绿状态 | 通过 |
| 桌面布局 | 左导航、中央大模型、右侧状态面板 | Flutter 左侧导航栏、916 × 620 WebGL 舞台、324 像素状态栏 | 通过 |
| 开门交互 | 左上 French door 开启后露出内腔 | 射线拾取左门，绕左铰链开启，露出层架、食材和柔光 | 通过 |
| 抽屉交互 | 中部抽屉沿轨道前移，内部可见 | 抽屉前移 1.32 个场景单位，镜头抬高，内部托盘和静态轨道可见 | 通过 |
| 移动端 | 冰箱为第一视觉，控件位于上下区域 | 390 × 844 首屏完整显示冰箱，420 像素高 3D 舞台，无横向溢出 | 通过 |
| 业务文本 | 现有功能文案与真实食材状态 | 保留登录、家庭成员、临期、菜谱、分区和表格降级文案 | 通过，无外部帖子版式 |

## 验证方式

- 使用 Codex 内置浏览器访问 `http://127.0.0.1:3000`。
- 桌面检查视口为 1440 × 900，移动端检查视口为 390 × 844。
- 点击 3D 模型左上部门后，场景状态回传“冷藏室已打开”；Flutter 分区同步后不会再次发送关闭指令。
- 点击中部抽屉后，场景状态回传“变温室已打开”，上方门保持关闭。
- 浏览器控制台最终无 error，3D 模块、Three.js core 和 RoomEnvironment 均从本地静态站点加载。
- 当前模型无法直接读取图片输入，因此截图审阅通过 `ds-vision-skill` 路由到 `glm-4.1v-thinking-flash`；文档渲染图另以 Word 导出 PDF、Poppler 转 PNG 后检查。

## 已知边界

- Web 是本次 WebGL 真 3D 验收路径。Android 构建保持通过，但 3D 视口当前显示同数据的兼容降级视图。
- 冰箱食材当前仍为演示数据，S2 接入 `fridge-service` 后再替换为真实 API 数据。
- Android release APK 仍使用模板 debug 签名，正式分发前必须配置 release keystore。
