import 'package:hive_ce/hive.dart';

/// 今日推荐单 - 本地缓存的分箱类型
enum TodayWatchBoxType {
  config('today_watch_config'),
  feedback('today_watch_feedback'),
  historyCache('today_watch_history_cache');

  final String name;
  const TodayWatchBoxType(this.name);
}
