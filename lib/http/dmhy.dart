/// DMHY (动漫花园) HTTP client.
///
/// Mirrors animeko's DmhyMediaSource logic.
///
/// Source: https://www.dmhy.org
/// animeko impl: datasource/bt/dmhy/

import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;

class DmhyHttp {
  static const baseUrl = 'https://www.dmhy.org';

  final Dio dio;

  DmhyHttp({Dio? dio}) : dio = dio ?? Dio();

  /// Search DMHY by keyword.
  Future<DmhySearchResult> search({
    required String keyword,
    int page = 1,
    String? orderId,
    String? sortId,
  }) async {
    final resp = await dio.get('$baseUrl/topics/list', queryParameters: {
      'keyword': keyword,
      if (page > 1) 'page': page,
      if (orderId != null) 'order': orderId,
      if (sortId != null) 'sort_id': sortId,
    });

    if (resp.data == null) {
      return DmhySearchResult(topics: [], hasNextPage: false, currentPage: page);
    }

    final doc = parse(resp.data.toString());
    final topics = <DmhyTopic>[];

    final items = doc.querySelectorAll('li.topic_description');
    for (final item in items) {
      final topic = _parseTopic(item);
      if (topic != null) topics.add(topic);
    }

    final hasNext = doc.querySelector('a[href*="page="]:last-of-type') != null;

    return DmhySearchResult(
      topics: topics,
      hasNextPage: hasNext,
      currentPage: page,
    );
  }

  DmhyTopic? _parseTopic(dynamic element) {
    final titleLink = element.querySelector('a[href*="/topics/"]');
    if (titleLink == null) return null;

    final title = titleLink.text.trim();
    final href = titleLink.attributes['href'] ?? '';

    final idMatch = RegExp(r'/topics/(\d+)').firstMatch(href);
    final topicId = idMatch?.group(1);

    final authorEl = element.querySelector('a[href*="/users/"]');
    final author = authorEl?.text.trim() ?? '';

    final allCells = element.querySelectorAll('td');
    final sizeText = allCells.length > 3 ? allCells[3].text.trim() : '';
    final dateText = allCells.length > 4 ? allCells[4].text.trim() : '';
    final commentText = allCells.length > 5 ? allCells[5].text.trim() : '';
    final commentCount = int.tryParse(commentText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    final magnetLink = element.querySelector('a[href*="magnet"]')?.attributes['href'];

    return DmhyTopic(
      id: topicId ?? '',
      title: title,
      author: author,
      size: sizeText,
      date: dateText,
      commentCount: commentCount,
      magnetUrl: magnetLink ?? '',
      detailUrl: href.startsWith('http') ? href : '$baseUrl$href',
    );
  }
}

class DmhyTopic {
  final String id;
  final String title;
  final String author;
  final String size;
  final String date;
  final int commentCount;
  final String magnetUrl;
  final String detailUrl;

  const DmhyTopic({
    required this.id,
    required this.title,
    required this.author,
    required this.size,
    required this.date,
    required this.commentCount,
    required this.magnetUrl,
    required this.detailUrl,
  });
}

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
