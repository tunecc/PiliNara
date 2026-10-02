import 'package:PiliPlus/services/media_source/kazumi_plugin.dart';
import 'package:PiliPlus/services/media_source/kazumi_rule_executor.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// Lists the episodes of a Kazumi rule search result.
class KazumiChapterPage extends StatefulWidget {
  const KazumiChapterPage({
    super.key,
    required this.pluginName,
    required this.url,
  });

  final String pluginName;
  final String url;

  @override
  State<KazumiChapterPage> createState() => _KazumiChapterPageState();
}

class _KazumiChapterPageState extends State<KazumiChapterPage> {
  final RxBool _loading = false.obs;
  final RxList<KazumiChapterItem> _items = <KazumiChapterItem>[].obs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  KazumiPlugin? get _plugin {
    for (final p in KazumiPluginService.stored) {
      if (p.name == widget.pluginName) return p;
    }
    return null;
  }

  Future<void> _load() async {
    final plugin = _plugin;
    if (plugin == null) return;
    _loading.value = true;
    final items = await KazumiRuleExecutor.chapters(plugin, widget.url);
    _items.assignAll(items);
    _loading.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.pluginName} · 剧集')),
      body: Obx(() {
        if (_loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_items.isEmpty) {
          return const Center(child: Text('未解析到剧集'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) => ListTile(
            title: Text(_items[index].name),
            subtitle: Text(
              _items[index].url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Get.to(
              () => KazumiChapterPage(
                pluginName: widget.pluginName,
                url: _items[index].url,
              ),
            ),
          ),
        );
      }),
    );
  }
}
