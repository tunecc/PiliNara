# 同步上游后的 fork 行为契约（sync-upstream-2026-11-09）

## Capability: upstream-sync

本 spec 描述本次合并完成后 fork `main` 的整体行为契约。上游本批为 `git log 1db0d72e4..eca9c04eb`，36 个提交（35 非 merge + 上游自身 merge `3a595f58b`），117 文件 +5924/−2605，无文件删除。本 spec 不逐条复述上游实现，只规定合并的裁决规则与结果不变量。

### Scenario: 上游功能与缺陷修复全收

- **WHEN** 上游在本批范围内新增功能或修复缺陷，且 fork 对这些文件没有冲突性更改
- **THEN** 合并结果完整采用上游实现：推荐来源多选（`rcmd_source.dart`、`Pref.rcmdSources`、带说明的多选对话框、按勾选顺序交错取数）、桌面推荐页刷新 FAB（`showRefreshFAB`）与刷新指示器修复、评论楼中楼线程树（`reply_threaded_indent_box.dart`、`reply_reply/tree.dart`、`foldDepth`）、离线字幕/视角（`subtitle_utils.dart`、`download_service.dart`、`Pref.cachePlayInfo`、视角跳转与偏好）、>100% 音量 alimiter 限幅（`setVolumeCapped`）、音频会话与本地音频打开修复、直播横屏全屏安全区、小窗/通知栏刷新与弹幕按钮、桌面最小窗口尺寸（`window_bounds.dart`）、DLNA Lebo 控制 URL 归一（`dlna_utils.dart`）、搜索 `#` 视频标签筛选、AI 对话中途停止、iOS 短信验证码注册刷新、剧集滚动偏移、拖拽关闭长图、文章消息空图、按 issue 号的修复与依赖升级，不夹带 fork 侧的回退。

### Scenario: seek API 重构对齐且 fork 行为不回退

- **WHEN** 上游 `ef30e2482` 移除 `seek()` 与 `isSeek` 参数（原 `isSeek: true` 用于拖动进度条时等待首帧防抖）
- **THEN** 合并后 `lib/` 内不存在任何 `isSeek` 引用；`PlPlayerController.seekTo` 只有一个 `Duration` 参数；fork 的全部调用点（`services/audio_handler.dart` 的 `seekToIfExists(position)`、`pages/video/controller.dart`、`plugin/pl_player/widgets/bottom_control.dart`、`plugin/pl_player/view/view.dart`、`pages/video/post_panel/view.dart`、`lib/utils/ios/pip_helper.dart`）对齐上游新签名；fork 的双击分向时长接线（SeekIndicator GlobalKey、`fastBackwardDuration`/`fastForwardDuration`）、两指轻点暂停、双击分区 `resolveType` 不回退；键盘 ←/→ 的分向时长单触发路径保持。

### Scenario: 音量 >100% 走限幅且 fork 音量能力保留

- **WHEN** 上游 `d7df91620` 将 mpv 音量恒 ≤100、>100% 增益挪入 af 链 `alimiter=level_in=X:limit=1:level=0`（`setVolumeCapped`，Android libmpv 无 volume 滤镜故用 alimiter）
- **THEN** `lib/models/common/audio_normalization.dart` 的 `setVolumeCapped`/`_boostAf` 在位；`pl_player/controller.dart` `_initPlayer` 不再设置 `'volume'`/`'volume-max'`，改在创建后调用 `setVolumeCapped`；`pages/audio/controller.dart`、`pages/video/widgets/player_focus.dart` 的音量路径同样经 `setVolumeCapped`；fork 的桌面 `Pref.maxVolume`（≤300%）、移动端应用内音量模式（`enableAppVolume`/`Pref.appVolume`）、音量增强二次确认解锁 200%（`enableVolumeBoost`、`volumeBoostUnlocked`、`gestureVolumeMax`、`onVolumeGestureEnd`）语义全部保留且消费者计数不为 0。

### Scenario: 离线字幕/视角全收且 fork 入口幸存

- **WHEN** 上游 `f67a90291` 将字幕下载逻辑迁出 `header_control.dart`（`subtitle_utils` + `download_service`），并在 `pages/video/controller.dart` 加入离线字幕/视角逻辑
- **THEN** `lib/utils/subtitle_utils.dart` 与下载服务的字幕/章节缓存路径在位；`header_control.dart` 不含被迁走的实现；同文件 fork 的作者专属倍速入口仍在；`pages/video/controller.dart` 中上游离线字幕/视角逻辑与 fork 的屏蔽画质（`blockedQualities`/`fallbackVideo` 兜底）与作者倍速（`applyAuthorDefaultSpeed`）共处、互不删除；视角跳转（`61409bb74`）与视角偏好（`8ba530518`）可用。

### Scenario: 推荐源多选落地且 fork 滚动行为保留

- **WHEN** 上游 `e3aff4435`/`4fce4bb5a` 将推荐来源改为 `RcmdSource` 多选（`Pref.rcmdSources`，勾选顺序决定交错取数），`rcmd/controller.dart` 重写
- **THEN** `lib/models/common/rcmd_source.dart` 与设置页带说明多选对话框在位；`lib/` 内不存在 `Pref.rcmdMode`/`RcmdMode` 的悬空调用（定义允许保留但无消费者）；`rcmd/view.dart` 同时保留上游 `ScaffoldLayout` + `FloatingActionButton`（`Pref.showRefreshFAB`）与 fork 的 `AutoScrollPhysics` 包装。

### Scenario: fork 保留项与自有功能不受影响

- **WHEN** 合并涉及 fork 钉定文件、平台/脚本差异或 fork 自有功能所在区域
- **THEN** 合并后须满足：
  - `pubspec.yaml` 保持 `connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`；`environment.flutter` 与 `.fvmrc` 均为 `3.47.9`；`version` 与上游一致；`dlna_dart` 改为 `^0.1.2`（上游已发布该版本）且不再用 git 源。
  - README fork 差异说明正文、`BUILD_IOS.md`、`lib/scripts/patch.sh` 保留；README 中 Flutter 版本描述与 `.fvmrc` 一致（3.47.9）。
  - ThreadRipper、屏蔽画质、双击区域调整与预览、两指轻点暂停、作者专属倍速、会员视频本地筛选、我的页横向预览卡片与稍后再看直删、推荐页滚动、悬浮底栏三种显示样式的入口、配置项与行为不变；`lib/services/thread_ripper/**` 文件数与合并前一致；fork 功能标识在 `lib/` 内引用计数非 0 且与合并前基线持平。

### Scenario: 已裁剪 CI 保持删除

- **WHEN** 合并完成后检查 CI 与 workflow 目录
- **THEN** `.github/workflows/linux_x64.yml`（上游本批唯一改动的 workflow）保持 fork 的删除状态；`.github/workflows` 仍只有 `sync_upstream_build.yml`、`android_reusable.yml`、增强版 `ios.yml`，其余已裁剪 workflow 不恢复，`build.yml` 不存在。

### Scenario: 文档记录

- **WHEN** 本批合并落地
- **THEN** `CHANGELOG.md` 在 `## [Unreleased]` 下新增「### 同步上游 2.6.2 批次（2026-11-09）」，涵盖本批吸收的上游主要能力与修复、fork 自有差异保持不变、`dlna_dart` 依赖形态变化与未恢复裁剪 workflow；既有条目不改写。上游 2.6.2 段落不整段搬运。

### Scenario: 合并形态与工作树纯净

- **WHEN** 本次同步合并提交并完成本地验证
- **THEN** `main` 上新增恰好一个双亲 merge commit（parents = 合并前 `main` `09379e6c1` 与 `upstream/main`@`eca9c04eb`）；重新 fetch 后 `git rev-list --count HEAD..upstream/main` 为 0；工作树无冲突标记；`pubspec.lock` 由 fork 钉版与镜像重新解析得到且 hosted URL 无 pub.dev 条目，与上游 lock 的结构化差异仅限三钉及其传递伴随包；`flutter analyze` 相对合并前基线不新增 error/warning，`flutter test` 全部通过（含上游新增 5 个测试文件）；若执行过 `patch.sh`，补丁污染文件在提交前还原，`geetest_plugin.dart` 不在工作树。

### Scenario: 撞车呈报规则

- **WHEN** fork 已实现的某功能，上游在本批中也做了同类实现（同一用户可见功能、不同写法）
- **THEN** 该条目不自动裁决；由 Agent 呈报双方差异，用户选择保留 fork 版 / 采用上游版 / 融合，结论记入 brief `# 决策` 并落盘
- **本批排查结论**：上游未实现 fork 任何自有功能（fork 标识与中文关键词在上游全树 0 命中，fork 功能目录本批上游提交数为 0，双侧改动文件交集 16 个且不含 fork 功能主文件），无二选一项；4 个语义交互点均为"上游结构 + fork 行为"的融合，不是功能撞车。
