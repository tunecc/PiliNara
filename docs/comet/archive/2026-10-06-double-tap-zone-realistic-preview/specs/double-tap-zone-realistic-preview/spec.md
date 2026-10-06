# 双击区域调整真实预览（完整目标规格）

本规格描述归档后 `double-tap-zone-realistic-preview` 能力的完整行为：「双击区域调整」页的 横屏 / 竖屏 预览模拟真实播放状态。

## 能力概述

设置 → 播放器设置 →「双击区域调整」页提供 竖屏 / 横屏 两种预览模式，分别模拟真实的竖屏半屏播放与横屏全屏播放状态。竖屏预览在页面顶部呈现 16:9 视频区；横屏预览真实旋转设备为横屏并全屏沉浸，与横屏全屏播放器观感一致。两种模式共用同一份双击区域配置，拖拽调整与保存行为不变。

## 数据模型（不变）

- 配置：`SettingBoxKey.doubleTapBackwardZone` / `doubleTapForwardZone`（int 百分比），横竖屏共用；读取经 `DoubleTapSeekLayout` 归一化，默认 25。
- 约束：`minSidePercent=1`、`maxSidePercent=40`、`minCenterPercent=20`；拖拽经 `clampBackward/ForwardPercentDouble`。
- 时长提示：`Pref.doubleTapBackwardDuration` / `Pref.doubleTapForwardDuration`。

## 旋转与系统栏（复用 `lib/plugin/pl_player/utils/fullscreen.dart`）

- 进入横屏预览（仅移动端，`PlatformUtils.isMobile`）：
  - `hideSystemBar()`（immersiveSticky）；
  - 方向：Android `landscapeLeftMode()`，iOS `landscapeRightMode()`（与播放器 `changeOrientation` 默认一致）。
- 退出横屏预览（切回竖屏模式、保存、或离开页面）：
  - `showSystemBar()` 恢复系统栏；
  - 方向恢复：`Pref.horizontalScreen` 为真 → `fullMode()`，否则 `portraitUpMode()`（与播放器 `resetScreenRotation` 语义一致）。
- 桌面端：不调用任何 `SystemChrome` 方向/系统栏接口，横屏预览仅切换为全屏宽度画布布局。
- 页面 `dispose` 必须在横屏状态下完成恢复，覆盖系统返回键直接退出页面的场景。

## 竖屏预览布局（默认模式）

- 页面结构（自上而下）：
  1. 顶部工具栏（返回、标题、重置、保存）——保留现状。
  2. 模式切换（竖屏 / 横屏 SegmentedButton）——保留现状。
  3. **模拟视频区**：宽度撑满可用宽度、高 = 宽 × 9/16 的黑色区域，即真实半屏播放器所在位置；区内为三区色带（左快退/中播放暂停/右快进）、两条可拖拽分隔线（含底部 快退/快进 标签）、中央播放图标、左右「快退/快进 X 秒」动作提示（内容随区宽自适应，过窄只显示色带）。
  4. **模拟视频页内容**：视频区下方的纯静态占位——标题行、作者行（圆形头像占位 + 名字条）、若干灰色圆角占位块，仅装饰。
  5. 底部面板：拖拽提示 + 左/中/右百分比 chip。
- 拖拽发生在 16:9 视频区内，百分比实时刷新并写同一份状态。

## 横屏预览布局

- 设备旋转后整页进入沉浸式全屏布局：
  - 背景纯黑，三区色带铺满整个屏幕（全屏宽度为拖拽与判定的基准），分隔线可拖拽，中央播放图标与左右动作提示保留。
  - 顶部悬浮精简操作行（退出横屏预览 / 重置 / 保存），底部悬浮「左 x% / 中 y% / 右 z%」紧凑提示；悬浮控件不遮挡可拖拽区域的核心视野。
  - 不渲染竖屏预览的模拟视频页占位内容与常规底部面板。
- 拖拽结果与竖屏模式共用同一状态，切回竖屏预览后分隔线位置同步。

## 行为不变量

- 模式切换、重置、保存、返回的既有流程语义不变；保存仍写同一对配置键并 toast。
- 预览为纯视觉模拟：不播放视频、不响应双击手势、不依赖网络或视频数据。
- 页面在任何时刻离开都不会遗留横屏方向或隐藏的系统栏。
