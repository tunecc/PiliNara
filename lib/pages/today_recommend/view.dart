import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/models/model_rec_video_item_model.dart';
import 'package:PiliPlus/pages/today_recommend/controller.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TodayRecommendPage extends StatefulWidget {
  const TodayRecommendPage({super.key});
  @override
  State<TodayRecommendPage> createState() => _TodayRecommendPageState();
}

class _TodayRecommendPageState extends State<TodayRecommendPage>
    with AutomaticKeepAliveClientMixin {
  late final TodayRecommendController _controller = Get.put(TodayRecommendController());
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日推荐'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => _controller.queryData(true))],
      ),
      body: Obx(() {
        final state = _controller.loadingState.value;
        if (state is Loading) return const Center(child: CircularProgressIndicator());
        if (state is Error) return HttpError(message: state.message, onRetry: () => _controller.queryData(true));
        if (state is Success) {
          final items = _controller.dataList;
          if (items == null || items.isEmpty) return const Center(child: Text('暂无推荐内容'));
          return RefreshIndicator(
            onRefresh: () => _controller.queryData(true),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: items.length + (_controller.isEnd ? 0 : 1),
              itemBuilder: (context, index) {
                if (index >= items.length) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                final item = items[index];
                if (item is BaseRcmdVideoItemModel) return _TodayRecommendCard(item: item);
                return const SizedBox.shrink();
              },
            ),
          );
        }
        return const SizedBox.shrink();
      }),
    );
  }
}

class _TodayRecommendCard extends StatelessWidget {
  final BaseRcmdVideoItemModel item;
  const _TodayRecommendCard({required this.item});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => PageUtils.toVideoPage(item.bvid ?? '', item.aid),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: Stack(fit: StackFit.expand, children: [
              if (item.pic != null) Image.network(item.pic!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Center(child: Icon(Icons.image_not_supported)))),
              Positioned(right: 8, bottom: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)), child: Text(item.durationStr ?? '', style: const TextStyle(color: Colors.white, fontSize: 11)))),
            ])),
            Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Row(children: [
                Text(item.owner?.name ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const Spacer(),
                if (item.stat?.view != null) Text('${_fmt(item.stat!.view!)}播放', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
              ]),
            ])),
          ],
        ),
      ),
    );
  }
  String _fmt(int c) { if (c >= 100000000) return '${(c/100000000).toStringAsFixed(1)}亿'; if (c >= 10000) return '${(c/10000).toStringAsFixed(1)}万'; return c.toString(); }
}
