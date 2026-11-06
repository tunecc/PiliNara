# 悬浮底栏显示样式（完整目标规格）

本规格描述归档后 `floating-nav-bar-display-style` 能力的完整行为：首页悬浮底栏支持「图标+文字 / 仅图标 / 仅文字」三种显示样式，用户在设置中三选一，选择立即生效并在重启后保留。

## 能力概述

开启「悬浮底栏」后，首页使用 `FloatingNavigationBar` 作为底部导航。设置 → 样式 中新增「悬浮底栏样式」条目，提供三个互斥选项：

| 选项 | 悬浮底栏显示 |
| --- | --- |
| 图标+文字（默认） | 每个 tab 同时显示图标与文字，沿用现有 `alwaysShow` 行为（所有项都显示文字） |
| 仅图标 | 只显示图标，隐藏文字（选中项与未选中项都隐藏），保留 tooltip 作为文字兜底 |
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

`FloatingNavigationBar` 新增 `style` 参数，类型 `FloatingNavBarStyle`，默认 `FloatingNavBarStyle.iconAndLabel`。样式经 `_NavigationDestinationInfo` 下发给每个 destination。

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

## 兼容与边界

- 现有调用方不传 `style` 时行为与改动前完全一致。
- `FloatingNavigationBar` 的尺寸（每项宽 86dp、高 64dp）、圆角、指示器、底部 padding、隐藏底栏动画（`hideBottomBar`）均不受样式影响。
- MD3 底栏、传统底栏、侧边栏分支不读取 `floatingNavBarStyle`。
- 设置页搜索（`settings_search`）通过 `styleSettings` 自动收录该条目，无需额外改动。

## 行为示例

- 默认（从未设置）：进入主页，悬浮底栏显示图标+文字，所有 tab 文字可见。
- 选择「仅图标」：返回主页，悬浮底栏只剩图标；长按（移动端）或悬停（桌面）显示对应 tab 文字；重启 App 后仍为仅图标。
- 选择「仅文字」：返回主页，悬浮底栏只剩居中文字，「首页 / 动态 / 我的」都可见；点击任一项正常切换 tab。
- 存储值被写坏（例如 99）：读取回退为「图标+文字」，不崩溃。
