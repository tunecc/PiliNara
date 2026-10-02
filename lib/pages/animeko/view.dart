/// Animeko aggregation page UI.
///
/// Full-featured page with:
/// - Bangumi-integrated search (exact match via Bangumi ID)
/// - Multi-source results (Mikan + DMHY)
/// - Episode/range filtering
/// - Resolution/alliance sorting
/// - Magnet link handling

import 'package:PiliPlus/models_new/animeko/animeko_resource.dart';
import 'package:PiliPlus/pages/animeko/widgets/resource_card.dart';
import 'package:PiliPlus/services/animeko_service.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart' as material;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class AnimekoPage extends StatefulWidget {
  const AnimekoPage({super.key});

  @override
  State<AnimekoPage> createState() => _AnimekoPageState();
}

class _AnimekoPageState extends State<AnimekoPage> {
  late final AnimekoService service;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    service = Get.put(AnimekoService());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    service.search(_searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('番剧聚合'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Get.toNamed('/animekoSettings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: material.TextField(
                    controller: _searchController,
                    decoration: material.InputDecoration(
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
                      onPressed: service.isLoading.value ? null : _performSearch,
                      child: service.isLoading.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: material.CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('搜索'),
                    )),
              ],
            ),
          ),

          // Episode filter (shown when searching with episode context)
          Obx(() {
            if (service.allResources.isEmpty && !service.isLoading.value) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip('全部', service.preferredSource.value == '全部',
                      () => service.setSourceFilter('全部')),
                  _filterChip('蜜柑计划', service.preferredSource.value == '蜜柑计划',
                      () => service.setSourceFilter('蜜柑计划')),
                  _filterChip('动漫花园', service.preferredSource.value == '动漫花园',
                      () => service.setSourceFilter('动漫花园')),
                  const SizedBox(width: 8),
                  // Resolution filter
                  DropdownButton<String>(
                    value: service.preferredResolution.value == '全部' ? null : service.preferredResolution.value,
                    items: ['全部', '4K', '1080P', '720P', '480P']
                        .map((r) => DropdownMenuItem(
                              value: r == '全部' ? null : r,
                              child: Text(r),
                            ))
                        .toList(),
                    onChanged: (v) => service.setResolutionFilter(v ?? '全部'),
                  ),
                  const Spacer(),
                  material.Checkbox(
                    value: service.showTorrentOnly.value,
                    onChanged: (v) => service.toggleTorrentOnly(v ?? false),
                  ),
                  const Text('仅BT'),
                ],
              ),
            );
          }),

          // Results count
          Obx(() {
            if (service.allResources.isEmpty && !service.isLoading.value) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '找到 ${service.allResources.length} 个资源'
                '${service.totalMikan.value > 0 ? ' (蜜柑: ${service.totalMikan.value})' : ''}'
                '${service.totalDmhy.value > 0 ? ' (DMHY: ${service.totalDmhy.value})' : ''}',
                style: const TextStyle(color: Colors.grey),
              ),
            );
          }),

          // Results list
          Expanded(
            child: Obx(() {
              if (service.isLoading.value && service.allResources.isEmpty) {
                return const Center(child: material.CircularProgressIndicator());
              }

              if (service.errorMsg.value.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(service.errorMsg.value),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _performSearch,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                );
              }

              if (service.allResources.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('输入番剧名称开始搜索', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('支持 Bangumi 精确匹配 + Mikan/DMHY 双源聚合', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: service.allResources.length,
                itemBuilder: (context, index) {
                  final resource = service.allResources[index];
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
