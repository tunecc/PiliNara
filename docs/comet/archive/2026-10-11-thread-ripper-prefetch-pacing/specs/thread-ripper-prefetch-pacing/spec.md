# 线程撕裂者消费驱动预取与 PCDN 默认排除（完整目标规格）

## 能力概述

线程撕裂者对开放末端 Range（`bytes=N-`）的预取改为消费驱动：服务棒长 8MiB，仅当播放器实际消费水位逼近棒末端（提前量 4MiB）才续棒，预取量始终有界（约棒长 + 提前量）。PCDN 直连地址（mountaintoys/mcdn/szbdyd）默认从候选中排除或改写（官方镜像换签已全覆盖其签名），提供开关。

## 消费驱动预取

### Scenario: 首棒钳制

- **WHEN** descriptor 总大小已知且代理收到开放末端或超长 Range 请求
- **THEN** 第一棒服务区间为 `[first, min(first + 8MiB - 1, 请求末端)]`，206 Content-Range 报告完整请求区间

### Scenario: 消费驱动续棒

- **WHEN** 当前棒完成且消费水位 + 4MiB 提前量未达下一棒起点
- **THEN** 下一棒挂起，不产生上游请求；消费水位推进越过阈值后下一棒自动启动
- **WHEN** 播放器暂停消费（水位长期不动）
- **THEN** 不再预取（挂起保持），不占带宽

### Scenario: 流连续性

- **WHEN** 跨棒交付
- **THEN** 字节连续无重叠无缺口，总长度等于已服务区间；消费落后时字节暂存待发，不丢不乱

## PCDN 默认排除

### Scenario: 直连地址默认排除（Scenario: 开关关闭恢复）

- **WHEN** 屏蔽开关为默认开启，候选含 PCDN 直连地址（mountaintoys/mcdn 的 upgcxcode 地址、裸形态）
- **THEN** upgcxcode 形态的 PCDN 地址从候选中移除（其换签候选保留官方镜像可达性）；无 upgcxcode 的 mcdn 私有传输改写为 proxy-tf 代理形式；szbdyd 改写为 `xy_usource` 真实主机；兜底地址若被排除则取首个幸存候选
- **WHEN** 用户关闭屏蔽开关
- **THEN** PCDN 直连候选恢复参与竞速（上一行为）

## 兼容性

- 有界 Range 行为不变；调度引擎并发/竞速常量不变；`/v1/resource` 剥离、mountaintoys P2P 判定、akamai 档位等既有修复不变；直播流不支持不变。
