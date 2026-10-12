---
generated_from_state_version: 26
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 3
- 迭代: 6
- 验证器尝试次数: 1
- 完成时间: 2026-10-12T01:00:26.661Z
- 摘要: 16/16 通过。四项 Builder 自报均经读码独立核实成立：A6 重写在有/无修复两向算术上均有鉴别力（2 vs 4 片、0 vs ≥4 第二棒）；_pieceGated 中间态断言区分片级与 job 级门控；代理侧 A7 以 consumedReports>1 鉴别 16ms 时间下界；seek 注释关于对齐/删除等价的陈述与 noteConsumed(??0 守卫)和 _continueChain 绝对比较相符。测试 159/159、scoped analyze 无问题均为本人重跑结果，未修改任何项目文件。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1（TTFB 超时）：片 0 的 attempt 模拟 headers 永不完成 → TTFB 超阈值且存在替代主机时被 abort 并由替代主机接管；无替代主机时保留等待（单测）。 | scheduler_test.dart:802/829 双向单测：有替代主机时 ttfbSoft×0.85×2=2040ms 处 abort(connectFail) 并由 hC 接管；单主机 3000ms<jobStallMs(8000) 保留等待。实现 scheduler.dart:1668-1681 将 ttfbOver 判定置于 firstByteAt==0 早退之前，media_transport_dio.dart 增加 receiveTimeout=12s 传输层兜底 |
| A2 | passed | brief.md | A2（片 0 优先）：serve 后首个上游请求为片 0（其余片在片 0 推进超过阈值后才启动）；mpv 收到的首字节时间不再受其余片竞争影响（单测断言启动顺序）。 | pacing_test.dart:109-132 断言首个上游请求 start==0、水位 0 时仅放行片 0/1（2MiB margin）、首棒钳制 8MiB；有序队列 + _pieceGated 使片 0 必然最先启动 |
| A3 | passed | brief.md | A3（片级消费门控）：消费水位落后超过 margin 时，未启动的片不 launch；水位推进后继续（单测：8MiB 棒模拟消费停滞 → 上游请求停止增长）。 | pacing_test.dart:150-179：水位 0 挡片 2/3，水位 2MiB 放行片 2、片 3 仍挡（中间态断言）；scheduler_test A6 零消费补完后无新请求。_pieceGated（scheduler.dart:1583-1587）按 seg.start-base>ahead+2MiB 判定 |
| A4 | passed | brief.md | A4（hedge 门修复）：bandWidth 缺失（requiredRate=0）时投机复制以典型速率为基准受抑制；bandWidth 正常时行为不变（单测）。 | scheduler_test.dart:626-658：requiredRate=0 时 1B/ms 允许复制（无回退则 1>=0 恒抑制、断言失败）、baseline 0.1 使判定翻转（基准值真实参与）、requiredRate 存在时忽略 baseline。实现 scheduler.dart:265-273，两处调用点(1103/1862)传 typicalSpeed.rate |
| A5 | passed | brief.md | A5（deadline 适配）：链式棒的 relief 触发频率随棒长适配——deadline 按 max(1500ms, 棒长/requiredRate) 计算（单测）。 | scheduler_test.dart:856-886 直测 Job.deadline：慢流 8MiB/100=83886ms；8MiB/500000B/ms≈16ms<1500 取 1500（若误乘 1000 得 16777 则失败，覆盖单位陷阱）。实现 scheduler.dart:613 |
| A6 | passed | brief.md | A6（seek 水位重置）：同 fileKey 新 Range 请求（新 first）到达时，旧消费水位清除，新链门控从零计算（单测）。 | scheduler_test.dart:898-964：先补完 warm 16MiB（serve 钳制为两棒，循环 6 轮覆盖续棒并以无 pending 断言收尾）释放 hostCap(6)；seek 回退后断言放行 2 片（无修复时 ahead=64MiB 放行 4 片）、零消费时第二棒 0 请求。读码核对两向算术均成立 |
| A7 | passed | brief.md | A7（发射批量化）：sink 发射与代理 flush 聚合（≥256KB 或 ≥16ms），全速下载时每秒 add/flush 次数显著下降（单测计数）。 | scheduler_test.dart:970-1008 断言 128×4KB 下 add<64（sink 批量，scheduler.dart:548-552）；media_proxy_server_test.dart:353-413 断言 63×1KB@10ms 时 consumedReports>1——仅字节阈值时全程 0 次 flush、收尾恰 1 次上报即失败，鉴别 16ms 时间下界（media_proxy_server.dart:235-249） |
| A8 | passed | brief.md | A8（totalSize 结论）：核实 DASH 模型（VideoItem/AudioItem）无 size 字段（B 站 dash 响应不含），totalSize 无法从 playinfo 贯通——首请求探测透传保留为已知限制，仅 durl 路径（已有 size）维持直传。 | BaseItem.fromJson（models/video/play/url.dart:338-353）无 size 字段；DASH 调用点（video/controller.dart:931/945/1311/1336）不传 totalSize，durl 路径传 i.size（1228/1237）——探测透传保留为已知限制的结论与代码一致 |
| A9 | passed | brief.md | A9（回归）：`flutter analyze` 无问题；`flutter test` 全量通过。 | 本人重跑：flutter test test/thread_ripper/ 159 全过；flutter analyze（lib/services/thread_ripper + test/thread_ripper）No issues。Runtime 两检查 passed；整仓测试日志 All tests passed(279)，整仓 analyze 76 条均为既有 info/warning（2 条在本次未改动的 test/utils/），无 error 级 |
| A10 | passed | specs/thread-ripper-mobile-delivery/spec.md | TTFB 挂起可中止 - **WHEN** 某 attempt 已发出请求但 TTFB 超过软阈值（×紧急系数×2）且该片段存在替代主机 - **THEN** 该 attempt 被中止并由替代主机接管；不再对未收到首字节的请求无限等待 - **WHEN** 不存在替代主机 - **THEN** 保留等待（避免打死唯一可达主机） | 同 A1：ttfbOver 中止需 attempts>1 或 _hasAlternative，否则保留等待至 jobStallMs 既有兜底（scheduler.dart:1678-1681），双分支均有单测 |
| A11 | passed | specs/thread-ripper-mobile-delivery/spec.md | 片 0 优先 - **WHEN** 一个棒启动 - **THEN** 片 0（contiguous 前缀所在片）最先启动，其余片在片 0 推进超过阈值后放行 | 同 A2：pacing A1 断言片 0 最先发起、其余片待片 0 推进（水位）超阈值后放行 |
| A12 | passed | specs/thread-ripper-mobile-delivery/spec.md | 片级消费门控 - **WHEN** 播放器消费水位落后超过 margin（未启动片的 start 超过「本棒起点 + 已消费量 + margin」） - **THEN** 未启动的片不 launch；水位推进后继续按序启动 - **WHEN** 全部已启动片完成且消费仍未推进 - **THEN** 流保持打开（不关闭不报错），等待消费 - **NOTE** 已消费量以本棒 range.first 为基准：seek 或续棒后新棒起点高于文件级绝对水位时， 高于起点的部分不计为落后，否则陈旧/不连续水位会使新链门控误判为消费停滞而永久挂起。 播放器顺序播放时（水位 = 绝对偏移）与文件级基准等价。 | 门控公式与 spec 文字等价（seg.start > base+ahead+margin）；「已启动片完成且消费未推进→流保持打开」由 pacing A2 尾部（第三棒 0 请求、errors 空、已收字节非空）与 A3（done 为 false）覆盖；基准取本棒 range.first 的 NOTE 在 _pieceGated 注释与实现一致 |
| A13 | passed | specs/thread-ripper-mobile-delivery/spec.md | 投机制受码率基准约束 - **WHEN** bandWidth 缺失（requiredRate 无法计算） - **THEN** 投机复制与 hedge 的判断以实测典型速率为基准，而不是恒开的 0 基准 | 同 A4：bandWidth 缺失时以典型速率为基准，0 基准恒开门径被双向用例排除 |
| A14 | passed | specs/thread-ripper-mobile-delivery/spec.md | 链式棒 deadline 适配 - **WHEN** 链式棒长度大于上游 segment 量级 - **THEN** job deadline 按 max(deadlineMs[cls], 棒长/requiredRate) 计算，消除慢性 relief 误触发 - **NOTE** requiredRate 单位是「字节每毫秒」（bandWidth/8000），棒长单位是字节， 故 棒长/requiredRate 直接得到毫秒，不得再乘 1000。 | 同 A5：max(deadlineMs[cls], 棒长/requiredRate)，requiredRate 为 B/ms，用例证明未多乘 1000 |
| A15 | passed | specs/thread-ripper-mobile-delivery/spec.md | seek 水位重置 - **WHEN** 同 fileKey 的新 Range 请求到达且 first 与既有消费水位不连续 - **THEN** 该 fileKey 的消费水位重置，新链门控从零计算 | 同 A6：serve 内新 first 落后旧水位超 consumptionLookaheadBytes(4MiB) 即把水位对齐到新起点（scheduler.dart:953-961），新链门控从零计算；前向 seek 由 max(0,consumed-base) 兜底 |
| A16 | passed | specs/thread-ripper-mobile-delivery/spec.md | 发射与 flush 批量化 - **WHEN** 全速下载（高频小 chunk 到达） - **THEN** sink 发射与代理 flush 按聚合条件（累计 ≥256KB 或距上次 ≥16ms）执行，单位时间系统调用与事件次数有界 | sink：累计<256KB 且 <16ms 且未完成才暂缓（≥256KB 或 ≥16ms 或完成即发射，done/attach 绕过）；proxy flush：≥256KB 或 ≥16ms，流结束无条件收尾 flush——两侧聚合条件与 spec 一致且各有鉴别性单测 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter test test/thread_ripper/ | -c PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn /Users/tune/fvm/versions/3.47.0/bin/flutter test test/thread_ripper/ | . | passed | 0 | 9190 ms |
| flutter analyze lib/services/thread_ripper/ test/thread_ripper/ | -c PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn /Users/tune/fvm/versions/3.47.0/bin/flutter analyze lib/services/thread_ripper/ test/thread_ripper/ | . | passed | 0 | 4341 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- flutter test test/thread_ripper/: passed — 159 项通过
- flutter analyze lib/services/thread_ripper/ test/thread_ripper/: passed — No issues found
- flutter test (whole project): passed — 282 项通过
- 已知限制: DASH（VideoItem/AudioItem）无 size 字段，totalSize 无法从 playinfo 贯通，首请求探测透传保留（brief A8 结论）。
- 已知限制: seek 前进且新起点仅略高于旧水位（差值 < 4MiB lookahead）时不重置，_continueChain 用旧水位立即放行后续棒——spec 未规定此边界，属既有取舍，顺序播放不触发（Verifier 二轮发现）。
- 已知限制: 未做 worker isolate 卸载（brief 明确不建）；真机（mpv）行为未验证，最终体验需用户确认。

## 阻塞项

_无。_

## 风险与跳过的工作

- brief 范围列出 video_settings.dart 副标题与 README.md 更新，本次 diff 未触及；现有文案（video_settings.dart:69、README.md:14）已描述消费驱动预取且仍准确，无验收项覆盖，仅作范围漂移记录（low）
- _emitAvailable 暂缓发射无独立定时器，依赖下一 progress/tick/done 事件冲刷；中途停滞由 stall 救援产生新事件兜底、完成时强制发射，测试通过，记录为设计权衡（low）

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 0 | recovery | — | Native confirmed acceptance criteria changed | 2026-10-11T13:38:14.158Z |
| 2 | 0 | 0 | recovery | — | Native confirmed acceptance criteria changed | 2026-10-11T13:48:00.859Z |
| 3 | 1 | 0 | recovery | — | Builder handoff Runtime checks failed: analyze-thread-ripper | 2026-10-11T14:05:26.682Z |
| 3 | 2 | 0 | recovery | — | Builder handoff Runtime checks failed: analyze-thread-ripper | 2026-10-11T14:05:49.957Z |
| 3 | 3 | 1 | fail | A4, A13 | 16 项中 15 项 passed，1 项 failed（A4/A13）。四个「死代码/单位错误」修复均已独立核实为真实修复且方向正确：(1) _tick 的 TTFB 逃生确实不再被 firstByteAt==0 短路（HEAD 原有该豁免，现已前移判定）；(2) Job deadline 单位正确（字节÷字节每毫秒=毫秒，无 ×1000，且 HEAD 原本完全没有棒长项）；(3) _hasSlot 片级门控基准确为本棒 range.first（seg.start > consumed + 2MiB）；(4) _pump 不再因单 job 无 slot 而 break 整轮（改为标记该 job 的 queued 片后 continue，后续 job 不再饿死）；(5) 代理侧 flush 确为字节量与时间双条件，且收尾有无条件 flush。回归方面由 Verifier 经 Runtime 独立补跑全量 flutter test（279/279 通过）与范围内 flutter analyze（No issues found）；全项目 analyze 退出码 1 经逐条核对全部源于本次未改动文件的既有问题。唯一失败项 A4/A13：hedge 门的 requiredRate=0 基准回落实现正确，但规格要求的单测缺失——现有 6 处 mayDuplicate 断言全部使用 requiredRate=10/baseline=10，新分支零覆盖，删除该分支不会有任何测试失败。 | 2026-10-11T14:26:42.876Z |
| 3 | 4 | 1 | recovery | — | Observed implementation write before lib/services/thread_ripper/scheduler.dart | 2026-10-11T15:36:25.538Z |
| 3 | 5 | 1 | recovery | — | Observed implementation write before lib/services/thread_ripper/scheduler.dart | 2026-10-11T15:45:48.710Z |
| 3 | 6 | 1 | pass | — | 16/16 通过。四项 Builder 自报均经读码独立核实成立：A6 重写在有/无修复两向算术上均有鉴别力（2 vs 4 片、0 vs ≥4 第二棒）；_pieceGated 中间态断言区分片级与 job 级门控；代理侧 A7 以 consumedReports>1 鉴别 16ms 时间下界；seek 注释关于对齐/删除等价的陈述与 noteConsumed(??0 守卫)和 _continueChain 绝对比较相符。测试 159/159、scoped analyze 无问题均为本人重跑结果，未修改任何项目文件。 | 2026-10-12T01:00:26.661Z |



## 结论

16/16 通过。四项 Builder 自报均经读码独立核实成立：A6 重写在有/无修复两向算术上均有鉴别力（2 vs 4 片、0 vs ≥4 第二棒）；_pieceGated 中间态断言区分片级与 job 级门控；代理侧 A7 以 consumedReports>1 鉴别 16ms 时间下界；seek 注释关于对齐/删除等价的陈述与 noteConsumed(??0 守卫)和 _continueChain 绝对比较相符。测试 159/159、scoped analyze 无问题均为本人重跑结果，未修改任何项目文件。
