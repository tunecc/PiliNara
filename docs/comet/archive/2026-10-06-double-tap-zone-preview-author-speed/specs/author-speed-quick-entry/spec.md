# 更多设置作者专属倍速快捷入口（完整目标规格）

本规格描述归档后 `author-speed-quick-entry` 能力的完整行为：视频播放页「更多设置」面板中为当前作者快捷设置专属倍速。

## 能力概述

播放 UGC 视频时，播放器右上角「更多设置」面板提供「作者专属倍速」条目；点击就地弹出倍速选择弹窗，选择并保存后立即对当前视频生效。数据写入已有的作者专属倍速存储，与 倍速设置页（`/playSpeedSet`）的作者专属倍速区块完全互通。非 UGC 内容（番剧/影视、本地文件）没有作者概念，不显示该条目。

## 复用的既有能力（不变）

- 存储：Hive `video` box 的 `authorPlaySpeeds`（`VideoBoxKey.authorPlaySpeeds`，`List<AuthorPlaySpeed>` JSON，`AuthorPlaySpeed { mid, name, speed }`）。
- 访问层：`Pref.authorPlaySpeeds` / `playSpeedForAuthor(mid)` / `upsertAuthorPlaySpeed` / `removeAuthorPlaySpeed`。
- 应用逻辑：`PlPlayerController.applyAuthorDefaultSpeed(mid, force: true)` 立即生效；`resetAuthorDefaultSpeedToGlobal` 回退全局默认；切换稿件/剧集时的既有触发点不变。
- 倍速选项：`Pref.speedList`（用户自定义倍速列表）。
- 倍速设置页（`lib/pages/setting/pages/play_speed_set.dart`）的作者专属倍速区块行为不变，与本入口共享同一存储。

## 面板条目（`lib/pages/video/widgets/header_control.dart` 的 `showSettingSheet()`）

- 仅当能取到当前视频作者（UGC：`introController.videoDetail.value.owner` 的 `mid`/`name` 非空）时显示；番剧/影视（PGC 无 `owner`）、本地文件源不显示。
- 条目形态：`ListTile(dense: true)`，与面板其他条目一致的图标、标题、副标题样式。
- 标题：`作者专属倍速`。
- 副标题：显示当前作者名；未设置专属倍速时提示「未设置，点击为 TA 添加」类文案；已设置时显示 `已设置 X.Xx`（X 为当前倍速值）。
- 位置：放在「重载视频」附近的播放行为分组，不改变既有条目的相对顺序与行为。

## 交互流程

- 点击条目：先关闭面板（`Get.back()`），再弹出倍速选择弹窗（复用 `play_speed_set.dart` 中 ChoiceChip 选倍速的交互样式）：
  - 初始选中：该作者已设置的倍速；未设置时无预选。
  - 选项：`Pref.speedList` 全部倍速。
  - 操作按钮：确认保存；该作者已设置时额外提供「移除专属倍速」入口。
- 保存：`upsertAuthorPlaySpeed(AuthorPlaySpeed(mid: 当前作者mid, name: 当前作者名, speed: 所选倍速))`，随后 `applyAuthorDefaultSpeed(mid, force: true)` 使当前播放立即切换到该倍速，并 toast 提示成功。
- 移除：`removeAuthorPlaySpeed(mid)`，随后让当前播放回退全局默认倍速（等价 `resetAuthorDefaultSpeedToGlobal(force: true)` 或按现有 API 语义实现），并 toast 提示。
- 取消弹窗不写入任何数据、不改变当前倍速。

## 一致性与边界

- 快捷入口的添加/修改/删除结果必须在倍速设置页的作者专属倍速列表中同步可见（同一存储，双向一致）。
- 面板在半屏/全屏两种形态下都可用；`heroTag` 定位 introController 的现有方式不变。
- 不新增「按作者管理列表」页面；不改动 `applyAuthorDefaultSpeed` 的既有触发逻辑（打开视频时的自动应用）。
- 手动改速仅本次有效的既有语义不变：快捷入口保存的是持久配置并立即应用。
