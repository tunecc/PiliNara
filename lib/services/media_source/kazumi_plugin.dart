import 'dart:convert';

import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:dio/dio.dart';

/// A Kazumi-style search/parse rule, mirroring Kazumi's `Plugin` schema.
class KazumiPlugin {
  KazumiPlugin({
    required this.name,
    this.api = '4',
    this.type = 'anime',
    this.version = '1.0',
    this.baseUrl = '',
    this.searchUrl = '',
    this.searchList = '',
    this.searchName = '',
    this.searchResult = '',
    this.chapterRoads = '',
    this.chapterResult = '',
    this.useWebview = false,
    this.useNativePlayer = false,
    this.muliSources = false,
    this.enabled = true,
    this.source = 'local',
  });

  final String name;
  final String api;
  final String type;
  final String version;
  final String baseUrl;
  final String searchUrl;
  final String searchList;
  final String searchName;
  final String searchResult;
  final String chapterRoads;
  final String chapterResult;
  final bool useWebview;
  final bool useNativePlayer;
  final bool muliSources;
  bool enabled;

  /// Where the rule came from: 'local' (bundled) or the remote repo.
  final String source;

  /// Kazumi treats the lowercased rule name as the identity of a rule.
  String get key => name.trim().toLowerCase();

  bool get isUsable =>
      name.isNotEmpty && searchUrl.isNotEmpty && searchList.isNotEmpty;

  factory KazumiPlugin.fromJson(Map<String, dynamic> json, {String source = 'local'}) {
    String str(String key, [String fallback = '']) {
      final value = json[key];
      return value is String ? value : fallback;
    }

    bool flag(String key) {
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) return value == 'true' || value == '1';
      return false;
    }

    return KazumiPlugin(
      name: str('name'),
      api: str('api', '4'),
      type: str('type', 'anime'),
      version: str('version', '1.0'),
      baseUrl: str('baseURL'),
      searchUrl: str('searchURL'),
      searchList: str('searchList'),
      searchName: str('searchName'),
      searchResult: str('searchResult'),
      chapterRoads: str('chapterRoads'),
      chapterResult: str('chapterResult'),
      useWebview: flag('useWebview'),
      useNativePlayer: flag('useNativePlayer'),
      muliSources: flag('muliSources'),
      enabled: json.containsKey('enabled') ? flag('enabled') : true,
      source: source,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'api': api,
    'type': type,
    'version': version,
    'baseURL': baseUrl,
    'searchURL': searchUrl,
    'searchList': searchList,
    'searchName': searchName,
    'searchResult': searchResult,
    'chapterRoads': chapterRoads,
    'chapterResult': chapterResult,
    'useWebview': useWebview,
    'useNativePlayer': useNativePlayer,
    'muliSources': muliSources,
    'enabled': enabled,
  };
}

/// Bundled rules shipped with the app.
abstract final class KazumiBuiltInPlugins {
  static const raw = [
    {
      'api': '4',
      'type': 'anime',
      'name': '7sefun',
      'version': '1.3',
      'muliSources': true,
      'useWebview': true,
      'useNativePlayer': true,
      'baseURL': 'https://www.7sefun.top/',
      'searchURL':
          'https://www.7sefun.top/vodsearch/-------------.html?wd=@keyword',
      'searchList': '//div[2]/div[2]/div[2]/div[2]/div',
      'searchName': '//div[2]/text()',
      'searchResult': '//a',
      'chapterRoads': '//div[2]/div[2]/div[2]/div/div[2]/div[1]//div',
      'chapterResult': '//a',
    },
    {
      'api': '5',
      'type': 'anime',
      'name': 'DM84',
      'version': '1.4',
      'adBlocker': true,
      'baseURL': 'https://dmbus.cc/',
      'searchURL': 'https://dmbus.cc/vodsearch/-------------.html?wd=@keyword',
      'searchList': '//div[2]/div[2]/div[2]/div[2]/div',
      'searchName': '//div[2]/text()',
      'searchResult': '//a',
      'chapterRoads': '//div[2]/div[2]/div[2]/div/div[2]/div[1]//div',
      'chapterResult': '//a',
    },
  ];

  static List<KazumiPlugin> defaults() => [
    for (final json in raw)
      KazumiPlugin.fromJson(Map<String, dynamic>.from(json)),
  ];
}

/// Fetches and persists Kazumi rules.
abstract final class KazumiPluginService {
  static const _repo = 'https://raw.githubusercontent.com/Predidit/KazumiRules/main/';
  static const _repoMirror =
      'https://raw.gitcode.com/gh_mirrors/ka/KazumiRules/raw/main/';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.plain,
    ),
  );

  static List<KazumiPlugin> get stored {
    final raw = GStorage.setting.get(SettingBoxKey.kazumiPlugins);
    if (raw is! List) return KazumiBuiltInPlugins.defaults();
    final result = <KazumiPlugin>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final plugin = KazumiPlugin.fromJson(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (plugin.isUsable) result.add(plugin);
    }
    if (result.isEmpty) return KazumiBuiltInPlugins.defaults();
    return result;
  }

  static Future<void> save(List<KazumiPlugin> plugins) async {
    await GStorage.setting.put(
      SettingBoxKey.kazumiPlugins,
      plugins.map((p) => p.toJson()).toList(),
    );
  }

  /// Merges [incoming] into [base], replacing only true duplicates
  /// (same lowercased name). Returns the merged list and how many were added.
  static (List<KazumiPlugin>, int) merge(
    List<KazumiPlugin> base,
    List<KazumiPlugin> incoming,
  ) {
    final merged = <String, KazumiPlugin>{
      for (final plugin in base) plugin.key: plugin,
    };
    var added = 0;
    for (final plugin in incoming) {
      if (!plugin.isUsable) continue;
      if (!merged.containsKey(plugin.key)) added++;
      merged[plugin.key] = plugin;
    }
    return (merged.values.toList(), added);
  }

  /// Loads the remote rule index, then every rule it lists.
  static Future<({int added, int total, String? error})> syncRemote() async {
    for (final base in [_repo, _repoMirror]) {
      try {
        final indexRes = await _dio.get<String>('${base}index.json');
        final decoded = jsonDecode(indexRes.data ?? '[]');
        if (decoded is! List) continue;
        final fetched = <KazumiPlugin>[];
        for (final item in decoded) {
          if (item is! Map) continue;
          final name = item['name']?.toString();
          if (name == null || name.isEmpty) continue;
          try {
            final res = await _dio.get<String>(
              '$base${Uri.encodeComponent(name)}.json',
            );
            final json = jsonDecode(res.data ?? '{}');
            if (json is Map) {
              fetched.add(
                KazumiPlugin.fromJson(
                  json.map((k, v) => MapEntry(k.toString(), v)),
                  source: 'remote',
                ),
              );
            }
          } catch (_) {
            // A single broken rule must not abort the whole sync.
          }
        }
        final current = stored;
        final (merged, added) = merge(current, fetched);
        await save(merged);
        return (added: added, total: merged.length, error: null);
      } catch (e) {
        continue;
      }
    }
    return (added: 0, total: stored.length, error: '规则仓库拉取失败');
  }
}
