# 目标

把线程撕裂者从「全文件全速预取下载器」改回「按播放消费驱动的加速器」，并默认排除 PCDN 直连候选。修复用户实测症状：开播即占满 100Mbps 带宽、流量巨大、缓冲进度提升不明显、PCDN 慢片阻塞交付。

根因（对比调查结论）：mpv 发开放末端 Range，无缝续棒让调度器全速把整个文件预取进内存（无任何消费背压）；PCDN 直连候选未被排除且国内实测快、稳态差；mpv 缓冲指示被 16s/4MiB 配置封顶，抢下的带宽不转化为可见进度。

# 范围

## 目录结构

### 新建

（无新增文件；开关与过滤逻辑在既有文件内实现）

### 修改

- `lib/services/thread_ripper/scheduler.dart`：新增 `openEndedLegBytes = 8MiB`（开放末端/超长请求的服务棒长）与 `consumptionLookaheadBytes = 4MiB`（续棒提前量）；serve 钳制改用棒长；续棒改为消费驱动——`_complete` 时若消费水位 + 提前量未达下一棒起点则挂起为 pending，由会话 tick 在水位满足时启动；`noteConsumed(fileKey, absoluteOffset)` 记录消费水位（按文件）。
- `lib/services/thread_ripper/media_proxy_server.dart`：`_serveAccelerated` 在每次 flush 后把「已交付到播放器的绝对偏移」通过 AcceleratedResponse 携带的消费回调上报。
- `lib/services/thread_ripper/contracts.dart`：`AcceleratedResponse` 增加可选消费回调字段。
- `lib/services/thread_ripper/thread_ripper_manager.dart`：`rewritePlayable` 在 `Pref.threadRipperBlockPcdn`（默认 true）时过滤候选——mountaintoys/mcdn 的 upgcxcode 地址丢弃（换签候选已覆盖其签名）、无 upgcxcode 的 mcdn 私有传输改写为 proxy-tf、szbdyd 改写为 xy_usource 真实主机；fallback 被过滤时取首个幸存候选。
- `lib/utils/storage_key.dart` / `storage_pref.dart`：新开关 `threadRipperBlockPcdn`（默认 true）。
- `lib/pages/setting/models/video_settings.dart`：Thread Ripper 分区新增「屏蔽 PCDN」开关（默认开启）+ 副标题说明。
- `README.md`：Thread Ripper 条目补充预取策略与 PCDN 默认排除说明。
- `test/`：消费驱动续棒、PCDN 过滤、开关回归用例。

### 删除

（无）

### 明确不建

- 不改 mpv 缓冲配置（cache-secs/demuxer-max-bytes）——缓冲进度观感受播放器机制限制，知情即可。
- 不做地区偏好。
- 不改调度引擎常量（并发/竞速参数）。

# 非目标

- 真机自动化验证（桌面单测模拟消费；真机由用户确认）。
- 直播流支持。

# 验收示例

- A1（首棒钳制）：总大小 200MiB 的 descriptor 收到 `bytes=0-`，serve 后第一个上游请求区间为 `[0, 8MiB-1]`（不再是 64MiB）。
- A2（消费驱动续棒）：模拟消费水位推进（经消费回调上报），水位 + 4MiB 提前量未达下一棒起点时不出现后续上游请求；推进越过阈值后下一棒请求出现。
- A3（流连续）：跨棒流式输出字节连续无重叠无缺口，总长度等于已服务区间；206 Content-Range 报告完整请求区间。
- A4（PCDN 默认排除）：`threadRipperBlockPcdn = true`（默认）时，mountaintoys/mcdn 的直连地址不出现在 descriptor 候选中，官方镜像换签候选保留；无 upgcxcode 的 mcdnTf 地址被改写为 proxy-tf 形式；szbdyd 地址被改写为 xy_usource 主机。
- A5（开关关闭回归）：`threadRipperBlockPcdn = false` 时 PCDN 直连候选恢复参与（上一 change 行为）。
- A6（回归）：`flutter analyze` 无问题；`flutter test` 全量通过。
