import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/utils/storage.dart';

typedef RcmdItem = RcmdVideoItemAppModel;

/// 今日推荐数据源（基于 app 接口，无 Web 端 API 时使用）
class TodayRecommendList {
  /// 获取指定页的 app 推荐视频列表（已过滤已看 / 超龄 / 去重）
  static Future<LoadingState<List<RcmdItem>>> fetch({
    required int freshIdx,
    bool hideWatched = true,
    int maxAgeHours = 48,
  }) async {
    final state = await VideoHttp.rcmdVideoListApp(freshIdx: freshIdx);
    if (state is! Success) return state;

    // 过滤已看
    var items = state.data;
    if (hideWatched) {
      items = items
          .where((v) {
            final progress = GStorage.watchProgress.get(v.cid);
            return progress == null || progress <= 5000;
          })
          .toList();
    }

    // 过滤超龄
    if (maxAgeHours > 0) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      items = items
          .where((v) {
            if (v.pubdate == null) return true;
            return (now - v.pubdate!) ~/ 3600 <= maxAgeHours;
          })
          .toList();
    }

    // 去重 + 排序
    items.sort((a, b) {
      final da = a.pubdate ?? 0, db = b.pubdate ?? 0;
      if (da != db) return db.compareTo(da);
      final ca = a.cid ?? 0, cb = b.cid ?? 0;
      return cb.compareTo(ca);
    });
    final seen = <int>{};
    items = items.where((v) => v.cid != null && seen.add(v.cid!)).toList();

    return Success(items);
  }
}
