/// Bangumi sync service for PiliNara.
///
/// Syncs the local "later" (watching list) with Bangumi.tv collections.
/// This enables cross-device watch progress synchronization.

import 'package:PiliNara/http/bangumi.dart';
import 'package:PiliNara/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class BangumiSyncService extends GetxController {
  final BangumiHttp bangumi = BangumiHttp();

  final RxBool isSyncing = false.obs;
  final RxString errorMsg = ''.obs;
  final RxInt syncedCount = 0.obs;

  /// Username stored in preferences (set after login)
  String? get username => Pref.bangumiUsername;

  /// Check if user is logged into Bangumi
  bool get isLoggedIn => username != null && username!.isNotEmpty;

  /// Sync local later list with Bangumi collection.
  /// For each item in local later, check/update Bangumi status.
  Future<void> syncLaterList(List<Map<String, dynamic>> localLater) async {
    if (!isLoggedIn) {
      errorMsg.value = '请先登录 Bangumi';
      return;
    }

    isSyncing.value = true;
    errorMsg.value = '';
    syncedCount.value = 0;

    try {
      for (final item in localLater) {
        final bangumiId = item['bangumi_subject_id'] as int?;
        if (bangumiId == null) continue;

        try {
          // Check current Bangumi status
          final collection = await bangumi.getCollection(
            username: username!,
            subjectId: bangumiId,
          );

          if (collection == null) {
            // Not in Bangumi yet, add as "watching"
            await bangumi.updateCollection(
              username: username!,
              subjectId: bangumiId,
              type: BangumiCollectionType.watching,
            );
            syncedCount.value++;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[BangumiSync] Failed for subject $bangumiId: $e');
          }
        }
      }
    } catch (e) {
      errorMsg.value = '同步失败: $e';
    } finally {
      isSyncing.value = false;
    }
  }

  /// Search Bangumi for an anime and return potential matches.
  Future<List<BangumiSubject>> searchAnime(String keyword) async {
    try {
      return await bangumi.search(keyword: keyword);
    } catch (e) {
      if (kDebugMode) debugPrint('[BangumiSync] Search error: $e');
      return [];
    }
  }

  /// Update Bangumi collection status for a subject.
  Future<bool> updateStatus({
    required int subjectId,
    required BangumiCollectionType type,
    String? comment,
  }) async {
    if (!isLoggedIn) return false;

    try {
      return await bangumi.updateCollection(
        username: username!,
        subjectId: subjectId,
        type: type,
        comment: comment,
      );
    } catch (e) {
      errorMsg.value = '更新失败: $e';
      return false;
    }
  }
}
