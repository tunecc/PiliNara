/// Unified resource model for animeko-style data sources.
///
/// Mirrors animeko's Media/MediaProperties but in Dart/Flutter types.
/// Source: /tmp/animeko_clone/datasource/api/src/commonMain/kotlin/Media.kt

class AnimekoResource {
  /// Global unique ID: "{sourceId}.{subjectId}-ep{num}"
  final String id;

  /// Source identifier: "mikan", "dmhy", etc.
  final String sourceId;

  /// Original title from the source
  final String title;

  /// Episode number (nullable if unknown)
  final int? episode;

  /// Resolution like "1080P", "720P"
  final String resolution;

  /// Subtitle group/name like "桜都字幕组"
  final String alliance;

  /// Download URL (magnet link or direct video URL)
  final String downloadUrl;

  /// Original URL to the source page
  final String originalUrl;

  /// Publish time (milliseconds since epoch)
  final DateTime? publishedAt;

  /// File size in bytes (0 if unknown)
  final int sizeBytes;

  /// Whether this is a torrent/BT source
  final bool isTorrent;

  const AnimekoResource({
    required this.id,
    required this.sourceId,
    required this.title,
    this.episode,
    this.resolution = '',
    this.alliance = '',
    required this.downloadUrl,
    required this.originalUrl,
    this.publishedAt,
    this.sizeBytes = 0,
    this.isTorrent = true,
  });

  factory AnimekoResource.fromMikan({
    required String subjectName,
    required String subjectId,
    required int episode,
    required String episodeName,
    required String linkUrl,
  }) {
    return AnimekoResource(
      id: '$subjectId-ep$episode',
      sourceId: 'mikan',
      title: '$subjectName 第$episode集 $episodeName',
      episode: episode,
      resolution: '1080P',
      alliance: '蜜柑计划',
      downloadUrl: linkUrl,
      originalUrl: '',
      isTorrent: linkUrl.startsWith('magnet'),
    );
  }

  factory AnimekoResource.fromDmhy({
    required String title,
    required String topicId,
    required String author,
    required String size,
    required String magnetUrl,
    required String detailUrl,
    int? episode,
    String? resolution,
  }) {
    return AnimekoResource(
      id: 'dmhy.$topicId',
      sourceId: 'dmhy',
      title: title,
      episode: episode,
      resolution: resolution ?? '',
      alliance: author,
      downloadUrl: magnetUrl.isNotEmpty ? magnetUrl : detailUrl,
      originalUrl: detailUrl,
      isTorrent: magnetUrl.isNotEmpty,
    );
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

  @override
  String toString() => 'AnimekoResource($sourceId, ep=$episode, $resolution, $title)';
}
