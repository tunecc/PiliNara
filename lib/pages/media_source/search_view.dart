import 'package:PiliPlus/pages/media_source/controller.dart';
import 'package:PiliPlus/pages/media_source/kazumi_chapter_view.dart';
import 'package:PiliPlus/services/media_source/kazumi_plugin.dart';
import 'package:PiliPlus/services/media_source/kazumi_rule_executor.dart';
import 'package:PiliPlus/services/media_source/media_source.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// Searches every enabled subscription source for a keyword and lists the
/// media it finds, grouped by source.
class MediaSourceSearchPage extends StatefulWidget {
  const MediaSourceSearchPage({super.key, required this.keyword});

  final String keyword;

  @override
  State<MediaSourceSearchPage> createState() => _MediaSourceSearchPageState();
}

class _MediaSourceSearchPageState extends State<MediaSourceSearchPage> {
  final RxBool _loading = false.obs;
  final RxnString _error = RxnString();
  final RxList<({String name, List<MediaMatch> matches})> _results =
      <({String name, List<MediaMatch> matches})>[].obs;
  final RxList<({String name, List<KazumiSearchItem> items})> _kazumiResults =
      <({String name, List<KazumiSearchItem> items})>[].obs;

  late final MediaSourceController _ctrl =
      Get.isRegistered<MediaSourceController>()
      ? Get.find<MediaSourceController>()
      : Get.put(MediaSourceController());

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    _loading.value = true;
    _error.value = null;
    _results.clear();
    _kazumiResults.clear();
    if (!_ctrl.isEnabled.value) {
      _error.value = '订阅源总开关已关闭';
      _loading.value = false;
      return;
    }
    final sources = _ctrl.sources.where((s) => s.enabled).toList();
    if (sources.isEmpty) {
      _error.value = '没有启用的订阅源';
      _loading.value = false;
      return;
    }
    final request = MediaFetchRequest(subjectNames: [widget.keyword]);
    for (final source in sources) {
      final matches = <MediaMatch>[];
      try {
        await for (final batch in source.fetch(request)) {
          matches.addAll(batch);
        }
      } catch (_) {
        // A failing source must not hide the others' results.
      }
      _results.add((name: source.metadata.name, matches: matches));
    }
    for (final plugin in KazumiPluginService.stored.where((p) => p.enabled)) {
      final items = await KazumiRuleExecutor.search(plugin, widget.keyword);
      _kazumiResults.add((name: plugin.name, items: items));
    }
    _loading.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('外部源搜索 · ${widget.keyword}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _search,
          ),
        ],
      ),
      body: Obx(() {
        if (_loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final error = _error.value;
        if (error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _search,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }
        final total = _results.fold<int>(0, (a, b) => a + b.matches.length);
        if (total == 0) {
          return const Center(child: Text('所有订阅源均未找到结果'));
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final group in _results)
              if (group.matches.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    '${group.name} · ${group.matches.length} 条',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                for (final match in group.matches)
                  ListTile(
                    leading: Icon(
                      match.media.locationType == MediaLocationType.torrent
                          ? Icons.download_outlined
                          : Icons.play_circle_outline,
                    ),
                    title: Text(
                      match.media.originalUrl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    subtitle: Text(
                      [
                        match.episodeRange.toString(),
                        if (match.media.properties.resolution != null)
                          match.media.properties.resolution!,
                        if (match.media.properties.subtitleGroup != null)
                          match.media.properties.subtitleGroup!,
                        match.kind == MatchKind.exact ? '精确匹配' : '模糊匹配',
                      ].join(' · '),
                    ),
                  ),
              ],
            for (final group in _kazumiResults)
              if (group.items.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    '${group.name} · ${group.items.length} 条',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
                for (final item in group.items)
                  ListTile(
                    leading: const Icon(Icons.rule),
                    title: Text(item.name),
                    subtitle: Text(
                      item.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Get.to(
                      () => KazumiChapterPage(
                        pluginName: group.name,
                        url: item.url,
                      ),
                    ),
                  ),
              ],
          ],
        );
      }),
    );
  }
}
