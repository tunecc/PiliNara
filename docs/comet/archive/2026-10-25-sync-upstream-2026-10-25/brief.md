# 目标

将上游 `upstream/main`（Starfallan/PiliNara @ b5694ccda，2026-10-24 抓取）合并进 fork `main`，完整保留 fork 自有更改。自 merge-base e52ad34a5 起共 3 个提交、19 个文件（+168/−192）：关键词过滤改为列表项逐项编译（16 文件）、下载队列杀进程后续传修复（2 文件）、总控 workflow 调用 NewLibmpv Windows 构建（build.yml）。

本批经撞车排查判定为**零撞车**：上游没有实现 fork 六项自有功能（ThreadRipper、屏蔽画质、双击区域调整与预览、两指轻点暂停、作者专属倍速、会员视频本地筛选）中的任何一项，因此不需要用户逐项裁决“保留上游还是保留 fork”。唯一的文件交集是 `lib/utils/storage_pref.dart`（fork 新增 Pref 定义、上游重写 ban-word API），`git merge-tree` 预检显示可自动合并，人工只需核对双方内容共存。

# 范围

- 用 `git merge upstream/main` 合入（保留双亲 merge commit），解决全部冲突并提交。
- merge-tree 预检：唯一冲突为 `.github/workflows/build.yml`（fork 已裁剪删除、上游修改 → 保持删除）；`lib/utils/storage_pref.dart` 自动合并。
- 上游修复全收：
  - b5694ccda 关键词过滤：每行独立正则、命中任一即过滤；`Pref.parseBanWordItems` 成为唯一解析入口，`Pref.compileBanWord` 逐项编译（单项非法只跳过该项）；`RegExpListMatch.hasMatch`；12 处 `.pattern.isNotEmpty` 改为 `.isNotEmpty`；`ListEditorDialog` 增加 `patternValidator` 与行内 `errorText`；三处快捷加入统一经 `Pref.parseBanWordItems` 解包；`parseBanWordToRegex` 删除且无残留调用点。
  - 93bf8643d 下载续传：`lib/pages/download/detail/widgets/item.dart` 的点击条件改为 `canActInPlace = isCompleted || onDelete != null`；`lib/pages/download/downloading/view.dart` 队列项增加 `customOnLongPress` 进入多选并勾中该条。
  - f999a4e6f CI：仅在 `build.yml` 新增 `build_win_x64_newlibmpv` 开关与 `win_x64_newlibmpv` job；fork 已删除该文件，保持删除，不引入该 job。
- fork 保留项（沿用既定 D3 口径）：三钉 `connectivity_plus: 7.0.0` / `device_info_plus: 13.0.0` / `file_picker: 12.0.0-beta.7`，`environment.flutter: 3.47.0`，`.fvmrc` 3.47.0，README fork 差异章节，`BUILD_IOS.md` / `lib/scripts/patch.sh` / `sync_upstream_build.yml`，8 个已裁剪 workflow 保持删除，fork 增强版 `ios.yml`。
- fork 六项功能全量幸存：ThreadRipper、屏蔽画质、双击区域调整与预览、两指轻点暂停、作者专属倍速、会员视频本地筛选。
- `storage_pref.dart` 双端合并：上游 ban-word API（`parseBanWordItems` / `compileBanWord`）与 fork 新增 Pref（`blockedVideoQualities`、`enableThreadRipper` / `threadRipperBlockPcdn`、`doubleTap*`、`enableTwoFingerTapPause`、`authorPlaySpeeds`）共存，无重复定义、无调用点遗漏。
- 验证链：记录合并前 analyze/test 基线 → `bash lib/scripts/patch.sh ios`（仅在补丁状态需要时）→ `fvm flutter analyze` 基线比对 → `fvm flutter test` → 清理补丁污染 → 提交双亲 merge commit → 重新 fetch 复核 rev-list 为 0。

## 目录结构

### 新建

- 无。本批 3 个提交均为对现有文件的修改。

### 修改

- 关键词过滤（16 文件）：`lib/utils/storage_pref.dart`、`lib/pages/setting/models/model.dart`、`lib/pages/setting/widgets/list_editor_dialog.dart`、`lib/utils/recommend_filter.dart`、`lib/common/widgets/video_popup_menu.dart`、`lib/common/widgets/context_menu/dyn_menu_helper.dart`、`lib/common/widgets/context_menu/reply_menu_helper.dart`、`lib/grpc/reply.dart`、`lib/http/video.dart`、`lib/models/dynamics/result.dart`、`lib/pages/setting/dynamics_setting.dart`、`lib/pages/setting/models/dynamics_settings.dart`、`lib/pages/setting/models/recommend_settings.dart`、`lib/pages/setting/models/reply_settings.dart`、`lib/pages/setting/reply_setting.dart`、`test/pages/search_panel/keyword_filter_test.dart`。
- 下载续传（2 文件）：`lib/pages/download/detail/widgets/item.dart`、`lib/pages/download/downloading/view.dart`。
- 冲突手工裁决（1 文件）：`.github/workflows/build.yml` 保持删除（不接受上游修改）。
- 自动合并后需人工核对（1 文件）：`lib/utils/storage_pref.dart` 的 ban-word 区段与 fork Pref 区段互不覆盖。

### 删除

- 本批上游无删除文件；fork 已裁剪的 workflow 在 merge 中保持删除状态。

### 明确不建

- 不新增 fork 侧功能文件；不引入 `BtrProxy` 或任何第三方 BTR 代码。
- 不恢复 `build.yml` 或其中新增的 `win_x64_newlibmpv` job。
- 不创建发布产物、PR 分支或 release。
- 不修改 `.comet/runtime/` 下任何 Runtime 本机文件。

# 非目标

- 不升级 Flutter 工作区版本（保持 fvm 3.47.0）；本批上游未改 `pubspec`，不主动刷新依赖。
- 不推送 origin、不创建 PR、不发布 release。
- 不重构或回移 fork 已有功能实现；只做上游差异所需的最小适配。
- 不恢复 fork 已裁剪的上游 CI workflow（含 `build.yml`、`win_x64_newlibmpv.yml`）。
- 不修复上游提交里注明“另开一轮处理”的搜索页 `SearchPanelController` 关键词拼接遗留。
- 不处理本批之外的上游分支。
- 不评估或引入第三方 BTR 实现。

# 验收示例

- A1: 合并后重新 `git fetch upstream`，`git rev-list --count HEAD..upstream/main` 为 0；merge commit 恰好两行 parent（合并前 main 与 upstream/main b5694ccda）。
- A2: 下载续传修复在位：`lib/pages/download/detail/widgets/item.dart` 使用 `canActInPlace = isCompleted || onDelete != null` 语义；`lib/pages/download/downloading/view.dart` 队列项带有进入多选并勾选的 `customOnLongPress` 接线。
- A3: 关键词过滤重构在位：`Pref.parseBanWordItems` 为唯一解析入口，`Pref.compileBanWord` 按项编译且单项失败只跳过该项，`RegExpListMatch.hasMatch` 生效；`Pref.parseBanWordToRegex` 已删除，仓库内无残留调用点；`test/pages/search_panel/keyword_filter_test.dart` 与实现匹配。
- A4: `lib/utils/storage_pref.dart` 双端共存：ban-word 新 API 与 fork 的 `blockedVideoQualities`、`enableThreadRipper` / `threadRipperBlockPcdn`、`doubleTap*`、`enableTwoFingerTapPause`、`authorPlaySpeeds` 均在且无重复定义。
- A5: 已裁剪 CI 保持删除：`.github/workflows/build.yml` 不存在，`win_x64.yml`、`win_x64_newlibmpv.yml` 等 8 个已裁剪 workflow 均未恢复；`sync_upstream_build.yml` 与增强版 `ios.yml` 未被改动或回退。
- A6: fork 保留项幸存：`pubspec.yaml` 含三钉与 `environment.flutter: 3.47.0`；`.fvmrc` 为 `{"flutter": "3.47.0"}`；README fork 差异章节、`BUILD_IOS.md`、`lib/scripts/patch.sh` 存在。
- A7: fork 六项功能全量幸存：`lib/services/thread_ripper/` 13 个文件与 `test/thread_ripper/` 用例齐全；屏蔽画质、双击区域调整与预览、两指轻点暂停、作者专属倍速、会员视频本地筛选的入口与行为未被本批合并改动。
- A8: 验证与纯净：`fvm flutter analyze` 相对合并前基线不新增 error / warning（存量 info 允许）；`fvm flutter test` 全部通过；提交前工作树无补丁污染与 `geetest_plugin.dart` 残留，仅含本 change 的实现与正式产物。
- A9: 撞车排查零遗漏：上游本批不存在与 fork 六项功能同类的实现；排查方式与证据记录于 brief D4；无新增撞车条目需要用户裁决。

# 约束与不变量

- 禁用 `git stash -u`（stash pop 会吞 MERGE_HEAD）；全程不使用 `reset --hard`、force push。
- flutter 命令必须使用绝对路径 `/Users/tune/fvm/versions/3.47.0/bin/flutter`；若触发 pub get，设置 `PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`。本批不改 `pubspec`，正常情况下不应触发。
- Runtime 的 verification_checks 直接执行可执行文件：flutter 必须写绝对路径；analyze 以 error/warning 计数为判据，不依赖退出码（存量 info 会让退出码为 1）。
- 若执行 `bash lib/scripts/patch.sh ios`，提交前用 `git checkout` 还原 bottom_sheet / geetest 补丁污染文件；`geetest_plugin.dart` 不留在工作树。
- 新增 `test/` 文件受 `.gitignore` 的 `test*` 规则影响时需 `git add -f` 纳入（本批无新增测试文件）。
- 提交前核对 `git status`，只允许本 change 的实现与正式产物；Builder 交接后不再编辑 brief。
- 上游新代码若与三钉 API 冲突，适配方向是修改调用方贴近钉版，不升级钉版本。
- merge commit 恰好两行 parent；不使用 squash 或 rebase 代替合并。
- 不修改 `.comet/runtime/` 下任何 Runtime 本机文件。
- 本机环境备注：Comet 0.5.0 首次迁移用户级 Runtime 时，按文件名把项目根的 `pubspec.lock` 误判为运行时锁（`.lock` 后缀）；已通过一次性临时改名完成迁移并立即还原，工作树无残留，后续命令不再触发。

# 决策

- D1 隔离方式 `current`：工作区干净、无其他 active change、无并行诉求，符合 Runtime 默认。
- D2 合并方式 `git merge`（保留 merge 双亲形态），与 fork 历史同步形态一致。
- D3 冲突裁决沿用既定原则：上游功能/修复全收；三钉 / flutter 3.47.0 / `.fvmrc` / README 差异 / `BUILD_IOS.md` / fork CI 裁剪集 / fork `ios.yml` 增强版为 fork 保留项；`build.yml` 在 fork 中已删除，上游对其新增的 `win_x64_newlibmpv` job 不恢复。
- D4 撞车排查结论：**零撞车**。排查方式：① 3 个非 merge 提交逐个核对与本 fork 六项功能的交集；② 两侧 changed-file 交集仅 `.github/workflows/build.yml`（fork 删除态 CI 文件）与 `lib/utils/storage_pref.dart`（偏好存储定义集合，不是功能实现重复），后者 merge-tree 自动合并；③ 对 `upstream/main` 全树 grep 标识 `thread_ripper`、`ThreadRipper`、`blockedQualit`、`twoFingerTap`、`authorPlaySpeed`、`doubleTapSeekZone`、`memberVideoFilter`、`playCountFilter`、`enableThreadRipper` 及中文关键词“屏蔽画质/作者倍速/双击区域/两指/会员视频/线程撕裂”均为 0 命中；④ 上游本批为两处缺陷修复与一处 CI 接线，不构成同类功能实现。结论：无需用户在“保留上游 / 保留 fork”之间逐项选择；若 Build 出现 brief 未预见的新撞车，按 A9 口径立即呈报用户裁决。
- D5 验证基线：Build 首次提交前记录合并前 analyze 的 error/warning 计数与 test 结果，作为 A8 基线；Runtime 检查复用绝对路径 flutter。
- D6 `storage_pref.dart` 合并策略：接受上游 ban-word 重构，保留 fork 全部新增 Pref；若自动合并结果出现重复定义或调用点遗漏，按“上游新 API + fork 配置项”补齐，不删除 fork 配置项。

# 待解决问题

无 `[blocking]`。本批零撞车，无需用户逐项裁决；Shape 确认后直接进入 Build。

# 验证预期

- 命令门槛：A8 的 `fvm flutter analyze`（error/warning 计数）与 `fvm flutter test`；如需补丁状态先执行 `bash lib/scripts/patch.sh ios`。
- 结构核对：A1 lineage 与双亲、A2/A3 上游修复、A4 `storage_pref` 双端共存、A5 CI 裁剪、A6/A7 fork 保留项与功能、A9 撞车排查。
- 纯净核对：A8 工作树无补丁污染与 geetest 残留；提交内容仅本 change 实现与正式产物。
- 时序完整性：结束前重新 `git fetch upstream` 复核 rev-list 为 0。
- 已知限制：analyze 存在存量 info 级 lint（退出码 1 属预期）；本次为本地 patch/analyze/test 验证，不构建 iOS 真机包（如需按 BUILD_IOS.md 由用户另行执行）。
