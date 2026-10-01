import 'package:PiliPlus/models/model_rcmd_video_item.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class TodayRecommendController
    extends CommonListController<List<RcmdItem>, List<RcmdItem>> {
  final RcmdApi _rcmdApi = RcmdApi();

  @override
  Future<void> customGetData() async {
    final response = await _rcmdApi.rcmdList(freshIdx: page);
    if (response.isSuccess) {
      return Success(response.data ?? []);
    }
    return Error(response.toString());
  }

  @override
  void handleListResponse(List<RcmdItem> dataList) {}

  @override
  List<RcmdItem>? getDataList(List<RcmdItem> response) => response;

  @override
  void checkIsEnd(int length) {
    isEnd = length < 20;
    hasFooter = !isEnd;
  }

  @override
  void onLoad() {
    if (hasFooter == true) {
      Future.microtask(onLoadMore);
    }
  }

  /// 加载下一页
  Future<void> onLoadMore() => queryData(false);

  /// 刷新
  Future<void> refresh() => queryData(true);
}
