# 同步上游后的 fork 行为契约（sync-upstream-2026-10）

## Capability: upstream-sync

本 spec 描述本次合并完成后 fork `main` 的整体行为契约。它不重复上游 2.1.6 的逐项功能清单（以 `git log 1807e22ed..8d755f16b` 为准），只规定合并的裁决规则与结果不变量。

### Scenario: 上游功能全收

- **WHEN** 上游新增或修改了功能实现，且 fork 对同一代码位置没有自己的更改或更改可与之共存
- **THEN** 合并结果采用上游实现，fork 不保留旧实现

### Scenario: fork 保留项不被上游覆盖

- **WHEN** 合并涉及以下 fork 钉定或差异文件
- **THEN** 合并后须满足：
  - `pubspec.yaml`: `connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`、`environment.flutter: 3.47.0`
  - `.fvmrc`: `{"flutter": "3.47.0"}`
  - README.md 保留 fork 差异文档章节（线程撕裂者、双击预览、画质屏蔽、作者专属倍速、iOS 构建指引）
  - fork 的 iOS 构建脚本（lib/scripts/patch.sh、BUILD_IOS.md）不被删除

### Scenario: 上游 API 差异适配

- **WHEN** 上游新代码按 file_picker 13.x / 其他已升级依赖的新 API 编写，而 fork 因三钉保留旧版依赖
- **THEN** 修改调用方代码适配 fork 钉版 API（不改钉版本身），适配不改变用户可见行为

### Scenario: 撞车取舍

- **WHEN** fork 已实现的某功能，上游在本批次中也做了同类实现（同一功能、不同写法）
- **THEN** 该条目不自动裁决；由 Agent 呈报双方差异，用户逐项选择保留 fork 版 / 采用上游版 / 融合，选择结论记入 brief `# Decisions` 并落盘
- **若排查后无撞车条目**，记录排查方式与"无撞车"结论，本场景以"零遗漏"为通过标准

### Scenario: 工作树纯净

- **WHEN** patch.sh 应用 geetest/bottom_sheet iOS 补丁产生工作区污染
- **THEN** 提交前污染文件恢复上游纯净态、`geetest_plugin.dart` 保持 untracked、`pubspec.yaml` 不含 `gt3_flutter_plugin`，merge commit 树中无 gt3 残留
