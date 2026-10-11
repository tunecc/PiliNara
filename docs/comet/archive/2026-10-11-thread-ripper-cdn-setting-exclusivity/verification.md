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
- 完成时间: 2026-10-11T10:30:41.778Z
- 摘要: 独立验收 12/12 通过。核心机制核实：pickCdnUrl 新增 bypassCdnPreference 参数，bypass 时（1）跳过全局 customCDNUrl 回退与 baseUrl 早退，（2）mirror 分支直接返回剥离包装后的 playinfo 原始地址，（3）mcdnUpgcxcode 返回剥离包装原始地址；与偏好无关的正确性改写（mcdnTf→proxy-tf、szbdyd→xy_usource、缺失时原样保留）在两种模式一致。设置页两处动态/静态提示与 README 互斥说明均落地。独立运行：exclusivity_test 9/9、回归 179/179、flutter analyze 0 issue、/tmp 独立探针 6/6（含弱断言补强）。verdict=pass，附 2 条低风险备注。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1（旁路节点偏好）：`useThreadRipper = true` 时，无论 `defaultCDNService` / `customCDNUrl` 取什么值，`getCdnUrl` 对官方镜像地址返回 playinfo 原始地址（已剥离 `/v1/resource`），对包装/PCDN 地址返回剥离后的原始地址，绝不出现「节点偏好改写后的地址」。 | pickCdnUrl mirror 分支在 bypassCdnPreference=true 时先于 customHost/defaultCDNService 使用直接 return url（lib/utils/video_utils.dart）；preparedUrls 已剥离 /v1/resource；多地址首个镜像即返回；/tmp 独立探针 PROBE6 证实与 defaultCDNService.baseUrl 组合仍返回原始镜像；播放链路（controller.dart:931/945/1225/1234/1311/1336）传 useThreadRipper:true 且不传 customHost |
| A2 | passed | brief.md | A2（正确性改写保留）：`useThreadRipper = true` 时，无 upgcxcode 的 mcdn 私有传输地址仍改写为 `proxy-tf-all-ws.bilivideo.com?url=`；szbdyd 地址仍按 `xy_usource` 改写。 | mcdnTf 分支无 bypass 条件，末尾 proxy-tf 重建同样无 bypass 条件（exclusivity_test 断言 startsWith proxy-tf 通过）；szbdyd 分支 xy_usource 在 bypass 三元之前优先取值——/tmp 探针 PROBE1/PROBE2 强断言 host 改写为 upos-sz-mirrorali.bilivideo.com，两模式一致；无 xy_usource 时 PROBE3 原样保留不崩溃 |
| A3 | passed | brief.md | A3（关闭时回归）：`useThreadRipper = false` 时，节点偏好改写行为与修复前完全一致（官方镜像按默认/自定义节点改写、包装形态重建为官方镜像剥离路径）。 | exclusivity_test A3 组 3 用例通过（镜像按默认节点改写/自定义节点优先/包装重建剥离路径）；逐行 diff 核对 bypass=false 路径：customHost 回退、baseUrl 早退、镜像改写、mcdnUpgcxcode 重建均以 !bypassCdnPreference 门控，语义与 HEAD 一致；上一 change 的 thread_ripper_getcdnurl_test/candidates_test 在回归中全部通过 |
| A4 | passed | brief.md | A4（设置页提示）：Thread Ripper 开关副标题包含互斥说明；「CDN 设置」条目在线程撕裂者开启时副标题含「不参与选点」提示，关闭时不含。 | video_settings.dart TR 开关副标题含「且「CDN 设置」选定的节点不参与选点（全部节点按速度自动竞速）」；CDN 设置条目 getSubtitle 为动态闭包，Pref.enableThreadRipper 为实时读 box 的 getter（storage_pref.dart:725），开启时追加「线程撕裂者开启中，本设置不参与选点」，关闭时返回原文不含提示 |
| A5 | passed | brief.md | A5（回归）：`flutter test` 全量通过；README 补充互斥说明。 | README Thread Ripper 条目新增「开启期间「CDN 设置」选定的节点不参与选点（全部节点按速度自动竞速），关闭后该设置恢复生效」；全量回归 test/thread_ripper/ + test/utils/ 共 179 用例全部通过 |
| A6 | passed | specs/thread-ripper-cdn-setting-exclusivity/spec.md | 竞速开启时旁路节点偏好 - **WHEN** Thread Ripper 开启（useThreadRipper = true）且播放信息给出官方镜像地址 - **THEN** 返回的兜底地址为 playinfo 原始地址（已剥离 `/v1/resource` 包装），无论默认节点/自定义节点如何设置 | spec Scenario 竞速开启旁路：video_utils.dart mirror 分支 bypass 直接 return url（剥离包装后的 playinfo 原始地址）；探针 PROBE5 证实 os=mcdn 镜像变体同样原样返回 |
| A7 | passed | specs/thread-ripper-cdn-setting-exclusivity/spec.md | 包装与 PCDN 地址返回剥离后的原始地址 - **WHEN** Thread Ripper 开启且 playinfo 地址为 PCDN 包装形态或 `*.edge.mountaintoys.cn` / `*.mcdn.bilivideo.*` 的 upgcxcode 地址 - **THEN** 兜底地址为剥离 `/v1/resource` 前缀后的原始地址（P2P 直连变体），而非改写到某个官方镜像节点 | spec Scenario 包装/PCDN 剥离原始保留：getCdnUrl 将原始 playinfo urls 传入 threadRipperCandidates，list=[fallback,...urls] 保留原始包装 URL，随后对每个 /upgcxcode/ 可替换主机地址追加剥离换签候选；既有 thread_ripper_candidates_test 断言 candidates contains(wrapped) 且 swaps 无 /v1/resource 并铺多节点，回归中通过 |
| A8 | passed | specs/thread-ripper-cdn-setting-exclusivity/spec.md | 竞速关闭时节点偏好照常 - **WHEN** Thread Ripper 关闭（useThreadRipper = false） - **THEN** 默认节点 / 自定义节点的改写行为与本变更前完全一致（官方镜像按所选节点改写、包装形态重建为官方镜像剥离路径） | bypass=false 分支经逐行 diff 核对与 HEAD 零语义差异（?? 括号化等价）；唯一微差在废弃 szbdyd 角落（无 upgcxcode 路径+无 xy_usource+偏好 baseUrl/backupUrl+无自定义 host）：旧代码返回 host:null+port:443 的 URL，新代码 continue 后返回无显式 :443 的同义 URL（探针 PROBE4），功能等价且实际不可达，记入 risks |
| A9 | passed | specs/thread-ripper-cdn-setting-exclusivity/spec.md | 私有传输走代理（两种模式一致） - **WHEN** 地址为裸 IP / `*.mcdn.bilivideo.*` 且 path 为 `/v\d/resource` 且不含 `/upgcxcode/` - **THEN** 无论 Thread Ripper 开关，地址都改写为 `proxy-tf-all-ws.bilivideo.com?url=<原始地址>` | spec Scenario 私有传输走代理：_mCdnTfRegex 分支（mcdnTf=url; continue）与末尾 proxy-tf Uri 重建均无 bypass 条件，两种模式行为一致；normalizeUpgcxcodeUri 的 /v1/resource 剥离带 (?=/upgcxcode/) 前瞻，私有传输路径保留故正则仍命中 |
| A10 | passed | specs/thread-ripper-cdn-setting-exclusivity/spec.md | szbdyd 按真实主机改写（两种模式一致） - **WHEN** 地址包含 szbdyd.com 且带 `xy_usource` 参数 - **THEN** 无论 Thread Ripper 开关，地址都改写到 `xy_usource` 指定的真实主机 | spec Scenario szbdyd 改写：xy_usource 优先于 bypass 三元（探针 PROBE1/2 两模式均改写真实主机）；旁路缺失 xy_usource 时 hostname==null continue，URL 原样保留不崩溃（探针 PROBE3） |
| A11 | passed | specs/thread-ripper-cdn-setting-exclusivity/spec.md | 竞速开关说明互斥 - **WHEN** 用户查看「Thread Ripper（多 CDN 并发下载）」开关 - **THEN** 副标题说明开启后 CDN 节点偏好设置不参与选点、全部节点按速度自动竞速 | spec Scenario 竞速开关说明：SwitchModel(title: 'Thread Ripper（多 CDN 并发下载）', setKey: enableThreadRipper) 副标题静态文本含「「CDN 设置」选定的节点不参与选点（全部节点按速度自动竞速）」，覆盖不参与选点+自动竞速两点 |
| A12 | passed | specs/thread-ripper-cdn-setting-exclusivity/spec.md | CDN 设置条目动态提示 - **WHEN** 线程撕裂者已开启，用户查看「CDN 设置」条目 - **THEN** 副标题提示节点偏好当前不参与选点；线程撕裂者关闭时不含该提示 | spec Scenario CDN 条目动态提示：getSubtitle 闭包内读 Pref.enableThreadRipper 动态分支，开启时追加「本设置不参与选点」，关闭时不含该提示 |

## 检查

_没有记录 Runtime 检查。_

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- 已知限制: 设置页提示在设置列表重建时刷新（SwitchModel 切换后依赖页面重建机制，与同页其他动态 getSubtitle 行为一致）
- 已知限制: 旁路仅作用于媒体选点：mcdnTf/szbdyd 的正确性改写保留（spec 明确）

## 阻塞项

_无。_

## 风险与跳过的工作

- A8 微差（低）：废弃 szbdyd URL（无 /upgcxcode/ 路径且无 xy_usource）在偏好为 baseUrl/backupUrl 且无自定义 host 时，旧实现返回显式 :443 端口 URL，新实现 continue 后返回隐式 443 的等价 URL；真实播放信息中 szbdyd 地址几乎必含 upgcxcode 路径（该分支本就不可达），无用户可见影响
- 测试强度（低）：exclusivity_test 中「szbdyd 按 xy_usource 改写」用 contains() 断言，查询参数含该主机名时平凡通过；已用 /tmp 独立探针以 startsWith 真实主机强断言补证通过；szbdyd 含 /upgcxcode/ 路径时两种模式都走 mcdnUpgcxcode 分支而非 szbdyd 分支（上一 change 既定顺序，本次未改动）

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | 独立验收 12/12 通过。核心机制核实：pickCdnUrl 新增 bypassCdnPreference 参数，bypass 时（1）跳过全局 customCDNUrl 回退与 baseUrl 早退，（2）mirror 分支直接返回剥离包装后的 playinfo 原始地址，（3）mcdnUpgcxcode 返回剥离包装原始地址；与偏好无关的正确性改写（mcdnTf→proxy-tf、szbdyd→xy_usource、缺失时原样保留）在两种模式一致。设置页两处动态/静态提示与 README 互斥说明均落地。独立运行：exclusivity_test 9/9、回归 179/179、flutter analyze 0 issue、/tmp 独立探针 6/6（含弱断言补强）。verdict=pass，附 2 条低风险备注。 | 2026-10-11T10:30:41.778Z |



## 结论

独立验收 12/12 通过。核心机制核实：pickCdnUrl 新增 bypassCdnPreference 参数，bypass 时（1）跳过全局 customCDNUrl 回退与 baseUrl 早退，（2）mirror 分支直接返回剥离包装后的 playinfo 原始地址，（3）mcdnUpgcxcode 返回剥离包装原始地址；与偏好无关的正确性改写（mcdnTf→proxy-tf、szbdyd→xy_usource、缺失时原样保留）在两种模式一致。设置页两处动态/静态提示与 README 互斥说明均落地。独立运行：exclusivity_test 9/9、回归 179/179、flutter analyze 0 issue、/tmp 独立探针 6/6（含弱断言补强）。verdict=pass，附 2 条低风险备注。
