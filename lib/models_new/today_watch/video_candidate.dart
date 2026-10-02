/// 今日推荐单 - 视频候选数据模型
/// 
/// 从 RcmdVideoItemModel 映射而来，保留推荐算法所需的字段
class TodayWatchVideoCandidate {
  final String bvid;
  final int? aid;
  final String title;
  final String? cover;
  final int duration;
  final int? pubdate;
  final int ownerMid;
  final String ownerName;
  final int viewCount;
  final int likeCount;
  final int coinCount;
  final int favoriteCount;
  final int shareCount;
  final int replyCount;
  final int danmakuCount;
  final int tid;
  final String tname;
  final double progress; // 0.0-1.0, -1 means fully watched
  final int? viewAt; // unix timestamp when last viewed

  const TodayWatchVideoCandidate({
    required this.bvid,
    this.aid,
    required this.title,
    this.cover,
    this.duration = 0,
    this.pubdate,
    required this.ownerMid,
    required this.ownerName,
    this.viewCount = 0,
    this.likeCount = 0,
    this.coinCount = 0,
    this.favoriteCount = 0,
    this.shareCount = 0,
    this.replyCount = 0,
    this.danmakuCount = 0,
    this.tid = 0,
    this.tname = '',
    this.progress = -1.0,
    this.viewAt,
  });

  factory TodayWatchVideoCandidate.fromRcmdVideo(dynamic rcmd) {
    // Adapt from RcmdVideoItemModel or similar source
    return TodayWatchVideoCandidate(
      bvid: rcmd.bvid ?? '',
      aid: rcmd.aid,
      title: rcmd.title ?? '',
      cover: rcmd.cover,
      duration: rcmd.duration ?? 0,
      pubdate: rcmd.pubdate,
      ownerMid: rcmd.owner?.mid ?? 0,
      ownerName: rcmd.owner?.name ?? '',
      viewCount: rcmd.stat?.view ?? 0,
      likeCount: rcmd.stat?.like ?? 0,
      coinCount: rcmd.stat is Map ? (rcmd.stat as Map)['coin'] ?? 0 : 0,
      favoriteCount: rcmd.stat is Map ? (rcmd.stat as Map)['favorite'] ?? 0 : 0,
      shareCount: rcmd.stat is Map ? (rcmd.stat as Map)['share'] ?? 0 : 0,
      replyCount: rcmd.stat is Map ? (rcmd.stat as Map)['reply'] ?? 0 : 0,
      danmakuCount: rcmd.stat?.danmu ?? 0,
      tid: 0, // Will be populated from other sources
      tname: '',
    );
  }

  TodayWatchVideoCandidate copyWith({
    String? bvid,
    String? title,
    double? progress,
    int? viewAt,
  }) {
    return TodayWatchVideoCandidate(
      bvid: bvid ?? this.bvid,
      aid: aid,
      title: title ?? this.title,
      cover: cover,
      duration: duration,
      pubdate: pubdate,
      ownerMid: ownerMid,
      ownerName: ownerName,
      viewCount: viewCount,
      likeCount: likeCount,
      coinCount: coinCount,
      favoriteCount: favoriteCount,
      shareCount: shareCount,
      replyCount: replyCount,
      danmakuCount: danmakuCount,
      tid: tid,
      tname: tname,
      progress: progress ?? this.progress,
      viewAt: viewAt ?? this.viewAt,
    );
  }
}
