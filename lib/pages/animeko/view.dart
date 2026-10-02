/// 番剧聚合搜索页面
import 'package:PiliPlus/pages/animeko/controller.dart';
import 'package:PiliPlus/pages/animeko/widgets/resource_card.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class AnimekoPage extends StatefulWidget {
  const AnimekoPage({super.key});
  @override
  State<AnimekoPage> createState() => _AnimekoPageState();
}

class _AnimekoPageState extends State<AnimekoPage> {
  late final AnimekoController _controller;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = Get.put(AnimekoController());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    _controller.search(_searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('番剧聚合'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '搜索番剧名称...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 12),
                Obx(() => ElevatedButton(
                      onPressed: _controller.isLoading.value ? null : _performSearch,
                      child: _controller.isLoading.value
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('搜索'),
                    )),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (_controller.isLoading.value && _controller.allResources.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_controller.errorMsg.value.isNotEmpty) {
                return Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_controller.errorMsg.value),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _performSearch, child: const Text('重试')),
                  ],
                ));
              }
              if (_controller.allResources.isEmpty) {
                return const Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('输入番剧名称开始搜索', style: TextStyle(color: Colors.grey)),
                  ],
                ));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _controller.allResources.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ResourceCard(resource: _controller.allResources[index]),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
