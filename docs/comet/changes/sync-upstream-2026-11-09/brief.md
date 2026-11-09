# 目标

把 `upstream/main`（Starfallan/PiliNara @ `eca9c04eb`）合并进 fork `main`，完整保留 fork 自有更改，并按用户要求排查"上游是否实现了 fork 已有的功能"。

本批范围：merge-base `1db0d72e4`（上一次同步停点，2026-11-04）到 `eca9c04eb`，共 36 个提交（35 个非 merge + 1 个上游自身的 merge `3a595f58b`），117 文件 +5924/−2605。上游本批没有删除任何文件。

撞车排查结论（D5，证据见 `# 决策`）：**上游本批没有实现 fork 任何一项自有功能**，因此不存在"同一功能两套实现、需要二选一"的取舍项。但存在 4 个**同一控制路径上的语义交互点**必须人工融合：`seek` API 重构（移除 `isSeek` 参数）、音量 >100% 削波修复（改为 `setVolumeCapped` + alimiter）、字幕下载逻辑迁移（离线字幕/视角）、推荐源改为多选（`RcmdMode` → `RcmdSources`）。这些按既定口径"上游全收 + fork 行为保留"处理，不削弱 fork 任何自有能力。

# 范围

- 用 `git merge upstream/main` 合入（保留双亲 merge commit），解决全部 7 处冲突（6 个 content + 1 个 modify/delete）并提交。
- 上游功能与修复全收（按组）：
  - 推荐来源多选：`e3aff4435` 桌面端推荐源（新增 `lib/models/common/rcmd_source.dart`、`Pref.rcmdSources`）、`4fce4bb5a` 改为带来源说明的 SelectDialog 多选，勾选顺序决定交错取数顺序；`Pref.rcmdMode`/`RcmdMode` 的旧实现随上游退出使用。
  - 桌面推荐页刷新：`3997f132f` 桌面悬浮刷新按钮（`SettingBoxKey.showRefreshFAB`）、`e3ab9715e` 刷新指示器、`c7ff9683c` 隐藏刷新手柄空转修复。
  - 评论楼中楼：`0005b8433` 回复线程树（`reply_threaded_indent_box.dart`、`reply_reply/tree.dart`、`reply_item_grpc.dart` 重写、`foldDepth` 设置）、`ec5eab9e3` 顶部回复过滤修复。
  - 离线字幕/视角：`f67a90291` 下载时一并保存字幕与章节、离线播放可用（`lib/utils/subtitle_utils.dart`、`download_service`、`Pref.cachePlayInfo`），`61409bb74` 跳转目标视角、`8ba530518` 视角偏好、`ef30e2482` seek 修复、`a32f1cc2c`/`934a7ada3` 本地字幕读取与更新修复。
  - 播放器/音频：`d7df91620` >100% 音量改用 af 增益 + alimiter 限幅（`setVolumeCapped`，取代 mpv `volume-max`）、`453dcb750` 音频会话、`39587f88c` 打开本地音频媒体。
  - 直播：`d0e03529b` 横屏全屏去掉底部安全区、`9f1bb96af` 小窗/通知栏刷新与弹幕按钮。
  - 桌面：`bcb55d268` 最小窗口尺寸计算（新增 `lib/utils/desktop/window_bounds.dart`）。
  - 其他修复：`8006ace0a` DLNA 旧 Lebo 控制 URL 归一（新增 `lib/utils/dlna_utils.dart`）、`efe023149` 搜索 `#` 视频标签筛选、`b2a74b385` AI 对话中途停止、`ab8baae38` iOS 短信验证码注册刷新、`bcc784385` 队列条目更新、`844001deb` 剧集滚动偏移、`33f32db2a` 拖拽关闭长图、`d8508cb2d` 文章消息空图、`0464679ca` 设置图标对齐、`56d5ff5de` lint、`35dd49785`/`737163c53`/`74764f2f3` 按 issue 号修复、`b94e1fc05` 依赖升级、`a80c655ac` 上游 CHANGELOG 2.6.2、`eca9c04eb` Linux rpm 补 elfutils。
- 7 处冲突逐文件裁决（冲突形态由 `git merge-tree --write-tree` 预检确认）：
  1. `.github/workflows/linux_x64.yml`（modify/delete）：fork 已裁剪，**保持删除**（D8）。
  2. `.gitignore`（content）：fork 的 Comet 产物/状态块与上游新增的 `!/test/`、`!/test/**` 反排除**并存**；不得丢掉任一侧。
  3. `CHANGELOG.md`（content）：保留 fork 结构与既有条目，在 `## [Unreleased]` 下新增本批条目（D7）。
  4. `README.md`（content）：上游侧实际是空白/换行抖动（`--ignore-all-space` 后仅 5 行差异），**保留 fork 的差异说明版本**，并修正其中已过期的 Flutter 版本描述（D7）。
  5. `lib/pages/rcmd/view.dart`（content，仅 import 行）：fork 的 `AutoScrollPhysics` 与上游的 `ScaffoldLayout` + `FloatingActionButton`（`Pref.showRefreshFAB`）**并存**。
  6. `lib/plugin/pl_player/controller.dart`（content，`_initPlayer` 的 opt 块）：fork 侧同一块差异只是 `dart format` 换行，**取上游删除** `'volume'`/`'volume-max'`，音量交由 `setVolumeCapped` 处理（D5）。
  7. `pubspec.lock`（content）：**不手工合并**，用 fork 钉版 + 镜像重新解析（D6、D9）。
- 4 个语义交互点的人工融合（自动合并后人工核对，见 A3–A7）：
  - `ef30e2482` 移除 `seek()` 方法与 `isSeek` 参数（`isSeek: true` 原用于"拖动进度条时等待首帧防抖"）；合并后 `lib/` 内不应残留 `isSeek:` 引用，fork 调用点（`services/audio_handler.dart`、`pages/video/controller.dart`、`plugin/pl_player/widgets/bottom_control.dart`、`plugin/pl_player/view/view.dart`、`pages/video/post_panel/view.dart`）全部对齐；`audio_handler` 的 `seekToIfExists(position)` 不再传 `isSeek`。
  - `d7df91620` 音量：`mpv` 常驻 `volume <= 100`，>100% 走 `af=[alimiter=level_in=X:limit=1:level=0]`；fork 的桌面 `Pref.maxVolume`（≤300%）、移动端应用内音量模式（`Pref.enableAppVolume`/`Pref.appVolume`）、音量增强二次确认解锁 200%（`Pref.enableVolumeBoost`、`volumeBoostUnlocked`、`gestureVolumeMax`）语义全部保留；`lib/pages/audio/controller.dart` 同样改走 `setVolumeCapped`。
  - `f67a90291` 字幕/视角：`header_control.dart` 中字幕下载相关逻辑被迁到 `subtitle_utils` + `download_service`，fork 在该文件里的作者专属倍速入口必须仍在；`pages/video/controller.dart` 中上游离线字幕/视角逻辑与 fork 的屏蔽画质（`blockedQualities`/`fallbackVideo`）、作者倍速共处，不得丢任一侧。
  - `e3aff4435` 推荐源多选：`rcmd/controller.dart` 被上游重写为多源交错取数，fork 的 `AutoScrollPhysics` 只落在 `view.dart`，确认融合后推荐页滚动行为不变、旧 `Pref.rcmdMode` 无悬空引用。
- 文档（D7）：
  - `CHANGELOG.md`：`## [Unreleased]` 下新增「### 同步上游 2.6.2 批次（2026-11-09）」，写明本批从上游吸收的能力与修复、fork 自有差异保持不变、`dlna_dart` 依赖形态变化，以及未恢复任何裁剪 workflow。
  - `README.md`：保留 fork 差异说明；把"Flutter 版本固定为 3.47.0…不跟随上游升级"修正为与 `.fvmrc` 一致的 `3.47.9`（上一批 D4 已跟随上游，文档未同步）。
- 验证链：记录合并前 analyze/test 基线 → 解冲突 → 最后一次改 `pubspec.yaml` 后镜像变量 pub get → `flutter analyze` 与基线比对 → `flutter test` → 需要时 `bash lib/scripts/patch.sh ios` 验证补丁仍可应用 → 清理补丁污染 → 提交双亲 merge commit → 重新 `git fetch upstream` 复核 `git rev-list --count HEAD..upstream/main` 为 0。

## 目录结构

### 修改

- `.gitignore` — 合并 fork 的 Comet 产物/状态块与上游 `!/test/`、`!/test/**` 反排除，两侧都保留。
- `CHANGELOG.md` — `[Unreleased]` 下新增本批同步条目，不改写既有版本段。
- `README.md` — 保留 fork 差异说明；Flutter 版本线描述改为 3.47.9。
- `pubspec.yaml` — 仅 `dlna_dart` 由 git 源改为 `^0.1.2`；三钉、`environment.flutter: 3.47.9`、`version` 保持不变。
- `pubspec.lock` — 镜像重解析生成，不手工选边。
- `lib/pages/rcmd/view.dart` — 融合 fork `AutoScrollPhysics` 与上游 `ScaffoldLayout` + 刷新 FAB。
- `lib/pages/rcmd/controller.dart` — 接受上游多源推荐重写，核对 fork 无遗留逻辑。
- `lib/pages/setting/models/recommend_settings.dart` — 上游推荐源多选对话框与来源说明；确认 fork 无自定义条目被覆盖。
- `lib/plugin/pl_player/controller.dart` — 取上游删除 `volume`/`volume-max` opt 与新的 `seekTo` 签名；保留 fork 的分向时长 getter、两指轻点、双击分区字段。
- `lib/plugin/pl_player/view/view.dart` — 上游 `seekTo`/`play`/`pause` 调用对齐；保留 fork 双击分区、两指轻点、SeekIndicator GlobalKey 接线。
- `lib/plugin/pl_player/widgets/bottom_control.dart`、`lib/pages/video/controller.dart`、`lib/pages/video/post_panel/view.dart`、`lib/services/audio_handler.dart`、`lib/utils/ios/pip_helper.dart` — 移除 `isSeek` 实参，对齐上游新签名。
- `lib/pages/video/widgets/header_control.dart` — 上游字幕下载逻辑迁出；确认 fork 作者专属倍速入口仍在。
- `lib/pages/video/widgets/player_focus.dart` — 上游改为 `setVolumeCapped`；保留 fork 键盘分向时长绑定与单触发路径。
- `lib/models/common/audio_normalization.dart` — 接受上游 `setVolumeCapped`/`_boostAf`（alimiter 增益+限幅）实现。
- `lib/pages/audio/controller.dart` — 上游音频会话与 `setVolumeCapped` 改造。
- `lib/services/download/download_service.dart`、`lib/utils/subtitle_utils.dart`、`lib/utils/path_utils.dart` — 上游离线字幕/章节缓存能力。
- `lib/utils/storage_key.dart`、`lib/utils/storage_pref.dart` — 上游新增 key/pref（`rcmdSources`、`showRefreshFAB`、`foldDepth`、`cachePlayInfo` 等）与 fork 全部 pref 并存、无重复。
- `lib/pages/main/controller.dart`、`lib/pages/mine/controller.dart` — 上游 `showRefresh` 接线；确认 fork 悬浮底栏与我的页卡片行为不变。
- `lib/utils/desktop/window_bounds.dart`、`lib/utils/dlna_utils.dart`、`lib/models/common/rcmd_source.dart`、`lib/pages/video/reply_reply/tree.dart`、`lib/pages/video/reply/widgets/reply_threaded_indent_box.dart` — 上游本批新增文件，全部接受。

### 删除

- `.github/workflows/linux_x64.yml` — 保持 fork 已裁剪状态，不因上游修改而恢复。

### 明确不建

- 不新增 fork 侧功能文件；不引入任何被上游淘汰的旧实现（`RcmdMode` 旧入口、mpv `volume-max` 音量放大、`isSeek` 防抖参数）。
- 不恢复任何已裁剪的上游 workflow，不新建 `build.yml`。
- 不创建 GitHub Release、发布产物或 PR 分支。

# 非目标

- 不推送 origin、不创建 PR、不发布 release。
- 不重构或回移 fork 已有功能实现；只做上游差异所需的最小适配。
- 不恢复 fork 已裁剪的上游 CI workflow。
- 不处理本批之外的上游分支或未合并 tag。
- 不处理与本批无关的 fork 缺陷或上游历史遗留问题（仅当阻塞编译/验收时才处理，并记录原因）。
- 不做 iOS/Android 真机构建与发布验证（仅在有需要时验证 `patch.sh ios` 可应用）。

# 验收示例

- A1: 合并后重新 `git fetch upstream`，`git rev-list --count HEAD..upstream/main` 为 0（上游停点 `eca9c04eb`）；`main` 上新增一个双亲 merge commit，两个 parent 分别为合并前 `main`（`09379e6c1`）与 `upstream/main`@`eca9c04eb`，恰好两行 parent；未使用 squash 或 rebase。
- A2: 7 处冲突全部按范围裁决落定：`git grep -n '^<<<<<<<' -- lib .gitignore CHANGELOG.md README.md .github` 无结果；`lib/pages/rcmd/view.dart` 同时包含 `AutoScrollPhysics(` 与 `ScaffoldLayout(`/`FloatingActionButton(`；`lib/plugin/pl_player/controller.dart` 的 `_initPlayer` 中不再出现 `'volume-max'` 与 `'volume':`，且存在 `setVolumeCapped(` 调用；`pubspec.lock` 由重解析生成而非手工合并。
- A3: seek API 对齐上游：`git grep -n 'isSeek' -- lib` 为 0 条；`lib/` 内不存在对已删除 `seek(Duration, {isSeek})` 方法的调用；`PlPlayerController.seekTo` 只有一个 `Duration` 参数；`lib/services/audio_handler.dart` 调用 `seekToIfExists(position)` 不传 `isSeek`。
- A4: 音量融合成立：`lib/models/common/audio_normalization.dart` 含 `setVolumeCapped`/`alimiter` 实现；`pl_player/controller.dart`、`pages/audio/controller.dart`、`pages/video/widgets/player_focus.dart` 的 >100% 路径均经 `setVolumeCapped`；同时 `maxVolume`、`gestureVolumeMax`、`volumeBoostUnlocked`、`Pref.enableVolumeBoost`、`Pref.enableAppVolume`、`Pref.maxVolume` 仍存在且被使用（`lib/` 引用计数非 0），fork 的「音量增强需二次确认解锁 200%」与桌面最大音量设置行为不变。
- A5: 离线字幕/视角全收且 fork 入口幸存：`lib/utils/subtitle_utils.dart` 与 `download_service` 中的字幕/章节缓存逻辑在位；`lib/pages/video/widgets/header_control.dart` 不再包含被迁走的字幕下载实现；同文件中 fork 的作者专属倍速入口仍在（`author_play_speed`/作者倍速相关引用非 0）；`view_point` 跳转与视角偏好入口可达。
- A6: 推荐源多选落地：`lib/models/common/rcmd_source.dart`、`Pref.rcmdSources`、`SettingBoxKey.rcmdSources`、设置页的带说明多选对话框均存在；`lib/pages/rcmd/controller.dart` 按多源交错取数；`lib/` 内不存在 `Pref.rcmdMode`/`RcmdMode` 的悬空调用（若上游保留定义但无消费者，允许定义存在，调用计数为 0）；fork 的 `AutoScrollPhysics` 仍在 `rcmd/view.dart` 生效。
- A7: fork 自有功能全量幸存：ThreadRipper（`lib/services/thread_ripper/**` 文件数与合并前一致）、屏蔽画质、双击区域调整与预览、两指轻点暂停、作者专属倍速、会员视频本地筛选、我的页横向预览卡片与稍后再看直删、推荐页滚动、悬浮底栏三种显示样式；对应标识在 `lib/` 内引用计数均非 0，且与合并前基线持平。
- A8: 版本线与钉版：`pubspec.yaml` 仍含 `connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`，`environment.flutter` 与 `.fvmrc` 均为 `3.47.9`，`version` 与上游 `pubspec.yaml` 一致；`dlna_dart` 为 `^0.1.2` 且 `pubspec.yaml` 内不再有 `dlna-dart.git` 的 git 源。
- A9: fork 保留项与 CI：README 差异说明正文仍在、`BUILD_IOS.md`、`lib/scripts/patch.sh` 存在；`.github/workflows` 仍只有 `sync_upstream_build.yml`、`android_reusable.yml`、`ios.yml`，`linux_x64.yml` 与其余已裁剪 workflow 均不存在，`ios.yml` 保留 `ref`/`artifact_name`/`file_suffix` 输入。
- A10: 依赖刷新：`pubspec.lock` 的 hosted URL 全为 `pub.flutter-io.cn`（0 条 pub.dev）；与上游 `pubspec.lock` 的结构化差异仅限三钉及其传递伴随包（`file_picker_darwin/linux/web/platform_interface`、`android/windows_file_picker`）；`material_ui`/`cupertino_ui` 版本与上游一致（1.10.0 / 1.1.6）。
- A11: `flutter analyze` 相对合并前基线不新增 error / warning（存量 info 允许；基线以本 change 记录的合并前计数为准）。
- A12: `flutter test` 全部通过，包含上游新增测试 `test/cdn_node_store_test.dart`、`test/utils/dlna_utils_test.dart`、`test/utils/desktop/window_bounds_test.dart`、`test/video_utils_test.dart`、`test/pages/login/geetest/captcha_config_test.dart`；已知 flaky 项允许重跑一次并记录。
- A13: `CHANGELOG.md` 的 `## [Unreleased]` 下新增「### 同步上游 2.6.2 批次（2026-11-09）」条目，内容涵盖本批吸收的上游主要能力与修复、fork 自有差异保持不变、`dlna_dart` 依赖形态变化与未恢复裁剪 workflow；既有条目与文件结构不被改写。
- A14: `README.md` 保留 fork 的差异说明结构，且 Flutter 版本描述与 `.fvmrc` 一致（3.47.9，跟随上游），不再出现"固定为 3.47.0…不跟随上游升级"。
- A15: 提交前工作树纯净：无补丁污染文件，`geetest_plugin.dart` 不在工作树；`git status` 仅包含本 change 的实现与正式产物；提交后 `git status` 干净。
- A16: 上游本批新配置项落地可用：`showRefreshFAB` 在桌面设置页有入口并作用于推荐页 FAB；推荐源多选在推荐设置可达；`foldDepth` 影响楼中楼折叠；离线字幕/章节在下载后离线播放可用（代码路径存在，行为由上游实现保证）。

# 约束与不变量

- 禁用 `git stash -u`（stash pop 会吞 MERGE_HEAD，使 merge commit 退化）；全程不使用 `reset --hard`、force push。
- flutter 命令使用绝对路径 `/Users/tune/fvm/versions/3.47.9/bin/flutter`（裸名 `flutter` 会命中 PATH 旧 SDK 导致 version solving failed）。
- 最后一次修改 `pubspec.yaml` 之后再统一 pub get：`PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn <flutter> pub get`；此后不再改 pubspec 再跑 analyze（否则隐式 pub get 会切回 pub.dev 缓存，导致 material_ui 补丁大面积 undefined error）。
- 若执行 `bash lib/scripts/patch.sh ios`，提交前还原 bottom_sheet / geetest 补丁污染文件；`geetest_plugin.dart` 不得留在工作树。
- 上游新代码若与三钉 API 冲突，适配方向是修改调用方贴近钉版，不升级钉版本。
- merge commit 恰好两行 parent；不使用 squash 或 rebase 代替合并。
- Runtime 检查中的多行 `/bin/sh -c` 脚本必须以 `set -e` 开头；`set -e` 与 `|| true` 按项目记忆成对使用，避免末条命令决定退出码造成假通过或假失败。
- 只提交本 change 的实现和正式产物，保留无关改动；不修改 `.comet/runtime/` 下任何 Runtime 本机文件。
- Build 交接后不再编辑 brief。

# 决策

- D1 隔离方式 `current`：工作区干净（`git status --porcelain` 0 行）、无其他 active Native change、无并行诉求，符合 Runtime 默认；与既往 sync change 一致。
- D2 合并方式 `git merge`，保留双亲 merge commit，与 fork 历史同步形态一致。
- D3 冲突裁决沿用既定原则：上游功能/修复全收；三钉、`.fvmrc`/`environment.flutter`、README 差异说明、`BUILD_IOS.md`、`lib/scripts/patch.sh`、fork 三条 workflow 与增强版 `ios.yml` 为 fork 保留项；实现细节（import 融合、调用点对齐、顺序）由 Agent 决定。
- D4 批次边界：`1db0d72e4..eca9c04eb` 全部纳入，共 36 个提交；不延伸到上游未合并分支或 tag。上游本批无文件删除，因此没有"跟随删除"项。
- D5 撞车排查结论：**本批上游未实现 fork 任何自有功能**，无"同一功能两套实现"的二选一。证据：① 对 upstream 全树 grep `ThreadRipper`/`thread_ripper`/`enableThreadRipper`/`blockedQualit`/`blockedVideoQualities`/`twoFingerTap`/`authorPlaySpeed`/`doubleTapSeekZone`/`doubleTapBackwardDuration` 及中文关键词"屏蔽画质/作者倍速/双击区域/线程撕裂"均 0 命中；② 上游本批对 `lib/services/thread_ripper`、`lib/pages/member_video`、`lib/utils/update.dart`、`lib/common/constants.dart`、`lib/http/api.dart`、`lib/common/widgets/scroll_physics.dart`、`lib/pages/setting/models/play_settings.dart` 的提交数均为 0；③ 双侧改动文件交集仅 16 个，不含 fork 功能主文件；④ 疑似同类项逐一排除：上游"离线字幕/视角"与 fork 无重合；上游"推荐源多选"与 fork"推荐页滚动优化/更新源"是不同维度；上游"桌面刷新 FAB"不替代 fork 任何开关。结论：按"上游全收 + fork 保留"处理，不做二选一呈报；Build 中若发现 brief 未预见的功能级撞车，立即呈报用户，不自行选边。
- D6 依赖策略：`dlna_dart` 跟随上游从 git 源（suconghou/dlna-dart@master）改为发布版 `^0.1.2`（上游为此发版）；三钉与 `environment.flutter` 3.47.9 不变；`pubspec.lock` 不手工合并，用镜像重解析后再与上游 lock 做结构化差异核对；`material_ui`/`cupertino_ui` 版本与当前 lock 相同（1.10.0/1.1.6），`patch.sh` 兼容性预期不变但仍需验证。
- D7 文档落点：`CHANGELOG.md` 沿用既有 fork 结构，在 `[Unreleased]` 下新增本批条目，不整段搬运上游 2.6.2（上游该段是面向其自身 fork 的累计说明）；`README.md` 保留 fork 版本，并修正上一批 D4 变更后未同步的 Flutter 版本线描述（3.47.0 → 3.47.9）。
- D8 已裁剪 CI：`linux_x64.yml` 的 modify/delete 冲突按"保持删除"处理，不恢复任何裁剪 workflow；上游本批未改 `.github` 其他文件。
- D9 验证基线：Build 首次提交前记录合并前 `flutter analyze` 的 error/warning 计数与 `flutter test` 结果，作为 A11/A12 的比较基准；项目记忆记录的 2026-11-06 基线为 73 issues / 0 error / 5 warning，仅作参考，以本次实测为准。
- D10 语义交互点处理口径：`seek` API、音量、字幕迁移、推荐源四处均"取上游结构，保留 fork 行为"，不新增 fork 侧替代实现；若对齐上游会丢失 fork 用户可见行为，先记录并呈报，不自行取舍。

# 验证期望

- Runtime 检查可直接执行的断言优先用整文件/整目录 grep 写出 `passed` 判定，避免依赖工具退出码；analyze 以 error/warning 计数为判据。
- 需要跑 flutter 的检查使用绝对路径与镜像环境变量。

# 待解决问题

无 `[blocking]`。
