import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import '../../models_new/today_watch/plugin_config.dart';
import '../../models_new/today_watch/video_model.dart';
import 'controller.dart';

/// 今日推荐单页面
class TodayWatchPage extends StatelessWidget {
  const TodayWatchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TodayWatchController());
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日推荐单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
            tooltip: '设置',
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (controller.errorMessage.value != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.errorMessage.value!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => controller._loadData(),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }
        
        if (!controller.enabled.value) {
          return _buildDisabledState(context);
        }
        
        if (controller.videoQueue.isEmpty && !controller.isLoading.value) {
          return _buildEmptyState(context);
        }
        
        return _buildContent(context, controller);
      }),
    );
  }
  
  Widget _buildDisabledState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '今日推荐单已禁用',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '在设置中开启今日推荐单功能',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showSettings(context),
            child: const Text('前往设置'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无推荐',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '多观看视频或增加观看历史后，系统将为您生成个性化推荐',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent(BuildContext context, TodayWatchController controller) {
    final theme = Theme.of(context);
    
    return CustomScrollView(
      slivers: [
        // UP 主榜
        if (controller.upRanks.isNotEmpty && controller.config.showUpRank)
          SliverToBoxAdapter(
            child: _buildUpRankSection(context, controller),
          ),
        
        // 推荐视频列表
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= controller.videoQueue.length) {
                return const SizedBox.shrink();
              }
              final video = controller.videoQueue[index];
              return _buildVideoCard(context, controller, video, index);
            },
            childCount: controller.videoQueue.length + 1,
          ),
        ),
      ],
    );
  }
  
  Widget _buildUpRankSection(BuildContext context, TodayWatchController controller) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(Style.cardSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '偏好 UP 主',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: controller.upRanks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final rank = controller.upRanks[index];
                return _buildUpRankChip(theme, rank);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  Widget _buildUpRankChip(ColorScheme theme, CreatorRank rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '${rank.name} (${rank.watchCount}次)',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.onPrimaryContainer,
        ),
      ),
    );
  }
  
  Widget _buildVideoCard(
    BuildContext context,
    TodayWatchController controller,
    TodayWatchVideoModel video,
    int index,
  ) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Style.cardSpace, vertical: 4),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 视频卡片
            VideoCardV(
              videoItem: video,
              onRemove: () {
                controller.markNotInterested(
                  video.bvid,
                  title: video.title,
                  creatorMid: video.ownerMid,
                  creatorName: video.ownerName,
                );
              },
            ),
            
            // 推荐理由
            if (controller.config.showReasonHint && 
                controller.explanationByBvid.containsKey(video.bvid))
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  controller.explanationByBvid[video.bvid] ?? '',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  void _showSettings(BuildContext context) {
    Get.to(() => const TodayWatchSettingsPage());
  }
}

/// 今日推荐单设置页面
class TodayWatchSettingsPage extends StatelessWidget {
  const TodayWatchSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TodayWatchController>();
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日推荐单设置'),
      ),
      body: Obx(() {
        final config = controller.config;
        
        return ListView(
          padding: const EdgeInsets.all(Style.cardSpace),
          children: [
            // 启用开关
            SwitchListTile(
              title: const Text('启用今日推荐单'),
              subtitle: const Text('根据观看历史生成个性化推荐'),
              value: controller.enabled.value,
              onChanged: (value) {
                controller.enabled.value = value;
              },
            ),
            
            const Divider(),
            
            // 推荐模式
            Text(
              '推荐模式',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    label: '轻松看',
                    selected: config.mode == TodayWatchMode.relax,
                    onTap: () => controller.updateConfig((c) => c.copyWith(mode: TodayWatchMode.relax)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeButton(
                    label: '深度学习',
                    selected: config.mode == TodayWatchMode.learn,
                    onTap: () => controller.updateConfig((c) => c.copyWith(mode: TodayWatchMode.learn)),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 推荐策略
            Text(
              '推荐策略',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StrategyChip(
                  label: '均衡推荐',
                  selected: config.strategy == TodayWatchStrategy.balanced,
                  onTap: () => controller.updateConfig((c) => c.copyWith(strategy: TodayWatchStrategy.balanced)),
                ),
                _StrategyChip(
                  label: '兴趣优先',
                  selected: config.strategy == TodayWatchStrategy.affinity,
                  onTap: () => controller.updateConfig((c) => c.copyWith(strategy: TodayWatchStrategy.affinity)),
                ),
                _StrategyChip(
                  label: '探索优先',
                  selected: config.strategy == TodayWatchStrategy.explore,
                  onTap: () => controller.updateConfig((c) => c.copyWith(strategy: TodayWatchStrategy.explore)),
                ),
              ],
            ),
            
            const Divider(),
            
            // 推荐规模
            Text(
              '推荐规模',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _IntSettingRow(
              label: 'UP 主榜数量',
              value: config.upRankLimit,
              values: const [3, 5, 8, 10],
              onChanged: (value) => controller.updateConfig((c) => c.copyWith(upRankLimit: value)),
            ),
            const SizedBox(height: 8),
            _IntSettingRow(
              label: '队列生成长度',
              value: config.queueBuildLimit,
              values: const [12, 20, 30, 40],
              onChanged: (value) => controller.updateConfig((c) => c.copyWith(queueBuildLimit: value)),
            ),
            const SizedBox(height: 8),
            _IntSettingRow(
              label: '卡片展示条数',
              value: config.queuePreviewLimit,
              values: const [4, 6, 8, 10],
              onChanged: (value) => controller.updateConfig((c) => c.copyWith(queuePreviewLimit: value)),
            ),
            
            const Divider(),
            
            // 显示选项
            SwitchListTile(
              title: const Text('显示 UP 主榜'),
              subtitle: const Text('在卡片中展示你近期偏好的创作者'),
              value: config.showUpRank,
              onChanged: (value) => controller.updateConfig((c) => c.copyWith(showUpRank: value)),
            ),
            SwitchListTile(
              title: const Text('显示推荐理由'),
              subtitle: const Text('显示"常看UP"、"近期更新"等提示文案'),
              value: config.showReasonHint,
              onChanged: (value) => controller.updateConfig((c) => c.copyWith(showReasonHint: value)),
            ),
            
            const Divider(),
            
            // 数据管理
            Text(
              '数据管理',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('清空推荐画像'),
              subtitle: const Text('清空本地学习到的偏好与不感兴趣反馈'),
              onTap: () => _showClearConfirm(context),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              '所有设置仅在本地生效，不上传你的历史记录。',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }),
    );
  }
  
  void _showClearConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空推荐画像'),
        content: const Text('确定清空本地推荐画像与不感兴趣反馈吗？该操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.find<TodayWatchController>().clearPersonalizationData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已清空，本地推荐将重新学习')),
              );
            },
            child: const Text('确定'),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _StrategyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StrategyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(label),
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
      ),
    );
  }
}

class _IntSettingRow extends StatelessWidget {
  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  const _IntSettingRow({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: values.map((v) => _IntChip(
            label: '$v',
            selected: value == v,
            onTap: () => onChanged(v),
          )).toList(),
        ),
      ],
    );
  }
}

class _IntChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IntChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
