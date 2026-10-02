/// Mikan (蜜柑计划) HTTP client.
///
/// Core logic ported from animeko's MikanMediaSource:
/// 1. Bangumi ID → Mikan ID cache lookup (MikanIndexCacheProvider)
/// 2. RSS feed parsing with Topic/EpisodeRange/Resolution extraction
/// 3. Title parsing for resolution, episode range, subtitle languages
///
/// Source: https://mikanani.me
/// animeko impl: datasource/bt/mikan/src/commonMain/kotlin/MikanMediaSource.kt

import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:xml/xml.dart' as xml;

class MikanHttp {
  static const baseUrl = 'https://mikanani.me';

  final Dio dio;
  final MikanIndexCache _cache = MikanIndexCache();

  MikanHttp({Dio? dio}) : dio = dio ?? Dio();

  /// Search Mikan by Bangumi subject ID (exact match, highest priority).
  /// Returns null if no Mikan subject is found for the given Bangumi ID.
  Future<List<MikanTopic>?> searchByBangumiId(String bangumiSubjectId) async {
    // Step 1: Check cache
    String? mikanId = await _cache.getMikanId(bangumiSubjectId);

    // Step 2: If not in cache, search by name and match Bangumi ID
    if (mikanId == null) {
      // We need the anime name to search - caller should provide it
      return null;
    }

    // Step 3: Fetch RSS feed for this Mikan subject
    return await _fetchRssFeed(bangumiId: mikanId);
  }

  /// Search Mikan by keyword (fuzzy match).
  /// Returns list of subjects matching the keyword.
  Future<List<MikanSubject>> searchSubjects(String keyword) async {
    final resp = await dio.get('$baseUrl/Home/BangumiSearch', queryParameters: {
      'searchstr': keyword,
    });

    if (resp.data == null) return [];

    final doc = parse(resp.data.toString());
    final subjects = <MikanSubject>[];

    final items = doc.querySelectorAll('li.light');
    for (final item in items) {
      final linkEl = item.querySelector('a[href*="/Home/Bangumi/"]');
      if (linkEl == null) continue;

      final href = linkEl.attributes['href'] ?? '';
      final name = linkEl.text.trim();
      final idMatch = RegExp(r'/Bangumi/(\d+)').firstMatch(href);
      final id = idMatch?.group(1);

      if (name.isNotEmpty && id != null) {
        subjects.add(MikanSubject(name: name, id: id));
      }
    }

    return subjects;
  }

  /// Get Mikan subject ID by name, then verify it matches the Bangumi ID.
  /// This is the index-matching logic from animeko's findMikanSubjectIdByName.
  Future<String?> findMikanIdByBangumi({
    required String animeName,
    required String bangumiSubjectId,
  }) async {
    final subjects = await searchSubjects(animeName.trim().split(' ')[0]);
    if (subjects.isEmpty) return null;

    // For each candidate, check if its Bangumi page links to the right Bangumi ID
    for (final subject in subjects) {
      try {
        final bangumiIdOnPage = await _getBangumiIdFromMikanPage(subject.id);
        if (bangumiIdOnPage == bangumiSubjectId) {
          // Cache the mapping
          await _cache.setMikanId(bangumiSubjectId, subject.id);
          return subject.id;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Fetch RSS feed for a Mikan subject by its ID.
  /// Parses RSS items into MikanTopic list.
  Future<List<MikanTopic>> _fetchRssFeed({required String bangumiId}) async {
    final resp = await dio.get('$baseUrl/RSS/Bangumi', queryParameters: {
      'bangumiId': bangumiId,
    });

    if (resp.data == null) return [];

    return _parseRssTopics(resp.data.toString(), bangumiId);
  }

  /// Parse RSS XML into MikanTopic list.
  /// Mirrors animeko's parseRssTopicList + parseDocument logic.
  List<MikanTopic> _parseRssTopics(String rssXml, String bangumiId) {
    final topics = <MikanTopic>[];
    final doc = xml.XmlParser().parse(rssXml);
    final items = doc.findAllElements('item');

    for (final item in items) {
      final title = item.findAllElements('title').firstOrNull?.text?.trim() ?? '';
      final guid = item.findAllElements('guid').firstOrNull?.text?.trim() ?? '';
      final pubDate = item.findAllElements('pubDate').firstOrNull?.text ?? '';
      final enclosure = item.findElements('enclosure').firstOrNull;
      final contentLength = item.findAllElements('contentLength').firstOrNull?.text ?? '';

      // Extract magnet link or torrent URL
      String? magnetUrl;
      String? torrentUrl;
      final linkEl = item.findElements('link').firstOrNull;
      final linkText = linkEl?.text?.trim();

      // Try to find magnet link in title or link
      if (title.contains('magnet')) {
        final magnetMatch = RegExp(r'magnet:\?xt=urn:btih:[a-zA-Z0-9]+').firstMatch(title);
        if (magnetMatch != null) magnetUrl = magnetMatch.group(0);
      }
      if (linkText != null && linkText.startsWith('magnet:')) {
        magnetUrl = linkText;
      }
      if (enclosure != null) {
        final url = enclosure.getAttribute('url') ?? '';
        if (url.endsWith('.torrent') || url.contains('uploadbt')) {
          torrentUrl = url;
        }
      }

      if (magnetUrl == null && torrentUrl == null) continue;

      // Parse title for episode range, resolution, subtitle languages
      final details = MikanTitleParser.parse(title);

      // Extract size
      int sizeBytes = 0;
      final sizeMatch = RegExp(r'([\d.]+)\s*(GB|MB|KB)').firstMatch(contentLength);
      if (sizeMatch != null) {
        final val = double.tryParse(sizeMatch.group(1) ?? '0') ?? 0;
        final unit = (sizeMatch.group(2) ?? 'MB').toUpperCase();
        switch (unit) {
          case 'GB':
            sizeBytes = (val * 1073741824).toInt();
            break;
          case 'MB':
            sizeBytes = (val * 1048576).toInt();
            break;
          case 'KB':
            sizeBytes = (val * 1024).toInt();
            break;
        }
      }

      // Parse publish time
      DateTime? publishedAt;
      try {
        publishedAt = DateTime.tryParse(pubDate);
      } catch (_) {}

      topics.add(MikanTopic(
        topicId: guid.split('/').last,
        rawTitle: title,
        alliance: details.alliance,
        episodeRange: details.episodeRange,
        resolution: details.resolution,
        subtitleLanguages: details.subtitleLanguages,
        magnetUrl: magnetUrl,
        torrentUrl: torrentUrl,
        sizeBytes: sizeBytes,
        publishedAt: publishedAt,
        originalLink: linkText ?? '',
      ));
    }

    return topics;
  }

  /// Get Bangumi subject ID from a Mikan subject page.
  /// Mirrors animeko's parseBangumiSubjectIdFromMikanSubjectDetails.
  Future<String?> _getBangumiIdFromMikanPage(String mikanId) async {
    try {
      final resp = await dio.get('$baseUrl/Home/Bangumi/$mikanId');
      if (resp.data == null) return null;

      final doc = parse(resp.data.toString());
      final bangumiInfo = doc.querySelectorAll('.bangumi-info')
          .where((e) => e.text.contains('Bangumi番组计划链接'))
          .toList();

      for (final el in bangumiInfo) {
        final link = el.querySelector('a')?.attributes['href'];
        if (link != null) {
          final idMatch = RegExp(r'subject/(\d+)').firstMatch(link);
          if (idMatch != null) return idMatch.group(1);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Get all episodes for a Mikan subject (for display purposes).
  /// This parses the HTML episode list page.
  Future<List<MikanEpisode>> getEpisodeList(String mikanId) async {
    final resp = await dio.get('$baseUrl/Home/Bangumi/$mikanId');
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
}

/// Cache for Mikan ↔ Bangumi ID mapping.
/// Mirrors animeko's MikanIndexCacheProvider.
class MikanIndexCache {
  final Map<String, String> _cache = {};

  Future<String?> getMikanId(String bangumiId) async {
    return _cache[bangumiId];
  }

  Future<void> setMikanId(String bangumiId, String mikanId) async {
    _cache[bangumiId] = mikanId;
  }
}

/// Parsed Mikan topic from RSS feed.
/// Mirrors animeko's Topic model.
class MikanTopic {
  final String topicId;
  final String rawTitle;
  final String alliance;
  final MikanEpisodeRange? episodeRange;
  final String? resolution;
  final List<String> subtitleLanguages;
  final String? magnetUrl;
  final String? torrentUrl;
  final int sizeBytes;
  final DateTime? publishedAt;
  final String originalLink;

  const MikanTopic({
    required this.topicId,
    required this.rawTitle,
    required this.alliance,
    this.episodeRange,
    this.resolution,
    this.subtitleLanguages = const [],
    this.magnetUrl,
    this.torrentUrl,
    this.sizeBytes = 0,
    this.publishedAt,
    this.originalLink = '',
  });

  /// Primary download URL (prefer magnet over torrent)
  String? get downloadUrl => magnetUrl ?? torrentUrl;

  /// Whether this is a torrent/BT resource
  bool get isTorrent => magnetUrl != null || torrentUrl != null;

  @override
  String toString() => 'MikanTopic($topicId, $rawTitle, ${episodeRange})';
}

/// Episode range parsed from Mikan title.
/// Mirrors animeko's EpisodeRange.
class MikanEpisodeRange {
  final int? start;
  final int? end;
  final bool isSingle;
  final bool isSeason;
  final int? seasonNumber;

  const MikanEpisodeRange({this.start, this.end, this.isSingle = false, this.isSeason = false, this.seasonNumber});

  /// Check if this range contains the given episode number.
  bool contains(int episode) {
    if (isSeason) return true;
    if (start == null || end == null) return false;
    return episode >= start! && episode <= end!;
  }

  @override
  String toString() {
    if (isSeason) return 'S$seasonNumber';
    if (isSingle && start != null) return 'Ep$start';
    if (start != null && end != null) return '$start-$end';
    return '?';
  }
}

/// Parsed information from Mikan topic title.
/// Mirrors animeko's TopicDetails / ParsedTopicTitle.
class MikanTitleDetails {
  final String alliance;
  final MikanEpisodeRange? episodeRange;
  final String? resolution;
  final List<String> subtitleLanguages;

  const MikanTitleDetails({
    this.alliance = '',
    this.episodeRange,
    this.resolution,
    this.subtitleLanguages = const [],
  });
}

/// Title parser for Mikan torrent titles.
/// Mirrors animeko's RawTitleParser / LabelFirstRawTitleParser.
class MikanTitleParser {
  const MikanTitleParser._();

  static MikanTitleDetails parse(String title) {
    String alliance = '';
    MikanEpisodeRange? episodeRange;
    String? resolution;
    final List<String> subtitleLanguages = [];

    // Extract alliance (subtitle group) from brackets
    final allianceMatch = RegExp(r'[\[【](.+?)[\]】]').firstMatch(title);
    if (allianceMatch != null) {
      alliance = allianceMatch.group(1) ?? '';
    }

    // Extract episode range
    final epMatch = RegExp(r'(?:第|EP|ep|Ep)?(\d+(?:\.\d+)?)?(?:[-—~](\d+(?:\.\d+)?))?(?:集|话|episode|Episode)?')
        .firstMatch(title);
    if (epMatch != null) {
      final start = double.tryParse(epMatch.group(1) ?? '');
      final endStr = epMatch.group(2);
      if (start != null) {
        final startInt = start.toInt();
        if (endStr != null) {
          final end = double.tryParse(endStr);
          if (end != null) {
            episodeRange = MikanEpisodeRange(start: startInt, end: end.toInt(), isSingle: startInt == end.toInt());
          } else {
            episodeRange = MikanEpisodeRange(start: startInt, isSingle: true);
          }
        } else {
          episodeRange = MikanEpisodeRange(start: startInt, isSingle: true);
        }
      }
    }

    // Extract season
    final seasonMatch = RegExp(r'S(\d+)|第(\d+)季').firstMatch(title);
    if (seasonMatch != null) {
      final seasonNum = int.tryParse(seasonMatch.group(1) ?? seasonMatch.group(2) ?? '');
      if (seasonNum != null) {
        episodeRange = MikanEpisodeRange(isSeason: true, seasonNumber: seasonNum);
      }
    }

    // Extract resolution
    if (title.contains('1080') || title.contains('1080p')) {
      resolution = '1080P';
    } else if (title.contains('720') || title.contains('720p')) {
      resolution = '720P';
    } else if (title.contains('480') || title.contains('480p')) {
      resolution = '480P';
    } else if (title.contains('2160') || title.contains('4K')) {
      resolution = '4K';
    }

    // Extract subtitle languages
    if (title.contains('简中') || title.contains('国语') || title.contains('China')) {
      subtitleLanguages.add('ZHO');
    }
    if (title.contains('繁中') || title.contains('粤语')) {
      subtitleLanguages.add('ZHT');
    }
    if (title.contains('日语') || title.contains('JP')) {
      subtitleLanguages.add('JPN');
    }
    if (title.contains('英语') || title.contains('EN')) {
      subtitleLanguages.add('ENG');
    }
    // Default to Chinese if not specified
    if (subtitleLanguages.isEmpty) {
      subtitleLanguages.add('ZHO');
    }

    return MikanTitleDetails(
      alliance: alliance,
      episodeRange: episodeRange,
      resolution: resolution,
      subtitleLanguages: subtitleLanguages,
    );
  }
}

/// A subject found in Mikan search results.
class MikanSubject {
  final String name;
  final String id;

  const MikanSubject({required this.name, required this.id});
}

/// An episode from Mikan's HTML episode list page.
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

  String? get primaryLink => links.isNotEmpty ? links.first.url : null;
}

/// A download link from Mikan episode page.
class MikanDownloadLink {
  final String url;
  final String type;

  const MikanDownloadLink({required this.url, required this.type});
}
