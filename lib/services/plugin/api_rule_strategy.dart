import 'dart:convert';
import 'package:json_path/json_path.dart';
import 'package:PiliPlus/plugins/api_rule_config.dart';
import 'package:PiliPlus/services/plugin/episode_url.dart';
import 'package:PiliPlus/services/plugin/plugin_search_module.dart';
import 'package:PiliPlus/services/plugin/road_module.dart';
import 'package:PiliPlus/services/plugin/rule_engine_models.dart';

class ApiRuleFormatException implements Exception {
  const ApiRuleFormatException(this.message);
  final String message;
  @override
  String toString() => 'ApiRuleFormatException: $message';
}

class RestrictedJsonPath {
  const RestrictedJsonPath._();

  static void validate(String expression) {
    if (expression.isEmpty || !expression.startsWith(r'$')) {
      throw ApiRuleFormatException('JSONPath 必须以 \$ 开头: $expression');
    }
    var index = 1;
    while (index < expression.length) {
      final char = expression[index];
      if (char == '.') {
        index++;
        final start = index;
        while (index < expression.length && RegExp(r'[A-Za-z0-9_$-]').hasMatch(expression[index])) index++;
        if (index == start) throw ApiRuleFormatException('不支持的 JSONPath: $expression');
        continue;
      }
      if (char == '[') {
        final end = _findBracketEnd(expression, index);
        final content = expression.substring(index + 1, end).trim();
        final isIndex = RegExp(r'^\d+$').hasMatch(content);
        final isWildcard = content == '*';
        final isQuoted = content.length >= 2 &&
            ((content.startsWith("'") && content.endsWith("'")) ||
                (content.startsWith('"') && content.endsWith('"')));
        if (!isIndex && !isWildcard && !isQuoted) {
          throw ApiRuleFormatException('不支持的 JSONPath 片段: [$content]');
        }
        index = end + 1;
        continue;
      }
      throw ApiRuleFormatException('不支持的 JSONPath: $expression');
    }
  }

  static int _findBracketEnd(String expression, int start) {
    String? quote;
    var escaped = false;
    for (var i = start + 1; i < expression.length; i++) {
      final char = expression[i];
      if (escaped) { escaped = false; continue; }
      if (char == '\\') { escaped = true; continue; }
      if (quote != null) { if (char == quote) quote = null; continue; }
      if (char == "'" || char == '"') { quote = char; continue; }
      if (char == ']') return i;
    }
    throw ApiRuleFormatException('JSONPath 缺少 ]: $expression');
  }

  static List<Object?> read(dynamic document, String expression) {
    validate(expression);
    try { return JsonPath(expression).readValues(document).toList(); }
    catch (e) { throw ApiRuleFormatException('JSONPath 解析失败 $expression: $e'); }
  }

  static Object? readFirst(dynamic document, String expression) {
    final values = read(document, expression);
    return values.isEmpty ? null : values.first;
  }
}

class ApiRuleStrategy {
  const ApiRuleStrategy();

  dynamic decodeResponse(String raw) {
    try { return jsonDecode(raw); }
    on FormatException catch (e) {
      throw ApiRuleFormatException('API 响应不是有效 JSON: ${e.message}');
    }
  }

  PreparedRuleRequest prepareRequest(ApiRequestConfig config, Map<String, Object?> variables) {
    final method = config.method.toUpperCase();
    if (method != 'GET' && method != 'POST') throw ApiRuleFormatException('仅支持 GET/POST，当前为 $method');
    if (config.url.trim().isEmpty) throw const ApiRuleFormatException('API 请求 URL 不能为空');
    final url = _renderTemplate(config.url.trim(), variables, encode: true);
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ApiRuleFormatException('API 请求 URL 无效: $url');
    }
    final hasBody = method == 'POST' && config.bodyType != ApiBodyType.none;
    return PreparedRuleRequest(
      method: method, url: url,
      headers: _renderMap(config.headers, variables),
      query: _renderMap(config.query, variables),
      bodyType: config.bodyType,
      body: hasBody ? _renderValue(config.body, variables) : null,
      includeCookies: true,
    );
  }

  RuleSearchParseResult parseSearch(String raw, ApiSearchConfig config) {
    final document = decodeResponse(raw);
    final nodes = RestrictedJsonPath.read(document, config.listPath);
    final items = <SearchItem>[];
    final diagnostics = <String>[];
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      try {
        final name = _stringValue(RestrictedJsonPath.readFirst(node, config.namePath));
        final source = _stringValue(RestrictedJsonPath.readFirst(node, config.sourcePath));
        if (name.isEmpty || source.isEmpty) {
          diagnostics.add('搜索节点 $i 缺少名称或来源，已跳过');
          continue;
        }
        items.add(SearchItem(name: name, src: source));
      } catch (e) {
        diagnostics.add('搜索节点 $i 解析失败: $e');
      }
    }
    return RuleSearchParseResult(items: items, diagnostics: diagnostics);
  }

  RuleChapterParseResult parseChapters(String raw, ApiChapterConfig config, {required String source, required String baseUrl}) {
    final document = decodeResponse(raw);
    final rootVars = <String, Object?>{'source': source};
    for (final entry in config.variables.entries) {
      final value = RestrictedJsonPath.readFirst(document, entry.value);
      if (value == null) throw ApiRuleFormatException('章节响应变量 ${entry.key} 未匹配到值: ${entry.value}');
      rootVars[entry.key] = value;
    }
    final diagnostics = <String>[];
    final roads = config.format == ApiChapterFormat.delimited
        ? _parseDelimited(document, config, rootVars, baseUrl, diagnostics)
        : _parseNested(document, config, rootVars, baseUrl, diagnostics);
    return RuleChapterParseResult(roads: roads, diagnostics: diagnostics);
  }

  List<Road> _parseNested(dynamic document, ApiChapterConfig config, Map<String, Object?> rootVars, String baseUrl, List<String> diagnostics) {
    final hasRoads = config.roadsPath.trim().isNotEmpty;
    final roadNodes = hasRoads ? RestrictedJsonPath.read(document, config.roadsPath) : <Object?>[document];
    final roads = <Road>[];
    for (var ri = 0; ri < roadNodes.length; ri++) {
      final roadNode = roadNodes[ri];
      try {
        final roadName = hasRoads && config.roadNamePath.trim().isNotEmpty
            ? _stringValue(RestrictedJsonPath.readFirst(roadNode, config.roadNamePath))
            : '';
        final episodeNodes = RestrictedJsonPath.read(roadNode, config.episodesPath);
        final urls = <String>[], names = <String>[];
        for (var ei = 0; ei < episodeNodes.length; ei++) {
          try {
            final epNode = episodeNodes[ei];
            final epName = _stringValue(RestrictedJsonPath.readFirst(epNode, config.episodeNamePath));
            final rawUrl = _stringValue(RestrictedJsonPath.readFirst(epNode, config.episodeUrlPath));
            final pageUrl = _resolveEpisodeUrl(config, rootVars, rawUrl: rawUrl, roadIndex: ri, episodeIndex: ei, baseUrl: baseUrl);
            if (pageUrl.isEmpty) { diagnostics.add('线路 $ri 的剧集节点 $ei 缺少 URL，已跳过'); continue; }
            urls.add(pageUrl);
            names.add(epName.isEmpty ? '第${ei + 1}集' : epName);
          } catch (e) { diagnostics.add('线路 $ri 的剧集节点 $ei 解析失败: $e'); }
        }
        if (urls.isEmpty) { diagnostics.add('线路节点 $ri 没有有效剧集，已跳过'); continue; }
        roads.add(Road(name: roadName.isEmpty ? '播放线路${roads.length + 1}' : roadName, data: urls, identifier: names));
      } catch (e) { diagnostics.add('线路节点 $ri 解析失败: $e'); }
    }
    return roads;
  }

  List<Road> _parseDelimited(dynamic document, ApiChapterConfig config, Map<String, Object?> rootVars, String baseUrl, List<String> diagnostics) {
    final namesValue = _stringValue(RestrictedJsonPath.readFirst(document, config.roadNamesPath));
    final episodesValue = _stringValue(RestrictedJsonPath.readFirst(document, config.roadEpisodesPath));
    if (episodesValue.isEmpty) return [];
    final roadNames = namesValue.split(config.roadSeparator);
    final roadGroups = episodesValue.split(config.roadSeparator);
    final roads = <Road>[];
    for (var ri = 0; ri < roadGroups.length; ri++) {
      final urls = <String>[], names = <String>[];
      final entries = roadGroups[ri].split(config.episodeSeparator);
      for (var ei = 0; ei < entries.length; ei++) {
        final entry = entries[ei].trim();
        if (entry.isEmpty) continue;
        final sepIdx = entry.indexOf(config.fieldSeparator);
        if (sepIdx < 0) { diagnostics.add('线路 $ri 的剧集条目 $ei 缺少字段分隔符，已跳过'); continue; }
        final name = entry.substring(0, sepIdx).trim();
        final rawUrl = entry.substring(sepIdx + config.fieldSeparator.length).trim();
        final pageUrl = _resolveEpisodeUrl(config, rootVars, rawUrl: rawUrl, roadIndex: ri, episodeIndex: ei, baseUrl: baseUrl);
        if (pageUrl.isEmpty) { diagnostics.add('线路 $ri 的剧集条目 $ei 缺少 URL，已跳过'); continue; }
        urls.add(pageUrl);
        names.add(name.isEmpty ? '第${ei + 1}集' : name);
      }
      if (urls.isEmpty) { diagnostics.add('线路 $ri 没有有效剧集，已跳过'); continue; }
      final configuredName = ri < roadNames.length ? roadNames[ri].trim() : '';
      roads.add(Road(name: configuredName.isEmpty ? '播放线路${roads.length + 1}' : configuredName, data: urls, identifier: names));
    }
    return roads;
  }

  String _resolveEpisodeUrl(ApiChapterConfig config, Map<String, Object?> rootVars, {required String rawUrl, required int roadIndex, required int episodeIndex, required String baseUrl}) {
    final page = config.episodePage;
    if (page == null) return normalizeEpisodeUrl(baseUrl, rawUrl);
    if (page.url.trim().isEmpty) throw const ApiRuleFormatException('播放页地址模板不能为空');
    final variables = <String, Object?>{...rootVars, 'episodeUrl': rawUrl, 'roadIndex': roadIndex, 'roadNumber': roadIndex + 1, 'episodeIndex': episodeIndex, 'episodeNumber': episodeIndex + 1};
    final path = _renderTemplate(page.url, variables, encode: true);
    final uri = Uri.tryParse(path);
    if (uri == null) throw ApiRuleFormatException('剧集页面 URL 无效: $path');
    final renderedQuery = _renderMap(page.query, variables).map((k, v) => MapEntry(k, v.toString()));
    final mergedQuery = <String, String>{...uri.queryParameters, ...renderedQuery};
    return normalizeEpisodeUrl(baseUrl, uri.replace(queryParameters: mergedQuery).toString());
  }

  String _stringValue(Object? value) => (value ?? '').toString();

  String _renderTemplate(String template, Map<String, Object?> vars, {bool encode = false}) {
    return template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
      final key = m.group(1)!;
      final val = vars[key]?.toString() ?? '';
      return encode ? Uri.encodeComponent(val) : val;
    });
  }

  Map<String, dynamic> _renderMap(Map<String, dynamic> map, Map<String, Object?> vars) {
    return map.map((k, v) => MapEntry(k, _renderValue(v, vars)));
  }

  dynamic _renderValue(dynamic value, Map<String, Object?> vars) {
    if (value is String) return _renderTemplate(value, vars);
    if (value is Map) return value.map((k, v) => MapEntry(k, _renderValue(v, vars)));
    if (value is List) return value.map((e) => _renderValue(e, vars)).toList();
    return value;
  }
}
