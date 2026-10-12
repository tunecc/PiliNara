# 线程撕裂者移动端交付层修复（完整目标规格）

## 能力概述

线程撕裂者在移动端（mpv + 本地代理）的交付层行为修正：请求必须有 TTFB 超时与逃生；片启动与消费水位联动（预取有界）；投机制受码率基准约束；链式棒的超时按棒长适配；发射与系统调用批量化以保护 UI 线程。调度引擎核心（并发/竞速/校验/宿主模型）不变。

## 请求逃生

### Scenario: TTFB 挂起可中止

- **WHEN** 某 attempt 已发出请求但 TTFB 超过软阈值（×紧急系数×2）且该片段存在替代主机
- **THEN** 该 attempt 被中止并由替代主机接管；不再对未收到首字节的请求无限等待
- **WHEN** 不存在替代主机
- **THEN** 保留等待（避免打死唯一可达主机）

## 交付节奏

### Scenario: 片 0 优先

- **WHEN** 一个棒启动
- **THEN** 片 0（contiguous 前缀所在片）最先启动，其余片在片 0 推进超过阈值后放行

### Scenario: 片级消费门控

- **WHEN** 播放器消费水位落后超过 margin（未启动片的 start 超过「本棒起点 + 已消费量 + margin」）
- **THEN** 未启动的片不 launch；水位推进后继续按序启动
- **WHEN** 全部已启动片完成且消费仍未推进
- **THEN** 流保持打开（不关闭不报错），等待消费
- **NOTE** 已消费量以本棒 range.first 为基准：seek 或续棒后新棒起点高于文件级绝对水位时，
  高于起点的部分不计为落后，否则陈旧/不连续水位会使新链门控误判为消费停滞而永久挂起。
  播放器顺序播放时（水位 = 绝对偏移）与文件级基准等价。

## 竞速约束

### Scenario: 投机制受码率基准约束

- **WHEN** bandWidth 缺失（requiredRate 无法计算）
- **THEN** 投机复制与 hedge 的判断以实测典型速率为基准，而不是恒开的 0 基准

### Scenario: 链式棒 deadline 适配

- **WHEN** 链式棒长度大于上游 segment 量级
- **THEN** job deadline 按 max(deadlineMs[cls], 棒长/requiredRate) 计算，消除慢性 relief 误触发
- **NOTE** requiredRate 单位是「字节每毫秒」（bandWidth/8000），棒长单位是字节，
  故 棒长/requiredRate 直接得到毫秒，不得再乘 1000。

### Scenario: seek 水位重置

- **WHEN** 同 fileKey 的新 Range 请求到达且 first 与既有消费水位不连续
- **THEN** 该 fileKey 的消费水位重置，新链门控从零计算

## UI 线程保护

### Scenario: 发射与 flush 批量化

- **WHEN** 全速下载（高频小 chunk 到达）
- **THEN** sink 发射与代理 flush 按聚合条件（累计 ≥256KB 或距上次 ≥16ms）执行，单位时间系统调用与事件次数有界

## 已知限制

- DASH 模型（VideoItem/AudioItem）无 size 字段（B 站 dash 响应不含），totalSize 无法从 playinfo 贯通——首请求的 4s 探测透传保留。

## 兼容性

- 调度引擎并发/竞速/校验语义不变；`/v1/resource` 剥离、mountaintoys P2P 判定、PCDN 默认排除、CDN 设置互斥等既有修复不变；关闭 Thread Ripper 时一切行为不变。
