# 目标

用户反馈：最近「仅图标」悬浮底栏被整体缩小（d8d189b12「仅图标模式使用紧凑悬浮底栏尺寸」：容器高 64→48dp、单元格宽 86→56dp），现在整条底栏有点太小。用户的取舍是「缩小留白就好，而不是整体放小」——原 86dp 整格文字宽度对单个 icon 水平留白过多的收窄方向是对的，但整体尺寸（尤其容器高度）不应跟着缩小。

本 change 恢复「仅图标」样式的整体尺寸，同时保留收窄的单元格宽度：

- 容器高度恢复 64dp，与「图标+文字」「仅文字」一致；选中指示器高度随之恢复 56dp，图标大小不变，圆角随高度回到 32dp（height/2 公式不变）。
- 单元格宽度保持 56dp 收窄（整条宽度 N×56+8dp），只消除水平留白，不回到 86dp 整格宽度。

# 范围

只调整 `FloatingNavigationBar` 内部「仅图标」分支的尺寸取值与对应测试断言；三种样式的行为逻辑（labelBehavior、tooltip、点击、指示器动画）不动。

## 目录结构

### 修改

- `lib/common/widgets/floating_navigation_bar.dart` — 删除 `_kCompactNavigationHeight`（48dp），「仅图标」复用 `_kNavigationHeight`（64dp）；保留 `_kCompactCellWidth`（56dp）与整条宽度 N×56+8dp 公式；指示器高度随 `navigationHeight − 2×4dp` 自动恢复 56dp。
- `test/common/widgets/floating_navigation_bar_test.dart` — 「iconOnly」用例更新为「iconOnly keeps full height with compact width」：整体尺寸 120×72dp（宽 2×56+8、高 64+默认 bottomPadding 8）、渲染指示器 56×56dp；新增「iconAndLabel and labelOnly keep original sizes」用例：整体尺寸 172×72dp、指示器配置尺寸 86×56dp（渲染均摊值以注释说明）；行为断言（tooltip、点击、文字隐藏）不变。

### 明确不建

- 不改设置页、主控制器、MD3/传统底栏与侧边栏分支 — 本 change 只调整悬浮底栏 widget 的内部尺寸常量。
- 不重新调整单元格宽度、不做尺寸可配置化 — 56dp 收窄（图标 24dp + 两侧各 16dp）已是已确认的正确方向，不新增设置项。

# 非目标

- 不改「图标+文字」「仅文字」两种样式的任何尺寸：每项宽 86dp、容器高 64dp、指示器 86×56dp。
- 不改「仅图标」的行为：文字仍 `alwaysHide` 淡出、tooltip 保留、点击回调、选中指示器动画、badge 均不变。
- 不改底部 `bottomPadding`（默认 8dp）、视图边距处理（`viewPaddingOf`）与隐藏底栏动画。
- 不为其他底栏样式提供同类尺寸调整。

# 验收示例

- A1: `style: FloatingNavBarStyle.iconOnly` 时悬浮底栏容器高度为 64dp（不含默认 `bottomPadding` 8dp，widget 整体高度 64+8=72dp）；不再是 48dp。
- A2: `iconOnly` 时每个 destination 单元格宽度保持 56dp，整条宽度为 N×56+8dp（两个 tab 且默认 padding 时为 120dp），不回到每项 86dp 的整格文字宽度。
- A3: `iconOnly` 时选中指示器尺寸为 56×56dp（宽 = 单元格宽，高 = 64−2×4dp 容器内边距）。
- A4: `iconAndLabel` 与 `labelOnly` 样式的尺寸完全不变：容器高 64dp、整条宽度 N×86dp（两个 tab 为 172dp）、指示器配置尺寸 86×56dp（渲染宽度受容器 4dp 内边距均摊为 82dp，两个 tab），均与本 change 之前一致。
- A5: `iconOnly` 行为不变：文字淡出透明度 0、每个 destination 保留 `Tooltip`、点击仍回调 `onDestinationSelected`；更新断言后的相关 widget 测试全部通过。
- A6: `flutter analyze` 相对本 change 前基线（73 issues / 0 error / 5 warning）不新增 error/warning；悬浮底栏相关 `flutter test` 用例通过，且验证命令以 build 生成输入备份/恢复包装运行，避免 Runtime 判 completed-input-drift。

# 约束与不变量

- Flutter 命令使用本机绝对路径 `/Users/tune/fvm/versions/3.47.9/bin/flutter`（与 `.fvmrc`、`pubspec.yaml` 的 `environment.flutter: 3.47.9` 一致），不使用 PATH 中的裸 `flutter`。
- 只改 `lib/common/widgets/floating_navigation_bar.dart` 与其测试文件；不触碰设置页、主控制器与其他底栏分支。
- `NavigationIndicator` 的公开默认参数保持不变（width 默认 `_kIndicatorWidth`、height 默认 `_kIndicatorHeight`）。
- 验证脚本中 `flutter test` 前后对 `build/**/*.track.dill` 与 `build/**/.DS_Store` 做备份/恢复（sha256 比对 changed 0），避免 completed-input-drift；`flutter analyze` 不改 build，无需包装。
- 提交前核对 `git status`，只包含本 change 的实现与正式产物。

# 决策

- D1 工作区采用 `current`：改动开始前工作区干净、没有其他 active Native change、无并行诉求。
- D2 「恢复高度、保留收窄宽度」：用户原话「原来的大小是合适的……缩小就好，而不是整体放小，现在有点太小了」——高度 64→48 是「整体放小」的错误部分，宽度 86→56 是「缩小留白」的正确部分，只回退前者。
- D3 单元格宽度维持 d8d189b12 已定的 56dp，不再调宽：56dp 下图标两侧各 16dp，相比原 86dp（两侧各 31dp）已明显消除留白。
- D4 实现方式：删除 `_kCompactNavigationHeight`，`iconOnly` 复用 `_kNavigationHeight`；`indicatorHeight = navigationHeight − 2×_kIndicatorPaddingInt` 与圆角 `navigationHeight/2` 公式不变，恢复 64dp 后自动得到 56dp 指示器与 32dp 圆角。
- D5 测试同步更新「iconOnly uses a compact bar and indicator」用例的尺寸断言，行为断言保持不变。
- D6 验收文字更正（本次修订）：A4/spec 中「指示器 86×56dp」系对渲染事实的转写偏差——实际布局为整条宽度 N×86dp、容器四周 4dp 内边距，指示器配置尺寸 86×56dp、渲染宽度按单元格均摊（两个 tab 为 82dp）；核对 d8d189b12 之前渲染逻辑与实测均证实。更正仅把同一含义写成可验证数值，无行为、目标或授权变化；Build 首轮曾以非行为类复核更正正式文件，Runtime 判定验收文字属于需求契约、须走需求修订并经用户重新确认，故本次修订按 revise-requirements 返回 Shape 重绑。测试相应在配置尺寸层面断言 A4，渲染均摊值以注释说明。

# 待解决问题

无 `[blocking]`。D2/D3 依据用户明确表述与既有实现取值确定；D6 为本轮需求修订（验收文字更正），随本 Shape 一并由用户重新确认。

# 验证预期

- `flutter analyze`：error/warning 数量不高于改动前基线（73 issues / 0 error / 5 warning）。
- `flutter test test/common/widgets/floating_navigation_bar_test.dart`（`/Users/tune/fvm/versions/3.47.9/bin/flutter`）：更新后的尺寸断言与既有行为断言全部通过。
- 代码核对：`iconOnly` 分支高度取 `_kNavigationHeight`；宽度公式 N×56+8dp；`iconAndLabel`/`labelOnly` 分支尺寸未动。
- 手工冒烟（可选）：设置「仅图标」样式，确认底栏高度与其他样式一致、宽度仍明显收窄、点击与 tooltip 正常。
