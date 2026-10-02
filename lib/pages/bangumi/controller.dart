import 'package:PiliPlus/http/bangumi.dart';
import 'package:PiliPlus/models/bangumi/calendar_item.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class BangumiController extends GetxController with ScrollOrRefreshMixin {
  final RxList<BangumiCalendarItem> items = <BangumiCalendarItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();

  @override
  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    onRefresh();
  }

  @override
  Future<void> onRefresh() async {
    isLoading.value = true;
    error.value = null;
    final list = await BangumiHttp.calendar();
    items.assignAll(list);
    if (list.isEmpty) {
      error.value = '获取 bangumi 日程失败';
    }
    isLoading.value = false;
  }

  Future<void> refreshCalendar() => onRefresh();

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
