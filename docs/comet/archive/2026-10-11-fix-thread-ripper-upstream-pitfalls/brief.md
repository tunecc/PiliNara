# 目标

修复 PiliNara 线程撕裂者移植版中与上游同源、且已被 VidBoost 浏览器插件实测踩实的问题，并解决 mpv 开放末端 Range 与接管上限错配导致的「顺序播放主链路无加速」。修复后：

1. `*.edge.mountaintoys.cn`（B 站 PCDN 边缘域）被 P2P 域名判定正确识别，不再被当作 B 站自有 PoP 优先使用。
2. 所有含 `/upgcxcode/` 的地址在进入候选与 fallback 选择前统一剥离 `/v\d/resource` 传输包装前缀（签名只绑定查询参数，实测 `os=mcdn` 签名在官方镜像 206），使包装形态（PCDN 观众常态）的文件也能获得多节点换签加速。
3. `_pickCdnUrl` 不再产出「官方镜像 + `/v1/resource` 路径」的必 404 坏 URL（该缺陷影响 Thread Ripper 关闭时的普通播放）。
4. upos 签名的换签候选不再指向 akamaized.net（Akamai 不接受 upos 签名，必 403）；签名家族与主机家族不匹配的候选标 foreign 档位最后尝试。
5. mpv 的开放末端 Range（`bytes=N-`）在总大小已知时不再被 64MiB 上限整单拒绝：服务区间钳制到 `min(total, first + maxServedLength - 1)`，由相邻 Job 无缝续棒同一响应流，Content-Range 报告完整请求区间。
6. 非 2xx/异常响应的排水（`_discardBody`）加上限，避免对异常主机拉取整文件。

# 范围

## 目录结构

### 新建

（无新增文件；全部为既有文件修改与既有/新增测试）

### 修改

- `lib/services/thread_ripper/classify.dart`：P2P 关键字名单追加 `.edge.mountaintoys.cn`；新增 `normalizeUpgcxcodeUri`（剥离 `/v\d/resource` 前缀）；host 家族与签名家族不匹配的档位判定（foreign）。
- `lib/utils/video_utils.dart`：playUrls 进入 `_pickCdnUrl` / `threadRipperCandidates` 前统一 normalize；`_isReplaceableMediaHost` 的 mountaintoys 判断改为子域后缀匹配；换签目标剔除 akamaized（upos 签名）；`_pickCdnUrl` 的 mcdnUpgcxcode 分支产出剥离后的官方镜像 URL。
- `lib/services/thread_ripper/scheduler.dart`：开放末端 Range 的接管与 Job 续棒；`_discardBody` 排水上限（约 1MiB / 2s）。
- `lib/services/thread_ripper/thread_ripper_manager.dart`：`rewritePlayable` 的 catch 增加 debug 日志（仅 debug 构建可见）。
- `test/`（classify_test、thread_ripper_getcdnurl_test、scheduler_test）：新增对应用例。

### 删除

（无）

### 明确不建

- 不移植完整的候选层 noP2pPolicy（保留现状：fallback 层 proxy/szbdyd 改写 + 原始 P2P 地址直连的架构变体）。
- 不做地区偏好（auto/大陆/海外）——PiliNara 用户以国内为主，测速学习自动排挤慢节点。
- 不改代理绑定失败的重试策略（维持现状，另行评估）。

# 非目标

- 不重构调度引擎的既有常量与算法（与 VidBoost 移植版保持一致）。
- 不做真机/集成自动化验证：mpv 对「206 区间小于请求区间 + Job 续棒」的兼容性由桌面 `flutter test` 模拟验证 + 用户真机确认（用户明确知悉断播风险并要求一并修复）。
- 不支持直播流。

# 验收示例

- A1（P2P 名单）：`isP2PCdnDomain('29e749o.edge.mountaintoys.cn')` 与 `isP2PCdnDomain('b-baaa93cg2y85fbm6d2wwavz6ydx6f.edge.mountaintoys.cn')` 为 true，且 `classifyCdnUrl` 对 `https://29e749o.edge.mountaintoys.cn/upgcxcode/...`（含 `os=mcdn` 与不含两种查询）返回 `mcdnUpgcxcode`；`upos-sz-mirrorali.bilivideo.com` 保持 false。
- A2（可替换 host 子域匹配）：`_isReplaceableMediaHost('29e749o.edge.mountaintoys.cn')` 为 true。
- A3（换签剥离）：包装形态 URL `https://xy220x202x9x135xy.mcdn.bilivideo.cn:8082/v1/resource/upgcxcode/99/91/x/x-1-30080.m4s?...` 经 `threadRipperCandidates` 产出**多个**不含 `/v1/resource` 的官方镜像换签候选（`https://<节点>/upgcxcode/99/91/...`），且原始包装 URL 保留在列表中。
- A4（坏 fallback 消除）：playUrls 仅含包装形态地址时，`_pickCdnUrl` 返回的 fallback 为官方镜像 + 剥离后路径（或 proxy-tf 改写），绝不包含「官方镜像 host + `/v1/resource` 路径」组合。
- A5（akamai 档位）：upos 签名（无 hdnts）的换签候选列表不含 akamaized.net 主机；签名家族与主机家族不匹配的候选档位为 foreign。
- A6（开放末端接管）：descriptor 总大小 200MiB、代理收到 `bytes=0-` 时，加速器接受请求（不因超过 maxServedLength 拒绝），首个 206 的 Content-Range 报告 `bytes 0-199999999/200000000`，流式输出按 64MiB 分棒连续无重叠无缺口（scheduler 单测以 mock transport 断言字节序与区间）。
- A7（排水上限）：mock 返回 200 + 大响应体时，`_discardBody` 在约 1MiB 或 2s 内取消读取（单测断言取消被调用）。
- A8（回归）：`flutter test` 全量通过（含既有 thread_ripper 测试）。
