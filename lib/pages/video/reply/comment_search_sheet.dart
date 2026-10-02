import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 评论搜索入口
/// 在评论面板中打开，对已加载的评论进行本地搜索
class CommentSearchSheet extends StatefulWidget {
  final List<ReplyInfo> replies;
  final int upMid;
  final Function(ReplyInfo) onCommentClick;
  final Function(ReplyInfo)? onSubReplyClick;
  final VoidCallback onDismiss;

  const CommentSearchSheet({
    super.key,
    required this.replies,
    this.upMid = 0,
    required this.onCommentClick,
    this.onSubReplyClick,
    required this.onDismiss,
  });

  @override
  State<CommentSearchSheet> createState() => _CommentSearchSheetState();
}

enum _CommentSearchSortMode { hot, time }

/// 评论搜索项包装
class _CommentSearchEntry {
  final ReplyInfo reply;
  final ReplyInfo? rootReply;
  final bool isSubReply;

  _CommentSearchEntry({
    required this.reply,
    this.rootReply,
    required this.isSubReply,
  });
}

class _CommentSearchSheetState extends State<CommentSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  bool _onlyUp = false;
  _CommentSearchSortMode _sortMode = _CommentSearchSortMode.hot;

  /// 扁平化所有评论（主评论 + 楼中楼）
  List<_CommentSearchEntry> get _allEntries {
    final list = <_CommentSearchEntry>[];
    for (final root in widget.replies) {
      list.add(_CommentSearchEntry(
        reply: root,
        rootReply: null,
        isSubReply: false,
      ));
      for (final sub in root.replies) {
        list.add(_CommentSearchEntry(
          reply: sub,
          rootReply: root,
          isSubReply: true,
        ));
      }
    }
    return list;
  }

  List<_CommentSearchEntry> get _filteredEntries {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return [];
    return _allEntries.where((entry) {
      final msg = entry.reply.content.message.toLowerCase();
      final name = entry.reply.member.name.toLowerCase();
      final msgMatches = msg.contains(query);
      final nameMatches = name.contains(query);
      final passesUpFilter =
          !_onlyUp || entry.reply.member.mid.toInt() == widget.upMid;
      return (msgMatches || nameMatches) && passesUpFilter;
    }).toList()
      ..sort((a, b) {
        if (_sortMode == _CommentSearchSortMode.hot) {
          return b.reply.like.toInt().compareTo(a.reply.like.toInt());
        } else {
          return b.reply.ctime.toInt().compareTo(a.reply.ctime.toInt());
        }
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filteredEntries;
    final query = _searchController.text.trim();

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
                    '搜索评论',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (query.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '找到 ${filtered.length} 条',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // 只看UP主 toggle
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => setState(() => _onlyUp = !_onlyUp),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _onlyUp
                            ? colorScheme.primary.withOpacity(0.15)
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '只看UP主',
                        style: TextStyle(
                          fontSize: 12,
                          color: _onlyUp
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 排序切换
                  _CommentSortToggle(
                    mode: _sortMode,
                    onChanged: (mode) =>
                        setState(() => _sortMode = mode),
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
                  hintText: '搜索评论内容或作者昵称...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isNotEmpty
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
            // 列表或提示
            if (query.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.35),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '输入关键词搜索已加载的评论',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              colorScheme.onSurfaceVariant.withOpacity(0.65),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '支持搜索主评论、楼中楼及作者名称',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              colorScheme.onSurfaceVariant.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    '未找到包含「$query」的评论',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final isUp =
                        entry.reply.member.mid.toInt() == widget.upMid;
                    return _CommentSearchItem(
                      entry: entry,
                      isUp: isUp,
                      upMid: widget.upMid,
                      onTap: () {
                        widget.onDismiss();
                        if (entry.isSubReply && entry.rootReply != null) {
                          widget.onSubReplyClick?.call(entry.rootReply!);
                        } else {
                          widget.onCommentClick(entry.reply);
                        }
                      },
                      onCopy: () {
                        Clipboard.setData(ClipboardData(
                            text: entry.reply.content.message));
                        SmartDialog.showToast('评论已复制');
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

class _CommentSortToggle extends StatelessWidget {
  final _CommentSearchSortMode mode;
  final ValueChanged<_CommentSearchSortMode> onChanged;

  const _CommentSortToggle({
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
          label: '最热',
          selected: mode == _CommentSearchSortMode.hot,
          color: colorScheme.primary,
          onTap: () => onChanged(_CommentSearchSortMode.hot),
        ),
        const SizedBox(width: 4),
        _SortChip(
          label: '最新',
          selected: mode == _CommentSearchSortMode.time,
          color: colorScheme.primary,
          onTap: () => onChanged(_CommentSearchSortMode.time),
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
    final colorScheme = Theme.of(context).colorScheme;
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
            color: selected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CommentSearchItem extends StatelessWidget {
  final _CommentSearchEntry entry;
  final bool isUp;
  final int upMid;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  const _CommentSearchItem({
    required this.entry,
    required this.isUp,
    required this.upMid,
    required this.onTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reply = entry.reply;
    final member = reply.member;
    final content = reply.content.message;
    final likeCount = reply.like.toInt();
    final replyCount = reply.count.toInt();
    final ctime = reply.ctime.toInt();

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：用户名 + UP主标签 + 楼中楼标记 + 时间
            Row(
              children: [
                // 用户名
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isUp) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'UP主',
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (entry.isSubReply) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                colorScheme.secondaryContainer.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '楼中楼回复',
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 时间
                if (ctime > 0)
                  Text(
                    DurationUtils.formatTimeDuration(
                        DateTime.now().difference(
                            DateTime.fromMillisecondsSinceEpoch(ctime * 1000))),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // 评论内容
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // 底部：点赞 + 回复 + IP + 复制
            Row(
              children: [
                if (likeCount > 0) ...[
                  Row(
                    children: [
                      Icon(Icons.thumb_up,
                          size: 13,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6)),
                      const SizedBox(width: 3),
                      Text(
                        likeCount.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ],
                if (replyCount > 0) ...[
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 13,
                          color:
                              colorScheme.onSurfaceVariant.withOpacity(0.6)),
                      const SizedBox(width: 3),
                      Text(
                        '$replyCount条回复',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ],
                final location = reply.replyControl.location;
                if (location.isNotEmpty)
                  Text(
                    location,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          colorScheme.onSurfaceVariant.withOpacity(0.45),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: onCopy,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          ],
        ),
      ),
    );
  }
}
