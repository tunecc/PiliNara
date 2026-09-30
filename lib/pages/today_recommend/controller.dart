import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/services/logger.dart';

class TodayRecommendController extends CommonListController {
  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  Future<LoadingState> customGetData() async {
    try {
      return await VideoHttp.rcmdVideoListApp(freshIdx: page);
    } catch (e) {
      logger.e('TodayRecommend fetch failed: $e');
      return Error(e.toString());
    }
  }

  @override
  List? getDataList(dynamic response) {
    if (response == null) return null;
    if (response is List) return response;
    return null;
  }
}
