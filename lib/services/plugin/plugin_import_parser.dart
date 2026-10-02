import 'dart:convert';
import 'package:PiliPlus/plugins/plugin.dart';
import 'package:PiliPlus/utils/rule_encoding.dart';

class PluginImportParseResult {
  const PluginImportParseResult({
    required this.plugins,
    required this.failures,
    required this.duplicateCount,
  });
  final List<Plugin> plugins;
  final List<String> failures;
  final int duplicateCount;
  int get failureCount => failures.length;
}

class PluginImportParser {
  const PluginImportParser._();

  static final RegExp _ruleLinkPayloadPrefix = RegExp(r'^[A-Za-z0-9+/_=%\-\s]+');

  static PluginImportParseResult parse(String input) {
    final value = input.trim();
    if (value.isEmpty) return const PluginImportParseResult(plugins: [], failures: ['导入内容为空'], duplicateCount: 0);

    final parsed = <Plugin>[];
    final failures = <String>[];
    Object? jsonValue;
    var decodedAsJson = false;
    try {
      jsonValue = json.decode(value);
      decodedAsJson = true;
    } on FormatException {}

    if (decodedAsJson) {
      if (jsonValue is List) {
        for (var i = 0; i < jsonValue.length; i++) _parseEntry(jsonValue[i], i + 1, parsed, failures);
      } else {
        _parseEntry(jsonValue, 1, parsed, failures);
      }
    } else {
      final segments = findKazumiRuleLinkSegments(value).toList();
      if (segments.isEmpty) {
        failures.add('未找到有效的 JSON 或 kazumi:// 规则链接');
      } else {
        for (var i = 0; i < segments.length; i++) {
          try {
            final entry = _decodeRuleEntry(segments[i].scheme, segments[i].rawPayload);
            _parseEntry(entry, i + 1, parsed, failures);
          } catch (e) {
            failures.add('第 ${i + 1} 条：$e');
          }
        }
      }
    }

    final uniquePlugins = <String, Plugin>{};
    var duplicateCount = 0;
    for (final plugin in parsed) {
      final key = plugin.name.toLowerCase();
      if (uniquePlugins.containsKey(key)) duplicateCount++;
      uniquePlugins[key] = plugin;
    }
    return PluginImportParseResult(
      plugins: List.unmodifiable(uniquePlugins.values),
      failures: List.unmodifiable(failures),
      duplicateCount: duplicateCount,
    );
  }

  static Map<String, dynamic> _decodeRuleEntry(String scheme, String rawPayload) {
    final payload = _ruleLinkPayloadPrefix.firstMatch(rawPayload)?.group(0)?.trimRight();
    if (payload == null || payload.isEmpty) throw const FormatException('Missing payload in rule link');
    final candidates = <String>[payload];
    for (final m in RegExp(r'\s+').allMatches(payload).toList().reversed) {
      final c = payload.substring(0, m.start).trimRight();
      if (c.isNotEmpty && c != candidates.last) candidates.add(c);
    }
    FormatException? firstError;
    for (final candidate in candidates) {
      try {
        final decoded = json.decode(kazumiBase64ToJson('$scheme$candidate'));
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        firstError ??= const FormatException('规则链接内容必须是 JSON object');
      } on FormatException catch (e) {
        firstError ??= e;
      }
    }
    throw firstError ?? const FormatException('Invalid rule link');
  }

  static void _parseEntry(Object? entry, int index, List<Plugin> plugins, List<String> failures) {
    try {
      late final Plugin plugin;
      if (entry is Map) {
        plugin = Plugin.fromJson(Map<String, dynamic>.from(entry));
      } else if (entry is String) {
        final decoded = json.decode(kazumiBase64ToJson(entry));
        if (decoded is! Map) throw const FormatException('规则链接内容必须是 JSON object');
        plugin = Plugin.fromJson(Map<String, dynamic>.from(decoded));
      } else {
        throw const FormatException('规则必须是 JSON object 或 kazumi:// 链接');
      }
      if (plugin.name.trim().isEmpty) throw const FormatException('规则名称不能为空');
      plugins.add(plugin);
    } catch (e) {
      failures.add('第 $index 条：$e');
    }
  }
}
