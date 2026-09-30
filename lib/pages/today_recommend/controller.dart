import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
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
    if (response is List<RcmdVideoItemAppModel>) return response;
    return null;
  }
}
