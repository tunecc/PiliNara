# 同步上游后的 fork 行为契约（sync-upstream-2026-10-18）

## Capability: upstream-sync

本 spec 描述本次合并完成后 fork `main` 的整体行为契约。它不重复上游本批（`git log 8d755f16b..b908eccfb`，18 个非 merge 提交：仅 WiFi 自动播放、离线缓存三层结构、手动文件夹分层、画质模型重构、键盘倍速步进、番剧分享链接修复、弹幕权重过滤、Linux 托盘修复等）的逐项功能清单，只规定合并的裁决规则与结果不变量。

### Scenario: 上游功能全收

- **WHEN** 上游新增或修改了功能实现，且 fork 对同一代码位置没有自己的更改或更改可与之共存
- **THEN** 合并结果采用上游实现，fork 不保留旧实现；上游新增文件（如 `lib/scripts/newlibmpv.patch`）随合并进入 fork 树

### Scenario: fork 保留项不被上游覆盖

- **WHEN** 合并涉及以下 fork 钉定或差异文件
- **THEN** 合并后须满足：
  - `pubspec.yaml`: `connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`、`environment.flutter: 3.47.0`
  - `.fvmrc`: `{"flutter": "3.47.0"}`
  - README.md 保留 fork 差异文档章节（线程撕裂者、双击预览、画质屏蔽、作者专属倍速、iOS 构建指引）
  - fork 的 iOS 构建脚本（`lib/scripts/patch.sh`、`BUILD_IOS.md`）与 `sync_upstream_build.yml` 不被删除
  - fork 已裁剪的上游 workflow（`linux_x64.yml`、`win_x64_newlibmpv.yml`、`android.yml`、`build.yml`、`debug_android.yml`、`debug_build.yml`、`mac.yml`、`win_x64.yml`）保持删除，即使上游在其删除后继续修改（delete/modify 冲突取删除侧）
  - fork 增强版 `ios.yml`（`ref` / `artifact_name` / `file_suffix` 输入）幸存，不回退为上游精简版

### Scenario: 上游 API 差异适配

- **WHEN** 上游重构了公共 API（本批：`VideoQuality` / `LiveQuality` / `AudioQuality` enum→class、`Dash.fromJson(json, supportFormats)`、`findAvailableVideoQuality` 收窄签名、`LiveQuality.fromCode` 非空化），而 fork 功能调用点建立在旧 API 上
- **THEN** 修改 fork 调用方代码适配新 API，fork 功能的用户可见行为保持不变（屏蔽画质的选择/兜底/菜单过滤、作者专属倍速的套用/回退、ThreadRipper 的 bandWidth/indexEnd 传递）；适配不删除 fork 功能、不改钉版依赖

### Scenario: 撞车取舍

- **WHEN** fork 已实现的某功能，上游在本批次中也做了同类实现（同一功能、不同写法）
- **THEN** 该条目不自动裁决；由 Agent 呈报双方差异，用户逐项选择保留 fork 版 / 采用上游版 / 融合，选择结论记入 brief `# Decisions` 并落盘
- **若排查后无撞车条目**，记录排查方式与"无撞车"结论，本场景以"零遗漏"为通过标准

### Scenario: BTR 评估边界（PiliPlus PR 3223）

- **WHEN** 第三方 fork（PiliPlus）实现了与自研 ThreadRipper 同源（Bilibili-thread-ripper）的功能
- **THEN** 本 fork 保留自研 ThreadRipper 实现（`lib/services/thread_ripper/` 全部 13 文件与调度语义：换签候选池、PCDN 处理、消费驱动预取、分级调度、饱和停止、画质切换预热）；不引入对方 `BtrProxy` 任何代码与其设置页；仅允许吸收与实现无关的宿主补丁（本批为 macOS `Release.entitlements` 的 `com.apple.security.network.server`）
- fork `lib/` 不得出现 `BtrProxy` / `BtrConfig` / `btr_proxy` 符号

### Scenario: 工作树纯净

- **WHEN** `patch.sh` 应用 geetest/bottom_sheet iOS 补丁产生工作区污染
- **THEN** 提交前污染文件恢复上游纯净态、`geetest_plugin.dart` 不在工作树（停车场策略）、`pubspec.yaml` 不含 `gt3_flutter_plugin`，merge commit 树中无 gt3 残留
