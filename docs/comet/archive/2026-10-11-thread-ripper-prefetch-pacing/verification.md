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
- 完成时间: 2026-10-11T11:50:15.325Z
- 摘要: 独立验收 10/10 通过，verdict=pass。实测：pacing_test 2/2；fvm flutter test 全量 273 通过（exit 0）；fvm flutter analyze（thread_ripper 全目录+video_utils+video_settings）0 issue。核心实现逐行核验：A1 serve 钳制 8MiB（替代 64MiB）；A2 消费驱动续棒（_continueChain 门控+noteConsumed 水位+tick 重试）三段断言真实；A3 _complete 门控前 flush 解决尾部滞留、attach/_emitFromJob 绝对偏移发射无跨棒错位（startRel<0 防御性抛错）；A4 filterPcdnCandidates 四类处理与 rewritePlayable 兜底/键接线正确；A5 开关关闭逐字回归旧行为；A6 analyze 0 issue+全量通过。链路传递（serve→_jobParams→JobParams→Job→_complete 链式重建）与清理（_giveUp/_stop onCancel/dispose 对 _pendingSuccessor/_successorParams/_consumedByFile）完整；nativeRetry/registry 以 effectiveFallback 为键内部自洽，registry-miss 透传目标改为官方镜像属改进。主要风险：PCDN 过滤无专项单测（brief 范围项部分未落地）；单槽 pending 在双链并发挂起的罕见场景可能覆盖丢链。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1（首棒钳制）：总大小 200MiB 的 descriptor 收到 `bytes=0-`，serve 后第一个上游请求区间为 `[0, 8MiB-1]`（不再是 64MiB）。 | 独立核验：scheduler.dart serve 将超长/开放末端请求钳制到 first+8MiB-1（openEndedLegBytes 取代 64MiB maxServedLength），AcceleratedResponse.last 仍报完整请求末端。pacing_test A1 实测通过：200MiB 描述符收 bytes=0- 后上游请求恰为 4 片覆盖 [0, 8MiB-1]（0-2MiB-1/2-4/4-6/6-8MiB），response.last=200MiB-1。断言真实、非自证。 |
| A2 | passed | brief.md | A2（消费驱动续棒）：模拟消费水位推进（经消费回调上报），水位 + 4MiB 提前量未达下一棒起点时不出现后续上游请求；推进越过阈值后下一棒请求出现。 | 独立核验：_continueChain 仅当 consumed+4MiB 提前量 >= next.range.first 才 _start，否则挂 _pendingSuccessor；noteConsumed 单调水位+即时 flush，tick 每 50ms 重试挂起棒，无上游请求。pacing_test A2 三段断言核实真实：第一棒完成且水位 0 时 leg2 请求数=0；noteConsumed(4MiB) 后 leg2 出现；第二棒完成且水位未推进时 leg3 保持 0 请求；noteConsumed(12MiB) 后 leg3 启动。生产接线：proxy _serveAccelerated 每 chunk 上报 delivered 绝对偏移经 AcceleratedResponse.onConsumed→noteConsumed(fileKey=descriptor.originalUrl)；播放器暂停时 response.flush() 背压使水位停滞，不预取。 |
| A3 | passed | brief.md | A3（流连续）：跨棒流式输出字节连续无重叠无缺口，总长度等于已服务区间；206 Content-Range 报告完整请求区间。 | 独立核验流连续性：_complete 在门控判定前 sink.flush(job) 冲刷末次跳过 progress 的尾部字节——挂起场景下尾部字节不再滞留 sink，消费水位精确到棒末端，不存在尾部滞留导致的死锁；attach() 先冲刷上一棒再切换，续棒以 _requestFirst 绝对偏移发射（startRel=_emitted-jobStartOffset，正常为 0），startRel<0 抛 StateError 防跨棒错位；_contiguous 封顶 job.length 防重叠。pacing_test A2 末段实测三棒累计 24MiB 无 errors 无缺口、流保持打开。206 Content-Range 由 proxy 以 accelerated.first/last（完整请求区间）+total 构造。 |
| A4 | passed | brief.md | A4（PCDN 默认排除）：`threadRipperBlockPcdn = true`（默认）时，mountaintoys/mcdn 的直连地址不出现在 descriptor 候选中，官方镜像换签候选保留；无 upgcxcode 的 mcdnTf 地址被改写为 proxy-tf 形式；szbdyd 地址被改写为 xy_usource 主机。 | 独立核验 filterPcdnCandidates+rewritePlayable 接线：非 P2P 主机（官方镜像及换签候选）原样保留；P2P+upgcxcode（mcdnUpgcxcode：edge.mountaintoys.cn/.mcdn.bilivideo/mirror14b/302* 形态）落入 default 分支丢弃；mcdnTf（无 upgcxcode 的 /v1/resource 私有传输）改写 https://proxy-tf-all-ws.bilivideo.com/?url=<orig>（与 video_utils._proxyTf 同主机）；szbdyd 改写 xy_usource 真实主机（缺参丢弃）。兜底被过滤时取首个幸存候选（候选耗尽则保留原兜底安全降级）；effectiveFallback 贯穿 descriptor.originalUrl/_tokenByFile/_probeTotal/_learnTotal 与 registry-miss 透传，键一致。classify_test 对 mountaintoys/szbdyd/mcdnUpgcxcode 的分类断言在全量套件中执行通过，锚定过滤前提。注：无专项单测（见 risks）。 |
| A5 | passed | brief.md | A5（开关关闭回归）：`threadRipperBlockPcdn = false` 时 PCDN 直连候选恢复参与（上一 change 行为）。 | 独立核验：Pref.threadRipperBlockPcdn 默认 true（storage_pref defaultValue:true + SwitchModel defaultVal:true）；为 false 时整个过滤分支跳过，effectiveCandidates/effectiveFallback 等于原始输入，候选构造与改动前代码逐字一致（对照 git diff 删除行），PCDN 直连恢复参与竞速。 |
| A6 | passed | brief.md | A6（回归）：`flutter analyze` 无问题；`flutter test` 全量通过。 | 实测：fvm flutter test 全量 273 项全部通过（exit 0，含 thread_ripper 13 个文件与 utils 回归）；fvm flutter analyze lib/services/thread_ripper lib/utils/video_utils.dart lib/pages/setting/models/video_settings.dart 报 No issues found。scheduler_test A6 已重写为 8MiB 棒长+消费门控（水位 0 无续棒、noteConsumed(4MiB) 后 leg2 区间 8388608-9437183 出现）。 |
| A7 | passed | specs/thread-ripper-prefetch-pacing/spec.md | 首棒钳制 - **WHEN** descriptor 总大小已知且代理收到开放末端或超长 Range 请求 - **THEN** 第一棒服务区间为 `[first, min(first + 8MiB - 1, 请求末端)]`，206 Content-Range 报告完整请求区间 | spec 首棒钳制 = A1：serve 仅当请求跨度 > 8MiB 才钳制，等价 [first, min(first+8MiB-1, 请求末端)]；有界短 Range 不受影响；Content-Range 报完整请求区间。与 spec Scenario 逐字一致。 |
| A8 | passed | specs/thread-ripper-prefetch-pacing/spec.md | 消费驱动续棒 - **WHEN** 当前棒完成且消费水位 + 4MiB 提前量未达下一棒起点 - **THEN** 下一棒挂起，不产生上游请求；消费水位推进越过阈值后下一棒自动启动 - **WHEN** 播放器暂停消费（水位长期不动） - **THEN** 不再预取（挂起保持），不占带宽 | spec 消费驱动续棒 = A2：完成时水位+4MiB 未达下一棒起点即挂起且不产生上游请求；noteConsumed/tick 双路径自动启动；水位长期不动则挂起保持、不占带宽（无在途请求，仅参数暂存）。与 spec 一致。 |
| A9 | passed | specs/thread-ripper-prefetch-pacing/spec.md | 流连续性 - **WHEN** 跨棒交付 - **THEN** 字节连续无重叠无缺口，总长度等于已服务区间；消费落后时字节暂存待发，不丢不乱 | spec 流连续性 = A3：跨棒字节连续无重叠无缺口、总长度=已服务区间、消费落后时字节暂存待发（sink 缓冲未发射字节，attach/flush 冲刷）不丢不乱。与 spec 一致。 |
| A10 | passed | specs/thread-ripper-prefetch-pacing/spec.md | 直连地址默认排除（Scenario: 开关关闭恢复） - **WHEN** 屏蔽开关为默认开启，候选含 PCDN 直连地址（mountaintoys/mcdn 的 upgcxcode 地址、裸形态） - **THEN** upgcxcode 形态的 PCDN 地址从候选中移除（其换签候选保留官方镜像可达性）；无 upgcxcode 的 mcdn 私有传输改写为 proxy-tf 代理形式；szbdyd 改写为 `xy_usource` 真实主机；兜底地址若被排除则取首个幸存候选 - **WHEN** 用户关闭屏蔽开关 - **THEN** PCDN 直连候选恢复参与竞速（上一行为） | spec 直连默认排除 = A4：默认开启时 upgcxcode 形态 PCDN 移除、mcdn 私有传输改 proxy-tf、szbdyd 改 xy_usource、兜底被排除取首个幸存候选；关闭开关恢复参与（A5）。与 spec 一致。 |

## 检查

_没有记录 Runtime 检查。_

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- 已知限制: mpv 缓冲指示被 cache-secs=16s/demuxer-max-bytes=4MiB 配置封顶：预取节省的流量不会转化为可见进度（播放器机制，brief 非目标）
- 已知限制: PCDN 排除后若 playinfo 仅含 PCDN 地址，候选为官方镜像换签（签名通用已实测）；无镜像可达的极端场景回退透传
- 已知限制: 消费水位由代理 flush 驱动，粒度为网络块级（非字节级），提前量 4MiB 覆盖该粒度

## 阻塞项

_无。_

## 风险与跳过的工作

- filterPcdnCandidates 与开关行为无专项单测：brief 范围列有「PCDN 过滤、开关回归用例」，任务包所述 test/thread_ripper/pcdn_filter_test.dart 实际不存在，test/ 下亦无 filterPcdnCandidates 引用；本次经源码审阅+既有 classify_test 锚定验证通过，但后续回归无防护，建议补测。
- _pendingSuccessor 为会话级单槽：若同一会话两条开放末端链同时挂起，第二条 pend 覆盖第一条；若第一条 sink 未被播放器取消（mpv seek 通常先 abort 旧流触发 onCancel 清槽，故罕见），该链流将永久挂起无数据无 error。改动前 _complete 总是立即续棒，无此回退面。
- JobParams.sourceCandidates 只写不读（死字段，链式重建实际只用 descriptor+chainRequestLast）；_fileByToken 同为只写不读（改动前已如此，非本次引入）。
- preloadOtherQualities 组装预热 descriptor 不经 rewritePlayable/PCDN 过滤，预热候选可含 PCDN；影响限于 init/index 小段且受 warmupCap=4 有界。
- proxy 的 onConsumed 在 await response.flush() 之前调用，水位为已写入 socket 而非 flush 完成，最多领先一个 socket 缓冲，远小于 4MiB 提前量，不影响门控语义；与代码注释措辞略有出入。
- mpv 缓冲指示封顶（cache-secs/demuxer-max-bytes）按 brief 明确不建项未改，缓冲进度观感仍受播放器机制限制。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | 独立验收 10/10 通过，verdict=pass。实测：pacing_test 2/2；fvm flutter test 全量 273 通过（exit 0）；fvm flutter analyze（thread_ripper 全目录+video_utils+video_settings）0 issue。核心实现逐行核验：A1 serve 钳制 8MiB（替代 64MiB）；A2 消费驱动续棒（_continueChain 门控+noteConsumed 水位+tick 重试）三段断言真实；A3 _complete 门控前 flush 解决尾部滞留、attach/_emitFromJob 绝对偏移发射无跨棒错位（startRel<0 防御性抛错）；A4 filterPcdnCandidates 四类处理与 rewritePlayable 兜底/键接线正确；A5 开关关闭逐字回归旧行为；A6 analyze 0 issue+全量通过。链路传递（serve→_jobParams→JobParams→Job→_complete 链式重建）与清理（_giveUp/_stop onCancel/dispose 对 _pendingSuccessor/_successorParams/_consumedByFile）完整；nativeRetry/registry 以 effectiveFallback 为键内部自洽，registry-miss 透传目标改为官方镜像属改进。主要风险：PCDN 过滤无专项单测（brief 范围项部分未落地）；单槽 pending 在双链并发挂起的罕见场景可能覆盖丢链。 | 2026-10-11T11:50:15.325Z |



## 结论

独立验收 10/10 通过，verdict=pass。实测：pacing_test 2/2；fvm flutter test 全量 273 通过（exit 0）；fvm flutter analyze（thread_ripper 全目录+video_utils+video_settings）0 issue。核心实现逐行核验：A1 serve 钳制 8MiB（替代 64MiB）；A2 消费驱动续棒（_continueChain 门控+noteConsumed 水位+tick 重试）三段断言真实；A3 _complete 门控前 flush 解决尾部滞留、attach/_emitFromJob 绝对偏移发射无跨棒错位（startRel<0 防御性抛错）；A4 filterPcdnCandidates 四类处理与 rewritePlayable 兜底/键接线正确；A5 开关关闭逐字回归旧行为；A6 analyze 0 issue+全量通过。链路传递（serve→_jobParams→JobParams→Job→_complete 链式重建）与清理（_giveUp/_stop onCancel/dispose 对 _pendingSuccessor/_successorParams/_consumedByFile）完整；nativeRetry/registry 以 effectiveFallback 为键内部自洽，registry-miss 透传目标改为官方镜像属改进。主要风险：PCDN 过滤无专项单测（brief 范围项部分未落地）；单槽 pending 在双链并发挂起的罕见场景可能覆盖丢链。
