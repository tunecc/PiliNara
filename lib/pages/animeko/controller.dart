/// Animeko 聚合控制器
import 'package:PiliPlus/http/mikan.dart';
import 'package:PiliPlus/models_new/animeko/animeko_resource.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class AnimekoController extends GetxController {
  final MikanHttp mikan = MikanHttp();
  
  final RxString searchQuery = ''.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMsg = ''.obs;
  final RxList<AnimekoResource> allResources = RxList<AnimekoResource>([]);
  final RxInt totalMikan = 0.obs;
  final RxInt totalDmhy = 0.obs;

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      allResources.clear();
      totalMikan.value = 0;
      totalDmhy.value = 0;
      errorMsg.value = '';
      return;
    }

    isLoading.value = true;
    errorMsg.value = '';

    try {
      final subjects = await mikan.search(query);
      totalMikan.value = subjects.length;
      
      // TODO: 添加更多数据源
      allResources.value = [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AnimekoController] Search error: $e\n$stackTrace');
      }
      errorMsg.value = '搜索失败: $e';
    } finally {
      isLoading.value = false;
    }
  }
}
