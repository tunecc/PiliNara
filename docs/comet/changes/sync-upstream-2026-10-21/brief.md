# 目标

将上游 `upstream/main`（Starfallan/PiliNara @ e52ad34a5，2026-10-21 抓取；自 merge-base b908eccfb 起 35 个提交 = 34 个非 merge + 1 个 merge，92 个文件 +3981/−1527）合并进 fork `main`，完整保留 fork 自有更改。

本批上游功能与 fork 六项自有功能（ThreadRipper、屏蔽画质、双击区域调整与预览、两指轻点暂停、作者专属倍速、会员视频本地筛选）无同类实现撞车（排查方式与证据见 D4），因此本 change 不需要用户逐项裁决。唯一重叠是上游把画质选择重构进 `VideoUtils.findTargetVideo`，属于 API 适配，fork 的屏蔽画质行为保持不变。合并产物需通过 patch / analyze / test 门槛并保持工作树纯净。

# 范围

- 用 `git merge upstream/main` 合入（保留双亲 merge commit），解决全部冲突并提交。
- merge-tree 预检冲突文件：`lib/models/video/play/url.dart`、`lib/pages/setting/models/play_settings.dart`、`lib/pages/video/controller.dart`、`pubspec.lock`。
- 上游功能全收（35 个提交），主要包括：设置页拆分（`extra_settings.dart` 内容拆到 play/dm/dyn 等设置）、导出/导入设置与全量数据 zip、评论过滤统一页、回复过滤/屏蔽与跳转回复来源、直播缓冲独立设置、缓存视频可选音质、会员主页重构、opus 合集、用户页勋章名、Wayland 黑屏修复、media-kit 等 15 个依赖升级、画质选择逻辑抽到 `VideoUtils`。
- fork 保留项（D3）：三钉 `connectivity_plus: 7.0.0` / `device_info_plus: 13.0.0` / `file_picker: 12.0.0-beta.7`，`environment.flutter: 3.47.0`，`.fvmrc` 3.47.0，README fork 差异章节，`BUILD_IOS.md` / `lib/scripts/patch.sh` / `sync_upstream_build.yml`，8 个已裁剪 workflow 保持删除，fork 增强版 `ios.yml`。
- fork 功能全量幸存：ThreadRipper 13 文件与 161 用例、屏蔽画质、双击区域调整与预览、两指轻点暂停、作者专属倍速、会员视频本地筛选（含自动翻页）。
- 上游 API 适配：`VideoUtils.findTargetVideo` 增加屏蔽画质支持（或等价最小改造），播放初始化、半屏→全屏切换、画质菜单过滤与兜底保持现有行为；`url.dart` 保留 `findAvailableVideoQuality(blockedQualities)` / `fallbackVideo` 供剩余调用点与单测使用。
- 依赖策略：采用上游对 15 个包（含 media_kit、cupertino_ui 1.1.4、material_ui 1.8.0 等）的 lock 升级，同时保持三钉与镜像 URL；用 fvm 3.47.0 + 镜像重新解析，lock 中不得出现 pub.dev URL。
- iOS patch 兼容：`patch.sh` 的 material_ui / cupertino_ui 补丁需在升级后的 lock 活跃版本目录应用成功；如补丁因版本升级失配，按新版源码调整 patch 文件，不降级依赖。
- 验证链：`bash lib/scripts/patch.sh ios` → `fvm flutter analyze`（与合并前基线比对）→ `fvm flutter test` → 清理补丁污染与 geetest 停车场 → 提交双亲 merge commit → 重新 fetch 复核 rev-list 为 0。

## 目录结构

### 新建

- 上游新增文件随合并进入：`lib/pages/member_opus/widgets/collection_item.dart`、`opus_grid.dart`、`space_opus_item_grpc.dart`、`lib/pages/setting/models/dm_settings.dart`、`lib/utils/config_archive.dart`、`test/utils/audio_quality_select_test.dart`、`live_buffer_test.dart`、`video_quality_select_test.dart`，以及合并树中的其他上游新文件（如导出导入对话框）。

### 修改

- 冲突手工融合：`lib/models/video/play/url.dart`、`lib/pages/setting/models/play_settings.dart`、`lib/pages/video/controller.dart`、`pubspec.lock`。
- 自动合并但需行为复核：`lib/utils/video_utils.dart`（上游追加 `findTargetVideo` / `findTargetAudio`）、`lib/pages/setting/models/video_settings.dart`（上游直播缓冲 + fork 三条目）、`lib/plugin/pl_player/controller.dart`、`lib/plugin/pl_player/view/view.dart`、`lib/pages/video/widgets/header_control.dart`、`lib/utils/storage_pref.dart`、`lib/utils/storage_key.dart`、`lib/utils/font_utils.dart`、下载相关文件。
- fork 保留项局部回写：三钉、`environment.flutter`、`.fvmrc`、README、CI 裁剪集、fork 版 `ios.yml`。

### 删除

- 本批上游无删除文件；fork 已裁剪的 8 个 workflow 在 merge 中保持删除状态。

### 明确不建

- 不新增 fork 侧功能文件；不引入 `BtrProxy` 或任何第三方 BTR 代码。
- 不创建发布产物、PR 分支或 release。
- 不修改 `.comet/runtime/` 下任何 Runtime 本机文件。

# 非目标

- 不升级 Flutter 工作区版本（保持 fvm 3.47.0）。
- 不推送 origin、不创建 PR、不发布 release。
- 不重构或回移 fork 已有功能实现；只做上游 API 差异所需的最小适配。
- 不恢复 fork 已裁剪的上游 CI workflow。
- 不处理本批之外的上游分支。
- 不评估或引入第三方 BTR 实现。

# 验收示例

- A1: 合并后重新 `git fetch upstream`，`git rev-list --count main..upstream/main` 为 0；merge commit 恰好两行 parent（合并前 main 与 upstream/main）。
- A2: fork 保留项幸存：`pubspec.yaml` 含三钉与 `environment.flutter: 3.47.0`；`.fvmrc` 为 `{"flutter": "3.47.0"}`；README fork 差异章节、`BUILD_IOS.md`、`lib/scripts/patch.sh`、`sync_upstream_build.yml` 存在；8 个被裁剪 workflow 保持删除；`ios.yml` 保留 ref/artifact_name/file_suffix 增强输入。
- A3: fork 功能全量幸存：`lib/services/thread_ripper/` 13 个文件与 161 用例；`video_settings` 含 Thread Ripper / PCDN / 屏蔽画质条目与 CDN 互斥 subtitle；pl_player controller 含作者倍速方法、双击分区 getter、`enableTwoFingerTapPause`；`view.dart` 含 `TwoFingerTapDetector` 与 `doubleTapSeekLayout.resolveType` 接线；router 含 `/doubleTapSeekZoneSetting`；`lib/pages/member_video/` 筛选文件完整；屏蔽画质语义在 `url.dart` 或等价位置保留。
- A4: `bash lib/scripts/patch.sh ios` 在升级后的 cupertino_ui / material_ui 上无失败段；抽验补丁应用在 lock 活跃版本目录。
- A5: `fvm flutter analyze` 相对合并前基线不新增 error / warning（存量 info 级 lint 允许，退出码 1 不作失败判据）。
- A6: `fvm flutter test` 全部用例通过（含 test/thread_ripper 161 用例与上游新增 3 个测试文件）。
- A7: 撞车排查零遗漏：上游本批不存在与 fork 六项功能同类的实现；排查方式与证据记录于 brief D4；无新增撞车条目需要用户裁决。
- A8: 提交树纯净：无 `gt3_flutter_plugin`；`geetest_plugin.dart` 不在工作树；bottom_sheet / geetest 补丁污染文件恢复上游纯净态。
- A9: 依赖刷新与钉版共存：`pubspec.lock` 采用上游 15 个包的版本升级，同时三钉保持钉定版本；hosted URL 全为镜像（无 pub.dev）；与上游 lock 的差异可逐项解释（钉版及其传递约束）。
- A10: 屏蔽画质在新 API 下行为不变：播放初始化、半屏→全屏切换、目标画质无流兜底、画质菜单过滤均剔除屏蔽档位；`test/models/video/play/video_quality_blocklist_test.dart` 及新增/调整用例通过。

# 约束与不变量

- 禁用 `git stash -u`（stash pop 会吞 MERGE_HEAD）；全程不使用 `reset --hard`、force push。
- pub get 必须用 `/Users/tune/fvm/versions/3.47.0/bin/flutter` 绝对路径，并设置 `PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`。
- Runtime 的 verification_checks 直接执行可执行文件：flutter 必须写绝对路径；analyze 以 error/warning 计数为判据，不依赖退出码。
- patch.sh 验证顺序：patch → analyze/test → `git checkout` 还原 bottom_sheet/geetest 污染文件 → 提交；`geetest_plugin.dart` 按停车场策略移出工作树，不留 untracked 副本。
- 新增 `test/` 文件受 `.gitignore` 的 `test*` 规则影响，需 `git add -f` 纳入。
- 提交前核对 `git status`，只允许本 change 的实现与正式产物；Builder 交接后不再编辑 brief。
- 上游新代码若与三钉 API 冲突，适配方向是修改调用方贴近钉版，不升级钉版本。
- lock 中 hosted URL 必须保持 `pub.flutter-io.cn`。
- 不修改 `.comet/runtime/` 下任何 Runtime 本机文件。

# 决策

- D1 隔离方式 `current`：工作区干净、无其他 active change、无并行诉求，符合 Runtime 默认。
- D2 合并方式 `git merge`（保留 merge 双亲形态），与 fork 历史同步形态一致。
- D3 冲突裁决沿用既定原则：上游功能全收；三钉 / flutter 3.47.0 / `.fvmrc` / README 差异 / `BUILD_IOS.md` / fork CI 裁剪集 / fork `ios.yml` 增强版为 fork 保留项；实现选择（API 适配细节、冲突手工融合）由 Agent 决定。本批新增：设置页拆分按上游结构落位 fork 条目（D8）；lock 按 D6 处理。
- D4 撞车排查结论：**零撞车**。排查方式：① 34 个非 merge 提交逐个核对与本 fork 六项功能的交集；② 对 `upstream/main` 全树 grep 关键标识（`thread_ripper`、`ThreadRipper`、`blockedQualit`、`doubleTapBackward`、`authorPlaySpeed`、`twoFinger`、`member_video_filter`、`playCountFilter`、`qualityBlock` 及中文关键词“线程撕裂/双击区域/作者专属/画质屏蔽/播放量筛选/两指”）均为 0 命中；③ 上游本批触及的会员页仅为 `member_home` 重构，未动 fork 筛选所在的 `member_video`；④ pl_player 改动为剧集面板与 `PlayOwner` typedef；⑤ 上游画质选择重构属于 API 迁移，不构成同类功能实现，按 D5 适配。结论：无需用户在“保留上游 / 保留 fork”之间逐项选择；若 Build 出现 brief 未预见的新撞车，按 A7 口径立即呈报用户裁决。
- D5 屏蔽画质适配方案（最小改动，行为不变）：在 `VideoUtils.findTargetVideo` / `_findAvailableVideoQuality` 增加可选 `blockedQualities` 参数，规则沿用 fork：候选集剔除屏蔽档，剔空则回退原候选；首选不低于最高档且最高档被屏蔽时取不超过它的最高未屏蔽档；目标画质无流时按 `fallbackVideo` 语义跳过屏蔽档。播放初始化改走新 `VideoUtils` 调用并传入 `Pref.blockedVideoQualities`；半屏→全屏切换与画质菜单继续使用 `url.dart` 现有方法与 `fallbackVideo`。新增/调整单测覆盖这些分支。
- D6 依赖策略：以 upstream lock 为基础合入 15 个包的升级；在合并后 `pubspec.yaml`（三钉 + flutter 3.47.0）上执行镜像 pub get，把 lock 解析为“上游升级 + 三钉约束 + 镜像 URL”。若解析版本与上游不一致，仅允许由三钉传递约束导致，并逐项记录；不允许为了对齐上游而升级三钉。material_ui / cupertino_ui 升级后必须重跑 patch.sh 验证补丁兼容。
- D7 iOS patch：若 material / cupertino 补丁在新版本失配，调整 `lib/scripts/material/*.patch` 或选目录逻辑以适配新源码，保持 patch.sh 幂等与可重复；不通过降级包版本规避。
- D8 设置拆分：接受上游把 `extra_settings.dart` 内容拆到 `play_settings` / `dm_settings` / `dyn_settings` / `dynamics_settings` / `reply_settings` / `style_settings` 的结构；fork 在 `play_settings` 与 `video_settings` 的条目按语义落到对应分组，保持标题、subtitle、开关与互斥逻辑不变；不把 fork 条目塞回 `extra_settings`。
- D9 验证基线：Build 首次提交前先记录合并前 analyze 的 error/warning/info 计数与 test 结果，作为 A5 / A6 基线；Runtime 检查复用绝对路径 flutter。

# 待解决问题

无 `[blocking]`。本批零撞车，无需用户逐项裁决；Shape 确认后直接进入 Build。

# 验证预期

- 命令门槛：A4 `patch.sh`、A5 analyze、A6 test。
- 结构核对：A1 git 计数与双亲、A2/A3 保留项与功能 grep、A8 gt3 与污染态、A9 lock 结构化 diff、A10 屏蔽画质分支与测试。
- 时序完整性：结束前重新 `git fetch upstream` 复核 rev-list 为 0。
- 已知限制：analyze 存在存量 info 级 lint（退出码 1 属预期）；本次为本地 patch/analyze/test 验证，不构建 iOS 真机包（如需按 BUILD_IOS.md 由用户另行执行）。
