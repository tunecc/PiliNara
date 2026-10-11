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
- 完成时间: 2026-10-11T08:46:24.460Z
- 摘要: 独立验收 fix-thread-ripper-upstream-pitfalls 通过。逐项核对 classify.dart（mountaintoys P2P 名单、normalizeUpgcxcodeUri、签名家族）、video_utils.dart（preparedUrls 预规范化、threadRipperCandidates 剥离换签、_isReplaceableMediaHost 子域后缀）、scheduler.dart（serve 钳制+_successorParams 续棒、ResponseSink 绝对偏移与 attach 冲刷、discardBody 1MiB/2s 上限）、thread_ripper_manager.dart（rewritePlayable catch debug 日志）与全部测试文件，A1-A8 用例均为真实行为断言（区间集合、流长度、取消时机、档位枚举等具体值）。定向测试 158 全过、全量回归 262 全过。3 项实现风险已列（续棒缓冲一次性分配、续棒后 onCancel 失效、分棒措辞粒度），均不阻塞验收。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1（P2P 名单）：`isP2PCdnDomain('29e749o.edge.mountaintoys.cn')` 与 `isP2PCdnDomain('b-baaa93cg2y85fbm6d2wwavz6ydx6f.edge.mountaintoys.cn')` 为 true，且 `classifyCdnUrl` 对 `https://29e749o.edge.mountaintoys.cn/upgcxcode/...`（含 `os=mcdn` 与不含两种查询）返回 `mcdnUpgcxcode`；`upos-sz-mirrorali.bilivideo.com` 保持 false。 | classify.dart isP2PCdnDomain 关键字表含 .edge.mountaintoys.cn（classify.dart:172，子串匹配覆盖两个被测子域）；classifyCdnUrl 对 mountaintoys + /upgcxcode/ 走 mcdnUpgcxcode 分支且与 os=mcdn 查询无关（classify.dart:203-213）。classify_test.dart:313-331 为真实断言：两个子域 isTrue、upos-sz-mirrorhw.bilivideo.com isFalse、含/不含 os=mcdn 均返回 mcdnUpgcxcode。 |
| A2 | passed | brief.md | A2（可替换 host 子域匹配）：`_isReplaceableMediaHost('29e749o.edge.mountaintoys.cn')` 为 true。 | video_utils.dart _isReplaceableMediaHost 改为 lower.endsWith('.edge.mountaintoys.cn')\|\|=='edge.mountaintoys.cn'。thread_ripper_candidates_test.dart A2 用例经 threadRipperCandidates 行为验证：mountaintoys 包装地址产出 https://upos-sz-* 换签候选非空（子域匹配失效时该断言必失败）。 |
| A3 | passed | brief.md | A3（换签剥离）：包装形态 URL `https://xy220x202x9x135xy.mcdn.bilivideo.cn:8082/v1/resource/upgcxcode/99/91/x/x-1-30080.m4s?...` 经 `threadRipperCandidates` 产出**多个**不含 `/v1/resource` 的官方镜像换签候选（`https://<节点>/upgcxcode/99/91/...`），且原始包装 URL 保留在列表中。 | threadRipperCandidates（video_utils.dart）对含 /upgcxcode/ 的可替换 host 先 normalizeUpgcxcodeUri 剥离 /v1/resource 再铺到 CDNService 全部节点；candidates_test A3 断言剥离形态换签候选 >1 个且均不含 /v1/resource/、原始包装 URL 保留在列表。 |
| A4 | passed | brief.md | A4（坏 fallback 消除）：playUrls 仅含包装形态地址时，`_pickCdnUrl` 返回的 fallback 为官方镜像 + 剥离后路径（或 proxy-tf 改写），绝不包含「官方镜像 host + `/v1/resource` 路径」组合。 | _pickCdnUrl 先对全部 urls 做 normalizeUpgcxcodeUri（preparedUrls），mcdnUpgcxcode 捕获与 rebuild 重建（清 4483/8082 端口）均基于剥离后路径，官方镜像+/v1/resource 组合在结构上不可产出；getcdnurl candidates_test A4 断言 fallback 为 https://upos-sz-mirrorali.bilivideo.com/upgcxcode/... 且不含 /v1/resource/；A4b 确认无包装地址行为不变。 |
| A5 | passed | brief.md | A5（akamai 档位）：upos 签名（无 hdnts）的换签候选列表不含 akamaized.net 主机；签名家族与主机家族不匹配的候选档位为 foreign。 | 换签侧：threadRipperCandidates 跳过 akamai 源 host、非 upos 签名源与 akamai 目标 host，candidates_test A5 断言候选无 .akamaized.net 且换签数 >1（防恒真）；档位侧：scheduler.dart ResolvedCandidate 构造器 (family==akam)!=isAkamaiHost(hostname) → CandidateTier.foreign（rank 7 最后尝试），scheduler_test 'family/host mismatch ranks foreign (A5)' 对真实 ResolvedCandidate 断言 tier==foreign、匹配家族保持 listedMirror。 |
| A6 | passed | brief.md | A6（开放末端接管）：descriptor 总大小 200MiB、代理收到 `bytes=0-` 时，加速器接受请求（不因超过 maxServedLength 拒绝），首个 206 的 Content-Range 报告 `bytes 0-199999999/200000000`，流式输出按 64MiB 分棒连续无重叠无缺口（scheduler 单测以 mock transport 断言字节序与区间）。 | scheduler.dart _serve：range.resolve 后 requestLast 保留请求末端，超 maxServedLength 钳制为 first+maxServedLength-1 并把后继参数 (first: clampedLast+1, last: requestLast) 存入 _successorParams；AcceleratedResponse.last=requestLast 报完整区间，media_proxy_server 据此写 Content-Range。_complete 取后继 _start(next, sink) + sink.attach 续流；ResponseSink 以 _requestFirst 绝对偏移发射，attach 先 _emitFromJob(previous) 冲刷上一棒尾字节，出现发射缺口时抛 StateError 而非跨棒错位。scheduler_test A6 用例（total=65MiB、bytes=0-）：断言 response.first/last/total=0/total-1/total、第一棒 4 片精确覆盖 [0,64Mi-1]、续棒请求区间恰为 [64Mi,total-1] 连续、errors 空、done、流长度==total，全部为具体区间/长度断言非恒真。 |
| A7 | passed | brief.md | A7（排水上限）：mock 返回 200 + 大响应体时，`_discardBody` 在约 1MiB 或 2s 内取消读取（单测断言取消被调用）。 | scheduler.dart discardBody：takeWhile(received<=discardCapBytes=1MiB)+.timeout(2s,onTimeout close)，fire-and-forget drain。scheduler_test A7 用例以自建 StreamController 断言：第一块 1MiB 内未取消、第二块越限即 onCancel 触发、取消后再喂块 consumed 不再增长（取消后不消费）。 |
| A8 | passed | brief.md | A8（回归）：`flutter test` 全量通过（含既有 thread_ripper 测试）。 | 独立运行：定向 fvm flutter test test/thread_ripper/ + 3 个 utils 测试 = 158 all passed（含 scheduler 712 行、classify 383 行用例集）；全量 fvm flutter test = 262 all passed，0 失败 0 跳过异常。 |

## 检查

_没有记录 Runtime 检查。_

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- 已知限制: mpv 对「206 区间小于请求区间 + Job 续棒」的兼容性由桌面 flutter test 模拟（A6 用例），真机验证由用户执行（brief 非目标已声明）
- 已知限制: 候选层 noP2pPolicy 未移植（brief 明确不建）：原始 P2P 地址保留直连，fallback 层 proxy-tf/szbdyd 改写维持既有行为
- 已知限制: video_utils 的 _mirrorRegex 与 classify.dart 存在两份（历史遗留，本次未收敛）

## 阻塞项

_无。_

## 风险与跳过的工作

- 续棒 Job 一次性分配剩余全区间 Uint8List：bytes=0- 的第一棒 64MiB 后，后继 Job 覆盖 [64Mi,total-1] 并 upfront 分配 (total-64MiB) 缓冲（200MiB 文件约 136MiB，更大文件线性增长）。功能正确、分片拉流有上限，但大文件真机内存占用需观察。
- 续棒后 ResponseSink._onCancel 仍捕获第一棒 Job（state 已 done），播放器在续棒期间断开不会 _stop 后继 Job，后继会拉完整个剩余区间才停——资源效率问题而非正确性问题，未影响 A6 验收（A6 只测正常完成）。
- brief A6 措辞'按 64MiB 分棒'与实现为'第一棒 64MiB + 单后继 Job 至请求末端（内部仍按 pieceCount 分片）'：与 spec Scenario'创建后继 Job 从已交付 frontier 继续，直至请求末端或 total'一致，单测断言区间连续与流长度达标，仅措辞粒度差异。
- mpv 对'206 区间小于请求区间+Job 续棒'的真机兼容性按 brief 非目标约定由用户真机确认，本次为桌面单测模拟验证。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | 独立验收 fix-thread-ripper-upstream-pitfalls 通过。逐项核对 classify.dart（mountaintoys P2P 名单、normalizeUpgcxcodeUri、签名家族）、video_utils.dart（preparedUrls 预规范化、threadRipperCandidates 剥离换签、_isReplaceableMediaHost 子域后缀）、scheduler.dart（serve 钳制+_successorParams 续棒、ResponseSink 绝对偏移与 attach 冲刷、discardBody 1MiB/2s 上限）、thread_ripper_manager.dart（rewritePlayable catch debug 日志）与全部测试文件，A1-A8 用例均为真实行为断言（区间集合、流长度、取消时机、档位枚举等具体值）。定向测试 158 全过、全量回归 262 全过。3 项实现风险已列（续棒缓冲一次性分配、续棒后 onCancel 失效、分棒措辞粒度），均不阻塞验收。 | 2026-10-11T08:46:24.460Z |



## 结论

独立验收 fix-thread-ripper-upstream-pitfalls 通过。逐项核对 classify.dart（mountaintoys P2P 名单、normalizeUpgcxcodeUri、签名家族）、video_utils.dart（preparedUrls 预规范化、threadRipperCandidates 剥离换签、_isReplaceableMediaHost 子域后缀）、scheduler.dart（serve 钳制+_successorParams 续棒、ResponseSink 绝对偏移与 attach 冲刷、discardBody 1MiB/2s 上限）、thread_ripper_manager.dart（rewritePlayable catch debug 日志）与全部测试文件，A1-A8 用例均为真实行为断言（区间集合、流长度、取消时机、档位枚举等具体值）。定向测试 158 全过、全量回归 262 全过。3 项实现风险已列（续棒缓冲一次性分配、续棒后 onCancel 失效、分棒措辞粒度），均不阻塞验收。
