/// 订阅页面 - 显示用户订阅的番剧
import 'package:PiliPlus/models_new/pgc/pgc_index_result/list.dart';
import 'package:PiliPlus/pages/animeko/subject_detail.dart';
import 'package:PiliPlus/services/animeko_service.dart';
import 'package:flutter/material.dart' as material;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class AnimekoCollectionPage extends StatefulWidget {
  const AnimekoCollectionPage({super.key});
  @override
  State<AnimekoCollectionPage> createState() => _AnimekoCollectionPageState();
}

class _AnimekoCollectionPageState extends State<AnimekoCollectionPage> {
  late final AnimekoService _service;

  @override
  void initState() {
    super.initState();
    _service = Get.put(AnimekoService());
    _service.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的订阅'), centerTitle: true),
      body: Obx(() {
        if (_service.isLoading.value && _service.subscriptions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_service.errorMsg.value.isNotEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_service.errorMsg.value),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => _service.init(), child: const Text('重试')),
          ]));
        }
        if (_service.subscriptions.isEmpty) {
          return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.library_books, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无订阅', style: TextStyle(color: Colors.grey)),
          ]));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.7,
          ),
          itemCount: _service.subscriptions.length,
          itemBuilder: (context, index) {
            final item = _service.subscriptions[index];
            return GestureDetector(
              onTap: () => Get.to(() => AnimekoSubjectDetailPage(seasonId: item.seasonId ?? 0)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(item.cover ?? '', width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey[300], child: const Icon(Icons.movie, size: 40)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}
