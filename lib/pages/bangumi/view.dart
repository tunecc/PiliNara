import 'package:PiliPlus/models/bangumi/calendar_item.dart';
import 'package:PiliPlus/pages/bangumi/controller.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class BangumiPage extends StatefulWidget {
  const BangumiPage({super.key});

  @override
  State<BangumiPage> createState() => _BangumiPageState();
}

class _BangumiPageState extends State<BangumiPage>
    with AutomaticKeepAliveClientMixin {
  late final BangumiController _ctrl = Get.put(BangumiController());

  @override
  bool get wantKeepAlive => true;

  static const _weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Obx(() {
      if (_ctrl.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final error = _ctrl.error.value;
      if (error != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _ctrl.onRefresh,
                child: const Text('重试'),
              ),
            ],
          ),
        );
      }
      final items = _ctrl.items;
      return RefreshIndicator(
        onRefresh: _ctrl.onRefresh,
        child: CustomScrollView(
          controller: _ctrl.scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '本季新番 · 共 ${items.length} 部',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130,
                  childAspectRatio: 0.52,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _BangumiCard(
                    item: items[index],
                    weekday: (items[index].weekdayId ?? 0) >= 1 &&
                            (items[index].weekdayId ?? 0) <= 7
                        ? _weekdays[items[index].weekdayId!]
                        : null,
                  ),
                  childCount: items.length,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _BangumiCard extends StatelessWidget {
  const _BangumiCard({required this.item, this.weekday});

  final BangumiCalendarItem item;
  final String? weekday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.image.isEmpty)
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.movie_outlined),
                  )
                else
                  Image.network(
                    item.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                if (item.rating != null && item.rating! > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        if (weekday != null)
          Text(
            weekday!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
      ],
    );
  }
}
