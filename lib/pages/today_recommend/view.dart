import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/pages/today_recommend/controller.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 今日推荐单页面
/// 对齐 BiliPai 设计：UP主榜 + 视频队列，支持模式切换
class TodayRecommendPage extends StatefulWidget {
  const TodayRecommendPage({super.key});

  @override
  State<TodayRecommendPage> createState() => _TodayRecommendPageState();
}

class _TodayRecommendPageState extends State<TodayRecommendPage> {
  late final TodayRecommendController _controller = Get.put(TodayRecommendController());
  late final RcmdController _rcmdController = Get.find<RcmdController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: refreshIndicator(
        onRefresh: _controller.onRefresh,
        child: CustomScrollView(
          slivers: [
            // AppBar
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('今日推荐单', style: theme.textTheme.titleLarge),
                  ],
                ),
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _controller.onRefresh,
                  tooltip: '刷新',
                ),
                const SizedBox(width: 8),
              ],
            ),
            
            // 模式切换
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _ModeSwitch(
                  selected: _controller.mode,
                  onChanged: (mode) => _controller.setMode(mode),
                ),
              ),
            ),
            
            // 说明文字
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '点开会自动从推荐单移除；想换一批可点右上角"刷新"。\n当前按你的观看习惯与模式偏好生成',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            
            // UP主榜
            SliverToBoxAdapter(
              child: _UpMainSection(
                signals: _controller.creatorSignals,
              ),
            ),
            
            // 视频队列
            SliverPadding(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              sliver: Obx(
                () => _buildVideoList(_rcmdController.loadingState.value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoList(LoadingState loadingState) {
    return switch (loadingState) {
      Loading() => const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator()),
        ),
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverList.builder(
                itemCount: response.length,
                itemBuilder: (context, index) {
                  if (index == response.length - 1) {
                    _rcmdController.onLoadMore();
                  }
                  final rawItem = response[index];
                  if (rawItem is RcmdVideoItemAppModel) {
                    return _VideoQueueItem(
                      index: index + 1,
                      item: rawItem,
                      onRemove: () {
                        final data = _rcmdController.loadingState.value.data;
                        if (data != null && index < data.length) {
                          data.removeAt(index);
                          _rcmdController.loadingState.refresh();
                        }
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              )
            : const SliverToBoxAdapter(
                child: Center(child: Text('暂无推荐内容')),
              ),
      Error(:final errMsg) => SliverToBoxAdapter(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(errMsg ?? '加载失败'),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _rcmdController.onReload,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
    };
  }
}

/// 模式切换器
class _ModeSwitch extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _ModeSwitch({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            label: '今晚轻松看',
            selected: selected == 0,
            onTap: () => onChanged(0),
          ),
          _ModeButton(
            label: '深度学习看',
            selected: selected == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// UP主榜 section
class _UpMainSection extends StatelessWidget {
  final List<CreatorSignal> signals;
  const _UpMainSection({required this.signals});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (signals.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UP主榜', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                signals.length < 10 ? signals.length : 10,
                (index) => _UpMainChip(
                  index: index + 1,
                  name: signals[index].name,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpMainChip extends StatelessWidget {
  final int index;
  final String name;
  const _UpMainChip({required this.index, required this.name});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        radius: 10,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          '$index',
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      label: Text(name, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// 视频队列条目
class _VideoQueueItem extends StatelessWidget {
  final int index;
  final RcmdVideoItemAppModel item;
  final VoidCallback onRemove;
  const _VideoQueueItem({
    required this.index,
    required this.item,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () {
          // 导航到视频播放
          if (item.bvid != null) {
            Get.toNamed('/video', parameters: {'bvid': item.bvid!});
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 序号
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.bodyLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          item.owner.name ?? '',
                          style: theme.textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.rcmdReason != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '· ${item.rcmdReason}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 删除按钮
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
