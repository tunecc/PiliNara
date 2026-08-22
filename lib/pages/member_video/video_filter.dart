import 'package:PiliPlus/models_new/space/space_archive/item.dart';

// 用户空间视频列表的客户端本地过滤条件
class MemberVideoFilter {
  // 预设播放量阈值：1万 / 10万 / 50万 / 100万
  static const List<int> playPresets = [10000, 100000, 500000, 1000000];

  bool enableMinPlay = false;
  int minPlay = playPresets.first;
  bool enableMaxPlay = false;
  int maxPlay = playPresets.last;
  bool hideCompleted = false;
  bool hideInProgress = false;

  bool get hasActiveFilter =>
      enableMinPlay || enableMaxPlay || hideCompleted || hideInProgress;

  // 已看完：history 存在且进度数据完整、progress == duration
  static bool isCompleted(SpaceArchiveItem item) {
    final history = item.history;
    final progress = history?.progress;
    final duration = history?.duration;
    return history != null &&
        progress != null &&
        duration != null &&
        progress == duration;
  }

  // 看过未看完：history 存在且进度数据完整、progress != duration
  static bool isInProgress(SpaceArchiveItem item) {
    final history = item.history;
    final progress = history?.progress;
    final duration = history?.duration;
    return history != null &&
        progress != null &&
        duration != null &&
        progress != duration;
  }

  bool shouldHide(SpaceArchiveItem item) {
    if (enableMinPlay) {
      final view = item.stat.view;
      if (view != null && view < minPlay) {
        return true;
      }
    }
    if (enableMaxPlay) {
      final view = item.stat.view;
      if (view != null && view > maxPlay) {
        return true;
      }
    }
    if (hideCompleted && isCompleted(item)) {
      return true;
    }
    if (hideInProgress && isInProgress(item)) {
      return true;
    }
    return false;
  }

  void reset() {
    enableMinPlay = false;
    enableMaxPlay = false;
    hideCompleted = false;
    hideInProgress = false;
  }
}
