# 目标

修复线程撕裂者移动端交付层的四个结构性缺陷，使手机端体验对齐 VidBoost 插件：

1. **「加载不出来」**：片 0 的 TTFB（首字节前）挂起无任何超时兜底——dio 无 receiveTimeout、tick 显式跳过未收到首字节的 attempt、job 级兜底被其他片进度瓦解 → 片 0 卡死则 mpv 无限转圈。修复：TTFB 超时中止 + 片 0 优先交付。
2. **「持续占满带宽」**：消费门控只在棒间（8MiB 拉完才检查），棒内盲拉；bandWidth 缺失时 requiredRate=0 使投机复制永不抑制；链式棒沿用 1500ms deadline 造成慢性 relief；seek 回退后 _consumedByFile 陈旧水位使门控失效。修复：片级消费门控 + hedge 门修复 + deadline 按棒长计算 + seek 水位重置。
3. **「特别卡」**：全部字节操作（逐字节校验比对、每 chunk flush syscall、50ms ticker、8MiB 分配）在主 isolate，100Mbps 双流下每秒数十万次小对象操作挤占 UI 线程。修复：发射与 flush 批量化（≥256KB 或 ≥16ms）。
4. **首次请求慢**：DASH 调用点未传 totalSize，首请求必走 4s 探测透传。修复：playinfo size 可用时传入。

# 范围

## 目录结构

### 新建

（无）

### 修改

- `lib/services/thread_ripper/media_transport_dio.dart`：BaseOptions 增加 receiveTimeout（headers+body 全程）。
- `lib/services/thread_ripper/scheduler.dart`：TTFB stall 中止（去掉 firstByteAt==0 豁免，改为 TTFB 超阈值且有替代主机时 abort）；片 0 优先启动；片级消费门控（_pump/tick 中未启动片需 consumed + margin >= seg.start）；链式棒 deadline 按棒长/requiredRate 计算；seek 新请求清同 fileKey 消费水位；hedge 门 requiredRate=0 时以典型速率替代；sink 发射/proxy flush 批量化（≥256KB 或 16ms）。
- `lib/pages/setting/models/video_settings.dart`：开关副标题同步行为变化。
- `README.md`：条目更新。
- `test/thread_ripper/`：新增/更新用例。

### 删除

（无）

### 明确不建

- 不做 worker isolate 卸载（批量化先行，若仍卡另立 change）。
- 不改调度引擎常量（globalCap/hostCap/piece 公式）。
- 不做地区偏好、custom 主机列表。

# 非目标

- 真机自动化验证（桌面单测模拟；真机由用户确认）。
- 直播流支持。

# 验收示例

- A1（TTFB 超时）：片 0 的 attempt 模拟 headers 永不完成 → TTFB 超阈值且存在替代主机时被 abort 并由替代主机接管；无替代主机时保留等待（单测）。
- A2（片 0 优先）：serve 后首个上游请求为片 0（其余片在片 0 推进超过阈值后才启动）；mpv 收到的首字节时间不再受其余片竞争影响（单测断言启动顺序）。
- A3（片级消费门控）：消费水位落后超过 margin 时，未启动的片不 launch；水位推进后继续（单测：8MiB 棒模拟消费停滞 → 上游请求停止增长）。
- A4（hedge 门修复）：bandWidth 缺失（requiredRate=0）时投机复制以典型速率为基准受抑制；bandWidth 正常时行为不变（单测）。
- A5（deadline 适配）：链式棒的 relief 触发频率随棒长适配——deadline 按 max(1500ms, 棒长/requiredRate) 计算（单测）。
- A6（seek 水位重置）：同 fileKey 新 Range 请求（新 first）到达时，旧消费水位清除，新链门控从零计算（单测）。
- A7（发射批量化）：sink 发射与代理 flush 聚合（≥256KB 或 ≥16ms），全速下载时每秒 add/flush 次数显著下降（单测计数）。
- A8（totalSize 结论）：核实 DASH 模型（VideoItem/AudioItem）无 size 字段（B 站 dash 响应不含），totalSize 无法从 playinfo 贯通——首请求探测透传保留为已知限制，仅 durl 路径（已有 size）维持直传。
- A9（回归）：`flutter analyze` 无问题；`flutter test` 全量通过。

# Open questions

（无——修复范围经用户确认：8 项一次性全做）
