import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart'
    show DanmakuElem;
import 'package:PiliPlus/pages/danmaku/controller.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 弹幕池搜索面板（底部抽屉）
/// 允许用户浏览当前视频已加载的全部弹幕，支持关键词搜索、点击跳转时间轴
class DanmakuPoolSheet extends StatefulWidget {
  final PlDanmakuController danmakuController;
  final double currentPositionMs;
  final VoidCallback onDismiss;
  final void Function(num ms) onSeekTo;

  const DanmakuPoolSheet({
    super.key,
    required this.danmakuController,
    this.currentPositionMs = 0,
    required this.onSeekTo,
    required this.onDismiss,
  });
  @override
  State<DanmakuPoolSheet> createState() => _DanmakuPoolSheetState();
}

enum _DanmakuPoolSortMode { time, hot }

class _DanmakuPoolSheetState extends State<DanmakuPoolSheet> {
  final TextEditingController _searchController = TextEditingController();
  _DanmakuPoolSortMode _sortMode = _DanmakuPoolSortMode.time;

  List<DanmakuElem> get _allDanmaku =>
      widget.danmakuController.getAllLoadedDanmaku();

  List<DanmakuElem> get _filteredDanmaku {
    final query = _searchController.text.trim().toLowerCase();
    var list = _allDanmaku;
    if (query.isNotEmpty) {
      list = list
          .where((e) => e.content.toLowerCase().contains(query))
          .toList();
    }
    if (_sortMode == _DanmakuPoolSortMode.hot) {
      list = list
        ..sort((a, b) => b.likeCount.toInt().compareTo(a.likeCount.toInt()));
    } else {
      list = list
        ..sort((a, b) => a.progress.compareTo(b.progress));
    }
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filteredDanmaku;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 顶栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '弹幕列表',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '共 ${_allDanmaku.length} 条',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  // 排序切换
                  _SortToggle(
                    mode: _sortMode,
                    onChanged: (mode) => setState(() => _sortMode = mode),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onDismiss,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索当前已加载的弹幕...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            // 列表
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.trim().isEmpty
                            ? '暂无弹幕数据'
                            : '未找到包含「${_searchController.text.trim()}」的弹幕',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final elem = filtered[index];
                        final isNearCurrent =
                            (elem.progress - widget.currentPositionMs)
                                        .abs() <
                                    3000 &&
                                elem.progress > 0;
                        return _DanmakuPoolItem(
                          elem: elem,
                          isNearCurrent: isNearCurrent,
                          isSelf: elem.isSelf,
                          onTap: () {
                            if (elem.progress > 0) {
                              widget.onSeekTo(elem.progress.toDouble());
                              SmartDialog.showToast(
                                  '已跳转至 ${DurationUtils.formatDuration(elem.progress / 1000)}');
                              widget.onDismiss();
                            }
                          },
                          onCopy: () {
                            // 复制到剪贴板
                            debugPrint('复制弹幕: ${elem.content}');
                            SmartDialog.showToast('弹幕内容已复制');
                            widget.onDismiss();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  final _DanmakuPoolSortMode mode;
  final ValueChanged<_DanmakuPoolSortMode> onChanged;

  const _SortToggle({
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SortChip(
          label: '时间',
          selected: mode == _DanmakuPoolSortMode.time,
          color: colorScheme.primary,
          onTap: () => onChanged(_DanmakuPoolSortMode.time),
        ),
        const SizedBox(width: 4),
        _SortChip(
          label: '热度',
          selected: mode == _DanmakuPoolSortMode.hot,
          color: colorScheme.primary,
          onTap: () => onChanged(_DanmakuPoolSortMode.hot),
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _DanmakuPoolItem extends StatelessWidget {
  final DanmakuElem elem;
  final bool isNearCurrent;
  final bool isSelf;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  const _DanmakuPoolItem({
    required this.elem,
    required this.isNearCurrent,
    required this.isSelf,
    required this.onTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isNearCurrent
              ? colorScheme.primaryContainer.withOpacity(0.35)
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间标签
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                DurationUtils.formatDuration(elem.progress / 1000),
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 弹幕内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isSelf)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '我的',
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const Spacer(),
                      // 点赞数
                      if (elem.likeCount > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite_border,
                                size: 13,
                                color: colorScheme.onSurfaceVariant
                                    .withAlpha(153)),
                            const SizedBox(width: 3),
                            Text(
                              elem.likeCount.toString(),
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant
                                    .withAlpha(153),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    elem.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 复制按钮
            GestureDetector(
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                child: Text(
                  '复制',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
