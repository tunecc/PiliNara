/// 今日推荐单 - 视频卡片适配器
/// 将 TodayWatchVideoCandidate 适配为 BaseRcmdVideoItemModel
import 'package:PiliPlus/models/model_rec_video_item.dart';

class TodayWatchVideoAdapter extends BaseRcmdVideoItemModel {
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
  final int danmakuCount;
  final String? rcmdReason;

  TodayWatchVideoAdapter({
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
    this.danmakuCount = 0,
    this.rcmdReason,
  });

  @override
  dynamic operator [](Object key) => switch (key) {
    'bvid' => bvid,
    'aid' => aid,
    'title' => title,
    'pic' => cover,
    'duration' => duration,
    'pubdate' => pubdate,
    'goto' => goto,
    'uri' => uri,
    'rcmd_reason' => rcmdReason,
    _ => null,
  };

  @override
  String toString() => 'TodayWatchVideoAdapter(bvid: $bvid, title: $title)';
}
