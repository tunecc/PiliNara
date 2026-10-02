import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/services/media_source/kazumi_plugin.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

class KazumiSearchItem {
  const KazumiSearchItem({required this.name, required this.url});

  final String name;
  final String url;
}

class KazumiChapterItem {
  const KazumiChapterItem({required this.name, required this.url});

  final String name;
  final String url;
}

/// Runs Kazumi-style XPath rules against a source site.
abstract final class KazumiRuleExecutor {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.plain,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      },
    ),
  );

  /// Searches [plugin]'s site for [keyword] using its `searchList` rule.
  static Future<List<KazumiSearchItem>> search(
    KazumiPlugin plugin,
    String keyword,
  ) async {
    if (!plugin.isUsable) return const [];
    try {
      final url = plugin.searchUrl.replaceAll(
        '@keyword',
        Uri.encodeQueryComponent(keyword),
      );
      final res = await _dio.get<String>(url);
      final root = parse(res.data ?? '').documentElement;
      if (root == null) return const [];
      final nodes = root.queryXPath(plugin.searchList).nodes;
      final items = <KazumiSearchItem>[];
      for (final node in nodes) {
        final name =
            node.queryXPath(plugin.searchName).node?.text?.trim() ?? '';
        final href = node
                .queryXPath(plugin.searchResult)
                .node
                ?.attributes['href']
                ?.trim() ??
            '';
        if (name.isEmpty || href.isEmpty) continue;
        items.add(
          KazumiSearchItem(
            name: name,
            url: _absolutize(plugin.baseUrl, href),
          ),
        );
      }
      return items;
    } catch (e) {
      logger.w('kazumi search failed [${plugin.name}]: $e');
      return const [];
    }
  }

  /// Resolves the episode list of [sourceUrl] via the `chapterRoads` rule.
  static Future<List<KazumiChapterItem>> chapters(
    KazumiPlugin plugin,
    String sourceUrl,
  ) async {
    if (plugin.chapterRoads.isEmpty) return const [];
    try {
      final url = _absolutize(plugin.baseUrl, sourceUrl);
      final res = await _dio.get<String>(url);
      final root = parse(res.data ?? '').documentElement;
      if (root == null) return const [];
      final roads = root.queryXPath(plugin.chapterRoads).nodes;
      final items = <KazumiChapterItem>[];
      for (final road in roads) {
        final eps = road.queryXPath(plugin.chapterResult).nodes;
        for (final ep in eps) {
          final node = ep.node;
          final href = node?.attributes['href']?.trim() ?? '';
          if (href.isEmpty) continue;
          items.add(
            KazumiChapterItem(
              name: node?.text?.trim() ?? '',
              url: _absolutize(plugin.baseUrl, href),
            ),
          );
        }
      }
      return items;
    } catch (e) {
      logger.w('kazumi chapters failed [${plugin.name}]: $e');
      return const [];
    }
  }

  static String _absolutize(String base, String href) {
    if (href.startsWith('http://') || href.startsWith('https://')) return href;
    final uri = Uri.tryParse(base);
    if (uri == null) return href;
    try {
      return uri.resolve(href).toString();
    } catch (_) {
      return href;
    }
  }
}
