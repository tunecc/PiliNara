# 线程撕裂者 CDN 地址处理修复（完整目标规格）

本规格描述修复后 `thread-ripper` 候选构建、地址规范化与代理服务的目标行为。既有调度引擎语义（并发上限、竞速、宿主模型）不在本规格范围内变更。

## 能力概述

线程撕裂者从 playinfo 的全部媒体地址构建候选并多节点并发拉流。B 站现行下发三类地址：官方镜像（裸 `/upgcxcode/` 路径）、PCDN 边缘 `*.edge.mountaintoys.cn`（裸与 `/v1/resource` 包装两种形态）、`xy<ip>xy.mcdn.bilivideo.cn:8082`（仅 `/v1/resource` 包装）。修复后三类地址都能进入多节点加速，且 PCDN 边缘不再被误判为 B 站自有 PoP。

## 地址规范化

### 包装前缀剥离（Scenario: 剥离 /v1/resource 前缀）

- **WHEN** 任一媒体 URL 的 path 以 `/v\d/resource/upgcxcode/` 开头
- **THEN** 进入候选构建与 fallback 选择前被规范化为剥离 `/v\d/resource` 前缀的形式（scheme/host/query 不变）；签名只绑定查询参数，剥离不影响有效性

### 原始地址保留（Scenario: 原始包装地址保留在候选中）

- **WHEN** 候选列表由包装形态地址构建
- **THEN** 原始包装 URL 仍作为候选存在（P2P 直连的架构变体），与剥离后的换签候选并存

## P2P 域名判定

### mountaintoys 边缘域识别（Scenario: mountaintoys 判为 P2P）

- **WHEN** 主机名为 `*.edge.mountaintoys.cn` 的任意子域（如 `29e749o.edge.mountaintoys.cn`、`b-baaa93cg2y85fbm6d2wwavz6ydx6f.edge.mountaintoys.cn`）
- **THEN** `isP2PCdnDomain` 返回 true；`classifyCdnUrl` 对其 `/upgcxcode/` 路径返回 `mcdnUpgcxcode`（与 `os=mcdn` 查询无关）
- **WHEN** 主机为 `upos-sz-mirrorali.bilivideo.com` 等官方镜像
- **THEN** `isP2PCdnDomain` 返回 false（不误伤）

## fallback 选择（_pickCdnUrl）

### 坏 URL 消除（Scenario: 包装形态不再产出官方镜像坏 URL）

- **WHEN** playUrls 仅含包装形态地址且默认 CDN 服务可用
- **THEN** fallback 为「官方镜像 host + 剥离后 `/upgcxcode/` 路径」，绝不出现「官方镜像 host + `/v1/resource` 路径」组合

### proxy-tf 改写不变（Scenario: 私有传输形态走代理）

- **WHEN** 地址为裸 IP / `*.mcdn.bilivideo.*` 且 path 为 `/v\d/resource` 且**不含** `/upgcxcode/`（真正的私有传输形态）
- **THEN** 维持既有 `proxy-tf-all-ws.bilivideo.com?url=` 改写行为

## 换签候选构建

### 全地址换签（Scenario: 包装形态获得多节点换签）

- **WHEN** playUrls 含包装形态地址且默认 CDN 服务可用
- **THEN** 剥离后的 `/upgcxcode/` 签名被铺到候选节点池的多个节点，产出多个官方镜像换签候选

### akamai 排除（Scenario: upos 签名不换签到 Akamai）

- **WHEN** 换签源签名为 upos 家族（无 hdnts）
- **THEN** 换签候选不含 akamaized.net 主机

### foreign 档位（Scenario: 家族不匹配标 foreign）

- **WHEN** 候选的签名家族与主机家族不匹配（upos 签名在 Akamai 主机，或 Akamai 签名在非 Akamai 主机）
- **THEN** 该候选档位为 foreign，仅在其余候选耗尽后被尝试

## 代理服务的区间接管

### 开放末端 Range 接管（Scenario: bytes=0- 不再被拒）

- **WHEN** descriptor 总大小已知且代理收到开放末端请求（如 `bytes=0-`）
- **THEN** 加速器接受请求：服务区间 = `[first, min(total - 1, first + maxServedLength - 1)]`，首个 206 的 Content-Range 报告完整请求区间 `bytes first-(区间末)/total`

### Job 续棒（Scenario: 区间末尾无缝续棒）

- **WHEN** 开放末端请求的第一棒（64MiB）临近完成且未到达请求末端
- **THEN** 创建后继 Job 从已交付 frontier 继续拉取同一响应流，字节连续、无重叠、无缺口，直至请求末端或 total

### 有界 Range 行为不变（Scenario: 有界请求维持既有语义）

- **WHEN** 请求为有界 Range 且长度 ≤ maxServedLength
- **THEN** 行为与修复前一致

## 排水上限

### 异常响应限量排水（Scenario: 排水不再无界）

- **WHEN** 某 attempt 的响应被判非 ok（如 200 全量返回）需要释放连接
- **THEN** 排水在读取约 1MiB 或 2 秒后取消，不再消费完整响应体

## 兼容性

- `auto`/默认配置下除上述修复外行为不变；调度引擎常量与算法不变；直播流不支持不变。
