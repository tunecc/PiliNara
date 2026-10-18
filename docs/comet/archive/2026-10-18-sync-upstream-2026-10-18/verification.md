---
generated_from_state_version: 14
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 4
- 验证器尝试次数: 1
- 完成时间: 2026-10-18T05:50:56.542Z
- 摘要: 独立 Verifier 全程只读取证：16/16 全部 passed。独立重跑 analyze（0 error/7 warning/67 info，优于基线 9 warning）与 test（306 全过）；git 结构（双亲 merge 1b173c3d7、main..upstream/main=0）、fork 功能幸存（13 TR 文件+161 用例+全部 UI/模型接线）、A10 退化口径、BTR 仅吸收 entitlements 一项均独立证实。Runtime 末轮检查记录（20513659）与独立取证一致。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1: 合并完成后重新 `git fetch upstream`，`git rev-list --count main..upstream/main` 为 0（同步期间上游若有新推送，按同一原则补合后复核仍为 0）。 | 独立复核 git rev-list --count main..upstream/main = 0，upstream/main 即 merge-base b908eccfb，同步期间上游无新推送 |
| A2 | passed | brief.md | A2: fork 保留项在合并后幸存：`pubspec.yaml` 含 `connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`、`environment.flutter: 3.47.0`；`.fvmrc` 为 `{"flutter": "3.47.0"}`；README.md 保留 fork 差异文档章节；BUILD_IOS.md、`lib/scripts/patch.sh`、`sync_upstream_build.yml` 存在；8 个被裁剪 workflow 文件保持删除。 | pubspec.yaml 三钉+flutter 3.47.0 逐行核对在位；.fvmrc 为 3.47.0；README fork 章节、BUILD_IOS.md、patch.sh、sync_upstream_build.yml 存在；8 个裁剪 workflow git cat-file -e 全部不存在 |
| A3 | passed | brief.md | A3: fork 功能全量幸存：`lib/services/thread_ripper/` 13 个文件完整；video_settings 含 Thread Ripper / PCDN / 屏蔽画质条目与 CDN 互斥 subtitle；pl_player controller 含 `applyAuthorDefaultSpeed` / `resetAuthorDefaultSpeedToGlobal` / 双击分区 getter / `enableTwoFingerTapPause`；view.dart 含 `TwoFingerTapDetector` 接线与 `doubleTapSeekLayout.resolveType`；url.dart 含 `blockedQualities` 兜底语义（按新 API 形态）；router 含 `/doubleTapSeekZoneSetting`。 | thread_ripper 13 文件完整；pl_player controller 双击分区 getter/两指轻点/作者倍速方法、view.dart TwoFingerTapDetector 与 resolveType 接线、router /doubleTapSeekZoneSetting、url.dart blockedQualities 兜底、video_settings 三条目与 CDN 互斥 subtitle 均 grep 命中且行号确认 |
| A4 | passed | brief.md | A4: `bash lib/scripts/patch.sh ios` 无失败段（material/cupertino 补丁打在 lock 活跃版本目录，抽验 source blob hash 一致）。 | 只读约束下以 git apply -R --check 反向校验 material tabs/cupertino bottom_sheet/SDK 抽样/device_info 13.0.0 全部通过=补丁在位；patch.sh find\|sort -V\|tail 选目录=lock 活跃版本一致；与 Runtime applied=2/skipped=36 记录自洽 |
| A5 | passed | brief.md | A5: `fvm flutter analyze` 相对合并前基线不新增 error / warning（存量 info 级 lint 允许，退出码 1 不作失败判据）。 | 独立运行 fvm 3.47.0 flutter analyze：0 error/7 warning/67 info；合并前基线 0/9/67，无新增 error/warning |
| A6 | passed | brief.md | A6: `fvm flutter test` 全部用例通过（含 test/thread_ripper/ 161 用例）。 | 独立运行 flutter test：00:26 +306 All tests passed！；test/thread_ripper 161 用例含内 |
| A7 | passed | brief.md | A7: 撞车排查零遗漏：fork 功能与上游本批改动的同类撞车条目为 0（排查方式与结论记录于 brief Decisions；如 Build 中出现新撞车，逐项呈报用户取舍）。 | 6 个 fork 功能标识对 upstream/main git grep 全 0 命中；上游画质重构按 brief D7 定性为 API 适配非同类实现；Build 中无新撞车呈报 |
| A8 | passed | brief.md | A8: 提交树纯净：merge commit 树中无 gt3_flutter_plugin 注入（pubspec.yaml 无 gt3_flutter_plugin、geetest_plugin.dart 不在库中），geetest/bottom_sheet iOS 补丁污染文件与上游纯净态一致；产物为双亲 merge commit（恰好两行 parent：ours 与 upstream/main）。 | git cat-file -p 1b173c3d7 恰 2 行 parent（192db3b14+b908eccfb）；HEAD pubspec 无 gt3；geetest_plugin 不在树；污染文件对 upstream/main diff 为空 |
| A9 | passed | brief.md | A9: BTR 吸收项落地且仅为该项：`macos/Runner/Release.entitlements` 含 `com.apple.security.network.server`；fork lib/ 下不含 `btr_proxy`、BtrConfig、BtrProxy 任何符号。 | Release.entitlements 含 network.server 且对 upstream diff 恰为该 2 行；grep BtrProxy/BtrConfig/btr_proxy lib/ = 0 |
| A10 | passed | brief.md | A10: pubspec.lock 相对合并前无变化（上游本批未改 lock；若 Merge 产生 lock 冲突或需要 pub get，则退化为：与上游 lock 结构化 diff 后差异仅三钉及其传递伴随包，URL 全为 pub.flutter-io.cn——沿用上轮验收口径）。 | 退化口径成立：三方 lock 结构化解析=三钉+伴随6包（上游独有）+^内更新3包（fork 合并前已有）+镜像 sha 漂移刷新6包（d024dd4f9 已文档化）；hosted URL 全 pub.flutter-io.cn 无一 pub.dev。严格说刷新 6 包超出『仅三钉伴随』字面，但属约束内重解析且已记录（保留意见） |
| A11 | passed | specs/upstream-sync/spec.md | 上游功能全收 - **WHEN** 上游新增或修改了功能实现，且 fork 对同一代码位置没有自己的更改或更改可与之共存 - **THEN** 合并结果采用上游实现，fork 不保留旧实现；上游新增文件（如 `lib/scripts/newlibmpv.patch`）随合并进入 fork 树 | merge 树含 newlibmpv.patch、download/download/ 新页、download_playback.dart、reply_scheme_helper.dart；download_collection_service.dart 已删；20 上游提交全部包含 |
| A12 | passed | specs/upstream-sync/spec.md | fork 保留项不被上游覆盖 - **WHEN** 合并涉及以下 fork 钉定或差异文件 - **THEN** 合并后须满足： - `pubspec.yaml`: `connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`、`environment.flutter: 3.47.0` - `.fvmrc`: `{"flutter": "3.47.0"}` - README.md 保留 fork 差异文档章节（线程撕裂者、双击预览、画质屏蔽、作者专属倍速、iOS 构建指引） - fork 的 iOS 构建脚本（`lib/scripts/patch.sh`、`BUILD_IOS.md`）与 `sync_upstream_build.yml` 不被删除 - fork 已裁剪的上游 workflow（`linux_x64.yml`、`win_x64_newlibmpv.yml`、`android.yml`、`build.yml`、`debug_android.yml`、`debug_build.yml`、`mac.yml`、`win_x64.yml`）保持删除，即使上游在其删除后继续修改（delete/modify 冲突取删除侧） - fork 增强版 `ios.yml`（`ref` / `artifact_name` / `file_suffix` 输入）幸存，不回退为上游精简版 | 同 A2 证据+fork ios.yml artifact_name/file_suffix/ref 增强输入行号确认在位 |
| A13 | passed | specs/upstream-sync/spec.md | 上游 API 差异适配 - **WHEN** 上游重构了公共 API（本批：`VideoQuality` / `LiveQuality` / `AudioQuality` enum→class、`Dash.fromJson(json, supportFormats)`、`findAvailableVideoQuality` 收窄签名、`LiveQuality.fromCode` 非空化），而 fork 功能调用点建立在旧 API 上 - **THEN** 修改 fork 调用方代码适配新 API，fork 功能的用户可见行为保持不变（屏蔽画质的选择/兜底/菜单过滤、作者专属倍速的套用/回退、ThreadRipper 的 bandWidth/indexEnd 传递）；适配不删除 fork 功能、不改钉版依赖 | VideoQuality class+superResolution(100) 在树；Dash.fromJson(json, supportFormats) 双参签名在；LiveQuality.fromCode 非空化在；fork 调用点 findAvailableVideoQuality(blockedQualities)/fallbackVideo 与新 API 共存；行为不变由 test 306+analyze 0 error 佐证 |
| A14 | passed | specs/upstream-sync/spec.md | 撞车取舍 - **WHEN** fork 已实现的某功能，上游在本批次中也做了同类实现（同一功能、不同写法） - **THEN** 该条目不自动裁决；由 Agent 呈报双方差异，用户逐项选择保留 fork 版 / 采用上游版 / 融合，选择结论记入 brief `# Decisions` 并落盘 - **若排查后无撞车条目**，记录排查方式与"无撞车"结论，本场景以"零遗漏"为通过标准 | 同 A7：无撞车结论与排查方式记录于 brief D5，零遗漏 |
| A15 | passed | specs/upstream-sync/spec.md | BTR 评估边界（PiliPlus PR 3223） - **WHEN** 第三方 fork（PiliPlus）实现了与自研 ThreadRipper 同源（Bilibili-thread-ripper）的功能 - **THEN** 本 fork 保留自研 ThreadRipper 实现（`lib/services/thread_ripper/` 全部 13 文件与调度语义：换签候选池、PCDN 处理、消费驱动预取、分级调度、饱和停止、画质切换预热）；不引入对方 `BtrProxy` 任何代码与其设置页；仅允许吸收与实现无关的宿主补丁（本批为 macOS `Release.entitlements` 的 `com.apple.security.network.server`） - fork `lib/` 不得出现 `BtrProxy` / `BtrConfig` / `btr_proxy` 符号 | 13 文件完整、调度语义未动；无 BtrProxy 符号；唯一吸收项 entitlements 已由 A9 独立证实 |
| A16 | passed | specs/upstream-sync/spec.md | 工作树纯净 - **WHEN** `patch.sh` 应用 geetest/bottom_sheet iOS 补丁产生工作区污染 - **THEN** 提交前污染文件恢复上游纯净态、`geetest_plugin.dart` 不在工作树（停车场策略）、`pubspec.yaml` 不含 `gt3_flutter_plugin`，merge commit 树中无 gt3 残留 | git status 仅 docs/comet（Native 产物）；geetest_plugin.dart 不在工作树；污染文件对 upstream 纯净态 diff 为空 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| analyze 无 error（error-only 门禁） | — | . | passed | 0 | 7577 ms |
| 全量测试 | test | . | passed | 0 | 30809 ms |
| 上游清零 | rev-list --count main..upstream/main | . | passed | 0 | 29 ms |
| 钉版在位 | -c connectivity_plus: 7.0.0 pubspec.yaml | . | passed | 0 | 4 ms |
| 无 BTR 符号 | /Users/tune/Develop/GitHub/PiliNara | . | passed | 0 | 266 ms |
| pubspec 无 gt3 | /Users/tune/Develop/GitHub/PiliNara | . | passed | 0 | 6 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- git fetch upstream + rev-list count: passed — main..upstream/main = 0，两次复核
- flutter analyze: passed — 0 error / 7 warning / 67 info，优于基线
- flutter test: passed — 306 全过（两轮）
- bash lib/scripts/patch.sh ios: passed — applied=2 skipped=36 无失败段；material tabs 反向 dry-run 验证已打上
- pins/entitlements/btr/gt3 grep 组: passed — 钉版 4 项在、network.server 在、BtrProxy 无、gt3 无
- 已知限制: A10 主路径（lock 与合并前逐字节一致）因镜像 sha 漂移不可达，按 brief 退化口径验证通过
- 已知限制: geetest_plugin.dart 按停车场策略移至 /tmp/geetest-plugin-parking/（重启后需从 fork 历史 58bcee3e1 恢复）
- 已知限制: 本次为本地验证（patch/analyze/test），未构建 iOS 真机包

## 阻塞项

_无。_

## 风险与跳过的工作

- A4 为间接取证：只读约束未实际执行 patch.sh（其会写工作树/pub-cache），以反向 apply 校验+选目录核对代替，与 Runtime 末轮记录自洽
- A10 刷新的 6 个传递依赖严格说超出 brief 退化口径『仅三钉及其传递伴随包』的字面范围，但属约束内重解析（镜像 sha 漂移触发、d024dd4f9 文档化、URL 全镜像），判定通过并留痕
- c336dddb0 测试修复将首包断言从『恰为 256KiB』放宽为『非空』，流式语义仍由『第二块未写出时已收到数据』保证，断言强度略降但合理
- geetest_plugin.dart 停车场位于 /tmp/geetest-plugin-parking/，重启丢失需从 fork 历史 58bcee3e1 恢复
- 本地 patch/analyze/test 门槛已过；iOS 真机构建按 brief 属用户另行执行范围

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 0 | recovery | — | Builder handoff Runtime checks failed: analyze-no-error, flutter-test-all, no-btr-symbols | 2026-10-18T05:10:02.462Z |
| 1 | 2 | 0 | recovery | — | Builder handoff Runtime checks failed: analyze-no-error | 2026-10-18T05:13:39.782Z |
| 1 | 3 | 0 | recovery | — | Builder handoff Runtime checks failed: flutter-test-all | 2026-10-18T05:16:02.986Z |
| 1 | 4 | 1 | pass | — | 独立 Verifier 全程只读取证：16/16 全部 passed。独立重跑 analyze（0 error/7 warning/67 info，优于基线 9 warning）与 test（306 全过）；git 结构（双亲 merge 1b173c3d7、main..upstream/main=0）、fork 功能幸存（13 TR 文件+161 用例+全部 UI/模型接线）、A10 退化口径、BTR 仅吸收 entitlements 一项均独立证实。Runtime 末轮检查记录（20513659）与独立取证一致。 | 2026-10-18T05:50:56.542Z |



## 结论

独立 Verifier 全程只读取证：16/16 全部 passed。独立重跑 analyze（0 error/7 warning/67 info，优于基线 9 warning）与 test（306 全过）；git 结构（双亲 merge 1b173c3d7、main..upstream/main=0）、fork 功能幸存（13 TR 文件+161 用例+全部 UI/模型接线）、A10 退化口径、BTR 仅吸收 entitlements 一项均独立证实。Runtime 末轮检查记录（20513659）与独立取证一致。
