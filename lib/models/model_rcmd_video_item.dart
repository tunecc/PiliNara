import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

typedef RcmdItem = RcmdVideoItemAppModel;

/// PiliNara's today-recommend list.
///
/// Uses Bilibili's app-side recommendation API via [VideoHttp.rcmdVideoListApp].
/// Filters by watch history (optional) and max age hours (optional).
class TodayRecommendList {
  static Future<LoadingState<Map<int, RcmdItem>>> fetch({
    int page = 1,
    bool hideWatched = true,
    int maxAgeHours = 48,
  }) async {
    final state =
        await VideoHttp.rcmdVideoListApp(freshIdx: page, forceRefresh: true);

    if (state is! Success) return state;

    List<RcmdItem> items = state.data;

    // Filter out already-watched videos (watch progress > 5000ms).
    if (hideWatched) {
      items =
          items
              .where((v) {
                final progress = GStorage.watchProgress.get(v.cid);
                return progress == null || progress <= 5000;
              })
              .toList();
    }

    // Filter out videos older than maxAgeHours.
    if (maxAgeHours > 0) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      items =
          items
              .where((v) {
                if (v.pubdate == null) return true;
                final ageHours = (now - v.pubdate!) ~/ 3600;
                return ageHours <= maxAgeHours;
              })
              .toList();
    }

    // Deduplicate by cid, keep newest.
    items.sort((a, b) {
      final da = a.pubdate ?? 0;
      final db = b.pubdate ?? 0;
      if (da != db) return db.compareTo(da);
      return b.cid!.compareTo(a.cid!);
    });
    final seen = <int>{};
    items = items.where((v) => seen.add(v.cid!)).toList();

    final map = <int, RcmdItem>{};
    for (final v in items) {
      map[v.cid!] = v;
    }
    return Success(map);
  }
}
