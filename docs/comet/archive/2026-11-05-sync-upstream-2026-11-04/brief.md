# 目标

将 `upstream/main`（Starfallan/PiliNara @ 1db0d72e4）合并进 fork `main`，完整保留 fork 自有更改。自 merge-base `b5694ccda` 起上游本批为 79 个非 merge 提交：前 78 个（`b5694ccda..9851aa3ba`，196 文件 +6819/−5199）包含 Release 2.2.0、flutter 3.47.8/3.47.9、Linux MPRIS 与 webview_all 重构、桌面端进度条 hover seek 预览、滚轮调节音量、侧栏标签隐藏、pgc section 与剧集/分P/选季面板重构、折叠评论、直播分区 pin、opus 优化、SC 全屏不透明度/缩放，以及一批按 issue 号命名的缺陷修复；第 79 个是首轮独立验收期间上游新推的 `1db0d72e4` *fix(player): defer desktop touch fullscreen until pointer release*（3 文件 +97/−3，改到 fork 也改过的 `pl_player/view/view.dart`），按 D12 一并纳入本 change。

撞车排查结论：**上游没有实现 fork 任何一项自有功能**（ThreadRipper、屏蔽画质、双击区域调整与预览、两指轻点暂停、作者专属倍速、会员视频本地筛选、我的页横向预览卡片与稍后再看直删、推荐页滚动与 fork 更新源）。`ThreadRipper`/`blockedQualit`/`twoFingerTap`/`authorPlaySpeed`/`doubleTapSeekZone` 与中文关键词在上游全树 0 命中；上游对 `lib/pages/member_video/**`、`lib/pages/mine/**`、`lib/pages/rcmd/**`、`lib/utils/update.dart`、`lib/common/constants.dart`、`lib/http/api.dart`、`lib/common/widgets/scroll_physics.dart` 本批提交数为 0；`lib/services/thread_ripper/**` 是 fork 独有目录。因此不存在"同一功能两套实现"的取舍，但存在 **3 个必须人工融合的语义交互点**（键盘连续快退、目标画质返回值、Akamai 签名 URL 守卫）。键盘时长来源、Flutter 版本线、上游删除项处置与 fork 既存缺陷共 4 项已由用户裁决，见 D4–D7；合并复核中又发现一项 fork 自有改动被**历史同步**丢弃 —— `40b077294` 把双击分向时长接回指示器的接线弄丢了，经用户裁决一并纳入本 change 恢复（D5、D11、A15、A16）。

merge-tree 预检（tree `cad9cf9f2`）：13 个内容冲突文件，11 个各只有 1 个冲突块、`storage_pref.dart` 有 2 块、`video_utils.dart`/`header_control.dart`/`send_danmaku/view.dart` 的块纯是 import 行；`pubspec.yaml` 的唯一真冲突是 `environment.flutter` 一行（三钉与上游新增依赖均自动合并落地）。上游未触及 `.github/`，平台与脚本文件双侧改动集合交集为空。

# 范围

- 用 `git merge upstream/main` 合入（保留双亲 merge commit），解决全部 13 处冲突并提交。
- 上游功能与修复全收（按组）：Linux MPRIS（`1edcc4677`/`07e2906cd`）与 webview_all 重构（`0fa4323cb`，删 fork 未改过的 `linux_webview_plugin.{cc,h}`）、桌面 hover seek 预览（`bdf2859b3`/`51d2d5f56`/`ac08e8ac3`）、滚轮调节音量（`5e4e181d3`/`0f07f3c02`）、侧栏标签隐藏（`1091380fa`）、全屏 SC 不透明度/缩放（`dbf468b89`，`fullscreen_sc_size.dart` → `fullscreen_sc.dart`）、pgc section 与面板重构（`628290b5c`/`45337679b`/`29dae90ca`/`c74127908`/`5416b7fb0`/`f6af69118`/`588a65611`/`875afd08e`/`d635f20e2`/`19ab2e93e`/`5f9cc3b9c`/`d507390df`）、折叠评论与回复分页（`72ec31edd`/`a6aa26ee7`/`1e7015984`/`57d46992f`）、直播分区 pin（`d4156aaa9`/`bc697b318`/`a294fde63`）、opus（`206e58ba7`/`7ae82ec86`/`a04c9b004`/`fbb6ba013`）、弹幕跳转 seek 提前（`c805f0b5b`）、触控板不平移视频（`9851aa3ba`）、长按换 P 恢复倍速（`6a7f1df4c`）、方向锁定不响应转屏（`c36ebfc9e`）与 ChromeOS 方向（`b4bcad42c`）、Android 播放信息（`0e2061470`/`bf83cefda`/`f14929cd9`）与本地网络权限（`fbc9f892d`）、macOS 标题栏可拖拽（`9746fbc9c`）与关闭 impeller（`ae083b478`）、Linux 蜂窝判定（`2c246b81d`）、按 issue 号的修复（`979b06418`/`3e2ef6096`/`e03e53d2b`/`96927899c`/`37a92d1fb`）、`ca6161eca` AppSign、`b7ba2240a` 设置搜索、`9f8f49a87` 搜索 UA、`006c0fdd1` 账号初始化、`77e1d4ec8` 收藏 toast、`058794483` 文本溢出、`3c573a87c` 脚本 git config、`57ac80b01` jumpscare 段类型、`3882683af` 简介面板 aid、`0fb3ebcb9` 发布面板、`9378093b0` 桌面旋转按钮、`ce8064747` 桌面时间字号、`265f879fa` Release 2.2.0；第二段合并再吸收 `1db0d72e4`（桌面触摸延迟全屏，见 D12）。
- 三个语义交互点的人工融合：
  - `d680e3f95` 键盘 `←` 长按连续快退：取上游结构（删除原 `case arrowLeft:`，改用 `multiBackwardStart`/`multiBackwardEnd`），禁止"两侧都留"，否则同一次按键退两次。按修订后的 D5，`multiBackwardStart` 的累加步长、`multiBackwardEnd` 的单按退避与 `→` 分支的 `onForward(...)` 全部改绑 fork 设置页的 `doubleTapBackwardDuration`/`doubleTapForwardDuration`，使键盘与触屏双击同源。
  - `401ddbfdb`：`VideoUtils.findTargetVideo` 记录首项由请求档位改为 `targetVideo.id`，全收；同时给 fork 屏蔽画质路径补 `targetQaVideoList` 为空时的 `fallbackVideo` 兜底（避免 `.first` 抛 StateError），并保持 fork 在"候选全被屏蔽"时返回 `highestVideoQa` 的既有语义；下载路径同源核对。
  - `5b33aa18a`：Akamai 签名 URL 守卫落在 fork 重构后的 `pickCdnUrl`（merged:205-214），核对它与 `bypassCdnPreference` 判定的先后顺序，并保持返回原始 `urls`（encoded query 原样），不经 `normalizeUpgcxcodeUri` 剥包装。
- 恢复被 `40b077294 Merge upstream/main into main` 那次同步丢掉的 fork 分向时长接线（用户裁决纳入本 change）：`lib/plugin/pl_player/view/view.dart` 的两个指示器重新取 `fastBackwardDuration`/`fastForwardDuration`，并补回 `GlobalKey<BackwardSeekIndicatorState>`/`GlobalKey<ForwardSeekIndicatorState>` 与"指示器已挂载时再次双击走 `increment()` 累加、不重复挂载"的短路分支；`PlPlayerController` 中改绑后不再有消费者的 `fastForBackwardInSeconds`/`fastForBackwardDuration` 字段随之移除。
- 删除 `play_settings.dart` 里上游的全局「双击快进/快退时长」条目（D11）：改绑分向时长后它对用户已无实际效果；`SettingBoxKey.fastForBackwardDuration`、`Pref.fastForBackwardDuration` 定义与两个分向条目的 `defaultValue: Pref.fastForBackwardDuration` 保持不变。
- 13 处冲突的逐文件裁决：`.fvmrc` 取上游 `3.47.9`（D4）；`pubspec.yaml` 仅 `environment.flutter` 同步取 `3.47.9`（D4）、其余自动；`storage_pref.dart` 双端共存且 `Pref.blockSettings` 取上游；`pl_player/controller.dart` 三行 getter 手工并存；`pages/video/controller.dart` 取 fork 的 `data.fallbackVideo(...)` 表达式 + 上游的 `fallback.id`；`header_control.dart` 与 `send_danmaku/view.dart` 仅解 import（fork 作者倍速入口与上游桌面旋转按钮都在）；`ugc/controller.dart` 定序为先 `updateIndex` 后 `applyAuthorDefaultSpeed`；`later/controller.dart` 与 `video_card_h_later.dart` 取 fork（上游 `628290b5c` 的 `aid` 签名改动作废于被 fork 删除的块）；`video_utils.dart` 保 `dart:math` + `base_quality.dart`。
- 依赖策略：`pubspec.lock` 不手工合并，改完 `pubspec.yaml` 后用 fork 钉版 + 镜像重新解析；采用上游新增 `nm`、`webview_all_linux`、`webview_platform_interface`、`window_manager ^0.6.0`（弃 git 源）、`dlna_dart` git 源（suconghou/dlna-dart@master）、`permission_handler_platform_interface ^4.4.0`；三钉保持 fork 值，`environment.flutter` 按 D4 取 `3.47.9`。`version` 跟随上游 `2.2.0+1`（9 次历史 sync 的 `version` 恒等于其上游父提交，fork release tag 由构建号/日期生成）。
- 上游删除项跟随：`fullscreen_sc_size.dart`、`pgc_panel.dart`、`linux_webview_plugin.{cc,h}`、`test/utils/live_buffer_test.dart`，以及 `Pref.buildLiveBuffer` 与 `static set buvid` 的移除，按 D6 结论接受删除，并核对 `lib/` 内无悬空引用、设置入口不残留。
- fork 保留项（沿用既定口径）：三钉、README fork 差异章节、`BUILD_IOS.md`、`lib/scripts/patch.sh`、fork 的三条 workflow（`sync_upstream_build.yml`/`android_reusable.yml`/增强版 `ios.yml`）与 8 个已裁剪 workflow 保持删除。本批上游未改 `.github/`，无恢复风险。
- 工具链（D4）：`fvm install 3.47.9`，`.fvmrc` 与 `pubspec.yaml` 的 `environment.flutter` 同步为 `3.47.9`，本机 pub get / analyze / test 与 CI（`flutter-version-file: pubspec.yaml`）使用同一版本；三钉不因版本升级而放宽。material_ui / cupertino_ui / device_info 隔离补丁必须在 3.47.9 与新依赖版本上重跑 `bash lib/scripts/patch.sh ios` 验证；若新 SDK 上解析失败或补丁失配，回到用户裁决，不自行降回 3.47.0。
- 第二段合并（D12）：把 `1db0d72e4` 也纳入 —— 新的 `git merge upstream/main`，其改动落在 `lib/plugin/pl_player/view/view.dart`、`lib/common/widgets/gesture/player_gesture_recognizer.dart` 与新增的 `device_kind_scale_gesture_recognizer.dart`；`view.dart` 与 fork 的双指轻点、双击指示器（GlobalKey + 分向时长）改动共存，手势识别器换实现时保持 fork 的双击分区与两指轻点行为不回退。
- 发版说明落地（D13）：在 `CHANGELOG.md` 的 `## [Unreleased]` 之下新增本批条目，写明本批从上游 2.2.0 吸收的主要能力与修复、fork 自有差异（分向双击时长与键盘同源、ThreadRipper、屏蔽画质、作者倍速、会员视频本地筛选、我的页卡片等），并明确点名"设置里的手动输入 buvid 入口与直播缓冲参数随上游移除"。
- 顺手修两处 fork 既存缺陷（D7）：`lib/pages/setting/models/play_settings.dart` 删除重复的 `SettingBoxKey.enableSlideFS` 条目只保留一条；`lib/pages/later/controller.dart` 的 `removeList.map((item) => item.aid).join(',')` 过滤 null（`.nonNulls`）并补最小单测（新增测试文件按 `test*` 忽略规则需 `git add -f`）。
- fork 功能全量幸存核对：ThreadRipper、屏蔽画质、双击区域调整与预览、两指轻点暂停、作者专属倍速、会员视频本地筛选、我的页横向预览卡片与稍后再看直删、推荐页滚动与 fork 更新源/release manifest。
- 自动合并但需回归的同层手势区：`pl_player/view/view.dart`、`mouse_interactive_viewer.dart`、`play_settings.dart`、`video_settings.dart` —— 双指轻点、触控板捏合、滚轮音量、hover 预览共用同一个 `MouseInteractiveViewer` 构造与设置页。
- 验证链：记录合并前 analyze/test 基线 → 解冲突 → 最后一次改 `pubspec.yaml` 后用镜像变量执行 pub get → `flutter analyze` 基线比对 → `flutter test` → 需要时 `bash lib/scripts/patch.sh ios` 验证补丁在新 cupertino_ui/material_ui 版本上可应用 → 清理补丁污染 → 提交双亲 merge commit → 重新 fetch 复核 rev-list 为 0。

## 目录结构

### 新建

上游本批新增 17 个文件，全部接受：`lib/common/widgets/hit_test.dart`、`lib/models/common/pgc_episode_type.dart`、`lib/models/common/video/base_quality.dart`、`lib/models/dynamics/eva3_comment.dart`、`eva3_toy.dart`、`eva3_user.dart`、`eva3_vote.dart`、`lib/pages/common/page_order/page_order_btn_mixin.dart`、`lib/pages/common/reply/fold/reply_fold_mixin.dart`、`lib/pages/common/reply/reply_footer_mixin.dart`、`lib/pages/live/widgets/sliver_pinned_header.dart`、`lib/pages/setting/pages/fullscreen_sc.dart`、`lib/pages/video/introduction/pgc/widgets/episode.dart`、`section.dart`、`lib/utils/scroll_offset_helper.dart`、`linux/runner/plugins/linux_context_menu.cc`、`test/utils/cdn_url_test.dart`。fork 侧无新增功能文件。

### 修改

- 文档：`CHANGELOG.md` 在 `## [Unreleased]` 之后新增本批条目（D13）。

- 冲突人工裁决（13）：`.fvmrc`、`pubspec.yaml`、`pubspec.lock`、`lib/utils/storage_pref.dart`、`lib/utils/video_utils.dart`、`lib/plugin/pl_player/controller.dart`、`lib/pages/video/controller.dart`、`lib/pages/video/widgets/player_focus.dart`、`lib/pages/video/widgets/header_control.dart`、`lib/pages/video/introduction/ugc/controller.dart`、`lib/pages/video/send_danmaku/view.dart`、`lib/pages/later/controller.dart`、`lib/pages/later/widgets/video_card_h_later.dart`。
- 双侧改动但自动合并、需人工核对结果（14）：`lib/common/widgets/dialog/export_import.dart`、`lib/common/widgets/gesture/mouse_interactive_viewer.dart`、`lib/models/video/play/url.dart`、`lib/pages/common/publish/common_publish_page.dart`、`lib/pages/common/publish/common_rich_text_pub_page.dart`、`lib/pages/dynamics_create/view.dart`、`lib/pages/login/controller.dart`、`lib/pages/setting/models/play_settings.dart`、`lib/pages/setting/models/video_settings.dart`、`lib/pages/video/reply_new/view.dart`、`lib/plugin/pl_player/view/view.dart`、`lib/utils/image_utils.dart`、`lib/utils/storage_key.dart`、`lib/utils/storage_utils.dart`。
- 上游独有修改：其余 196 文件差集，按"全收"处理。

### 删除

跟随上游删除 5 个 fork 未改过的文件：`lib/pages/setting/pages/fullscreen_sc_size.dart`（重命名后继为 `fullscreen_sc.dart`）、`lib/pages/video/introduction/pgc/widgets/pgc_panel.dart`、`linux/runner/plugins/linux_webview_plugin.cc`、`.h`、`test/utils/live_buffer_test.dart`。fork 已裁剪的 8 个 workflow 保持删除状态。

### 明确不建

- 不新增 fork 侧功能文件；不引入第三方 BTR 实现。
- 不恢复任何已裁剪 workflow，不新建 `build.yml`。
- 不创建 GitHub Release、发布产物或 PR 分支；`CHANGELOG.md` 的 `[Unreleased]` 文本条目属文档更新，不视为发布产物（D13）。
- 不修改 `.comet/runtime/` 与 Runtime 本机状态文件。

# 非目标

- 不放宽三钉依赖版本；Flutter 版本线按 D4 改为跟随上游 `3.47.9`，不再保持 `3.47.0`。
- 不推送 origin、不创建 PR、不发布 release。
- 不重构或回移 fork 已有功能实现；只做上游差异所需的最小适配。
- 不恢复 fork 已裁剪的上游 CI workflow。
- 不处理本批之外的上游分支，不追上游未合并的 tag。
- 除 D7 明确纳入的两处既存缺陷修复外，不处理其他与本批无关的 fork 缺陷或上游历史遗留问题。
- 不做 iOS/Android 真机构建与发布验证。

# 验收示例

- A1: 合并后重新 `git fetch upstream`，`git rev-list --count HEAD..upstream/main` 为 0（批次含 `1db0d72e4`）；`main` 上按顺序保留两个双亲 merge commit——第一个 parent 为 合并前 `main`(67c3e55a1) 与 `upstream/main`@9851aa3ba，第二个的 parent 为第一个 merge commit 与 `upstream/main`@1db0d72e4，两个都是恰好两行 parent。
- A2: 13 处冲突全部按 brief 逐文件裁决落定，工作树无冲突标记残留；`video_utils.dart`/`header_control.dart`/`send_danmaku/view.dart` 的 import 块同时保住 `base_quality.dart`（上游）与 fork 侧 `author_play_speed.dart`/`double_tap_seek_layout.dart`/`chat_bottom_panel_ext.dart`。
- A3: 键盘与触屏双击时长同源且快退只有一条触发路径：`player_focus.dart` 中不存在 fork 旧 `case arrowLeft:` 与上游 `multiBackwardStart/multiBackwardEnd` 并存的双触发；`multiBackwardStart` 的累加步长、`multiBackwardEnd` 的单按退避与 `→` 分支的 `onForward(...)` 均取自 `Pref.doubleTapBackwardDuration`/`doubleTapForwardDuration`；`PlPlayerController` 不再保留无消费者的 `fastForBackwardInSeconds`/`fastForBackwardDuration` 字段。
- A4: `lib/utils/storage_pref.dart` 双端共存：fork 全部 pref（`blockedVideoQualities`、`enableThreadRipper`/`threadRipperBlockPcdn`、`doubleTapBackward/ForwardDuration`、`doubleTap*ZoneRaw`/`Zone`、`enableTwoFingerTapPause`、`authorPlaySpeeds` 与 `playSpeedForAuthor`/`upsertAuthorPlaySpeed`/`removeAuthorPlaySpeed`）与上游新增 `enableScrollVolume`、`hideSideBarLabel`、`enableFullScreenSC`/`fullScreenSCOpacity`/`fullScreenSCScale` 均在且无重复定义；`Pref.blockSettings` 取上游的越界兜底实现；`storage_key.dart` 双侧新增 key 集合不相交、无碰撞。
- A5: 上游画质与选点修复在位且 fork 语义不被削弱：`findTargetVideo` 记录首项返回 `targetVideo.id`；fork 屏蔽候选为空时走 `fallbackVideo` 兜底而非 `.first` 抛异常；`pickCdnUrl` 保留 Akamai 原始签名 URL 早退，其与 `bypassCdnPreference` 的先后顺序有明确结论并可解释。
- A6: `findVideoByQa` 融合结果同时保住 fork 的 `data.fallbackVideo(blockedQualities:)` 语义与上游的 `fallback.id`；作者倍速在 `ugc/controller.dart` 中于 `updateIndex` 之后应用，且 `cid` 初始化迁移后 `_authorSpeedContentKey` 的同集 reinits 判定不复现 `cid==0` 误判。
- A7: `lib/pages/later/controller.dart` 与 `video_card_h_later.dart` 取 fork：稍后再看单个移除仍为直删（无二次确认弹窗），我的页横向卡片样式与 `toViewDel(videoItem)` 调用保留；上游 `628290b5c` 的 `aid` 签名改动未在已删除的 fork 代码路径上留下悬空调用。
- A8: fork 非播放器功能未被上游改动波及：`git log b5694ccda..upstream/main` 对 `lib/pages/member_video/**`、`lib/pages/mine/**`、`lib/pages/rcmd/**`、`lib/common/widgets/scroll_physics.dart`、`lib/utils/update.dart`、`lib/common/constants.dart`、`lib/http/api.dart` 提交数为 0；`lib/services/thread_ripper/**` 与 `test/thread_ripper/**` 文件数与合并前一致。
- A9: fork 保留项幸存：`pubspec.yaml` 含三钉（`connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`）且 `environment.flutter: 3.47.9`、`version: 2.2.0+1`；`.fvmrc` 为 `3.47.9` 且与 `environment.flutter` 一致；README fork 差异章节、`BUILD_IOS.md`、`lib/scripts/patch.sh` 存在；`.github/workflows` 仍只有 fork 三条 workflow，8 个已裁剪文件未恢复，`ios.yml` 保留 `ref`/`artifact_name`/`file_suffix` 增强输入。
- A10: 上游删除项按 D6 接受删除且自洽：`test/utils/live_buffer_test.dart`、`fullscreen_sc_size.dart`、`pgc_panel.dart`、`linux/runner/plugins/linux_webview_plugin.{cc,h}` 不残留，`lib/` 内对 `buildLiveBuffer` 与 `Pref.buvid =` 的引用计数为 0，`recommend_settings.dart` 不再出现手动输入 buvid 的入口且可编译。
- A11: 依赖刷新与钉版共存：`pubspec.lock` 由 fork 钉版 + 镜像重解析得到，hosted URL 全为 `pub.flutter-io.cn`（0 条 pub.dev）；上游新增 `nm`/`webview_all_linux`/`webview_platform_interface`/`window_manager ^0.6.0`/`dlna_dart` git 源在位；`bash lib/scripts/patch.sh ios` 在合并后的 cupertino_ui/material_ui 活跃版本目录上无失败段。
- A12: `flutter analyze` 相对合并前基线不新增 error / warning（存量 info 允许），`flutter test` 全部通过（含 `test/thread_ripper/direct_fetcher_test.dart` 已知 flaky 项允许重跑）；提交前工作树无补丁污染、`geetest_plugin.dart` 不在工作树，提交内容仅含本 change 实现与正式产物。
- A13: 合并后的 `lib/pages/setting/models/play_settings.dart` 中 `setKey: SettingBoxKey.enableSlideFS` 只出现 1 次（D7），播放设置页不再有两条同名"中间滑动进入/退出全屏"开关，且该条目的说明文案与开关行为不变。
- A14: `lib/pages/later/controller.dart` 拼接移除参数时过滤掉 null `aid`（D7），请求参数中不出现字符串 `"null"`；存在覆盖该分支的最小单测并随 `flutter test` 通过。
- A15: `40b077294` 丢失的分向时长接线已恢复：`lib/plugin/pl_player/view/view.dart` 中 `BackwardSeekIndicator` 带 `key: _backwardSeekIndicatorKey` 且 `duration` 取 `plPlayerController.fastBackwardDuration`，`ForwardSeekIndicator` 带 `key: _forwardSeekIndicatorKey` 且 `duration` 取 `fastForwardDuration`；`onDoubleTapDownMobile` 在对应指示器已挂载（`mountSeekBackwardButton`/`mountSeekForwardButton` 为 true）时先调用 `increment()` 再返回，不重复挂载；`DoubleTapType` 所需 import 在位。
- A16: `play_settings.dart` 不再包含 `key: SettingBoxKey.fastForBackwardDuration` 的全局「双击快进/快退时长」条目（D11）；`SettingBoxKey.fastForBackwardDuration` 与 `Pref.fastForBackwardDuration` 定义仍在，两个分向条目的 `defaultValue: Pref.fastForBackwardDuration` 未变。
- A17: `CHANGELOG.md` 的 `## [Unreleased]` 之后新增本批条目（D13），内容涵盖本批吸收的上游 2.2.0 主要能力与修复、fork 自有差异，并明确写出"设置中手动输入 buvid 的入口与直播缓冲参数随上游移除"；既有条目与文件结构不被改写。
- A18: 第二段合并不丢 fork 行为：`1db0d72e4` 的桌面触摸延迟全屏改动并入后，`pl_player/view/view.dart` 仍保留 fork 的两指轻点暂停、双击分区 `resolveType`、两个 SeekIndicator 的 GlobalKey 与分向时长接线；`player_focus.dart` 的键盘单触发路径与分向时长取值不被回退。

# 约束与不变量

- 禁用 `git stash -u`（stash pop 会吞 MERGE_HEAD）；全程不使用 `reset --hard`、force push。
- flutter 命令使用绝对路径 `/Users/tune/fvm/versions/3.47.9/bin/flutter`（D4 采用 3.47.9，需先 `fvm install 3.47.9`）；裸名 `flutter` 会命中 PATH 的旧 SDK（3.41.9），会报 version solving failed。3.47.9 安装或解析失败时立即上报并回到用户裁决，不得改用 3.47.0/3.41.x 顶替出结论。
- 最后一次修改 `pubspec.yaml` 之后再统一 pub get：`PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn <flutter> pub get`，随后再 analyze/test，中途不再改 pubspec（否则隐式 pub get 会把解析切回 pub.dev 缓存，导致 material_ui 补丁大面积 undefined error）。
- Runtime verification_checks 直接执行可执行文件：写绝对路径；analyze 以 error/warning 计数为判据，不依赖退出码（存量 info 会使退出码为 1）；grep 取反类断言要写成可独立判定 passed 的形式。**多行 `/bin/sh -c` 检查脚本必须以 `set -e` 开头**：首轮的 `merge-lineage` 因缺少 `set -e`、由末尾 `echo` 决定退出码而假通过，独立 Verifier 判为不可复用证据。
- 上游新代码若与三钉 API 冲突，适配方向是修改调用方贴近钉版，不升级钉版本（沿用既定约束）。
- `pubspec.lock` 不手工合并、不逐块选边；只做重新解析后与上游 lock 做结构化差异核对。
- 若执行 `bash lib/scripts/patch.sh ios`，提交前用 `git checkout` 还原 bottom_sheet / geetest 补丁污染文件；`geetest_plugin.dart` 不得留在工作树（会让 analyze 报 uri_does_not_exist）。
- 新增 `test/` 文件受 `.gitignore` 的 `test*` 规则影响时需 `git add -f` 纳入。
- 提交前核对 `git status`，只允许本 change 的实现与正式产物；Builder 交接后不再编辑 brief（会触发 Shape 复查退回 goal_cycle 2）。
- merge commit 恰好两行 parent；不使用 squash 或 rebase 代替合并。
- 不修改 `.comet/runtime/` 下任何 Runtime 本机文件。

# 决策

- D1 隔离方式 `current`：工作区干净（`git status --porcelain` 0 行）、无其他 active Native change、无并行诉求，符合 Runtime 默认；与既往 8 次 sync change 一致。
- D2 合并方式 `git merge`（保留 merge 双亲形态），与 fork 历史同步形态一致。
- D3 冲突裁决沿用既定原则：上游功能/修复全收；三钉 / `.fvmrc` / `environment.flutter` / README 差异 / `BUILD_IOS.md` / `lib/scripts/patch.sh` / fork CI 三条 workflow 与增强版 `ios.yml` 为 fork 保留项；实现细节（选边顺序、import 融合、getter 并存）由 Agent 决定。
- D4 Flutter 版本线（用户裁决）：**跟随上游 `3.47.9`**。`.fvmrc` 与 `pubspec.yaml` 的 `environment.flutter` 同步为 `3.47.9`，本机需 `fvm install 3.47.9`；CI 的 `flutter-action` 用 `flutter-version-file: pubspec.yaml`，会自动装同一版本。三钉不因版本升级放宽。已知风险与处置：补丁链（material_ui / cupertino_ui / device_info 隔离）与 iOS 构建此前只在 3.47.0 上验证过，本 change 必须在 3.47.9 上重跑 `patch.sh` + pub get + analyze + test；若新 SDK 上解析失败或补丁失配，回到用户裁决而不是自行降回 3.47.0。
- D5 键盘与双击快进/快退时长（用户两轮裁决；第二轮纠正第一轮的事实前提）：**键盘与触屏统一跟设置页的分向时长**。取上游 `multiBackwardStart/multiBackwardEnd` 结构并删除 fork 的 `case arrowLeft:`，把 `multiBackwardStart` 累加步长、`multiBackwardEnd` 单按退避与 `→` 分支 `onForward(...)` 绑到 `doubleTapBackwardDuration`/`doubleTapForwardDuration`；同时恢复 `40b077294` 丢掉的指示器接线（A15）。第一轮选择"照上游全局时长"基于我给出的错误前提（误以为设置页时长仍作用于触屏双击，实际那条接线早已被历史同步丢弃），已在追问中更正并按更正后的事实重选。
- D11 上游全局「双击快进/快退时长」设置项：**从设置页删除**（用户裁决）。改绑分向时长后该条目已无消费者，保留会让用户调了一个不起作用的开关；`SettingBoxKey.fastForBackwardDuration` 与 `Pref.fastForBackwardDuration` 继续作为两个分向 pref 未设置时的默认值来源。
- D6 buvid 与直播缓冲（用户裁决）：**接受上游删除**，不在 fork 恢复手动输入 buvid 的能力，不保留 `Pref.buildLiveBuffer` 与其单测；核对无悬空引用与残留设置入口，并在 `CHANGELOG.md` 的 `[Unreleased]` 条目中点名该入口消失（D13）。
- D12 批次边界延到 `1db0d72e4`（用户裁决）：首轮独立验收 20 passed / 3 blocked，其中 A1/A23 因上游在合并完成后新推 1 个提交而未满足。该提交改到 `pl_player/view/view.dart` 与手势识别器，正是 fork 自有改动密集的文件；fork 的每日 03:20 UTC 同步 workflow 只会在 CI 里 `git merge` 并在冲突时 `merge --abort` + 上传 sync-conflict-report，冲突意味着当晚 Android/iOS 构建与 release 全部不生成。因此把这条并入本 change，代价是第二段合并与一次重跑检查。
- D13 发版说明落点（用户裁决）：`CHANGELOG.md` 由 fork 实际维护（最近条目 2.1.6，2b33fc0f7），其内容里正把"自定义 buvid"列为已引入能力，故用 `[Unreleased]` 新条目记录本批与 buvid 入口移除，而不是另建发布产物或删掉该要求。
- D7 fork 既存缺陷（用户裁决）：**两个都顺手修** —— 删除 `play_settings.dart` 中重复的 `SettingBoxKey.enableSlideFS` 条目只留一条；`lib/pages/later/controller.dart` 的 `removeList.map((item) => item.aid).join(',')` 过滤 null（`.nonNulls`）并补最小单测。分别由 A13、A14 覆盖。
- D8 依赖策略：以"上游 lock 为参考 + fork 钉版约束 + 镜像重解析"得到最终 lock；允许与上游解析版本不一致的项仅限三钉及其传递约束，逐项记录。`version` 跟随上游 `2.2.0+1`（证据：9 次历史 sync merge 的 `version` 恒等于其上游父提交，fork 从不自 bump，release tag 由构建号/日期生成）。
- D9 撞车排查方式与结论：① 78 个非 merge 提交逐个核对与 fork 自有功能的交集；② 上游全树 grep fork 标识与中文关键词（`ThreadRipper`/`thread_ripper`/`enableThreadRipper`/`blockedQualit`/`twoFingerTap`/`authorPlaySpeed`/`doubleTapSeekZone` 及"屏蔽画质/作者倍速/双击区域/两指/线程撕裂"）均 0 命中，`doubleTap` 命中的是 merge-base 已有的上游固定四分法；③ fork 非播放器功能所在目录本批上游提交数为 0；④ `bdf2859b3` 的 hover 预览是桌面端进度条 seek 缩略图，与 fork 设置页 `double_tap_seek_zone_setting.dart` 的横竖屏模拟预览表面与数据源均不同，不构成同类实现。结论：无"同一功能两套实现"的取舍项；用户裁决集中在 D4–D7。若 Build 出现 brief 未预见的新撞车，立即呈报用户，不自行选边。
- D10 验证基线：Build 首次提交前记录合并前 analyze 的 error/warning 计数与 test 结果，作为 A12 基线。

# 待解决问题

无 `[blocking]`。D4–D7、D11 已由用户裁决（含就键盘左右时长一致性的一次追问）；首轮验收后的两项扩展 D12（批次边界延到 `1db0d72e4`）与 D13（`CHANGELOG.md` 记录）也已由用户确认。本 Shape 重新确认后进入 Build，完成第二段合并与文档条目。

# 验证预期

- 命令门槛：`/Users/tune/fvm/versions/3.47.9/bin/flutter pub get`（带镜像变量）、`flutter analyze`（error/warning 计数与合并前基线比对）、`flutter test`（全量）、`bash lib/scripts/patch.sh ios`（补丁在 3.47.9 与新 cupertino_ui/material_ui 版本上的兼容性）、`git rev-list --count HEAD..upstream/main`（应为 0，批次含 1db0d72e4）、两个 merge commit 的双亲断言、lock 的 hosted URL 统计。检查脚本一律 `set -e`。
- 结构核对：A1 lineage 与双亲、A2 冲突落定与 import 共存、A3 单一路径的键盘快退、A4 pref 双端共存与 key 不相交、A5/A6 画质与选点及作者倍速定序、A7 稍后再看直删、A8 fork 区域零上游提交、A9 保留项与 CI 裁剪、A10 删除项自洽、A11 依赖与补丁。
- 手测项（Agent 无法自动覆盖，须在报告中说明执行与结论）：键盘 `←` 长按连退与 `→` 单按的步长等于设置页的分向时长，且一次 `←` 按键只产生一次快退；触屏双击左/右区按分向时长生效，指示器已显示时在同一手势上再次双击是累加（`increment()`）而不是重新挂载；播放设置页"中间滑动进入/退出全屏"只出现一条开关且不再有"双击快进/快退时长"条目；双指轻点暂停、触控板捏合缩放、滚轮音量、hover seek 预览共用同一 `MouseInteractiveViewer` 时互不干扰。
- 纯净核对：A12 工作树无补丁污染与 geetest 残留；提交内容仅本 change 实现与正式产物。
- 时序完整性：结束前重新 `git fetch upstream` 复核 rev-list 为 0。
- 已知限制：analyze 存在存量 info 级 lint（退出码 1 属预期）；`test/thread_ripper/direct_fetcher_test.dart` 首包断言存在约 1/3 概率的时序脆弱（既有修复为放宽断言，若偶发失败按重跑处理）；本次为本地 pub get/analyze/test 验证，不构建 iOS/Android 真机包；Linux 平台的 MPRIS 与 webview_all 行为不在本机构建范围内，仅验证代码与依赖在位。
