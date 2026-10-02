import 'package:PiliPlus/models/horizontal_video_model.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/parse_string.dart';

class RcmdVideoItemAppModel extends BaseRcmdVideoItemModel {
  int? get id => aid;

  /// Whether this is a paid UGC video (充电专属 / 付费视频).
  bool isUgcPay = false;
  String? talkBack;
  String? tname;
  int? canPlay;

  String? cardType;
  ThreePoint? threePoint;

  RcmdVideoItemAppModel.fromJson(Map<String, dynamic> json) {
    aid = json['player_args']?['aid'] ?? parseIntOrNull(json['param']);
    bvid = json['bvid'] ?? IdUtils.av2bv(aid!);
    cid = json['player_args']?['cid'];
    cover = json['cover'];
    stat = RcmdStat.fromJson(json);
    // 改用player_args中的duration作为原始数据（秒数）
    duration = json['player_args']?['duration'] ?? 0;
    //duration = json['cover_right_text'];
    title = json['title'];
    isUgcPay = json['is_ugc_pay'] == 1 ||
        json['ugc_pay'] == 1 ||
        json['args']?['is_ugc_pay'] == 1;
    pubdate = json['pubdate'] ?? json['args']?['pubdate'];
    goto = json['card_goto'];
    owner = RcmdOwner.fromJson(json, goto);
    rcmdReason = json['rcmd_reason'];
    if (rcmdReason == '竖屏') rcmdReason = null;
    //     json['bottom_rcmd_reason'] ??
    //     json['top_rcmd_reason'];
    if (rcmdReason != null && rcmdReason!.contains('赞')) {
      // 有时能在推荐原因里获得点赞数
      (stat as RcmdStat).like = NumUtils.parseNum(rcmdReason!);
    }
    // 由于app端api并不会直接返回与owner的关注状态
    // 所以借用推荐原因是否为“已关注”、“新关注”判别关注状态，从而与web端接口等效
    isFollowed = const {'已关注', '新关注'}.contains(rcmdReason);
    // 如果是，就无需再显示推荐原因，交由view统一处理即可
    if (isFollowed) rcmdReason = null;

    param = int.parse(json['param']);
    uri = json['uri'];
    talkBack = json['talk_back'];
    canPlay = json['can_play'];

    if (goto == 'bangumi') {
      pgcBadge = json['cover_right_text'];
    }

    cardType = json['card_type'];
    tname = json['args']?['tname'];
    threePoint = json['three_point_v2'] != null
        ? ThreePoint.fromJson(json['three_point_v2'])
        : null;
    desc = json['desc'];
  }

  /// 适配为横向视频卡片（[VideoCardH]）可用的 [HorizontalVideoModel]。
  /// 让 app 推荐数据源（今日推荐单等）也能走统一的横向卡片渲染。
  HorizontalVideoModel toHorizontalVideoModel() =>
      RcmdHorizontalModel.fromRcmd(this);
}

/// 将 app 推荐数据源（[RcmdVideoItemAppModel]）适配为 [HorizontalVideoModel]，
/// 供 [VideoCardH] 渲染横向视频卡片。仅映射横向卡片实际用到的字段。
class RcmdHorizontalModel extends HorizontalVideoModel {
  RcmdHorizontalModel.fromRcmd(RcmdVideoItemAppModel src) {
    aid = src.aid;
    cid = src.cid;
    bvid = src.bvid;
    cover = src.cover;
    title = src.title;
    pubdate = src.pubdate;
    desc = src.desc;
    duration = src.duration;
    owner = src.owner;
    stat = src.stat;
    isFollowed = src.isFollowed;
    badge = src.pgcBadge;
  }
}

class RcmdStat extends BaseStat {
  RcmdStat.fromJson(Map<String, dynamic> json) {
    view = NumUtils.parseNum(json["cover_left_text_1"] ?? '');
    danmu = NumUtils.parseNum(json["cover_left_text_2"] ?? '');
    reply = NumUtils.parseNum(json["cover_right_text_2"] ?? '');
  }
}

class RcmdOwner extends BaseOwner {
  RcmdOwner.fromJson(Map<String, dynamic> json, String? goto) {
    name = goto == 'av'
        ? (json['args']?['up_name'] ?? '')
        : (json['desc_button']?['text'] ?? '');
    mid = json['args']?['up_id'] ?? 0;
  }
}

class ThreePoint {
  List<Reason>? dislikeReasons;
  List<Reason>? feedbacks;
  // int? watchLater;

  ThreePoint.fromJson(List json) {
    for (final elem in json) {
      switch (elem['type']) {
        // case 'watch_later':
        //   watchLater = 1;
        //   break;
        case 'feedback':
          feedbacks = (elem['reasons'] as List?)
              ?.map((i) => Reason.fromJson(i))
              .toList();
          break;
        case 'dislike':
          dislikeReasons = (elem['reasons'] as List?)
              ?.map((i) => Reason.fromJson(i))
              .toList();
          break;
      }
    }
  }
}

class Reason {
  int? id;
  String? name;
  String? toast;

  Reason.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    toast = json['toast'];
  }
}
