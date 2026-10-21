# 同步上游后的 fork 行为契约（sync-upstream-2026-10-21）

## Capability: upstream-sync

本 spec 描述本次合并完成后 fork `main` 的整体行为契约。它不重复上游本批（`git log b908eccfb..e52ad34a5`，34 个非 merge 提交：设置页拆分、导出/导入设置与全量数据 zip、评论过滤统一页、回复过滤/屏蔽、直播缓冲独立设置、缓存视频可选音质、会员主页重构、opus 合集、依赖升级、画质选择逻辑抽到 `VideoUtils` 等）的逐项功能清单，只规定合并的裁决规则与结果不变量。

### Scenario: 上游功能全收

- **WHEN** 上游在 `b908eccfb..e52ad34a5` 范围内新增或修改了功能实现，且 fork 对同一代码位置没有自己的更改或更改可与之共存
- **THEN** 合并结果采用上游实现，fork 不保留旧实现；上游新增文件（如 `config_archive.dart`、`dm_settings.dart`、member_opus 组件与 3 个新增测试）随合并进入 fork 树；上游对设置页的拆分结构（`extra_settings.dart` 内容迁出到 play/dm/dyn 等设置）被完整接受

### Scenario: fork 保留项不被上游覆盖

- **WHEN** 合并涉及以下 fork 钉定或差异文件
- **THEN** 合并后须满足：
  - `pubspec.yaml`: `connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`、`environment.flutter: 3.47.0`
  - `.fvmrc`: `{"flutter": "3.47.0"}`
  - README.md 保留 fork 差异文档章节（线程撕裂者、双击预览、画质屏蔽、作者专属倍速、iOS 构建指引）
  - fork 的 iOS 构建脚本（`lib/scripts/patch.sh`、`BUILD_IOS.md`）与 `sync_upstream_build.yml` 不被删除
  - fork 已裁剪的上游 workflow（`linux_x64.yml`、`win_x64_newlibmpv.yml`、`android.yml`、`build.yml`、`debug_android.yml`、`debug_build.yml`、`mac.yml`、`win_x64.yml`）保持删除，即使上游在其删除后继续修改
  - fork 增强版 `ios.yml`（`ref` / `artifact_name` / `file_suffix` 输入）幸存，不回退为上游精简版

### Scenario: 上游 API 重构适配

- **WHEN** 上游重构了画质/音质选择 API（本批：`PlayUrlModel.findAvailableVideoQuality` 被移除，选择逻辑迁入 `VideoUtils.findTargetVideo` / `findTargetAudio`，`acceptQuality` 与 `Dash` 列表成为入参），而 fork 的屏蔽画质调用点建立在旧 API 上
- **THEN** 修改 fork 调用方与 `VideoUtils` 以适配新 API：屏蔽画质的候选剔除、剔空回退、最高档被屏蔽时的降档、目标画质无流兜底与菜单过滤行为保持不变；fork 的 ThreadRipper URL 改写参数（`useThreadRipper` / `mimeType` / `bandWidth` / `indexEnd`）继续传入；适配不删除 fork 功能、不改钉版依赖

### Scenario: 撞车取舍

- **WHEN** fork 已实现的某功能，上游在本批次中也做了同类实现（同一功能、不同写法）
- **THEN** 该条目不自动裁决；由 Agent 呈报双方差异，用户逐项选择保留 fork 版 / 采用上游版 / 融合，选择结论记入 brief `# Decisions` 并落盘
- **若排查后无撞车条目**，记录排查方式与“无撞车”结论，本场景以“零遗漏”为通过标准

### Scenario: 依赖刷新与钉版共存

- **WHEN** 上游本批升级了 `pubspec.lock`（media-kit 及 15 个兼容包），而 fork 维护三钉与镜像 URL
- **THEN** 合并后的 lock 采用上游的版本升级（含 `material_ui 1.8.0`、`cupertino_ui 1.1.4` 等），三钉保持钉定版本；所有 hosted 依赖 URL 为 `pub.flutter-io.cn`，无 `pub.dev`；lock 与上游的剩余差异仅来自三钉及其传递约束，并可逐项解释；iOS 补丁脚本在升级后的包版本上仍可应用

### Scenario: 工作树纯净

- **WHEN** `patch.sh` 应用 geetest / bottom_sheet iOS 补丁产生工作区污染
- **THEN** 提交前污染文件恢复上游纯净态、`geetest_plugin.dart` 不在工作树（停车场策略）、`pubspec.yaml` 不含 `gt3_flutter_plugin`，merge commit 树中无 gt3 残留
