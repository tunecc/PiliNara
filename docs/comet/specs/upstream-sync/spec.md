# 同步上游后的 fork 行为契约（sync-upstream-2026-10-25）

## Capability: upstream-sync

本 spec 描述本次合并完成后 fork `main` 的整体行为契约。上游本批为 `git log e52ad34a5..b5694ccda`，共 3 个非 merge 提交：关键词过滤改为列表项逐项编译、下载队列杀进程后续传修复、总控 workflow 调用 NewLibmpv Windows 构建。本 spec 不逐条复述上游实现，只规定合并的裁决规则与结果不变量。

### Scenario: 上游缺陷修复全收

- **WHEN** 上游在 `e52ad34a5..b5694ccda` 范围内修改缺陷修复代码，且 fork 对这些文件没有自己的更改或更改可与之共存
- **THEN** 合并结果完整采用上游修复：
  - 关键词过滤按列表项逐项编译，命中任一即过滤；`Pref.parseBanWordItems` 是唯一解析入口，`Pref.compileBanWord` 对每一项独立编译且单项非法只跳过该项；`Pref.parseBanWordToRegex` 不再存在，仓库内无残留调用点；`RegExpListMatch.hasMatch` 供四个过滤器使用；`ListEditorDialog` 对非法行给出 `patternValidator` 与行内 `errorText`。
  - 下载队列在进程被杀死后，等待中条目可继续下载；点击条件为 `canActInPlace = isCompleted || onDelete != null`；队列项长按进入多选并勾中该条，分P 页列表（不传 `onDelete`）保持点击播放。

### Scenario: 已裁剪 CI 保持删除

- **WHEN** 上游修改了 fork 已裁剪删除的 workflow 文件（本批：`.github/workflows/build.yml` 新增 `build_win_x64_newlibmpv` 开关与 `win_x64_newlibmpv` job）
- **THEN** 合并后 `.github/workflows/build.yml` 仍不存在，`win_x64.yml`、`win_x64_newlibmpv.yml` 等 8 个已裁剪 workflow 均不恢复；fork 自有的 `sync_upstream_build.yml` 与增强版 `ios.yml`（`ref` / `artifact_name` / `file_suffix` 输入）不被修改或回退。

### Scenario: fork 保留项与自有功能不受影响

- **WHEN** 合并涉及 fork 钉定文件、CI 差异或六项自有功能所在的代码区域
- **THEN** 合并后须满足：
  - `pubspec.yaml` 保持 `connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`、`environment.flutter: 3.47.0`；`.fvmrc` 为 `{"flutter": "3.47.0"}`
  - README 的 fork 差异章节、`BUILD_IOS.md`、`lib/scripts/patch.sh` 保留
  - ThreadRipper、屏蔽画质、双击区域调整与预览、两指轻点暂停、作者专属倍速、会员视频本地筛选的入口、配置项与行为不变
  - `lib/utils/storage_pref.dart` 同时包含上游 ban-word API 与 fork 新增 Pref（`blockedVideoQualities`、`enableThreadRipper` / `threadRipperBlockPcdn`、`doubleTap*`、`enableTwoFingerTapPause`、`authorPlaySpeeds`），无重复定义、无调用点遗漏

### Scenario: 撞车取舍

- **WHEN** fork 已实现的某功能，上游在本批次中也做了同类实现（同一功能、不同写法）
- **THEN** 该条目不自动裁决；由 Agent 呈报双方差异，用户逐项选择保留 fork 版 / 采用上游版 / 融合，选择结论记入 brief `# Decisions` 并落盘
- **若排查后无撞车条目**，记录排查方式与“无撞车”结论，本场景以“零遗漏”为通过标准

### Scenario: 合并形态与工作树纯净

- **WHEN** 本次同步合并提交并完成本地验证
- **THEN** merge commit 恰好两行 parent（合并前 `main` 与 `upstream/main`），重新 fetch 后 `git rev-list --count HEAD..upstream/main` 为 0；`flutter analyze` 相对合并前基线不新增 error / warning，`flutter test` 全部通过；若执行过 `patch.sh`，bottom_sheet / geetest 补丁污染文件在提交前已还原，`geetest_plugin.dart` 不在工作树，提交内容仅包含本 change 的实现与正式产物。
