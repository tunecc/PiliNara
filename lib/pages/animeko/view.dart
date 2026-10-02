/// Animeko aggregation page UI.
///
/// Displays search results from multiple anime data sources (Mikan, DMHY)
/// in a unified interface.

import 'package:PiliNara/models_new/animeko/animeko_resource.dart';
import 'package:PiliNara/pages/animeko/controller.dart';
import 'package:PiliNara/pages/animeko/widgets/resource_card.dart';
import 'package:PiliNara/utils/page_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class AnimekoPage extends StatefulWidget {
  const AnimekoPage({super.key});

  @override
  State<AnimekoPage> createState() => _AnimekoPageState();
}

class _AnimekoPageState extends State<AnimekoPage> {
  late final AnimekoController controller;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = Get.put(AnimekoController());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    controller.search(_searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('番剧聚合'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索番剧名称...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        gapPadding: 0,
                      ),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 12),
                Obx(() => ElevatedButton(
                      onPressed: controller.isLoading.value ? null : _performSearch,
                      child: controller.isLoading.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('搜索'),
                    )),
              ],
            ),
          ),

          // Filters
          Obx(() {
            if (controller.allResources.isEmpty && !controller.isLoading.value) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _filterChip('全部', controller.sourceFilter.value == '全部',
                      () => controller.setSourceFilter('全部')),
                  const SizedBox(width: 8),
                  _filterChip('蜜柑计划', controller.sourceFilter.value == '蜜柑计划',
                      () => controller.setSourceFilter('蜜柑计划')),
                  const SizedBox(width: 8),
                  _filterChip('动漫花园', controller.sourceFilter.value == '动漫花园',
                      () => controller.setSourceFilter('动漫花园')),
                  const Spacer(),
                  Checkbox(
                    value: controller.showTorrentOnly.value,
                    onChanged: (v) => controller.toggleTorrentOnly(v ?? false),
                  ),
                  const Text('仅BT'),
                ],
              ),
            );
          }),

          // Results count
          Obx(() {
            if (controller.allResources.isEmpty && !controller.isLoading.value) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '找到 ${controller.allResources.length} 个资源'
                '${controller.totalMikan.value > 0 ? ' (蜜柑: ${controller.totalMikan.value})' : ''}'
                '${controller.totalDmhy.value > 0 ? ' (DMHY: ${controller.totalDmhy.value})' : ''}',
                style: const TextStyle(color: Colors.grey),
              ),
            );
          }),

          // Results list
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.allResources.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.errorMsg.value.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(controller.errorMsg.value),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _performSearch,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                );
              }

              if (controller.allResources.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('输入番剧名称开始搜索', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              final filtered = controller.filteredResources;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final resource = filtered[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ResourceCard(resource: resource),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }
}
