import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/services/media_source/media_source.dart';
import 'package:PiliPlus/services/media_source/rss_media_source.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:get/get.dart';

class MediaSourceController extends GetxController {
  final RxList<RssMediaSource> sources = <RssMediaSource>[].obs;
  final RxBool isEnabled = true.obs;

  @override
  void onInit() {
    super.onInit();
    isEnabled.value = GStorage.setting.get(SettingBoxKey.mediaSourceEnabled, defaultValue: true);
    _loadSources();
  }

  void _loadSources() {
    // Load built-in sources; in future, also load user-configured custom sources
    sources.assignAll(BuiltInSources.defaults());
  }

  Future<void> toggleEnabled(bool value) async {
    isEnabled.value = value;
    await GStorage.setting.put(SettingBoxKey.mediaSourceEnabled, value);
  }

  Future<void> toggleSource(String id, bool enabled) async {
    final idx = sources.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      sources[idx].enabled = enabled;
      sources.refresh();
      logger.i('MediaSource[$id] enabled=$enabled');
    }
  }

  Future<void> updateTier(String id, int tier) async {
    final idx = sources.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      // RssMediaSource.tier is final, so we'd need to rebuild.
      // For now just log; full implementation would persist custom tiers.
      logger.i('MediaSource[$id] tier change requested to $tier (not yet persisted)');
    }
  }
}
