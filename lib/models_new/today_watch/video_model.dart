/// 今日推荐单 - 视频卡片适配器
/// 将 TodayWatchVideoCandidate 转换为可显示在推荐流中的模型
import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';

/// 简单的 Owner 实现
class _SimpleOwner extends BaseOwner {
  final int mid;
  final String name;
  _SimpleOwner(this.mid, this.name);
}

/// 今日推荐单视频模型，继承自 RcmdVideoItemModel 以便复用 VideoCardV
class TodayWatchVideoModel extends RcmdVideoItemModel {
  TodayWatchVideoModel({
    required String bvid,
    int? aid,
    required String title,
    String? cover,
    int duration = 0,
    int? pubdate,
    required int ownerMid,
    required String ownerName,
    int viewCount = 0,
    int likeCount = 0,
    int coinCount = 0,
    int favoriteCount = 0,
    int shareCount = 0,
    int replyCount = 0,
    int danmakuCount = 0,
    String? rcmdReason,
  }) : super.fromJson({
    'id': aid,
    'bvid': bvid,
    'cid': null,
    'goto': 'av',
    'uri': null,
    'pic': cover,
    'title': title,
    'duration': duration,
    'pubdate': pubdate,
    'owner': {'mid': ownerMid, 'name': ownerName},
    'stat': {
      'view': viewCount,
      'like': likeCount,
      'danmaku': danmakuCount,
      'coin': coinCount,
      'favorite': favoriteCount,
      'share': shareCount,
      'reply': replyCount,
    },
    'is_followed': 0,
    'rcmd_reason': rcmdReason != null ? {'content': rcmdReason} : null,
  });
}
