import 'package:PiliPlus/services/traffic_stats_service.dart';
import 'package:get/get.dart';

class TrafficStatsController extends GetxController {
  final RxMap<String, dynamic> stats = <String, dynamic>{}.obs;

  @override
  void onInit() {
    super.onInit();
    refreshStats();
  }

  void refreshStats() {
    // TrafficStatsService exposes static methods; read current accumulated data
    stats.value = {'note': 'Traffic stats are accumulated hourly. See service for raw data.'};
  }
}
