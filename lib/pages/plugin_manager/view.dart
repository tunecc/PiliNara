import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:PiliPlus/plugins/plugin.dart';
import 'package:PiliPlus/services/plugin/plugin_import_parser.dart';
import 'package:PiliPlus/services/plugin/plugin_storage.dart';
import 'package:PiliPlus/utils/rule_encoding.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/pages/plugin_editor/rule_management_widgets.dart';
import 'package:dio/dio.dart';

/// KazumiRules 热门规则列表（内置默认订阅）
const _defaultRuleUrls = [
  'https://raw.githubusercontent.com/Predidit/KazumiRules/main/DM84.json',
  'https://raw.githubusercontent.com/Predidit/KazumiRules/main/FQDM.json',
  'https://raw.githubusercontent.com/Predidit/KazumiRules/main/AGE.json',
  'https://raw.githubusercontent.com/Predidit/KazumiRules/main/BF.json',
  'https://raw.githubusercontent.com/Predidit/KazumiRules/main/IF.json',
  'https://raw.githubusercontent.com/Predidit/KazumiRules/main/LMM.json',
  'https://raw.githubusercontent.com/Predidit/KazumiRules/main/HZDM.json',
  'https://raw.githubusercontent.com/Predidit/KazumiRules/main/7sefun.json',
];

class PluginManagerPage extends StatefulWidget {
  const PluginManagerPage({super.key});
  @override
  State<PluginManagerPage> createState() => _PluginManagerPageState();
}

class _PluginManagerPageState extends State<PluginManagerPage> {
  List<Plugin> _plugins = [];
  bool _loading = true;
  String? _importError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _loading = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final list = PluginStorage.load();
      setState(() { _plugins = list; _loading = false; });
    });
  }

  void _save() {
    PluginStorage.save(_plugins);
  }

  Future<void> _importSingle(Plugin plugin) async {
    final key = plugin.name.toLowerCase();
    if (_plugins.any((p) => p.name.toLowerCase() == key)) {
      setState(() => _plugins[_plugins.indexWhere((p) => p.name.toLowerCase() == key)] = plugin);
    } else {
      setState(() => _plugins.add(plugin));
    }
    _save();
  }

  Future<void> _importFromUrl(String url) async {
    setState(() => _importError = null);
    try {
      final resp = await Dio().get(url);
      final data = resp.data;
      if (data is! String) { setState(() => _importError = '响应不是文本'); return; }
      final parseResult = PluginImportParser.parse(data);
      for (final p in parseResult.plugins) await _importSingle(p);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入 ${parseResult.plugins.length} 条规则${parseResult.duplicateCount > 0 ? '，跳过 ${parseResult.duplicateCount} 重复' : ''}')),
      );
    } catch (e) {
      setState(() => _importError = '导入失败: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
    }
  }

  Future<void> _importFromText(String text) async {
    setState(() => _importError = null);
    final result = PluginImportParser.parse(text);
    for (final p in result.plugins) await _importSingle(p);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('导入 ${result.plugins.length} 条规则${result.duplicateCount > 0 ? '，跳过 ${result.duplicateCount} 重复' : ''}')),
    );
  }

  void _showImportDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => _ImportSheetBody(
          onImport: _importFromText,
          onLoadDefaults: () async {
            for (final url in _defaultRuleUrls) await _importFromUrl(url);
          },
        ),
      ),
    );
  }

  void _editPlugin(Plugin plugin) {
    final fc = TextEditingController(text: jsonEncode(plugin.toJson()));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('编辑规则：${plugin.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: fc,
            maxLines: 20,
            decoration: const InputDecoration(hintText: '粘贴 JSON 规则'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              try {
                final parsed = jsonDecode(fc.text) as Map<String, dynamic>;
                final p = Plugin.fromJson(parsed);
                await _importSingle(p);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('JSON 解析失败: $e')));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _sharePlugin(Plugin plugin) {
    final link = jsonToKazumiBase64(jsonEncode(plugin.toJson()));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('分享规则'),
        content: SelectableText(link, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制规则链接'))); }
            },
            child: const Text('复制链接'),
          ),
        ],
      ),
    );
  }

  void _deletePlugin(Plugin plugin) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('删除「${plugin.name}」？'),
        content: const Text('删除后将不再使用此来源搜索番剧。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () { setState(() => _plugins.remove(plugin)); _save(); if (mounted) Navigator.pop(context); }, child: const Text('删除')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('订阅规则管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plugins.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.import_contacts_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('暂无订阅规则', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('点击下方按钮导入 KazumiRules', style: TextStyle(color: Colors.grey)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _plugins.length,
                  itemBuilder: (context, i) {
                    final p = _plugins[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                              style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                        ),
                        title: Text(p.name.isEmpty ? '(无名规则)' : p.name),
                        subtitle: Text(p.baseUrl.isEmpty ? '' : p.baseUrl.replaceAll(RegExp(r'https?://'), '')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editPlugin(p), tooltip: '编辑'),
                          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () => _sharePlugin(p), tooltip: '分享'),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deletePlugin(p), tooltip: '删除'),
                        ]),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showImportDialog,
        icon: const Icon(Icons.add),
        label: const Text('导入规则'),
      ),
    );
  }
}

class _ImportSheetBody extends StatefulWidget {
  const _ImportSheetBody({required this.onImport, required this.onLoadDefaults});
  final Future<void> Function(String) onImport;
  final Future<void> Function() onLoadDefaults;

  @override
  State<_ImportSheetBody> createState() => _ImportSheetBodyState();
}

class _ImportSheetBodyState extends State<_ImportSheetBody> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        controller: ScrollController(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('导入规则', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              EditorTextField(controller: _ctrl, label: '规则内容', hint: '粘贴 kazumi:// 链接或 JSON，支持多条'),
              const SizedBox(height: 12),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('导入'),
                    onPressed: _ctrl.text.trim().isEmpty ? null : () async {
                      setState(() => _error = null);
                      await widget.onImport(_ctrl.text);
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async { await widget.onLoadDefaults(); if (mounted) Navigator.pop(context); },
                  child: const Text('加载默认'),
                ),
              ]),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ],
          ),
        ),
      ),
    );
  }
}

class EditorTextField extends StatelessWidget {
  const EditorTextField({super.key, required this.controller, required this.label, this.hint, this.maxLines = 1});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(label, style: theme.textTheme.labelLarge),
      const SizedBox(height: 8),
      TextField(controller: controller, maxLines: maxLines, autocorrect: false, enableSuggestions: false,
        style: maxLines > 1 ? theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace') : null,
        decoration: ruleInputDecoration(context, hint: hint),
      ),
    ]);
  }
}
