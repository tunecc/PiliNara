# 悬浮底栏显示样式（完整目标规格）

本规格描述归档后 `floating-nav-bar-display-style` 能力的完整行为：首页悬浮底栏支持「图标+文字 / 仅图标 / 仅文字」三种显示样式，用户在设置中三选一，选择立即生效并在重启后保留。「仅图标」样式在保持整体尺寸（容器高度、指示器高度、图标大小）与其他样式一致的前提下，仅收窄单元格宽度以消除单个 icon 的水平留白，不整体缩小。

## 能力概述

开启「悬浮底栏」后，首页使用 `FloatingNavigationBar` 作为底部导航。设置 → 样式 中新增「悬浮底栏样式」条目，提供三个互斥选项：

| 选项 | 悬浮底栏显示 |
| --- | --- |
| 图标+文字（默认） | 每个 tab 同时显示图标与文字，沿用现有 `alwaysShow` 行为（所有项都显示文字） |
| 仅图标 | 只显示图标，隐藏文字（选中项与未选中项都隐藏），保留 tooltip 作为文字兜底；单元格宽度收窄为 56dp |
| 仅文字 | 只显示文字，隐藏图标；所有 tab 的文字恒显并居中 |

设置只作用于悬浮底栏。MD3 样式底栏（`NavigationBar`）、传统底栏（`BottomNavigationBar`）与侧边栏（`NavigationRail` / `NavigationDrawer`）保持现状。

## 数据模型

- 枚举 `FloatingNavBarStyle`（`lib/models/common/floating_nav_bar_style.dart`）实现 `EnumWithLabel`：
  - `iconAndLabel('图标+文字')`
  - `iconOnly('仅图标')`
  - `labelOnly('仅文字')`
- 存储键：`SettingBoxKey.floatingNavBarStyle = 'floatingNavBarStyle'`，值取枚举 `index`（int），存于 setting box。
- 读取：`Pref.floatingNavBarStyle`，未设置或值越界时返回 `FloatingNavBarStyle.iconAndLabel`；不抛异常、不做数据迁移。
- 写入：设置项选择后写入 setting box 的 `floatingNavBarStyle`。
- 主控制器 `MainController` 持有响应式样式值（初值取自 `Pref.floatingNavBarStyle`），设置页选择后同步更新，使主页悬浮底栏无需重启即可重建。

## 设置入口

- 位置：设置 → 样式，紧接现有「悬浮底栏」开关之后。
- 形态：`PopupModel` + `EnumWithLabel` 弹窗选择项，标题「悬浮底栏样式」，列出三个选项并回显当前值。
- 选择后立即写入持久化并更新 `MainController` 的响应式样式值。
- 该条目不影响「悬浮底栏」开关本身；「悬浮底栏」关闭时该选择仍可保存，但不改变其他底栏外观。

## 悬浮底栏渲染

`FloatingNavigationBar` 持有 `style` 参数，类型 `FloatingNavBarStyle`，默认 `FloatingNavBarStyle.iconAndLabel`。样式经 `_NavigationDestinationInfo` 下发给每个 destination。

### 图标+文字（`iconAndLabel`）

- 与改动前一致：图标在上、文字在下，文字按现有 `labelBehavior` 渲染（默认 `alwaysShow`，所有项文字可见）。
- 不出现 tooltip；点击回调 `onDestinationSelected` 不变。

### 仅图标（`iconOnly`）

- 该样式下有效 `labelBehavior` 强制为 `alwaysHide`：文字淡出（透明度 0），选中项也不显示文字。
- 图标在 destination 内垂直居中。
- 每个 destination 带 `Tooltip`，message 为对应 tab 的 `label`（沿用现有 `_NavigationBarDestinationTooltip` 机制）。
- 选中指示器、点击回调、badge 等不变。

### 仅文字（`labelOnly`）

- destination 不构建图标，只构建文字。
- 文字在该 destination 内居中，并且所有 destination（选中与未选中）都可见；不依赖选中动画。
- 不出现 tooltip（文字已直接可见）。
- 点击区域覆盖整个 destination，点击仍回调 `onDestinationSelected`。
- 选中指示器仍按 `selectedIndex` 显示在文字后方，颜色与形状沿用现有实现。

## 尺寸规范

三种样式的容器高度一致，「仅图标」只收窄单元格宽度：

- 容器高度：三种样式均为 64dp（不含 `bottomPadding`，默认 8dp）；圆角 = 容器高度 / 2 = 32dp，公式不随样式变化。
- 容器内边距：四周各 4dp（`_kIndicatorPaddingInt`），指示器高度 = 容器高度 − 2×4dp = 56dp，三种样式一致。
- `iconAndLabel` / `labelOnly`：每个 destination 单元格宽 86dp，整条宽度 N×86dp；指示器配置尺寸 86×56dp，渲染宽度受容器 4dp 内边距均摊收窄（两个 tab 时为 82dp）。
- `iconOnly`：每个 destination 单元格宽 56dp（图标 24dp，两侧各约 16dp），整条宽度 N×56+8dp（含左右各 4dp 容器内边距），指示器 56×56dp。
- `iconOnly` 的收窄只作用于宽度：容器高度、指示器高度、图标大小与圆角公式与其他样式一致，整体不缩小。

Scenario: 仅图标容器高度恢复
WHEN 悬浮底栏样式为「仅图标」
THEN 悬浮底栏容器高度为 64dp，与「图标+文字」「仅文字」样式一致；两个 tab 且 `bottomPadding` 为默认 8dp 时 widget 整体尺寸为 120×72dp
验收：A1

Scenario: 仅图标保持收窄宽度
WHEN 悬浮底栏样式为「仅图标」
THEN 每个 destination 单元格宽度为 56dp，整条宽度为 N×56+8dp；两个 tab 且默认 padding 时整条宽度为 120dp，不回到每项 86dp
验收：A2

Scenario: 仅图标指示器尺寸
WHEN 悬浮底栏样式为「仅图标」且某项被选中
THEN 选中指示器尺寸为 56×56dp
验收：A3

Scenario: 其他样式尺寸不变
WHEN 悬浮底栏样式为「图标+文字」或「仅文字」
THEN 容器高度 64dp、整条宽度 N×86dp（两个 tab 为 172dp）、指示器配置尺寸 86×56dp（渲染宽度按容器内边距均摊，两个 tab 为 82dp），与本 change 之前一致
验收：A4

Scenario: 仅图标行为回归
WHEN 悬浮底栏样式为「仅图标」
THEN 文字淡出透明度为 0、每个 destination 带 `Tooltip`（message 为对应 `label`）、点击仍回调 `onDestinationSelected`
验收：A5

Scenario: 验证基线
WHEN 以 build 生成输入备份/恢复包装运行 `/Users/tune/fvm/versions/3.47.9/bin/flutter analyze` 与相关 `flutter test`
THEN analyze 不新增 error/warning（基线 73 issues / 0 error / 5 warning）；悬浮底栏相关测试全部通过，且 build 生成输入指纹无变化（无 completed-input-drift）
验收：A6

## 兼容与边界

- 现有调用方不传 `style` 时行为与改动前完全一致。
- 尺寸与样式的关系：`iconAndLabel` / `labelOnly` 尺寸不受样式影响（每项宽 86dp、高 64dp，指示器配置尺寸 86×56dp、渲染宽度按容器内边距均摊）；`iconOnly` 容器高度与其他样式一致（64dp），仅单元格宽度收窄为 56dp。底部 padding、隐藏底栏动画（`hideBottomBar`）不随样式变化。
- MD3 底栏、传统底栏、侧边栏分支不读取 `floatingNavBarStyle`。
- 设置页搜索（`settings_search`）通过 `styleSettings` 自动收录该条目，无需额外改动。

## 行为示例

- 默认（从未设置）：进入主页，悬浮底栏显示图标+文字，所有 tab 文字可见。
- 选择「仅图标」：返回主页，悬浮底栏只剩图标，底栏高度与其他样式一致、宽度明显收窄（两个 tab 约 120dp），没有大段水平留白；长按（移动端）或悬停（桌面）显示对应 tab 文字；重启 App 后仍为仅图标。
- 选择「仅文字」：返回主页，悬浮底栏只剩居中文字，「首页 / 动态 / 我的」都可见；点击任一项正常切换 tab。
- 存储值被写坏（例如 99）：读取回退为「图标+文字」，不崩溃。
