---
generated_from_state_version: 8
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 1
- 完成时间: 2026-10-25T02:11:51.684Z
- 摘要: 独立复核全部 14 项验收：合并提交 0072fc492 双亲为 f84c1ec86 与 b5694ccda，HEAD..b5694ccda=0；上游关键词过滤逐项编译与下载续传修复与上游树逐字节一致；8 个已裁剪 workflow 均未恢复且增强版 ios.yml 未被改动；三钉/Flutter 3.47.0/.fvmrc/README/BUILD_IOS.md/patch.sh 与六项 fork 功能入口完好，合并不触及 thread_ripper/member_video/pl_player/video_utils；上游全树对六项功能标识 0 命中，零撞车结论成立；Runtime analyze 0 error/7 warning 与 test 316 全过（candidateId 匹配），工作树除 Comet 状态文件外干净。判定 pass。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1: 合并后重新 `git fetch upstream`，`git rev-list --count HEAD..upstream/main` 为 0；merge commit 恰好两行 parent（合并前 main 与 upstream/main b5694ccda）。 | git log -1 --format=%P HEAD => f84c1ec86abb9cabf0bfc3a70f777e84013e3134 b5694ccdaf6064b3bf582bfe7991936d508740b8（恰好双亲）；git rev-parse upstream/main=b5694ccda，git rev-list --count HEAD..b5694ccda=0；分支 main。 |
| A2 | passed | brief.md | A2: 下载续传修复在位：`lib/pages/download/detail/widgets/item.dart` 使用 `canActInPlace = isCompleted \|\| onDelete != null` 语义；`lib/pages/download/downloading/view.dart` 队列项带有进入多选并勾选的 `customOnLongPress` 接线。 | lib/pages/download/detail/widgets/item.dart:97 `final canActInPlace = entry.isCompleted \|\| onDelete != null;` 并在 :111 作为早退判据；lib/pages/download/downloading/view.dart:82-85 customOnLongPress 置 enableMultiSelect=true 并 onSelect(entry)；git diff b5694ccda HEAD -- 这两个文件为空（与上游 93bf8643d 完全一致）。 |
| A3 | passed | brief.md | A3: 关键词过滤重构在位：`Pref.parseBanWordItems` 为唯一解析入口，`Pref.compileBanWord` 按项编译且单项失败只跳过该项，`RegExpListMatch.hasMatch` 生效；`Pref.parseBanWordToRegex` 已删除，仓库内无残留调用点；`test/pages/search_panel/keyword_filter_test.dart` 与实现匹配。 | lib/utils/storage_pref.dart:1116 parseBanWordItems、:1151 compileBanWord（:1153 逐项 RegExp，:1156 FormatException 仅跳过该项）、:61 extension RegExpListMatch 及 :64 hasMatch；grep parseBanWordToRegex lib test = 0 命中；list_editor_dialog.dart:17/30 patternValidator、:168-172 返回'无效的正则表达式'、:255 errorText: _errorTextOf(index)；测试 test/pages/search_panel/keyword_filter_test.dart:424 已改为 `rcmdRegExp = [RegExp('推荐屏蔽')]`，与 List<RegExp> 实现一致且全量测试通过。 |
| A4 | passed | brief.md | A4: `lib/utils/storage_pref.dart` 双端共存：ban-word 新 API 与 fork 的 `blockedVideoQualities`、`enableThreadRipper` / `threadRipperBlockPcdn`、`doubleTap*`、`enableTwoFingerTapPause`、`authorPlaySpeeds` 均在且无重复定义。 | lib/utils/storage_pref.dart 同时含 :1116/:1151 上游 ban-word API 与 :463 blockedVideoQualities、:736/739 enableThreadRipper get/set、:743/746 threadRipperBlockPcdn、:1042-1071 doubleTap*、:1074 enableTwoFingerTapPause、:1490/1493 authorPlaySpeeds；逐项 grep 仅一处 getter 定义，重复定义会导致编译错误而 analyze 为 0 error。 |
| A5 | passed | brief.md | A5: 已裁剪 CI 保持删除：`.github/workflows/build.yml` 不存在，`win_x64.yml`、`win_x64_newlibmpv.yml` 等 8 个已裁剪 workflow 均未恢复；`sync_upstream_build.yml` 与增强版 `ios.yml` 未被改动或回退。 | ls .github/workflows 仅 android_reusable.yml / ios.yml / sync_upstream_build.yml；build.yml、win_x64.yml、win_x64_newlibmpv.yml、android.yml、debug_android.yml、debug_build.yml、linux_x64.yml、mac.yml 逐一 test -e 均 absent；git diff --stat f84c1ec86 HEAD -- .github/workflows/{ios,sync_upstream_build,android_reusable}.yml 为空；ios.yml:5-24 保留 ref/artifact_name/file_suffix 输入。 |
| A6 | passed | brief.md | A6: fork 保留项幸存：`pubspec.yaml` 含三钉与 `environment.flutter: 3.47.0`；`.fvmrc` 为 `{"flutter": "3.47.0"}`；README fork 差异章节、`BUILD_IOS.md`、`lib/scripts/patch.sh` 存在。 | pubspec.yaml:24 `flutter: 3.47.0`、:77 connectivity_plus 7.0.0、:81 device_info_plus 13.0.0、:93 file_picker 12.0.0-beta.7；.fvmrc 内容为 {"flutter": "3.47.0"}；README.md:1 为 '# PiliNara fork 差异说明'；BUILD_IOS.md、lib/scripts/patch.sh、.github/workflows/sync_upstream_build.yml 均存在。 |
| A7 | passed | brief.md | A7: fork 六项功能全量幸存：`lib/services/thread_ripper/` 13 个文件与 `test/thread_ripper/` 用例齐全；屏蔽画质、双击区域调整与预览、两指轻点暂停、作者专属倍速、会员视频本地筛选的入口与行为未被本批合并改动。 | lib/services/thread_ripper/*.dart=13、test/thread_ripper/*.dart=13；六项入口在位：blockedVideoQualities 用于 lib/pages/video/controller.dart 与 setting/models/video_settings.dart，two_finger_tap_detector 用于 pl_player/view.dart+controller.dart，authorPlaySpeeds 用于 lib/pages/video/widgets/header_control.dart:586，DoubleTapSeekZoneSettingPage 路由 lib/router/app_pages.dart:121，MemberVideoFilterDialog 入口 lib/pages/member_video/view.dart:321；git diff --name-status f84c1ec86 HEAD 中不含 lib/services/thread_ripper、test/thread_ripper、lib/pages/member_video、lib/plugin/pl_player、lib/utils/video_utils 任何条目（0 处改动）。 |
| A8 | passed | brief.md | A8: 验证与纯净：`fvm flutter analyze` 相对合并前基线不新增 error / warning（存量 info 允许）；`fvm flutter test` 全部通过；提交前工作树无补丁污染与 `geetest_plugin.dart` 残留，仅含本 change 的实现与正式产物。 | verify.checks.value.candidateId=11b19474d0…72 与候选一致，analyze-no-new-issues 与 flutter-test-all 均 status=passed；日志 5974…-analyze-no-new-issues.log 末行 'errors=0 warnings=7'（门槛 ≤7），flutter-test-all.log 末行 'All tests passed!'（+316）；git status --porcelain 仅 M docs/comet/changes/.../comet-state.yaml，git diff HEAD -- lib test pubspec.yaml pubspec.lock .github 为空，lib/pages/login/geetest/geetest_plugin.dart 不存在，pubspec 无 gt3_flutter_plugin，bottom_sheet.dart 等补丁目标文件未被改动。 |
| A9 | passed | brief.md | A9: 撞车排查零遗漏：上游本批不存在与 fork 六项功能同类的实现；排查方式与证据记录于 brief D4；无新增撞车条目需要用户裁决。 | brief.md D4 记录了排查方法与证据；对上游树 git grep b5694ccda -- lib test 检索 thread_ripper/ThreadRipper/blockedVideoQualities/twoFingerTap/authorPlaySpeed/memberVideoFilter/playCountFilter/enableThreadRipper/屏蔽画质/作者倍速/双击区域/两指/会员视频 均 0 文件命中（正向对照 canActInPlace 在 b5694ccda:item.dart 命中 2 次，证明检索有效）；上游 3 个提交仅改 ban-word 16 文件、下载 2 文件与 build.yml，与六项功能无交集，无需用户裁决。 |
| A10 | passed | specs/upstream-sync/spec.md | 上游缺陷修复全收 - **WHEN** 上游在 `e52ad34a5..b5694ccda` 范围内修改缺陷修复代码，且 fork 对这些文件没有自己的更改或更改可与之共存 - **THEN** 合并结果完整采用上游修复： - 关键词过滤按列表项逐项编译，命中任一即过滤；`Pref.parseBanWordItems` 是唯一解析入口，`Pref.compileBanWord` 对每一项独立编译且单项非法只跳过该项；`Pref.parseBanWordToRegex` 不再存在，仓库内无残留调用点；`RegExpListMatch.hasMatch` 供四个过滤器使用；`ListEditorDialog` 对非法行给出 `patternValidator` 与行内 `errorText`。 - 下载队列在进程被杀死后，等待中条目可继续下载；点击条件为 `canActInPlace = isCompleted \|\| onDelete != null`；队列项长按进入多选并勾中该条，分P 页列表（不传 `onDelete`）保持点击播放。 | 两处上游修复与 b5694ccda 逐字节一致（git diff b5694ccda HEAD -- item.dart downloading/view.dart 为空），canActInPlace/自定义长按在 item.dart:97,111 与 downloading/view.dart:82-85；RegExpListMatch.hasMatch 被 4 组以上过滤器使用：lib/grpc/reply.dart:144、lib/utils/recommend_filter.dart:49,55、lib/models/dynamics/result.dart:101,105、lib/http/video.dart:116,209,1019；ListEditorDialog patternValidator+行内 errorText 在位；分P 列表 lib/pages/download/page/view.dart:250 调 DetailItem 不传 onDelete，故未完成项走下载页、已完成项仍点击播放，符合上游注释。 |
| A11 | passed | specs/upstream-sync/spec.md | 已裁剪 CI 保持删除 - **WHEN** 上游修改了 fork 已裁剪删除的 workflow 文件（本批：`.github/workflows/build.yml` 新增 `build_win_x64_newlibmpv` 开关与 `win_x64_newlibmpv` job） - **THEN** 合并后 `.github/workflows/build.yml` 仍不存在，`win_x64.yml`、`win_x64_newlibmpv.yml` 等 8 个已裁剪 workflow 均不恢复；fork 自有的 `sync_upstream_build.yml` 与增强版 `ios.yml`（`ref` / `artifact_name` / `file_suffix` 输入）不被修改或回退。 | 同 A5 证据：.github/workflows 仅 3 个文件，build.yml 与 win_x64_newlibmpv.yml 不存在，grep -rn win_x64_newlibmpv .github = 0 命中；sync_upstream_build.yml 与增强版 ios.yml（ref/artifact_name/file_suffix）相对合并前 main 无改动（git diff 为空）。 |
| A12 | passed | specs/upstream-sync/spec.md | fork 保留项与自有功能不受影响 - **WHEN** 合并涉及 fork 钉定文件、CI 差异或六项自有功能所在的代码区域 - **THEN** 合并后须满足： - `pubspec.yaml` 保持 `connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`、`environment.flutter: 3.47.0`；`.fvmrc` 为 `{"flutter": "3.47.0"}` - README 的 fork 差异章节、`BUILD_IOS.md`、`lib/scripts/patch.sh` 保留 - ThreadRipper、屏蔽画质、双击区域调整与预览、两指轻点暂停、作者专属倍速、会员视频本地筛选的入口、配置项与行为不变 - `lib/utils/storage_pref.dart` 同时包含上游 ban-word API 与 fork 新增 Pref（`blockedVideoQualities`、`enableThreadRipper` / `threadRipperBlockPcdn`、`doubleTap*`、`enableTwoFingerTapPause`、`authorPlaySpeeds`），无重复定义、无调用点遗漏 | 由 A6（三钉/flutter 3.47.0/.fvmrc/README/BUILD_IOS.md/patch.sh）、A7（13+13 文件与六项功能入口，合并不触及）与 A4（storage_pref 双端共存、无重复定义）合并判定通过；全量 316 测试含 thread_ripper/member_video/double_tap/author_speed 用例均通过。 |
| A13 | passed | specs/upstream-sync/spec.md | 撞车取舍 - **WHEN** fork 已实现的某功能，上游在本批次中也做了同类实现（同一功能、不同写法） - **THEN** 该条目不自动裁决；由 Agent 呈报双方差异，用户逐项选择保留 fork 版 / 采用上游版 / 融合，选择结论记入 brief `# Decisions` 并落盘 - **若排查后无撞车条目**，记录排查方式与“无撞车”结论，本场景以“零遗漏”为通过标准 | brief.md D4 给出排查方式与“零撞车”结论，且独立复核（同 A9）上游全树对六项功能标识与中文关键词为 0 命中，3 个上游提交不构成同类实现；本场景以零遗漏通过，无待用户裁决项。 |
| A14 | passed | specs/upstream-sync/spec.md | 合并形态与工作树纯净 - **WHEN** 本次同步合并提交并完成本地验证 - **THEN** merge commit 恰好两行 parent（合并前 `main` 与 `upstream/main`），重新 fetch 后 `git rev-list --count HEAD..upstream/main` 为 0；`flutter analyze` 相对合并前基线不新增 error / warning，`flutter test` 全部通过；若执行过 `patch.sh`，bottom_sheet / geetest 补丁污染文件在提交前已还原，`geetest_plugin.dart` 不在工作树，提交内容仅包含本 change 的实现与正式产物。 | git log -1 --format=%P HEAD 恰为 f84c1ec86…+b5694ccda… 两亲，git rev-list --count HEAD..b5694ccda=0；Runtime analyze 0 error/7 warning（门槛=合并前基线 7，日志 errors=0 warnings=7）与 flutter test 316 全过；未执行 patch.sh（git status 无 bottom_sheet/geetest 改动），geetest_plugin.dart 不在工作树，提交内容只含本 change 的 lib/test 修复、Comet 产物与 .gitignore 的 Comet 托管块。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter analyze：0 error 且 warning 不超过基线 7 | -c export PUB_HOSTED_URL=https://pub.flutter-io.cn export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn out=$(/Users/tune/fvm/versions/3.47.0/bin/flutter analyze 2>&1) printf '%s\n' "$out" \| tail -1 e=$(printf '%s\n' "$out" \| grep -cE '^ *error ') w=$(printf '%s\n' "$out" \| grep -cE '^ *warning ') echo "errors=$e warnings=$w" test "$e" -eq 0 && test "$w" -le 7 | . | passed | 0 | 9828 ms |
| flutter test 全量用例 | -c export PUB_HOSTED_URL=https://pub.flutter-io.cn export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn /Users/tune/fvm/versions/3.47.0/bin/flutter test | . | passed | 0 | 33709 ms |
| 合并双亲与 upstream 祖先完整 | -c m=$(git rev-list --merges -n1 HEAD) test "$(git rev-list --parents -n1 "$m" \| wc -w \| tr -d ' ')" -eq 3 test "$(git rev-parse --short "$m")" = "0072fc492" git merge-base --is-ancestor b5694ccda HEAD test "$(git rev-list --count HEAD..b5694ccda \| tr -d ' ')" -eq 0 echo "lineage-ok merge=$m" | . | passed | 0 | 208 ms |
| 上游关键词过滤与下载续传修复在位、裁剪 CI 未恢复 | -c test "$(grep -rn 'parseBanWordToRegex' lib test \| wc -l \| tr -d ' ')" -eq 0 grep -q 'static List<String> parseBanWordItems' lib/utils/storage_pref.dart grep -q 'static List<RegExp> compileBanWord' lib/utils/storage_pref.dart grep -q 'extension RegExpListMatch on List<RegExp>' lib/utils/storage_pref.dart grep -q 'patternValidator' lib/pages/setting/widgets/list_editor_dialog.dart grep -q 'canActInPlace = entry.isCompleted \|\| onDelete != null' lib/pages/download/detail/widgets/item.dart grep -q 'customOnLongPress' lib/pages/download/downloading/view.dart test ! -e .github/workflows/build.yml test ! -e .github/workflows/win_x64_newlibmpv.yml echo upstream-fixes-ok | . | passed | 0 | 307 ms |
| fork 钉定、文档脚本与六项功能幸存、storage_pref 双端共存 | -c grep -q 'connectivity_plus: 7.0.0' pubspec.yaml grep -q 'device_info_plus: 13.0.0' pubspec.yaml grep -q 'file_picker: 12.0.0-beta.7' pubspec.yaml grep -q 'flutter: 3.47.0' pubspec.yaml grep -q '"flutter": "3.47.0"' .fvmrc head -1 README.md \| grep -q 'fork 差异说明' test -f BUILD_IOS.md test -f lib/scripts/patch.sh test -f .github/workflows/sync_upstream_build.yml test "$(ls lib/services/thread_ripper/*.dart \| wc -l \| tr -d ' ')" -eq 13 test "$(ls test/thread_ripper/*.dart \| wc -l \| tr -d ' ')" -ge 13 test -f lib/pages/member_video/video_filter.dart for k in blockedVideoQualities enableThreadRipper threadRipperBlockPcdn enableTwoFingerTapPause authorPlaySpeeds; do test "$(grep -c "$k" lib/utils/storage_pref.dart \| tr -d ' ')" -ge 1 \|\| exit 1; done test "$(grep -c 'static bool get enableThreadRipper' lib/utils/storage_pref.dart \| tr -d ' ')" -eq 1 grep -q 'artifact_name' .github/workflows/ios.yml grep -q 'file_suffix' .github/workflows/ios.yml echo fork-retention-ok | . | passed | 0 | 71 ms |
| 无 gt3/geetest/补丁污染且代码无未提交改动 | -c ! grep -q gt3_flutter_plugin pubspec.yaml pubspec.lock ! git ls-files \| grep -q geetest_plugin.dart test ! -e lib/pages/login/geetest/geetest_plugin.dart git diff --quiet HEAD -- lib test pubspec.yaml pubspec.lock .github test -z "$(git ls-files --others --exclude-standard -- lib test \| head -1)" test -z "$(git status --porcelain \| grep -v 'docs/comet/changes/' \|\| true)" echo tree-clean-ok | . | passed | 0 | 135 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- 合并前基线 flutter analyze: passed — 0 error / 7 warning / 74 issues
- 合并后 flutter analyze: passed — 0 error / 7 warning / 74 issues，与基线一致；退出码 1 为存量 info
- 合并后 flutter test: passed — 316 用例全部通过
- 合并形态: passed — 0072fc492 双亲 f84c1ec86+b5694ccda；HEAD..b5694ccda=0
- 上游修复与 CI 裁剪结构核对: passed — parseBanWordToRegex 0 命中；下载续传语句在位；build.yml 保持删除
- fork 保留项核对: passed — 三钉/.fvmrc/README/BUILD_IOS/patch.sh；thread_ripper 13 文件；storage_pref 双端共存
- 工作树纯净核对: passed — 无 gt3/geetest/补丁污染；lib/test/pubspec/.github 无未提交改动
- iOS 真机构建: not-run — 本批未改依赖，未重跑 patch.sh，未构建真机包
- 已知限制: 未构建或运行 iOS 真机包；本批未改依赖，未重跑 patch.sh，analyze/test 沿用合并前已应用的补丁缓存。
- 已知限制: flutter analyze 存在存量 74 issues（0 error / 7 warning / 67 info），退出码 1 属预期，判据为 error/warning 计数。

## 阻塞项

_无。_

## 风险与跳过的工作

- flutter analyze 的合并前基线（0 error / 7 warning / 74 issues）无法在只读验证中重新测量，仅能依据 Runtime 检查门槛（warning ≤ 7）与 Builder 记录的基线；合并后实测 errors=0 warnings=7，未超出基线。
- merge commit 相对合并前 main 额外包含 .gitignore 的 Comet 托管忽略块与 docs/comet/* 本 change 产物（brief/spec/state），brief 的“修改”清单未列出 .gitignore；属 Comet 状态产物，非补丁污染。
- 未重新执行 git fetch upstream（只读约束），A1 以本地 upstream/main 引用 b5694ccda 与 rev-list=0 判定；未构建 iOS 真机包（Builder 已声明 not-run）。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | 独立复核全部 14 项验收：合并提交 0072fc492 双亲为 f84c1ec86 与 b5694ccda，HEAD..b5694ccda=0；上游关键词过滤逐项编译与下载续传修复与上游树逐字节一致；8 个已裁剪 workflow 均未恢复且增强版 ios.yml 未被改动；三钉/Flutter 3.47.0/.fvmrc/README/BUILD_IOS.md/patch.sh 与六项 fork 功能入口完好，合并不触及 thread_ripper/member_video/pl_player/video_utils；上游全树对六项功能标识 0 命中，零撞车结论成立；Runtime analyze 0 error/7 warning 与 test 316 全过（candidateId 匹配），工作树除 Comet 状态文件外干净。判定 pass。 | 2026-10-25T02:11:51.684Z |



## 结论

独立复核全部 14 项验收：合并提交 0072fc492 双亲为 f84c1ec86 与 b5694ccda，HEAD..b5694ccda=0；上游关键词过滤逐项编译与下载续传修复与上游树逐字节一致；8 个已裁剪 workflow 均未恢复且增强版 ios.yml 未被改动；三钉/Flutter 3.47.0/.fvmrc/README/BUILD_IOS.md/patch.sh 与六项 fork 功能入口完好，合并不触及 thread_ripper/member_video/pl_player/video_utils；上游全树对六项功能标识 0 命中，零撞车结论成立；Runtime analyze 0 error/7 warning 与 test 316 全过（candidateId 匹配），工作树除 Comet 状态文件外干净。判定 pass。
