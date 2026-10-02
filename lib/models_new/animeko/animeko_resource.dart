/// Unified resource model for animeko-style data sources.
///
/// Ported from animeko's Media/Topic models to provide a unified interface
/// for both Mikan (BT) and DMHY (BT) sources, plus future Web sources.
///
/// Key design:
/// - EpisodeRange supports single episode, range, season, and combined
/// - Resolution follows animeko's standard values (480P, 720P, 1080P, 4K)
/// - Subtitle languages use ISO 639-2 codes (ZHO, JPN, ENG)
/// - ResourceLocation maps to actual download types (magnet, torrent, streaming)

class AnimekoResource {
  /// Global unique ID: "{sourceId}.{resourceId}"
  final String id;

  /// Source identifier: "mikan", "dmhy", "ikaros", etc.
  final String sourceId;

  /// Original title from the source
  final String title;

  /// Episode range this resource covers
  final AnimekoEpisodeRange? episodeRange;

  /// Resolution (480P, 720P, 1080P, 4K)
  final String? resolution;

  /// Subtitle group/alliance name
  final String alliance;

  /// Subtitle languages (ISO 639-2 codes)
  final List<String> subtitleLanguages;

  /// Download URL (magnet link, torrent file, or streaming URL)
  final String downloadUrl;

  /// Original URL to the source page
  final String originalUrl;

  /// Resource type
  final AnimekoResourceType type;

  /// File size in bytes (0 if unknown)
  final int sizeBytes;

  /// Publish time
  final DateTime? publishedAt;

  /// Bangumi subject ID if known
  final String? bangumiSubjectId;

  const AnimekoResource({
    required this.id,
    required this.sourceId,
    required this.title,
    this.episodeRange,
    this.resolution,
    this.alliance = '',
    this.subtitleLanguages = const [],
    required this.downloadUrl,
    required this.originalUrl,
    this.type = AnimekoResourceType.bittorrent,
    this.sizeBytes = 0,
    this.publishedAt,
    this.bangumiSubjectId,
  });

  /// Create from Mikan RSS topic
  factory AnimekoResource.fromMikanTopic({
    required MikanTopic topic,
    required String bangumiSubjectId,
  }) {
    return AnimekoResource(
      id: 'mikan.${topic.topicId}',
      sourceId: 'mikan',
      title: topic.rawTitle,
      episodeRange: topic.episodeRange?.toAnimekoRange(),
      resolution: topic.resolution,
      alliance: topic.alliance,
      subtitleLanguages: topic.subtitleLanguages,
      downloadUrl: topic.downloadUrl ?? '',
      originalUrl: topic.originalLink,
      type: topic.isTorrent ? AnimekoResourceType.bittorrent : AnimekoResourceType.streaming,
      sizeBytes: topic.sizeBytes,
      publishedAt: topic.publishedAt,
      bangumiSubjectId: bangumiSubjectId,
    );
  }

  /// Create from DMHY topic
  factory AnimekoResource.fromDmhyTopic({
    required DmhyTopic topic,
    String? bangumiSubjectId,
  }) {
    // Parse episode from title
    final epMatch = RegExp(r'(?:第|EP|ep|Ep)?(\d+(?:\.\d+)?)?(?:[-—~](\d+(?:\.\d+)?))?(?:集|话|episode|Episode)?')
        .firstMatch(topic.title);
    AnimekoEpisodeRange? episodeRange;
    if (epMatch != null) {
      final start = double.tryParse(epMatch.group(1) ?? '');
      final endStr = epMatch.group(2);
      if (start != null) {
        final startInt = start.toInt();
        if (endStr != null) {
          final end = double.tryParse(endStr);
          if (end != null) {
            episodeRange = AnimekoEpisodeRange.single(start: startInt, end: end.toInt());
          } else {
            episodeRange = AnimekoEpisodeRange.single(start: startInt);
          }
        } else {
          episodeRange = AnimekoEpisodeRange.single(start: startInt);
        }
      }
    }

    // Parse resolution
    String? resolution;
    if (topic.title.contains('1080') || topic.title.contains('1080p')) {
      resolution = '1080P';
    } else if (topic.title.contains('720') || topic.title.contains('720p')) {
      resolution = '720P';
    } else if (topic.title.contains('480') || topic.title.contains('480p')) {
      resolution = '480P';
    } else if (topic.title.contains('2160') || topic.title.contains('4K')) {
      resolution = '4K';
    }

    return AnimekoResource(
      id: 'dmhy.${topic.id}',
      sourceId: 'dmhy',
      title: topic.title,
      episodeRange: episodeRange,
      resolution: resolution,
      alliance: topic.allianceName,
      subtitleLanguages: ['ZHO'], // Default to Chinese
      downloadUrl: topic.magnetUrl,
      originalUrl: topic.detailUrl,
      type: topic.isTorrent ? AnimekoResourceType.bittorrent : AnimekoResourceType.streaming,
      sizeBytes: topic.sizeBytes,
      publishedAt: _parseDate(topic.date),
      bangumiSubjectId: bangumiSubjectId,
    );
  }

  static DateTime? _parseDate(String dateStr) {
    try {
      return DateTime.tryParse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// Human-readable size string
  String get sizeString {
    if (sizeBytes == 0) return '未知';
    if (sizeBytes >= 1073741824) {
      return '${(sizeBytes / 1073741824).toStringAsFixed(1)} GB';
    }
    if (sizeBytes >= 1048576) {
      return '${(sizeBytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$sizeBytes B';
  }

  /// Check if this resource matches the requested episode
  bool matchesEpisode(int episode) {
    if (episodeRange == null) return false;
    return episodeRange!.contains(episode);
  }

  @override
  String toString() => 'AnimekoResource($sourceId, ${episodeRange}, $resolution, $title)';
}

/// Episode range for anime resources.
/// Mirrors animeko's EpisodeRange with Single, Range, Season, Combined.
class AnimekoEpisodeRange {
  final int? start;
  final int? end;
  final bool isSeason;
  final int? seasonNumber;

  const AnimekoEpisodeRange._({this.start, this.end, this.isSeason = false, this.seasonNumber});

  /// Single episode
  const AnimekoEpisodeRange.single({required int start, int? end})
      : this._(start: start, end: end ?? start);

  /// Episode range (start to end inclusive)
  const AnimekoEpisodeRange.range({required int start, required int end})
      : this._(start: start, end: end);

  /// Whole season
  const AnimekoEpisodeRange.season(int number)
      : this._(isSeason: true, seasonNumber: number);

  /// Check if this range contains the given episode number
  bool contains(int episode) {
    if (isSeason) return true;
    if (start == null) return false;
    if (end != null) {
      return episode >= start! && episode <= end!;
    }
    return episode == start;
  }

  /// Check if this is a single episode
  bool get isSingle => start != null && end != null && start == end;

  /// Get all episodes in this range
  List<int> get episodes {
    if (isSeason) return [];
    if (start == null) return [];
    if (end != null) {
      return List.generate(end! - start! + 1, (i) => start! + i);
    }
    return [start!];
  }

  @override
  String toString() {
    if (isSeason) return 'S$seasonNumber';
    if (isSingle && start != null) return 'Ep$start';
    if (start != null && end != null) return '$start-$end';
    return '?';
  }
}

/// Resource type classification.
/// Mirrors animeko's MediaSourceKind.
enum AnimekoResourceType {
  /// BitTorrent magnet link or .torrent file
  bittorrent,

  /// Direct HTTP streaming (HLS, MP4, etc.)
  streaming,

  /// WebView-based (needs browser to extract video URL)
  webvideo,

  /// Local cached file
  localcache,
}

/// Extension to convert MikanEpisodeRange to AnimekoEpisodeRange
extension MikanEpisodeRangeX on MikanEpisodeRange? {
  AnimekoEpisodeRange? toAnimekoRange() {
    if (this == null) return null;
    final r = this!;
    if (r.isSeason) {
      return AnimekoEpisodeRange.season(r.seasonNumber ?? 0);
    }
    if (r.start != null && r.end != null) {
      return AnimekoEpisodeRange.range(start: r.start!, end: r.end!);
    }
    if (r.start != null) {
      return AnimekoEpisodeRange.single(start: r.start!);
    }
    return null;
  }
}
