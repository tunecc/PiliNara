/// Animeko 资源模型
class AnimekoResource {
  final String id;
  final String source; // "bilibili" | "mikan"
  final String title;
  final String? cover;
  final int? seasonId; // B 站 season ID
  final int? epId; // B 站 episode ID
  final String? magnetUrl; // BT 磁力链接
  final String? bangumiId; // Bangumi 条目 ID
  final double? rating;
  final List<String>? tags;

  const AnimekoResource({
    required this.id,
    required this.source,
    required this.title,
    this.cover,
    this.seasonId,
    this.epId,
    this.magnetUrl,
    this.bangumiId,
    this.rating,
    this.tags,
  });

  bool get canPlay => source == 'bilibili' && seasonId != null && epId != null;
  bool get isTorrent => magnetUrl != null;
}
