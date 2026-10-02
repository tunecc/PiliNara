import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/plugins/plugin.dart';
import 'dart:convert';

/// 规则列表持久化：Hive setting box
abstract final class PluginStorage {
  static List<Plugin> load() {
    final raw = GStorage.setting.get(SettingBoxKey.pluginList, defaultValue: <dynamic>[]);
    if (raw is! List) return [];
    return raw.map((e) => Plugin.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  static void save(List<Plugin> plugins) {
    GStorage.setting.put(SettingBoxKey.pluginList, plugins.map((p) => p.toJson()).toList());
  }

  static String toJsonString(List<Plugin> plugins) => jsonEncode(plugins.map((p) => p.toJson()).toList());
}
