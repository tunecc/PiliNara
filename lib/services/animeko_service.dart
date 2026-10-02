/// Animeko 服务 - 整合 B 站 PGC 和 Mikan BT 源
import 'package:PiliPlus/http/pgc.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/pgc/pgc_index_result/list.dart';
import 'package:PiliPlus/models_new/pgc/pgc_timeline/result.dart';
import 'package:PiliPlus/http/mikan.dart';
import 'package:PiliPlus/models_new/animeko/animeko_resource.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class AnimekoService extends GetxController {
  final MikanHttp mikan = MikanHttp();
  
  // 订阅列表
  final RxList<PgcIndexItem> subscriptions = RxList<PgcIndexItem>([]);
  
  // 搜索历史
  final RxList<String> searchHistory = RxList<String>([]);
  
  // 加载状态
  final RxBool isLoading = false.obs;
  final RxString errorMsg = ''.obs;

  Future<void> init() async {
    isLoading.value = true;
    errorMsg.value = '';
    try {
      await _loadSubscriptions();
    } catch (e) {
      errorMsg.value = '加载失败: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadSubscriptions() async {
    final res = await PgcHttp.pgcIndex(page: 1);
    if (res case Success(:final data)) {
      subscriptions.value = data ?? [];
    }
  }

  /// 搜索番剧（B 站 + Mikan）
  Future<List<AnimekoResource>> search(String keyword) async {
    final resources = <AnimekoResource>[];
    
    // TODO: 添加 B 站 PGC 搜索结果
    // 目前先返回空列表，需要对接 B 站番剧搜索 API
    
    return resources;
  }

  /// 添加订阅
  Future<void> addSubscription(PgcIndexItem item) async {
    if (!subscriptions.any((s) => s.seasonId == item.seasonId)) {
      subscriptions.add(item);
    }
  }

  /// 移除订阅
  Future<void> removeSubscription(int seasonId) async {
    subscriptions.removeWhere((s) => s.seasonId == seasonId);
  }

  bool isSubscribed(int seasonId) => subscriptions.any((s) => s.seasonId == seasonId);
}
