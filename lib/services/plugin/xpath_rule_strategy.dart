import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:PiliPlus/plugins/anti_crawler_config.dart';
import 'package:PiliPlus/services/plugin/episode_url.dart';
import 'package:PiliPlus/services/plugin/plugin_search_module.dart';
import 'package:PiliPlus/services/plugin/road_module.dart';
import 'package:PiliPlus/services/plugin/rule_engine_models.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

enum _XPathField {
  searchList,
  searchName,
  searchResult,
  chapterRoads,
  chapterResult,
  captchaDetectValue,
  captchaImage,
  captchaButton,
}

class XPathRuleFormatException implements Exception {
  const XPathRuleFormatException(this.message, {required this.kind});
  final String message;
  final String kind;
  @override
  String toString() => 'XPathRuleFormatException.$kind: $message';
}

class XPathRuleStrategy {
  const XPathRuleStrategy();

  PreparedRuleRequest prepareSearchRequest(
    RuleExecutionConfig config,
    String keyword,
  ) {
    final queryUrl = config.searchUrl.replaceAll(
      '@keyword',
      Uri.encodeQueryComponent(keyword),
    );
    final uri = Uri.tryParse(queryUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw XPathRuleFormatException('搜索 URL 无效: $queryUrl', kind: 'invalidUrl');
    }
    if (!config.usePost) {
      return PreparedRuleRequest(method: 'GET', url: queryUrl, includeCookies: true);
    }
    return PreparedRuleRequest(
      method: 'POST',
      url: uri.replace(query: null).toString(),
      bodyType: 'form',
      body: uri.queryParameters,
      includeCookies: true,
    );
  }

  PreparedRuleRequest prepareChapterRequest(
    RuleExecutionConfig config,
    String source,
  ) {
    final url = normalizeEpisodeUrl(config.baseUrl, source);
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw XPathRuleFormatException('章节 URL 无效: $url', kind: 'invalidUrl');
    }
    return PreparedRuleRequest(method: 'GET', url: url);
  }

  RuleSearchParseResult parseSearch(String raw, RuleExecutionConfig config) {
    final root = _documentElement(raw);
    if (_detectsCaptcha(raw, config.antiCrawlerConfig, htmlElement: root)) {
      throw CaptchaRequiredException(config.pluginName);
    }
    final items = <SearchItem>[];
    final diagnostics = <String>[];
    final nodes = _runSelector(config.searchList, () => root.queryXPath(config.searchList).nodes);
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      try {
        final name = (_runSelector(config.searchName, () => node.queryXPath(config.searchName).node)?.text?.trim()) ?? '';
        final source = (_runSelector(config.searchResult, () => node.queryXPath(config.searchResult).node)?.attributes['href']?.trim()) ?? '';
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

  RuleChapterParseResult parseChapters(String raw, RuleExecutionConfig config) {
    final root = _documentElement(raw);
    final roads = <Road>[];
    final diagnostics = <String>[];
    final roadNodes = _runSelector(config.chapterRoads, () => root.queryXPath(config.chapterRoads).nodes);
    for (var ri = 0; ri < roadNodes.length; ri++) {
      final urls = <String>[];
      final names = <String>[];
      final episodeNodes = _runSelector(config.chapterResult, () => roadNodes[ri].queryXPath(config.chapterResult).nodes);
      for (var ei = 0; ei < episodeNodes.length; ei++) {
        try {
          final ep = episodeNodes[ei].node;
          final source = (ep.attributes['href'] ?? '').trim();
          if (source.isEmpty) {
            diagnostics.add('线路 $ri 的剧集节点 $ei 缺少 URL，已跳过');
            continue;
          }
          final name = (ep.text ?? '').replaceAll(RegExp(r'\s+'), '');
          urls.add(normalizeEpisodeUrl(config.baseUrl, source));
          names.add(name.isEmpty ? '第${ei + 1}集' : name);
        } catch (e) {
          diagnostics.add('线路 $ri 的剧集节点 $ei 解析失败: $e');
        }
      }
      if (urls.isEmpty) {
        diagnostics.add('线路 $ri 没有有效剧集，已跳过');
        continue;
      }
      roads.add(Road(name: '播放线路${roads.length + 1}', data: urls, identifier: names));
    }
    return RuleChapterParseResult(roads: roads, diagnostics: diagnostics);
  }

  bool _detectsCaptcha(String raw, AntiCrawlerConfig config, {Element? htmlElement}) {
    if (!config.enabled) return false;
    final detectValue = config.captchaDetectValue.trim();
    if (detectValue.isNotEmpty) {
      switch (config.captchaDetectType) {
        case 2: return raw.contains(detectValue);
        case 3:
          try { return RegExp(detectValue, caseSensitive: false, dotAll: true).hasMatch(raw); }
          on FormatException { return false; }
        default:
          final root = htmlElement ?? _documentElement(raw);
          return _runSelector(detectValue, () => root.queryXPath(detectValue).node) != null;
      }
    }
    final root = htmlElement ?? _documentElement(raw);
    for (final expr in [config.captchaImage, config.captchaButton]) {
      if (expr.trim().isEmpty) continue;
      if (_runSelector(expr, () => root.queryXPath(expr).node) != null) return true;
    }
    return false;
  }

  Element _documentElement(String raw) {
    try {
      final el = parse(raw).documentElement;
      if (el == null) throw XPathRuleFormatException('HTML 响应没有根节点', kind: 'invalidDocument');
      return el;
    } catch (e) {
      throw XPathRuleFormatException('HTML 响应解析失败', kind: 'invalidDocument');
    }
  }

  T _runSelector<T>(String expression, T Function() query) {
    if (expression.trim().isEmpty) {
      throw XPathRuleFormatException('XPath 不能为空', kind: 'invalidSelector');
    }
    try {
      return query();
    } catch (e) {
      throw XPathRuleFormatException('XPath 无效: $expression', kind: 'invalidSelector');
    }
  }
}
