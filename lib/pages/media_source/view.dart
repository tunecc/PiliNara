import 'package:PiliPlus/pages/media_source/controller.dart';
import 'package:PiliPlus/pages/media_source/search_view.dart';
import 'package:PiliPlus/services/media_source/kazumi_plugin.dart';
import 'package:PiliPlus/services/media_source/rss_media_source.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class MediaSourcePage extends StatefulWidget {
  const MediaSourcePage({super.key});

  @override
  State<MediaSourcePage> createState() => _MediaSourcePageState();
}

class _MediaSourcePageState extends State<MediaSourcePage> {
  late final MediaSourceController _ctrl = Get.put(MediaSourceController());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅源管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索外部源',
            onPressed: _searchExternal,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined),
            tooltip: '同步 Kazumi 规则',
            onPressed: _syncPlugins,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加订阅源',
            onPressed: _showAddDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final builtIn = _ctrl.sources
            .where((s) => _ctrl.isBuiltIn(s.id))
            .toList();
        final custom = _ctrl.sources
            .where((s) => !_ctrl.isBuiltIn(s.id))
            .toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            SwitchListTile(
              title: const Text('启用订阅源'),
              subtitle: const Text('关闭后番剧详情页不显示外部源搜索结果'),
              value: _ctrl.isEnabled.value,
              onChanged: _ctrl.toggleEnabled,
            ),
            const Divider(height: 1),
            _SectionTitle('内置数据源'),
            ...builtIn.map(_buildTile),
            const Divider(height: 1),
            _SectionTitle('自定义订阅源'),
            if (custom.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  '暂无自定义订阅源，点击右下角 + 添加。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ...custom.map(_buildTile),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '提示：订阅源用于在番剧详情页聚合搜索外部播放资源（BT/在线）。'
                '地址需包含 {query} 占位符，搜索时会替换为番剧标题。'
                '数据来自第三方站点，PiliNara 不提供任何视频资源。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _SectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );

  Widget _buildTile(RssMediaSource src) {
    final theme = Theme.of(context);
    final canDelete = !_ctrl.isBuiltIn(src.id);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          src.metadata.name.substring(0, 1),
          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
      title: Text(src.metadata.name),
      subtitle: Text('Tier ${src.tier} · ${src.enabled ? '已启用' : '已禁用'}'),
      trailing: Row(
        mainAxisSize: .min,
        children: [
          Switch(
            value: src.enabled,
            onChanged: (v) => _ctrl.toggleSource(src.id, v),
          ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
              onPressed: () => _ctrl.removeSource(src.id),
            ),
        ],
      ),
      onLongPress: canDelete ? () => _ctrl.removeSource(src.id) : null,
    );
  }

  Future<void> _searchExternal() async {
    final controller = TextEditingController();
    final keyword = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('搜索外部源'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '番剧 / 视频标题',
            hintText: '例如：孤独摇滚',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
    if (keyword == null || keyword.isEmpty) return;
    Get.to(() => MediaSourceSearchPage(keyword: keyword));
  }

  Future<void> _syncPlugins() async {
    SmartDialog.showLoading(msg: '正在同步规则');
    final res = await KazumiPluginService.syncRemote();
    SmartDialog.dismiss();
    final error = res.error;
    SmartDialog.showToast(
      error ?? '规则已同步，新增 ${res.added} 条，共 ${res.total} 条',
    );
    if (mounted) setState(() {});
  }

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加订阅源'),
        content: Column(
          mainAxisSize: .min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例如：动漫花园',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '订阅地址',
                hintText: 'https://example.org/rss?keyword={query}',
                helperText: '需包含 {query} 占位符',
              ),
              maxLines: 2,
              minLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await _ctrl.addSource(
      name: nameController.text,
      url: urlController.text,
    );
    if (error != null) {
      SmartDialog.showToast(error);
    } else {
      SmartDialog.showToast('已添加');
    }
  }
}
