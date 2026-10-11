# 目标

明确线程撕裂者（Thread Ripper）与 App 自带 CDN 节点设置（「CDN 设置」里的默认节点 / 自定义节点）的关系为**互斥**：线程撕裂者开启时，节点偏好设置不参与媒体地址选点（全部节点按实测速度自动竞速，playinfo 原始地址作为兜底），并在设置页两处给出动态提示；关闭时 CDN 节点设置行为与现状完全一致。

背景：当前实现是「组合」语义——节点偏好选出的地址只是候选列表第一位的兜底，开启线程撕裂者后被稀释为约 20 个竞速者之一，用户选点意图被静默忽略且无任何提示（用户已确认改为互斥语义，对齐 VidBoost 插件已上线的双向自动互斥决策）。

# 范围

## 目录结构

### 新建

（无）

### 修改

- `lib/utils/video_utils.dart`：`_pickCdnUrl` 增加 `bypassCdnPreference` 参数（`getCdnUrl` 在 `useThreadRipper` 为 true 时传入）——旁路节点偏好改写，但保留与偏好无关的正确性改写（mcdn-tf 无 upgcxcode 私有传输 → proxy-tf 代理；szbdyd → xy_usource 真实主机）。
- `lib/pages/setting/models/video_settings.dart`：Thread Ripper 开关副标题追加互斥说明；「CDN 设置」条目副标题在线程撕裂者开启时动态提示「本设置不参与选点」。
- `README.md`：Thread Ripper 条目补充互斥说明。
- `test/utils/thread_ripper_exclusivity_test.dart`（新建）：旁路与回归用例。

### 删除

（无）

### 明确不建

- 不做地区偏好（auto/大陆/海外）。
- 不动线程撕裂者调度引擎、候选换签、P2P 名单（上一 change 已完成）。
- 不改「直播 CDN 设置」与「音频不跟随 CDN 设置」的语义。

# 非目标

- 不做真机自动化验证（设置页提示为编译期检查 + 单测覆盖行为旁路）。
- 不改变线程撕裂者关闭时的任何行为。

# 验收示例

- A1（旁路节点偏好）：`useThreadRipper = true` 时，无论 `defaultCDNService` / `customCDNUrl` 取什么值，`getCdnUrl` 对官方镜像地址返回 playinfo 原始地址（已剥离 `/v1/resource`），对包装/PCDN 地址返回剥离后的原始地址，绝不出现「节点偏好改写后的地址」。
- A2（正确性改写保留）：`useThreadRipper = true` 时，无 upgcxcode 的 mcdn 私有传输地址仍改写为 `proxy-tf-all-ws.bilivideo.com?url=`；szbdyd 地址仍按 `xy_usource` 改写。
- A3（关闭时回归）：`useThreadRipper = false` 时，节点偏好改写行为与修复前完全一致（官方镜像按默认/自定义节点改写、包装形态重建为官方镜像剥离路径）。
- A4（设置页提示）：Thread Ripper 开关副标题包含互斥说明；「CDN 设置」条目在线程撕裂者开启时副标题含「不参与选点」提示，关闭时不含。
- A5（回归）：`flutter test` 全量通过；README 补充互斥说明。
