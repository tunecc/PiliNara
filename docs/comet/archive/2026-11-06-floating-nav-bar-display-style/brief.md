# 目标

为首页悬浮底栏（`FloatingNavigationBar`，设置中「悬浮底栏」开启时使用）增加一个三选一的显示样式设置：**图标+文字**（默认，保持现状）、**仅图标**（隐藏文字说明）、**仅文字**（隐藏图标）。选择后主页悬浮底栏立即以所选样式呈现，重启 App 后保留。

# 范围

- 新增显示样式枚举与持久化：`FloatingNavBarStyle { iconAndLabel, iconOnly, labelOnly }`（实现 `EnumWithLabel`，中文标签「图标+文字 / 仅图标 / 仅文字」），写入 setting box 的 `floatingNavBarStyle`（int index），读取默认 `iconAndLabel`，越界回退默认。
- `FloatingNavigationBar` 新增 `style` 参数（默认 `iconAndLabel`，向后兼容）。三种样式的渲染规则：
  - `iconAndLabel`：现有行为不变——每个 destination 同时渲染图标与文字（文字沿用现有 `labelBehavior`，默认 `alwaysShow`，即所有项都显示文字）。
  - `iconOnly`：文字不显示（选中与未选中均不显示），图标居中；复用现有 `alwaysHide` 的淡出与 tooltip 机制，tooltip 内容为对应 tab 的文字。
  - `labelOnly`：图标不渲染，只渲染文字，文字在 destination 内居中且所有项恒显（不只选中项），无 tooltip；选中指示器、点击切换、badge 等既有行为不变。
- 设置入口：设置 → 样式 → 在「悬浮底栏」开关之后新增「悬浮底栏样式」弹窗选择项（复用现有 `PopupModel` + `EnumWithLabel` 选择控件），三个选项互斥，回显当前值。
- 立即生效：主控制器持有响应式样式值，设置页选择后同步更新；主页悬浮底栏随 `Obx` 重建；重启后从 Hive 恢复。
- 测试：新增 widget 测试覆盖三种样式的关键可观察行为（文字/图标可见性、tooltip、点击回调）以及 `Pref` 默认值与越界回退。

## 目录结构

### 新建

- `lib/models/common/floating_nav_bar_style.dart`：`FloatingNavBarStyle` 枚举（`iconAndLabel` / `iconOnly` / `labelOnly`，`EnumWithLabel` 中文标签）。
- `test/common/widgets/floating_navigation_bar_test.dart`：悬浮底栏三样式 widget 测试。
- `test/utils/floating_nav_bar_style_pref_test.dart`：`Pref.floatingNavBarStyle` 默认值与越界回退的单元测试。
- `docs/comet/changes/floating-nav-bar-display-style/specs/floating-nav-bar-display-style/spec.md`：完整目标规格。

### 修改

- `lib/common/widgets/floating_navigation_bar.dart`：`FloatingNavigationBar` 新增 `style` 参数并下发到 destination；`FloatingNavigationDestination` 按样式选择 `iconAndLabel` / `iconOnly` / `labelOnly` 布局。
- `lib/pages/main/controller.dart`：新增响应式 `floatingNavBarStyle`（读取 `Pref.floatingNavBarStyle`）。
- `lib/pages/main/view.dart`：向 `FloatingNavigationBar` 传入当前样式（在已有 `Obx` 内读取，切换设置后立即重建底栏）。
- `lib/pages/setting/models/style_settings.dart`：新增「悬浮底栏样式」`PopupModel`，选择后写入设置并同步主控制器。
- `lib/utils/storage_key.dart`：新增 `floatingNavBarStyle` 键。
- `lib/utils/storage_pref.dart`：新增 `Pref.floatingNavBarStyle` getter。

### 明确不建

- 不新增设置页、路由或独立配置页面；沿用现有样式设置列表与弹窗控件。
- 不改动 MD3 样式底栏（`enableMYBar` 分支）、传统 `BottomNavigationBar`、侧边栏 `NavigationRail`/`NavigationDrawer` 的显示样式；本设置只作用于悬浮底栏。
- 不新增主题、字号、图标尺寸等额外定制项。

# 非目标

- 不改变悬浮底栏的尺寸（宽 86dp/项、高 64dp）、圆角、指示器、颜色、阴影、点击切换、隐藏底栏动画与 badge 等现有行为。
- 不为 MD3 底栏、传统底栏或侧边栏提供同类三选一样式。
- 不迁移、不改写已有设置数据；未设置过该项的用户得到默认「图标+文字」。
- 不改变「悬浮底栏」开关本身的语义与重启生效方式。

# 验收示例

- A1: `FloatingNavigationBar` 存在 `style` 参数且默认值为 `FloatingNavBarStyle.iconAndLabel`；默认样式的渲染与改动前一致：每个 destination 同时渲染图标与文字，所有项文字可见（`alwaysShow`），tooltip 不出现，点击仍回调 `onDestinationSelected`。
- A2: `style: FloatingNavBarStyle.iconOnly` 时每个 destination 的文字不显示（选中与未选中项均无可见文字，文字 fade 透明度为 0），图标居中显示；每个 destination 带 `Tooltip`，其 message 等于对应 `label`；点击仍回调 `onDestinationSelected`。
- A3: `style: FloatingNavBarStyle.labelOnly` 时 destination 不渲染图标，只渲染文字；所有 destination（含未选中项）的文字均可见并在 destination 内居中，不出现 tooltip；选中指示器仍按 `selectedIndex` 显示，点击仍回调 `onDestinationSelected`。
- A4: 设置 → 样式 中存在「悬浮底栏样式」条目，弹窗列出「图标+文字 / 仅图标 / 仅文字」三个互斥选项并回显当前值；选择后写入 `SettingBoxKey.floatingNavBarStyle`（int index），主页悬浮底栏无需重启立即切换为该样式，重启 App 后仍为该样式。
- A5: 从未设置过该项时 `Pref.floatingNavBarStyle` 返回 `FloatingNavBarStyle.iconAndLabel`；存储值超出枚举范围时同样回退 `iconAndLabel`，不抛异常。
- A6: 该设置只影响 `floatingNavBar == true` 的悬浮底栏；MD3 底栏、传统底栏与侧边栏的渲染不读取 `floatingNavBarStyle`；「悬浮底栏」关闭时切换样式不改变其他底栏的外观。
- A7: `flutter analyze` 相对本 change 前基线不新增 error/warning；新增的 widget 测试与 `Pref` 单元测试随 `flutter test` 通过。

# 约束与不变量

- 默认行为兼容：未设置该项的既有用户保持「图标+文字」，观感与改动前一致。
- `FloatingNavigationBar` 的公开 API 保持向后兼容：新增参数带默认值，现有调用方（`lib/pages/main/view.dart`）不传该参数时行为不变。
- 只作用于悬浮底栏；不得改动 `NavigationBar`（MD3）与 `BottomNavigationBar`（传统）分支的渲染代码。
- 不修改 `pubspec.yaml` / `pubspec.lock` / 三钉依赖与 material_ui 补丁；Flutter 命令使用本机绝对路径 `/Users/tune/fvm/versions/3.47.9/bin/flutter`（与 `.fvmrc`、`pubspec.yaml` 的 `environment.flutter: 3.47.9` 一致），不使用 PATH 中的裸 `flutter`。
- 存储键沿用项目既有模式：`SettingBoxKey` 常量 + `Pref` getter，读写 setting box，不新增 Hive box。
- 提交前核对 `git status`，只包含本 change 的实现与正式产物；新增 `test/` 文件受 `test*` 忽略规则影响时用 `git add -f` 纳入。

# 决策

- D1 工作区采用 `current`：改动开始前工作区干净、没有其他 active Native change、无并行诉求。
- D2 三种样式合并为一个三选一设置项（用户原话「三种样式的选择」），不做两个独立开关；默认「图标+文字」保持既有用户观感。
- D3 `iconOnly` 下选中项也不显示文字，保留 tooltip 作为文字兜底；`labelOnly` 下所有 tab 恒显文字（不只选中项），避免未选中项失去可识别性，且不显示 tooltip。
- D4 选择后立即生效：主控制器用响应式值承载样式，设置页选择后同步更新；同时写入 Hive，重启后恢复。
- D5 范围只覆盖悬浮底栏，不扩展到 MD3 底栏、传统底栏与侧边栏。
- D6 设置入口放在「悬浮底栏」开关之后，复用现有 `PopupModel` 与枚举选择控件，不新增页面。
- D7 存储为 `SettingBoxKey.floatingNavBarStyle`（int index），`Pref.floatingNavBarStyle` 默认 `iconAndLabel`、越界回退默认，不做数据迁移。
- D8 渲染实现：`FloatingNavigationBar` 新增 `style` 参数并经 `_NavigationDestinationInfo` 下发给 destination；`iconOnly` 复用既有 `alwaysHide` 淡出 + tooltip，`labelOnly` 使用独立居中文字布局（不构建图标），保证点击区域覆盖整个 destination。
- D9 测试覆盖：新增 widget 测试验证三种样式的可观察差异与点击回调；新增单元测试验证 `Pref` 默认值与越界回退。

# 待解决问题

无 `[blocking]`。D1–D9 均为可在现有代码与用户要求中确定的结论，无影响用户可见结果的未决项。

# 验证预期

- `flutter analyze`：error/warning 数量不高于改动前基线。
- `flutter test`：新增的悬浮底栏 widget 测试与 `Pref.floatingNavBarStyle` 单元测试通过；既有测试不回归。
- 代码核对：`lib/pages/main/view.dart` 的 `FloatingNavigationBar` 传入样式；设置页「悬浮底栏样式」三个选项与持久化键一致；MD3/传统底栏/侧边栏分支未读取该样式。
- 手工冒烟（可选）：开启「悬浮底栏」后依次切换三种样式，观察主页底栏显示即时变化，重启后保持。
