/// DMHY (动漫花园) HTTP client.
///
/// Core logic ported from animeko's DmhyMediaSource:
/// 1. HTML table parsing with proper column extraction
/// 2. Alliance (subtitle group) parsing from CSS tags
/// 3. Topic title parsing for episode/range/resolution
///
/// Source: https://www.dmhy.org
/// animeko impl: datasource/bt/dmhy/src/jvmMain/kotlin/

import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;

class DmhyHttp {
  static const baseUrl = 'https://www.dmhy.org';

  final Dio dio;

  DmhyHttp({Dio? dio}) : dio = dio ?? Dio();

  /// Search DMHY by keyword.
  /// Returns paginated list of topics matching the search term.
  Future<DmhySearchResult> search({
    required String keyword,
    int page = 1,
    String? orderId, // "date-asc", "date-desc", "size-asc", "size-desc"
    String? sortId,  // category sort ID (e.g., "2" for anime)
  }) async {
    final resp = await dio.get('$baseUrl/topics/list', queryParameters: {
      'keyword': keyword,
      if (page > 1) 'page': page,
      if (orderId != null) 'order': orderId,
      if (sortId != null) 'sort_id': sortId,
    });

    if (resp.data == null) {
      return const DmhySearchResult(topics: [], hasNextPage: false, currentPage: page);
    }

    final doc = parse(resp.data.toString());
    final topics = <DmhyTopic>[];

    // DMHY topic list items have class "topic_description"
    final items = doc.querySelectorAll('li.topic_description');
    for (final item in items) {
      final topic = _parseTopic(item);
      if (topic != null) topics.add(topic);
    }

    // Check pagination - look for next page link
    final hasNext = doc.querySelectorAll('a[href*="page="]').isNotEmpty;

    return DmhySearchResult(
      topics: topics,
      hasNextPage: hasNext && topics.isNotEmpty,
      currentPage: page,
    );
  }

  /// Parse a single DMHY topic element.
  /// Mirrors animeko's ListParser.Row.toTopic() logic.
  DmhyTopic? _parseTopic(dynamic element) {
    // The table structure:
    // td[0]: date
    // td[1]: category (with link)
    // td[2]: alliance + title + comments (multiple elements)
    // td[3]: magnet link
    // td[4]: size
    // td[5]: author

    final cells = element.querySelectorAll('td');
    if (cells.length < 6) return null;

    // Date
    final dateText = cells[0].text.trim();

    // Category
    final categoryLink = cells[1].querySelector('a')?.attributes['href'] ?? '';
    final categoryId = categoryLink.split('/').lastOrNull;
    final categoryName = cells[1].text.trim();

    // Alliance and title (td[2] contains multiple links)
    final allianceLinks = cells[2].querySelectorAll('span.tag a');
    String? allianceId;
    String? allianceName;
    String title = '';
    int commentCount = 0;

    for (int i = 0; i < allianceLinks.length; i++) {
      final link = allianceLinks[i];
      final linkHref = link.attributes['href'] ?? '';
      final linkText = link.text.trim();

      if (linkHref.contains('/alliance/')) {
        allianceId = linkHref.split('/').last;
        allianceName = linkText;
      } else if (i == allianceLinks.length - 1) {
        // Last link is the title
        title = linkText;
      }
    }

    // Extract comment count from text
    final commentMatch = RegExp(r'(\d+)\s*评论').firstMatch(cells[2].text);
    if (commentMatch != null) {
      commentCount = int.tryParse(commentMatch.group(1) ?? '0') ?? 0;
    }

    // Title link
    final titleLink = cells[2].querySelector('a[href*="/topics/"]');
    final topicLink = titleLink?.attributes['href'] ?? '';
    final topicId = topicLink.split('/').lastOrNull;

    // Magnet link (td[3])
    final magnetCell = cells[3];
    final magnetLink = magnetCell.querySelector('a[href*="magnet"]')?.attributes['href'] ?? '';

    // Size (td[4])
    final sizeText = cells[4].text.trim();

    // Author (td[5])
    final authorCell = cells[5];
    final authorLink = authorCell.querySelector('a')?.attributes['href'] ?? '';
    final authorId = authorLink.split('/').lastOrNull;
    final authorName = authorCell.text.trim();

    if (topicId == null || topicId.isEmpty) return null;

    return DmhyTopic(
      id: topicId,
      date: dateText,
      categoryId: categoryId ?? '',
      categoryName: categoryName,
      allianceId: allianceId,
      allianceName: allianceName ?? '',
      title: title,
      commentCount: commentCount,
      magnetUrl: magnetLink,
      sizeText: sizeText,
      authorId: authorId,
      authorName: authorName,
      detailUrl: topicLink.startsWith('http') ? topicLink : '$baseUrl$topicLink',
    );
  }

  /// Get topic details by ID.
  Future<DmhyTopic?> getTopic(String topicId) async {
    try {
      final resp = await dio.get('$baseUrl/topics/$topicId');
      if (resp.data == null) return null;

      final doc = parse(resp.data.toString());
      // Parse single topic page
      final titleEl = doc.querySelector('h1')?.text.trim();
      final magnetLink = doc.querySelector('a[href*="magnet"]')?.attributes['href'] ?? '';
      final sizeEl = doc.querySelector('.size')?.text.trim() ?? '';

      if (titleEl == null) return null;

      return DmhyTopic(
        id: topicId,
        title: titleEl,
        magnetUrl: magnetLink,
        sizeText: sizeEl,
        detailUrl: '$baseUrl/topics/$topicId',
      );
    } catch (e) {
      return null;
    }
  }
}

/// Parsed DMHY topic.
/// Mirrors animeko's DmhyTopic model.
class DmhyTopic {
  final String id;
  final String date;
  final String categoryId;
  final String categoryName;
  final String? allianceId;
  final String allianceName;
  final String title;
  final int commentCount;
  final String magnetUrl;
  final String sizeText;
  final String? authorId;
  final String authorName;
  final String detailUrl;

  const DmhyTopic({
    required this.id,
    required this.date,
    required this.categoryId,
    required this.categoryName,
    this.allianceId,
    required this.allianceName,
    required this.title,
    required this.commentCount,
    required this.magnetUrl,
    required this.sizeText,
    this.authorId,
    required this.authorName,
    required this.detailUrl,
  });

  /// Primary download URL (prefer magnet)
  String? get downloadUrl => magnetUrl.isNotEmpty ? magnetUrl : null;

  /// Whether this is a torrent/BT resource
  bool get isTorrent => magnetUrl.isNotEmpty;

  /// Parsed file size in bytes
  int get sizeBytes {
    final match = RegExp(r'([\d.]+)\s*(GB|MB|KB)').firstMatch(sizeText);
    if (match == null) return 0;
    final val = double.tryParse(match.group(1) ?? '0') ?? 0;
    final unit = (match.group(2) ?? 'MB').toUpperCase();
    switch (unit) {
      case 'GB':
        return (val * 1073741824).toInt();
      case 'MB':
        return (val * 1048576).toInt();
      case 'KB':
        return (val * 1024).toInt();
      default:
        return 0;
    }
  }

  @override
  String toString() => 'DmhyTopic($id, $title, ${allianceName})';
}

/// Search result from DMHY.
class DmhySearchResult {
  final List<DmhyTopic> topics;
  final bool hasNextPage;
  final int currentPage;

  const DmhySearchResult({
    required this.topics,
    required this.hasNextPage,
    required this.currentPage,
  });
}
