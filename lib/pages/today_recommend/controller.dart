import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/services/logger.dart';

class TodayRecommendController
    extends CommonListController<dynamic, RcmdVideoItemAppModel> {
  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  Future<LoadingState<dynamic>> customGetData() async {
    try {
      return await VideoHttp.rcmdVideoListApp(freshIdx: page);
    } catch (e) {
      logger.e('TodayRecommend fetch failed: $e');
      return Error(e.toString());
    }
  }

  @override
  List<RcmdVideoItemAppModel>? getDataList(dynamic response) {
    if (response is! List<RcmdVideoItemAppModel>) return null;
    final hideWatched = Pref.todayRecommendHideWatched;
    final maxAgeHours = Pref.todayRecommendMaxAgeHours;
    if (!hideWatched && maxAgeHours <= 0) return response;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return response.where((item) {
      if (hideWatched && _isWatched(item)) return false;
      if (maxAgeHours > 0 && item.pubdate != null) {
        final ageHours = (now - item.pubdate!) ~/ 3600;
        if (ageHours > maxAgeHours) return false;
      }
      return true;
    }).toList();
  }

  /// A video counts as watched once we have non-trivial watch progress for it.
  bool _isWatched(RcmdVideoItemAppModel item) {
    final progress = GStorage.watchProgress.get(item.cid);
    return progress != null && progress > 5000;
  }
}
