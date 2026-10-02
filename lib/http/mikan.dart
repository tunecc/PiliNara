/// Mikan (蜜柑计划) HTTP client.
///
/// Mirrors animeko's MikanMediaSource logic but returns parsed data objects
/// instead of the internal Media/Kotlin types.
///
/// Source: https://mikanani.me
/// animeko impl: datasource/bt/mikan/

import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;

class MikanHttp {
  static const baseUrl = 'https://mikanani.me';

  final Dio dio;

  MikanHttp({Dio? dio}) : dio = dio ?? Dio();

  /// Search Mikan by keyword, returns list of (subjectName, subjectId, link).
  Future<List<MikanSubject>> search(String keyword) async {
    final resp = await dio.get('$baseUrl/Home/BangumiSearch', queryParameters: {
      'searchstr': keyword,
    });

    if (resp.data == null) return [];

    final doc = parse(resp.data.toString());
    final results = <MikanSubject>[];

    final items = doc.querySelectorAll('li.light');
    for (final item in items) {
      final linkEl = item.querySelector('a[href*="/Home/Bangumi/"]');
      if (linkEl == null) continue;

      final href = linkEl.attributes['href'] ?? '';
      final name = linkEl.text.trim();
      final idMatch = RegExp(r'/Bangumi/(\d+)').firstMatch(href);
      final id = idMatch?.group(1);

      if (name.isNotEmpty && id != null) {
        results.add(MikanSubject(name: name, id: id, url: '$baseUrl$href'));
      }
    }

    return results;
  }

  /// Get episode list for a Mikan subject by its ID.
  Future<List<MikanEpisode>> getEpisodes(String subjectId) async {
    final resp = await dio.get('$baseUrl/Home/Bangumi/$subjectId');

    if (resp.data == null) return [];

    final doc = parse(resp.data.toString());
    final episodes = <MikanEpisode>[];

    final dayColumns = doc.querySelectorAll('.bf-green');
    for (final column in dayColumns) {
      final rows = column.querySelectorAll('tr');
      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 3) continue;

        final timeText = cells[0].text.trim();
        final episodeText = cells[1].text.trim();
        final linkCell = cells[2];

        final epMatch = RegExp(r'第?(\d+)集|EP(\d+)').firstMatch(episodeText);
        final epNum = epMatch != null
            ? int.tryParse(epMatch.group(1) ?? epMatch.group(2) ?? '0') ?? 0
            : 0;

        final links = <MikanDownloadLink>[];
        for (final a in linkCell.querySelectorAll('a')) {
          final href = a.attributes['href'] ?? '';
          final text = a.text.trim();
          if (href.isNotEmpty) {
            links.add(MikanDownloadLink(
              url: href.startsWith('http') ? href : '$baseUrl$href',
              type: text.isEmpty ? 'link' : text,
            ));
          }
        }

        if (epNum > 0) {
          episodes.add(MikanEpisode(
            episode: epNum,
            name: episodeText,
            time: timeText,
            links: links,
          ));
        }
      }
    }

    episodes.sort((a, b) => a.episode.compareTo(b.episode));
    return episodes;
  }

  /// Get RSS feed for a specific bangumi ID.
  Future<String> getRssFeed(String bangumiId, {String? token}) async {
    final params = <String, dynamic>{'bangumiId': bangumiId};
    if (token != null) params['token'] = token;
    final resp = await dio.get('$baseUrl/RSS/Bangumi', queryParameters: params);
    return resp.data ?? '';
  }
}

class MikanSubject {
  final String name;
  final String id;
  final String url;

  const MikanSubject({required this.name, required this.id, required this.url});
}

class MikanEpisode {
  final int episode;
  final String name;
  final String time;
  final List<MikanDownloadLink> links;

  const MikanEpisode({
    required this.episode,
    required this.name,
    required this.time,
    required this.links,
  });

  String? get primaryLink => links
      .firstWhere((l) => l.type.contains('Magnet') || l.url.startsWith('magnet'),
          orElse: () => links.isNotEmpty ? links.first : const MikanDownloadLink(url: '', type: ''))
      .url;
}

class MikanDownloadLink {
  final String url;
  final String type;

  const MikanDownloadLink({required this.url, required this.type});
}
