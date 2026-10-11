# 线程撕裂者与 CDN 节点设置互斥（完整目标规格）

## 能力概述

线程撕裂者（多节点并发竞速）与 App 自带的 CDN 节点偏好（默认节点 / 自定义节点）互斥：竞速开启时节点偏好旁路，全部候选按实测速度自动选优；竞速关闭时节点偏好照常生效。与节点偏好无关的地址正确性改写（私有传输代理、szbdyd 真实主机）在两种模式下都保留。

## 互斥语义

### Scenario: 竞速开启时旁路节点偏好

- **WHEN** Thread Ripper 开启（useThreadRipper = true）且播放信息给出官方镜像地址
- **THEN** 返回的兜底地址为 playinfo 原始地址（已剥离 `/v1/resource` 包装），无论默认节点/自定义节点如何设置

### Scenario: 包装与 PCDN 地址返回剥离后的原始地址

- **WHEN** Thread Ripper 开启且 playinfo 地址为 PCDN 包装形态或 `*.edge.mountaintoys.cn` / `*.mcdn.bilivideo.*` 的 upgcxcode 地址
- **THEN** 兜底地址为剥离 `/v1/resource` 前缀后的原始地址（P2P 直连变体），而非改写到某个官方镜像节点

### Scenario: 竞速关闭时节点偏好照常

- **WHEN** Thread Ripper 关闭（useThreadRipper = false）
- **THEN** 默认节点 / 自定义节点的改写行为与本变更前完全一致（官方镜像按所选节点改写、包装形态重建为官方镜像剥离路径）

## 正确性改写保留

### Scenario: 私有传输走代理（两种模式一致）

- **WHEN** 地址为裸 IP / `*.mcdn.bilivideo.*` 且 path 为 `/v\d/resource` 且不含 `/upgcxcode/`
- **THEN** 无论 Thread Ripper 开关，地址都改写为 `proxy-tf-all-ws.bilivideo.com?url=<原始地址>`

### Scenario: szbdyd 按真实主机改写（两种模式一致）

- **WHEN** 地址包含 szbdyd.com 且带 `xy_usource` 参数
- **THEN** 无论 Thread Ripper 开关，地址都改写到 `xy_usource` 指定的真实主机

## 设置页提示

### Scenario: 竞速开关说明互斥

- **WHEN** 用户查看「Thread Ripper（多 CDN 并发下载）」开关
- **THEN** 副标题说明开启后 CDN 节点偏好设置不参与选点、全部节点按速度自动竞速

### Scenario: CDN 设置条目动态提示

- **WHEN** 线程撕裂者已开启，用户查看「CDN 设置」条目
- **THEN** 副标题提示节点偏好当前不参与选点；线程撕裂者关闭时不含该提示
