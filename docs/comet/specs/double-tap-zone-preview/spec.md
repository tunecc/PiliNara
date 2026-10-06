# 双击区域调整（完整目标规格）

本规格描述归档后 `double-tap-zone-preview` 能力的完整行为：播放器设置中的「双击区域调整」页面支持横屏 / 竖屏两种模仿预览模式，且播放器双击手势实际按配置区域判定。

## 能力概述

设置 → 播放器设置 →「双击区域调整」打开可视化调整页。页面提供 横屏 / 竖屏 预览模式切换：竖屏模式以竖幅（约 9:16）画布模仿竖屏播放页，横屏模式以宽幅（约 16:9）黑底画布模仿横屏播放器；两种模式展示同一份双击区域配置，都可以拖拽左右分隔线调整「快退 / 播放暂停 / 快进」三区宽度。保存后，播放器双击手势按配置区域判定，配置真实生效。

## 数据模型（不变）

- 存储键：`SettingBoxKey.doubleTapBackwardZone` / `doubleTapForwardZone`（int 百分比，存于 setting box），横竖屏共用同一套值，不新增配置结构、不做迁移。
- 读取：`Pref.doubleTapBackwardZone` / `Pref.doubleTapForwardZone`，经 `DoubleTapSeekLayout.clamp*Percent` 归一化，默认 25。
- 布局模型：`DoubleTapSeekLayout`（`lib/plugin/pl_player/models/double_tap_seek_layout.dart`），约束 `minSidePercent=1`、`maxSidePercent=40`、`minCenterPercent=20`，`normalize` / `clamp` / `resolveType` 算法不变。
- 双击时长：`Pref.doubleTapBackwardDuration` / `Pref.doubleTapForwardDuration`（5/10/15/20/30 秒选项）不变。

## 调整页 UI（`lib/pages/setting/pages/double_tap_seek_zone_setting.dart`）

- 顶部工具栏：返回、标题「双击快进/快退区域」、恢复默认（重置为 25/50/25）、保存，保留现有行为。
- **预览模式切换**：横屏 / 竖屏 两个切换项（分段控件或等价 UI）；进入页面默认竖屏；切换只在页面内生效，不持久化。
- **竖屏预览**：竖幅画布（宽高比约 9:16，适配可用空间），黑底，模仿竖屏播放页：中央播放/暂停图标，左区显示「快退 X 秒」动作提示、右区显示「快进 X 秒」动作提示（图标 + 文案，X 取当前配置的双击时长）。
- **横屏预览**：宽幅画布（宽高比约 16:9），黑底，模仿横屏播放器：同样的中央图标与左右动作提示。
- 两种模式的画布上都绘制三条区域：左「快退区」、中「播放/暂停区」、右「快进区」，区域边界为可拖拽分隔线，拖拽交互保留现状（`onHorizontalDragUpdate`，`delta.dx / 画布宽度` 换算百分比），拖拽中百分比实时刷新。
- 百分比约束在两侧一致：拖拽结果经 `DoubleTapSeekLayout.clamp` 归一化（左右各 1%~40%，中间 ≥20%）。
- 底部信息区：拖拽说明 + 左/中/右百分比 chip；两种模式显示同一份百分比。
- 保存：写入 `doubleTapBackwardZone` / `doubleTapForwardZone`，行为与现状一致；恢复默认把两值重置为 25 并刷新预览。
- 快进/快退时长设置变化后，重新进入调整页时动作提示中的秒数随之变化（提示读取当前配置，不缓存旧值）。

## 播放器双击判定（`lib/plugin/pl_player/view/view.dart`）

- `onDoubleTapDownMobile` 删除硬编码 `maxWidth / 4`（25%/50%/50%）三段判定，改为：

```dart
final type = plPlayerController.doubleTapSeekLayout.resolveType(
  tapPosition: details.localPosition.dx,
  maxWidth: maxWidth,
);
plPlayerController.doubleTapFuc(type);
```

- `PlPlayerController.doubleTapSeekLayout` getter（读取 `Pref.doubleTapBackwardZone` / `doubleTapForwardZone` 并 normalize）保持现状；横竖屏（全屏与否）使用同一份配置。
- `DoubleTapSeekLayout.resolveType`：`tapPosition < backwardPercent% * maxWidth` → left；`< (100 - forwardPercent)% * maxWidth` → center；否则 right（以现有实现为准）。
- 直播（`isLive`）与控制栏锁定（`controlsLock`）时忽略双击的现状不变。
- 上下滑动手势（亮度/音量）的 `maxWidth / 3` 划分不属于本能力，保持现状。

## 设置项副标题

`lib/pages/setting/models/play_settings.dart` 的「双击区域调整」条目副标题保持现状逻辑：按 `DoubleTapSeekLayout.normalize` 实时计算并展示「左 x% / 中 y% / 右 z%」。

## 行为示例

- 左区配置 10% 时：双击画布（播放器）左侧 10% 以内 → 快退；10%~(100-右区)% → 播放/暂停；其余 → 快进。
- 配置在调整页保存后立即对下一次双击生效；重启 App 后保留。
