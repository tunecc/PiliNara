# Outcome

将上游 `upstream/main`（Starfallan/PiliNara @ 8d755f16b，本地基线 1807e22ed 之后的 92 个提交）合并进 fork `main`，完整保留 fork 自身更改；凡 fork 更改与上游同类实现撞车的条目，逐项交由用户取舍后落盘。合并产物通过 patch / analyze / test 门槛并保持工作树纯净。

# Scope

- 以 `git merge upstream/main` 合入（与 fork 历史形态一致，均为 merge），解决全部冲突并提交双亲 merge commit。
- 冲突裁决默认原则（沿用 2026-08-30 / 2026-09-10 既定裁决）：上游功能全收；fork 保留项 = iOS 三钉（`connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`）+ `environment.flutter: 3.47.0` + `.fvmrc` 压回 3.47.0 + fork 的 README 差异文档 / iOS 构建文档 / fork CI。
- fork 更改与上游同类实现撞车的冲突（如同一功能双方各写了一版），不自动裁决：整理双方差异与理由后，当面逐项请用户取舍。
- lock 处理：冲突取 ours → 用 fvm 3.47.0 绝对路径 + flutter-io.cn 镜像执行 pub get 重解析 → 与上游 lock 结构化 diff 核对，差异仅剩三钉及其传递伴随包，URL 全为 pub.flutter-io.cn。
- 合并后适配：上游新代码若按 file_picker 13.x API 编写，适配回 beta.7（`saveFile` 返回 `String?`、`pickFiles` 返回 `FilePickerResult?`）；getx resolved-ref 与上游 lock 对齐（当前两边已一致，合并后复核）。
- 验证链：`bash lib/scripts/patch.sh ios`（注意 pub-cache 双目录坑，确保选中 lock 活跃版本目录）→ `fvm flutter analyze` → `fvm flutter test` → gt3 污染还原（geetest_webview_dialog.dart / common_slide_page.dart / mini_scaffold.dart / geetest_plugin.dart 恢复上游纯净态并从暂存区移除，pubspec.yaml 去除 gt3_flutter_plugin 注入，pub get 重生成不含 gt3 的 lock）→ 提交 merge commit。
- 结束前再 `git fetch upstream && git log main..upstream/main` 复核同步期间上游无新增提交；有则按同样原则补合。

## Source coverage

无外部源文档；需求来源为用户本次请求 + 项目记忆 `upstream-sync-workflow`（裁决原则与已知坑）+ 本次实际探测结果（92 个上游提交、冲突文件清单：`.fvmrc`、`README.md`、`lib/pages/mine/controller.dart`、`lib/pages/mine/view.dart`、`lib/pages/video/controller.dart`、`lib/plugin/pl_player/controller.dart`、`pubspec.yaml`、`pubspec.lock`）。

## 目录结构

### 新建

- `docs/comet/changes/sync-upstream-2026-10/`（本 change 正式产物；归档时由 Runtime 移至 `docs/comet/archive/`）
- 合并引入的上游新文件（如 `.github/workflows/win_x64_newlibmpv.yml`、`lib/common/widgets/gesture/image_*_gesture_recognizer.dart` 等，以 merge 树为准）

### 修改

- 合并涉及的 231 个上游改动文件（`git diff HEAD...upstream/main --stat`），重点冲突文件：`pubspec.yaml`、`pubspec.lock`、`.fvmrc`、`README.md`、`lib/pages/mine/controller.dart`、`lib/pages/mine/view.dart`、`lib/pages/video/controller.dart`、`lib/plugin/pl_player/controller.dart`
- fork 保留项按裁决局部回写（三钉、flutter 环境行、.fvmrc、README fork 章节）

### 删除

- 上游已删除而 fork 无保留理由的文件，以 merge 自动结果为准（如上游移除的 `waterfall_flow`、`desktop_webview_window` 依赖引用）

### 明确不建

- 不新增 fork 侧功能文件；不创建发布产物、不创建 PR 分支
- 不修改 `.comet/runtime/` 下任何 Runtime 本机文件

# Non-goals

- 不升级 Flutter 工作区版本（保持 fvm 3.47.0，不跟上游 3.47.7；升级需另行评估 Xcode 16.4 iOS 构建约束）。
- 不推送 origin、不创建 PR、不发布 release（同步完成后由用户另行决定）。
- 不重构/不回移 fork 已有功能实现；仅做上游 API 差异所需的最小适配。
- 不处理不在本次合并范围内的上游分支（`upstream/develop` 等）。

# Acceptance examples

- A1: 合并完成后 `git rev-list --count main..upstream/main` 为 0（同步期间上游若有新推送，补充合入后复核仍为 0）。
- A2: fork 保留项在合并后的 `pubspec.yaml` / `.fvmrc` 中幸存：`connectivity_plus: 7.0.0`、`device_info_plus: 13.0.0`、`file_picker: 12.0.0-beta.7`、`environment.flutter: 3.47.0`、`.fvmrc` 内容为 `{"flutter": "3.47.0"}`。
- A3: 本地 pubspec.lock 与上游 lock 按包名+版本结构化 diff 后，版本差异仅含三钉及其传递伴随包（file_picker_darwin、file_picker_linux、file_picker_web、file_picker_platform_interface、android_file_picker、windows_file_picker 等），且全部 source URL 为 pub.flutter-io.cn。
- A4: `bash lib/scripts/patch.sh ios` 无失败段（material/cupertino 补丁实际打在 lock 活跃版本目录上，`git hash-object <pkgdir>/lib/src/tabs.dart` 与 patch 头 source blob 一致抽验）。
- A5: `fvm flutter analyze` 相对合并前基线不新增 error / warning（项目既有 info 级 lint 允许存在，退出码 1 不作为失败判据，以 issue 分级数比对为准）。
- A6: `fvm flutter test` 全部用例通过。
- A7: 撞车冲突清单零遗漏：Build 过程中双方都实现同类功能的条目（如有）全部经用户逐项取舍，取舍结论记录于本 brief `# Decisions`；如经排查无撞车，记录"无撞车"结论及排查方式。
- A8: 提交树纯净：merge commit 的树中不含 gt3_popup_tool / gt3_flutter_plugin 注入（pubspec.yaml 无 gt3_flutter_plugin、geetest_plugin.dart 不在库中），geetest/bottom_sheet 污染文件与上游纯净态一致。
- A9: 产物为双亲 merge commit（`git cat-file -p <merge>` 恰好两行 parent——ours 与 upstream/main），无因 stash 吞 MERGE_HEAD 退化为单亲。

# Constraints and invariants

- 禁用 `git stash -u`（stash pop 会吞 MERGE_HEADER）；全程不使用 `reset --hard`、force push。
- pub get 必须用 fvm 3.47.0 绝对路径并以 `PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn` 运行。
- 新增测试文件如被 `.gitignore` 的 `test*` 规则忽略，`git add -f` 纳入。
- patch.sh 的 material/cupertino 段选目录时注意 pub-cache 双缓存目录排序坑：确保选中 lock 活跃版本目录（必要时以 pub.flutter-io.cn 目录最新为准），patch 后抽验 source blob hash。
- 上游新代码若依赖 beta.7 不存在的 API（file_picker 13.x 等），适配方向是改调用方代码贴近 beta.7，而不是升级钉版。
- 验证顺序：patch.sh → analyze/test（此时 gt3 在 pubspec 里、geetest_plugin.dart 可解析）→ restore 污染文件 → pub get 重生成 lock → 提交。

# Decisions

- D1 隔离方式 `current`：工作区干净、无其他 active change、无并行诉求，符合 Runtime 默认，无需隔离工作区。
- D2 合并方式 `git merge`（保留 merge 双亲形态），与 fork 历史既有同步形态一致。
- D3 冲突裁决沿用既定原则：上游功能全收；三钉/flutter 3.47.0/.fvmrc/README 差异为 fork 保留项；实现选择（API 适配细节、lock 重解析流程）由 Agent 决定。
- D4 撞车条目（fork 实现的功能上游也实现了）不自动裁决，逐项呈报用户取舍——用户本次明确要求。

# Open questions

（当前无 `[blocking]`。撞车条目若在 Build 中出现，按 D4 即时逐项提问，写作：`- [blocking] C1: <撞车条目>`。）

# Verification expectations

- 命令门槛：A4 patch.sh 成功、A5 analyze 无新增 error/warning、A6 test 全过。
- 结构核对：A1 rev-list 计数、A2 保留项 grep、A3 lock 结构化 diff、A8 gt3 纯净态检查、A9 双亲提交检查。
- 时序完整性：结束前重新 `git fetch upstream` 复核无新增提交。
- 已知限制：项目 analyze 存在存量 info 级 lint（退出码 1 属预期）；DASH 流无 size 字段等历史已知项不因本次合并改变。
