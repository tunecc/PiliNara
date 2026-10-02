/// 源管理页面
import 'package:PiliPlus/http/tvbox.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SourceManagerPage extends StatefulWidget {
  const SourceManagerPage({super.key});
  @override
  State<SourceManagerPage> createState() => _SourceManagerPageState();
}

class _SourceManagerPageState extends State<SourceManagerPage> {
  final TVBoxHttp _tvbox = TVBoxHttp();
  final List<TVBoxSource> _sources = [];
  bool _isLoading = false;
  final _urlController = TextEditingController();

  Future<void> _loadSources() async {
    setState(() => _isLoading = true);
    try {
      final sources = await _tvbox.loadSources('https://raw.githubusercontent.com/gaotianliuyun/gao/master/0821.json');
      setState(() => _sources.addAll(sources));
    } catch (e) {
      _showSnackBar('加载源失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addSource() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final source = await _tvbox.parseSource(url);
      if (source != null) {
        _sources.add(source);
        _urlController.clear();
        _showSnackBar('已添加源: ${source.name}');
      }
    } catch (e) {
      _showSnackBar('添加源失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeSource(TVBoxSource source) {
    setState(() => _sources.remove(source));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('源管理')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: '输入源 URL 或仓库地址',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _addSource,
                  child: const Text('添加'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading && _sources.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _sources.length,
                    itemBuilder: (context, index) {
                      final source = _sources[index];
                      return ListTile(
                        title: Text(source.name),
                        subtitle: Text(source.url),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeSource(source),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
