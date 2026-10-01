import 'package:PiliPlus/pages/bangumi/controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

  static const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Obx(() {
      if (_ctrl.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final error = _ctrl.error.value;
      if (error != null) {
        return Center(
          child: Column(
            mainAxisSize: .min,
            children: [
              Text(error),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _ctrl.refreshCalendar,
                child: const Text('重试'),
              ),
            ],
          ),
        );
      }
      final items = _ctrl.items;
      return RefreshIndicator(
        onRefresh: _ctrl.refreshCalendar,
        child: ListView.builder(
          controller: _ctrl.scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: item.image.isEmpty
                    ? const Icon(Icons.movie_outlined)
                    : Image.network(
                        item.image,
                        width: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image),
                      ),
                title: Text(item.displayName),
                subtitle: Text(
                  [
                    if (item.weekdayId != null &&
                        item.weekdayId! >= 1 &&
                        item.weekdayId! <= 7)
                      weekdays[item.weekdayId!],
                    if (item.airDate.isNotEmpty) item.airDate,
                    if (item.rating != null) '评分 ${item.rating}',
                  ].join(' · '),
                ),
                trailing: item.collectionCount != null
                    ? Text(
                        '${item.collectionCount} 人在看',
                        style: theme.textTheme.labelSmall,
                      )
                    : null,
              ),
            );
          },
        ),
      );
    });
  }
}
