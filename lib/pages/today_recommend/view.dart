import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/pages/today_recommend/controller.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

class TodayRecommendPage extends StatefulWidget {
  const TodayRecommendPage({super.key});

  @override
  State<TodayRecommendPage> createState() => _TodayRecommendPageState();
}

class _TodayRecommendPageState extends State<TodayRecommendPage>
    with AutomaticKeepAliveClientMixin {
  late final TodayRecommendController _controller =
      Get.put(TodayRecommendController());

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日推荐'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.queryData(true),
          ),
        ],
      ),
      body: Obx(() {
        final state = _controller.loadingState.value;
        return switch (state) {
          Loading() => const Center(child: CircularProgressIndicator()),
          Error(:final errMsg) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    Text(errMsg ?? '加载失败'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => _controller.queryData(true),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          Success(:final response) => _buildList(response),
        };
      }),
    );
  }

  Widget _buildList(List<RcmdVideoItemAppModel>? items) {
    if (items == null || items.isEmpty) {
      return const Center(child: Text('暂无推荐内容'));
    }
    return RefreshIndicator(
      onRefresh: () => _controller.queryData(true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: items.length + (_controller.isEnd ? 0 : 1),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _TodayRecommendCard(item: items[index]);
        },
      ),
    );
  }
}

class _TodayRecommendCard extends StatelessWidget {
  const _TodayRecommendCard({required this.item});

  final RcmdVideoItemAppModel item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => PageUtils.toVideoPage(
          bvid: item.bvid,
          cid: item.cid ?? 0,
          cover: item.cover,
          title: item.title,
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.cover != null)
                    Image.network(
                      item.cover!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        DurationUtils.formatDuration(item.duration),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.owner.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (item.stat.view != null)
                        Text(
                          '${NumUtils.numFormat(item.stat.view)}播放',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
