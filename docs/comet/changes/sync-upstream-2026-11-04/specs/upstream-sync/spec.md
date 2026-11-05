# 同步上游后的 fork 行为契约（sync-upstream-2026-11-04）

## Capability: upstream-sync

本 spec 描述本次合并完成后 fork `main` 的整体行为契约。上游本批为 `git log b5694ccda..1db0d72e4`，79 个非 merge 提交：前 78 个（到 `9851aa3ba`，196 文件）含 Release 2.2.0、flutter 3.47.8/3.47.9、Linux MPRIS 与 webview_all 重构、桌面 hover seek 预览、滚轮音量、侧栏标签隐藏、pgc section 与面板重构、折叠评论、直播分区 pin、opus 优化与一批 issue 修复；第 79 个 `1db0d72e4`（桌面触摸延迟全屏）在首轮验收期间由上游新推，按 D12 一并纳入。本 spec 不逐条复述上游实现，只规定合并的裁决规则与结果不变量。

### Scenario: 上游功能与缺陷修复全收

- **WHEN** 上游在本批范围内新增功能或修复缺陷，且 fork 对这些文件没有冲突性更改
- **THEN** 合并结果完整采用上游实现：Linux MPRIS 与 `nm` 依赖、webview_all 替换自定义 Linux WebView、桌面进度条 hover seek 预览、`enableScrollVolume` 滚轮音量、`hideSideBarLabel`、全屏 SC 不透明度/缩放（`fullscreen_sc.dart`）、pgc section 与剧集/分P/选季面板重构、折叠评论与回复分页、直播分区 pin、opus 优化、`hit_test.dart` 与 `member_contribute` 命中修复、`979b06418`/`3e2ef6096`/`e03e53d2b`/`96927899c`/`37a92d1fb` 等 issue 修复、AppSign、设置搜索、搜索 UA、账号初始化、收藏 toast、文本溢出、macOS 标题栏拖拽与 impeller 关闭、ChromeOS 方向、Android 播放信息与本地网络权限均落地，不夹带 fork 侧的回退。

### Scenario: 语义交互点必须人工融合

- **WHEN** 上游改动与 fork 自有实现落在同一函数或同一控制路径上
- **THEN** 结果须同时满足：
  - 键盘 `←` 只有上游 `multiBackwardStart/multiBackwardEnd` 一条处理路径，不存在与 fork 旧 `case arrowLeft:` 并存导致的单次按键两次快退；按 D5，`multiBackwardStart` 的累加步长、`multiBackwardEnd` 的单按退避与 `→` 分支的 `onForward(...)` 都取自 fork 设置页的 `Pref.doubleTapBackwardDuration`/`doubleTapForwardDuration`，与触屏双击同源；`PlPlayerController` 中因改绑而失去消费者的 `fastForBackwardInSeconds`/`fastForBackwardDuration` 字段一并移除。
  - 按 D5/A15 恢复 `40b077294` 那次同步丢掉的 fork 接线：`pl_player/view/view.dart` 的 `BackwardSeekIndicator`/`ForwardSeekIndicator` 分别取 `fastBackwardDuration`/`fastForwardDuration` 并挂上对应 `GlobalKey`，指示器已挂载时再次双击走 `increment()` 累加而不重新挂载；按 D11/A16 从设置页删除已无消费者的上游全局「双击快进/快退时长」条目，但保留 `SettingBoxKey.fastForBackwardDuration`/`Pref.fastForBackwardDuration` 作为两个分向 pref 的默认值来源。
  - `VideoUtils.findTargetVideo` 记录首项返回 `targetVideo.id`（上游 `401ddbfdb`），fork 屏蔽画质路径在候选集为空时走 `fallbackVideo` 兜底而不是抛 `StateError`，且"候选全被屏蔽时返回最高档"的既有语义不变。
  - `5b33aa18a` 的 Akamai 原始签名 URL 早退位于 fork 的 `pickCdnUrl` 内，返回未经 `normalizeUpgcxcodeUri` 剥包装的 URL，其与 `bypassCdnPreference` 的先后顺序可解释且 ThreadRipper 开启时行为成立。
  - `pl_player/controller.dart` 中 fork 的 `fastBackwardDuration`/`fastForwardDuration` getter 与上游的 `fastForBackwardInSeconds` 并存可编译；`pages/video/controller.dart` 的 `findVideoByQa` 同时保住 `data.fallbackVideo(blockedQualities:)` 与 `fallback.id`；`introduction/ugc/controller.dart` 中 `updateIndex` 先于 `applyAuthorDefaultSpeed`，且 `cid` 初始化迁移不破坏同集 reinits 判定。

### Scenario: fork 保留项与自有功能不受影响

- **WHEN** 合并涉及 fork 钉定文件、平台/脚本差异或 fork 自有功能所在区域
- **THEN** 合并后须满足：
  - `pubspec.yaml` 保持 `connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`；`environment.flutter` 与 `.fvmrc` 按 D4 均为 `3.47.9`（跟随上游，本机需安装该 SDK，CI 通过 `flutter-version-file: pubspec.yaml` 使用同一版本）；`version` 跟随上游 `2.2.0+1`；上游新增的 `nm`、`webview_all_linux`、`webview_platform_interface`、`window_manager ^0.6.0`、`dlna_dart` git 源、`permission_handler_platform_interface ^4.4.0` 全部在位。
  - README fork 差异章节、`BUILD_IOS.md`、`lib/scripts/patch.sh`、fork 的平台文件差异（`android/app/build.gradle.kts`、`lib/scripts/build.ps1`、`macos` xcconfig/entitlements）保留。
  - ThreadRipper、屏蔽画质、双击区域调整与预览、两指轻点暂停、作者专属倍速、会员视频本地筛选、我的页横向预览卡片与稍后再看直删、推荐页滚动与 fork 更新源/release manifest 的入口、配置项与行为不变；`lib/pages/member_video/**`、`lib/pages/mine/**`、`lib/pages/rcmd/**`、`lib/common/widgets/scroll_physics.dart`、`lib/utils/update.dart`、`lib/services/thread_ripper/**` 未被上游本批改动。
  - `lib/utils/storage_pref.dart` 同时包含上游新增 Pref（`enableScrollVolume`、`hideSideBarLabel`、SC 三项、`blockSettings` 越界兜底）与 fork 新增 Pref（`blockedVideoQualities`、`enableThreadRipper`/`threadRipperBlockPcdn`、`doubleTap*`、`enableTwoFingerTapPause`、`authorPlaySpeeds` 及其方法），无重复定义、无调用点遗漏；`lib/utils/storage_key.dart` 双侧新增 key 不相交。

### Scenario: 已裁剪 CI 保持删除

- **WHEN** 合并完成后检查 CI 与 workflow 目录
- **THEN** 上游本批未触及 `.github/`，`.github/workflows` 仍只有 fork 的 `sync_upstream_build.yml`、`android_reusable.yml`、增强版 `ios.yml`（保留 `ref` / `artifact_name` / `file_suffix` 输入），fork 已裁剪的 8 个 workflow 均不恢复，`build.yml` 仍不存在。

### Scenario: 上游删除项的处置

- **WHEN** 上游删除文件或移除 fork 之前可见的配置能力
- **THEN** fork 未改过的删除跟随：`lib/pages/setting/pages/fullscreen_sc_size.dart`（改名 `fullscreen_sc.dart`）、`lib/pages/video/introduction/pgc/widgets/pgc_panel.dart`、`linux/runner/plugins/linux_webview_plugin.{cc,h}` 不残留引用；按 D6 接受上游移除 `Pref.buildLiveBuffer`、`static set buvid` 及其设置入口与 `test/utils/live_buffer_test.dart`，`lib/` 内对三者的引用计数为 0，`recommend_settings.dart` 不再出现手动输入 buvid 的入口，且该消失项在 `CHANGELOG.md` 的 `[Unreleased]` 新增条目中点名（D13）。

### Scenario: 撞车与版本线取舍

- **WHEN** fork 已实现的某功能，上游在本批中也做了同类实现（同一用户可见功能、不同写法），或合并需要改变 fork 的构建/依赖钉版
- **THEN** 该条目不自动裁决；由 Agent 呈报双方差异，用户逐项选择保留 fork 版 / 采用上游版 / 融合，结论记入 brief `# Decisions` 并落盘
- **本批排查结论**：上游未实现 fork 任何自有功能（标识与中文关键词全树 0 命中，fork 功能目录本批上游提交数为 0），`bdf2859b3` 的 hover seek 预览与 fork 双击区域设置页预览表面和数据源不同，不构成同类实现；用户裁决项已定并记入 brief D4–D7、D11 —— Flutter 版本线跟随上游 `3.47.9`、键盘与触屏双击步长统一取设置页分向时长并恢复被历史同步丢弃的接线、接受上游移除手动 buvid 输入与直播缓冲参数、顺手修两处 fork 既存缺陷、删除改绑后无消费者的全局时长条目。

### Scenario: 合并形态与工作树纯净

- **WHEN** 本次同步合并提交并完成本地验证
- **THEN** `main` 上按顺序存在两个双亲 merge commit（第一个为合并前 `main`(67c3e55a1) + `upstream/main`@9851aa3ba，第二个为其 + `upstream/main`@1db0d72e4），每个恰好两行 parent；重新 fetch 后 `git rev-list --count HEAD..upstream/main` 为 0；第二段合并不回退 fork 的两指轻点暂停、双击分区 `resolveType`、SeekIndicator 的 GlobalKey 与分向时长接线，也不恢复键盘 `←` 的第二条触发路径；工作树无冲突标记；`pubspec.lock` 由 fork 钉版与镜像重新解析得到且 hosted URL 无 pub.dev 条目；`flutter analyze` 相对合并前基线不新增 error / warning，`flutter test` 全部通过；若执行过 `patch.sh`，bottom_sheet / geetest 补丁污染文件在提交前已还原，`geetest_plugin.dart` 不在工作树，提交内容仅包含本 change 的实现与正式产物；Runtime 检查计划中的多行 shell 脚本以 `set -e` 起始，避免末条命令决定退出码造成假通过。
