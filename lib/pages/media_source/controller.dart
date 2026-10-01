import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/services/media_source/media_source.dart';
import 'package:PiliPlus/services/media_source/rss_media_source.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:get/get.dart';

class MediaSourceController extends GetxController {
  final RxList<RssMediaSource> sources = <RssMediaSource>[].obs;
  final RxBool isEnabled = true.obs;

  /// ids of the built-in sources; these can be disabled but never deleted.
  static final Set<String> _builtInIds =
      BuiltInSources.defaults().map((s) => s.id).toSet();

  bool isBuiltIn(String id) => _builtInIds.contains(id);

  @override
  void onInit() {
    super.onInit();
    isEnabled.value = GStorage.setting.get(
      SettingBoxKey.mediaSourceEnabled,
      defaultValue: true,
    );
    _loadSources();
  }

  void _loadSources() {
    final disabled = _disabledIds();
    final list = BuiltInSources.defaults()
        .map(
          (s) => RssMediaSource(
            id: s.id,
            name: s.metadata.name,
            feedUrlTemplate: s.feedUrlTemplate,
            tier: s.tier,
            enabled: !disabled.contains(s.id),
          ),
        )
        .toList();
    list.addAll(_loadCustom().map((s) => s..enabled = !disabled.contains(s.id)));
    sources.assignAll(list);
  }

  Set<String> _disabledIds() {
    final raw = GStorage.setting.get(SettingBoxKey.mediaSourceDisabled);
    if (raw is List) {
      return raw.map((e) => e.toString()).toSet();
    }
    return const <String>{};
  }

  Future<void> _saveDisabledIds() async {
    final ids = sources
        .where((s) => !s.enabled)
        .map((s) => s.id)
        .toList(growable: false);
    await GStorage.setting.put(SettingBoxKey.mediaSourceDisabled, ids);
  }

  List<RssMediaSource> _loadCustom() {
    final raw = GStorage.setting.get(SettingBoxKey.mediaSourceCustom);
    if (raw is! List) return const <RssMediaSource>[];
    final result = <RssMediaSource>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final source = RssMediaSource.fromJson(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (source != null) result.add(source);
    }
    return result;
  }

  Future<void> _saveCustom() async {
    final custom = sources
        .where((s) => !isBuiltIn(s.id))
        .map((s) => s.toJson())
        .toList(growable: false);
    await GStorage.setting.put(SettingBoxKey.mediaSourceCustom, custom);
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
      await _saveDisabledIds();
    }
  }

  bool get hasSearchable => sources.any((s) => s.enabled);

  /// Adds a user-supplied RSS/Atom source.
  ///
  /// Returns an error message when the input is unusable, null on success.
  Future<String?> addSource({required String name, required String url}) async {
    final trimmedName = name.trim();
    final trimmedUrl = url.trim();
    if (trimmedName.isEmpty) return '请输入名称';
    if (trimmedUrl.isEmpty) return '请输入订阅地址';
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return '地址需以 http:// 或 https:// 开头';
    }
    if (!trimmedUrl.contains('{query}')) {
      return '地址需包含 {query} 占位符，例如 ...?keyword={query}';
    }
    final id = 'custom:${trimmedUrl.toLowerCase()}';
    if (sources.any((s) => s.id == id)) return '该订阅已存在';

    sources.add(
      RssMediaSource(
        id: id,
        name: trimmedName,
        feedUrlTemplate: trimmedUrl,
        tier: 3,
      ),
    );
    await _saveCustom();
    return null;
  }

  Future<void> removeSource(String id) async {
    if (isBuiltIn(id)) return;
    sources.removeWhere((s) => s.id == id);
    await _saveCustom();
    await _saveDisabledIds();
  }

  Future<void> updateTier(String id, int tier) async {
    final idx = sources.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    final old = sources[idx];
    sources[idx] = RssMediaSource(
      id: old.id,
      name: old.metadata.name,
      feedUrlTemplate: old.feedUrlTemplate,
      tier: tier,
      enabled: old.enabled,
    );
    if (!isBuiltIn(id)) await _saveCustom();
  }
}
