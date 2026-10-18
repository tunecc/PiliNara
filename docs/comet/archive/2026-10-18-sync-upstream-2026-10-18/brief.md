# Outcome

将上游 `upstream/main`（Starfallan/PiliNara @ b908eccfb，自 merge-base 8d755f16b 以来的 20 个提交，其中 18 个非 merge）合并进 fork `main`，完整保留 fork 自身更改；fork 功能与上游本批改动无同类撞车（已逐项排查，结论记录于 Decisions）。附带完成 PiliPlus PR 3223（BtrProxy 线程撕裂者移植）评估：保留我们自研的 ThreadRipper，仅吸收对方 1 个 macOS 沙盒修复，不引入其实现。合并产物通过 patch / analyze / test 门槛并保持工作树纯净。

# Scope

- 以 `git merge upstream/main` 合入（保持 merge 双亲形态），解决全部冲突并提交双亲 merge commit。
- 冲突裁决默认原则（沿用 2026-08-30 / 09-10 / 10-15 既定裁决）：上游功能全收；fork 保留项 = iOS 三钉（`connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`）+ `environment.flutter: 3.47.0` + `.fvmrc` 压回 3.47.0 + fork 的 README 差异文档 / BUILD_IOS.md / fork CI 裁剪集（`sync_upstream_build.yml` 保留，`linux_x64.yml`、`win_x64_newlibmpv.yml`、`android.yml`、`build.yml`、`debug_android.yml`、`debug_build.yml`、`mac.yml`、`win_x64.yml` 维持删除）+ fork 的 `ios.yml` 增强版（ref/artifact_name/file_suffix 参数）。
- 本批上游无 pubspec.yaml / pubspec.lock / CHANGELOG.md 改动（`git log 8d755f16b..upstream/main` 核对为空），lock 按 merge 自动保持 ours，无需重解析；如因 patch 需要跑 pub get，仍用 fvm 3.47.0 绝对路径 + flutter-io.cn 镜像。
- 上游 API 重构适配（不改用户可见行为）：`VideoQuality` / `LiveQuality` / `AudioQuality` 由 enum 改为 class（含新档位 `superResolution(100)`）、`Dash.fromJson(json, supportFormats)` 签名变化、`findAvailableVideoQuality` 失去 `blockedQualities` 参数——fork 的屏蔽画质 / 作者专属倍速调用点按新 API 重接，fork 功能行为保持不变。
- fork 功能全量幸存：ThreadRipper（`lib/services/thread_ripper/` 全目录 + video_utils 改写链路 + video controller 集成 + 预热 + CDN 设置互斥 subtitle + PCDN 屏蔽）、画质屏蔽（video_settings + url.dart 兜底 + header_control 过滤 + controller fallback）、双击区域调整（分区时长左/右 + 布局 + 设置页 + router + view 手势）、两指轻点暂停、作者专属倍速（author_play_speed 模型 + controller 方法 + header_control 入口 + video_driver 调用点）、member 视频筛选、fork 测试目录。
- BTR 吸收项（唯一）：`macos/Runner/Release.entitlements` 增加 `com.apple.security.network.server`（对方 PR e525f2933 的修复；本地 macOS Release 构建沙盒下 ThreadRipper 回环代理才能绑定端口；fork Release entitlements 现缺该项而 Debug 版已有）。不引入 BtrProxy 任何代码。
- 验证链：`bash lib/scripts/patch.sh ios` → `fvm flutter analyze`（与基线比对 error/warning，info 不作失败判据）→ `fvm flutter test` 全过 → gt3 污染还原 + `geetest_plugin.dart` 移出工作树（维持停车场策略）→ 提交 merge commit → `git fetch upstream && git log main..upstream/main` 复核为 0。
- 预计冲突文件（Build 阶段以实际为准）：`.github/workflows/linux_x64.yml` 与 `win_x64_newlibmpv.yml`（delete/modify：维持删除）、`.github/workflows/ios.yml`（modify/modify：取 ours 增强版）、`README.md`（双方改动融合）、`lib/utils/storage_pref.dart` / `storage_key.dart`、`lib/models/video/play/url.dart`、`lib/pages/setting/models/play_settings.dart` / `video_settings.dart`、`lib/pages/video/controller.dart`、`lib/pages/video/widgets/header_control.dart` / `player_focus.dart`、`lib/pages/video/reply_new/view.dart`、`lib/pages/common/publish/common_rich_text_pub_page.dart`、`lib/pages/dynamics_create/view.dart`、`lib/plugin/pl_player/controller.dart` / `view/view.dart`、`lib/router/app_pages.dart`。

## Source coverage

PR 3223（https://github.com/bggRGjQaUbCoE/PiliPlus/pull/3223，分支 CharlesYWL/PiliPlus@pr/btr-proxy，本地 `/Users/tune/Downloads/PiliPlus`）为本 change 的取证/评估材料，不作为需求来源，不触发源文档完整覆盖模式；其评估结论见 Decisions D4。无其他外部源文档。

## 目录结构

### 新建

- 合并引入的上游新文件（如 `lib/scripts/newlibmpv.patch`、离线缓存三层结构新页 `lib/pages/download/download/`、`download_playback.dart`、`reply_scheme_helper.dart` 等，以 merge 树为准）
- `macos/Runner/Release.entitlements` 修改（BTR 吸收项，见修改）

### 修改

- 上游本批改动涉及的文件（`git diff 8d755f16b..upstream/main --stat`，约 60 个，重点：download 全目录、video/controller.dart、pl_player controller/view、音视频/直播画质模型、play/video settings、reply 链路、dyn 页面）
- 预计冲突文件的手工融合（约 15 个，见 Scope 列表）：`.github/workflows/linux_x64.yml`、`win_x64_newlibmpv.yml`（维持删除）、`ios.yml`（取 ours）、`README.md`、`lib/utils/storage_pref.dart`、`storage_key.dart`、`lib/models/video/play/url.dart`、`lib/pages/setting/models/play_settings.dart`、`video_settings.dart`、`lib/pages/video/controller.dart`、`header_control.dart`、`player_focus.dart`、`reply_new/view.dart`、`lib/pages/common/publish/common_rich_text_pub_page.dart`、`lib/pages/dynamics_create/view.dart`、`lib/plugin/pl_player/controller.dart`、`view/view.dart`、`lib/router/app_pages.dart`
- fork 保留项按裁决局部回写（三钉、flutter 环境行、.fvmrc、README fork 章节、fork CI 裁剪）
- `macos/Runner/Release.entitlements`：Release 配置增加 `com.apple.security.network.server`（BTR 唯一吸收项）

### 删除

- 上游已删除而 fork 无保留理由的文件，以 merge 自动结果为准（本批以上游删除 `download_collection_service.dart` 等 download 旧结构为主）
- fork 已裁剪 workflow 在 merge 中保持删除状态

### 明确不建

- 不新增 fork 侧功能文件；不引入 `lib/services/btr_proxy/` 及任何 BtrProxy 符号
- 不创建发布产物、不创建 PR 分支
- 不修改 `.comet/runtime/` 下任何 Runtime 本机文件

# Non-goals

- 不升级 Flutter 工作区版本（保持 fvm 3.47.0，不跟上游 3.47.7；升级需另行评估 Xcode 16.4 iOS 构建约束）。
- 不推送 origin、不创建 PR、不发布 release（同步完成后由用户另行决定）。
- 不采用 PiliPlus PR 3223 的 BtrProxy 实现，不删除/重构自研 ThreadRipper。
- 不重构/不回移 fork 已有功能实现；仅做上游 API 差异所需的最小适配。
- 不恢复 fork 已裁剪的上游 CI workflow（既定决策）。
- 不处理不在本次合并范围内的上游分支（`upstream/refactor/download-upstream-3layer` 等）。

# Acceptance examples

- A1: 合并完成后重新 `git fetch upstream`，`git rev-list --count main..upstream/main` 为 0（同步期间上游若有新推送，按同一原则补合后复核仍为 0）。
- A2: fork 保留项在合并后幸存：`pubspec.yaml` 含 `connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`、`environment.flutter: 3.47.0`；`.fvmrc` 为 `{"flutter": "3.47.0"}`；README.md 保留 fork 差异文档章节；BUILD_IOS.md、`lib/scripts/patch.sh`、`sync_upstream_build.yml` 存在；8 个被裁剪 workflow 文件保持删除。
- A3: fork 功能全量幸存：`lib/services/thread_ripper/` 13 个文件完整；video_settings 含 Thread Ripper / PCDN / 屏蔽画质条目与 CDN 互斥 subtitle；pl_player controller 含 `applyAuthorDefaultSpeed` / `resetAuthorDefaultSpeedToGlobal` / 双击分区 getter / `enableTwoFingerTapPause`；view.dart 含 `TwoFingerTapDetector` 接线与 `doubleTapSeekLayout.resolveType`；url.dart 含 `blockedQualities` 兜底语义（按新 API 形态）；router 含 `/doubleTapSeekZoneSetting`。
- A4: `bash lib/scripts/patch.sh ios` 无失败段（material/cupertino 补丁打在 lock 活跃版本目录，抽验 source blob hash 一致）。
- A5: `fvm flutter analyze` 相对合并前基线不新增 error / warning（存量 info 级 lint 允许，退出码 1 不作失败判据）。
- A6: `fvm flutter test` 全部用例通过（含 test/thread_ripper/ 161 用例）。
- A7: 撞车排查零遗漏：fork 功能与上游本批改动的同类撞车条目为 0（排查方式与结论记录于 brief Decisions；如 Build 中出现新撞车，逐项呈报用户取舍）。
- A8: 提交树纯净：merge commit 树中无 gt3_flutter_plugin 注入（pubspec.yaml 无 gt3_flutter_plugin、geetest_plugin.dart 不在库中），geetest/bottom_sheet iOS 补丁污染文件与上游纯净态一致；产物为双亲 merge commit（恰好两行 parent：ours 与 upstream/main）。
- A9: BTR 吸收项落地且仅为该项：`macos/Runner/Release.entitlements` 含 `com.apple.security.network.server`；fork lib/ 下不含 `btr_proxy`、BtrConfig、BtrProxy 任何符号。
- A10: pubspec.lock 相对合并前无变化（上游本批未改 lock；若 Merge 产生 lock 冲突或需要 pub get，则退化为：与上游 lock 结构化 diff 后差异仅三钉及其传递伴随包，URL 全为 pub.flutter-io.cn——沿用上轮验收口径）。

# Constraints and invariants

- 禁用 `git stash -u`（stash pop 会吞 MERGE_HEAD）；全程不使用 `reset --hard`、force push。
- pub get 必须用 `~/fvm/versions/3.47.0/bin/flutter` 绝对路径并以 `PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn` 运行。
- 新增测试文件如被 `.gitignore` 的 `test*` 规则忽略，`git add -f` 纳入。
- patch.sh 的 material/cupertino 段选目录时注意 pub-cache 双缓存目录排序坑：确保选中 lock 活跃版本目录，patch 后抽验 source blob hash。
- patch.sh ios 应用后 bottom_sheet/geetest 段会污染工作树（mini_scaffold.dart / common_slide_page.dart 等）：验证顺序为 patch.sh → analyze/test → `git checkout` 还原污染文件 → 提交；交接前同时确认 `geetest_plugin.dart` 不在工作树（已 maintained 停车场策略）。
- 上游新代码若与三钉 API 冲突，适配方向是改调用方代码贴近钉版，不升级钉版本本批无此情况）。
- fork 功能文件在上游同名改动中取 theirs 时，逐文件核对 fork 插入块（getter、方法、import、UI 条目）并手工补回。

# Decisions

- D1 隔离方式 `current`：工作区干净、无其他 active change、无并行诉求，符合 Runtime 默认。
- D2 合并方式 `git merge`（保留 merge 双亲形态），与 fork 历史同步形态一致。
- D3 冲突裁决沿用既定原则：上游功能全收；三钉 / flutter 3.47.0 / .fvmrc / README 差异 / BUILD_IOS.md / fork CI 裁剪集 / fork ios.yml 增强版为 fork 保留项；实现选择（API 适配细节、冲突手工融合）由 Agent 决定。
- D4 BTR（PiliPlus PR 3223，CharlesYWL@pr/btr-proxy，7 提交 +898 行）处置——用户裁决（2026-10-18）：**保留自研 ThreadRipper + 仅吸收 1 个修复，不采用对方实现**。依据（实际比对双方代码后）：
  - 功能面：我们为功能超集。我们基于官方镜像换签候选池（签名只绑定查询参数，全镜像 206）动态构建节点；对方用硬编码静态 host 池（8 大陆 + 5 海外），上游节点池变动即失效，且不含 PCDN mcdn/szbdyd 改写、无换签、无 Akamai 兼容。
  - 调度面：我们 1:1 移植上游 engine.ts 并经 4 轮加固（消费驱动预取、渐进启动、PCDN 默认排除、移动端交付层修复、CDN 设置互斥）；对方为简化移植（256KB 探测 + EWMA + head-of-line rescue），无 barrier/优先级分级（critical/urgent/relaxed）、无双击预热（init segment/索引预载）、无画质切换预热、无饱和停止。
  - 质量面：我们 13 文件 4431 行 + 161 测试用例（e2e/scheduler/range 语义等 16 个测试文件）；对方 2 文件 837 行、0 测试。
  - 集成面：对方改 PlPlayerController.wrap 接管全部点播 + 直播竞速；我们走 getCdnUrl 改写链路 + descriptor 注册，直播不接管（与本 fork 行为一致）。替换 = 大规模重写集成层 + 废弃 161 测试，收益为负。
  - 唯一吸收项：macOS Release.entitlements 补 `network.server`（对方因同样使用回环代理踩到沙盒坑；我们 Debug 版已有、Release 版缺失，导致本地 Release 构建下 ThreadRipper 静默降级直连）。
- D5 本轮撞车排查结论：**无撞车**。排查方式：① 上游 18 个非 merge 提交逐个核对与 fork 功能的交集（仅 WiFi 自动播放、键盘倍速步进、离线缓存三层重构、画质模型重构、番剧分享链接修复、弹幕权重过滤等，均与 fork 功能无同类实现）；② fork 关键功能标识（blockedVideoQualities / enableThreadRipper / doubleTapBackwardZone / enableTwoFingerTapPause / authorPlaySpeed / member_video_filter）在上游 `git grep` 全部为空。上游 936072449 画质模型重构与 fork 屏蔽画质共存，属 API 适配而非撞车，按 D3 最小适配处理。
- D6 delete/modify 冲突（fork 删除的上游 workflow：linux_x64.yml 上游改 2 次、win_x64_newlibmpv.yml 上游改 1 次）维持删除——沿用用户既定 CI 裁剪决策（ec7e043a4「精简 fork 无用的上游 workflow，仅保留同步构建链」）；随上游新增的 `lib/scripts/newlibmpv.patch` 按上游功能全收保留（仅被已删 workflow 引用，无副作用）。
- D7 上游画质模型重构（936072449：enum→class + `fromFormat` + `Dash.fromJson` 双参 + live quality 非空化）的适配：fork 屏蔽画质的选择/兜底/菜单过滤与作者倍速调用点接上新 API，用户可见行为不变；新增档位 `superResolution(100)`（智能修复）随上游进入屏蔽候选集。

# Open questions

（当前无 `[blocking]`。BTR 处置已由用户裁决（D4）；若 Build 中出现本 brief 未预见的新撞车条目，按 D5 口径即时逐项提问，写作：`- [blocking] C1: <撞车条目>`。）

# Verification expectations

- 命令门槛：A4 patch.sh 成功、A5 analyze 不新增 error/warning、A6 test 全过。
- 结构核对：A1 rev-list 计数、A2/A3 保留项与功能幸存 grep、A8 gt3 纯净态 + 双亲提交检查、A9 entitlements 与 BtrProxy 排除检查、A10 lock 无变化（或退化口径的结构化 diff）。
- 时序完整性：结束前重新 `git fetch upstream` 复核无新增提交。
- 已知限制：项目 analyze 存在存量 info 级 lint（退出码 1 属预期）；本次为本地验证（patch/analyze/test），不构建 iOS 真机包（如需按 BUILD_IOS.md Step 1–6 由用户另行执行）。
