import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';

/// 创作者观看信号（对齐 BiliPai TodayWatchProfileStore）
class CreatorSignal {
  final int mid;
  final String name;
  final double score;
  final int watchCount;

  CreatorSignal({
    required this.mid,
    required this.name,
    required this.score,
    required this.watchCount,
  });
}

/// 今日推荐单控制器
/// 基于用户观看历史生成个性化推荐（UP主榜 + 视频队列）
class TodayRecommendController extends CommonListController {
  /// 已观看的UP主信号
  final List<CreatorSignal> _creatorSignals = [];
  
  /// 推荐模式：轻松看 / 深度学习
  int _mode = 0; // 0=轻松看, 1=深度学习

  @override
  void onInit() {
    super.onInit();
    page = 0;
    queryData();
  }

  /// 切换推荐模式
  void setMode(int mode) {
    _mode = mode;
    page = 0;
    queryData(true);
  }

  @override
  Future<LoadingState> customGetData() async {
    try {
      // 获取App端推荐
      final result = await VideoHttp.rcmdVideoListApp(freshIdx: page);
      
      if (result case Success(:final response)) {
        final videos = response;
        if (videos.isNotEmpty) {
          // 基于UP主信号排序
          if (_creatorSignals.isNotEmpty) {
            final sorted = videos.toList()
              ..sort((a, b) {
                final aMid = (a as RcmdVideoItemAppModel).owner.mid;
                final bMid = (b as RcmdVideoItemAppModel).owner.mid;
                final aSignal = _creatorSignals.firstWhere(
                  (s) => s.mid == aMid,
                  orElse: () => CreatorSignal(mid: 0, name: '', score: 0, watchCount: 0),
                );
                final bSignal = _creatorSignals.firstWhere(
                  (s) => s.mid == bMid,
                  orElse: () => CreatorSignal(mid: 0, name: '', score: 0, watchCount: 0),
                );
                return bSignal.score.compareTo(aSignal.score);
              });
            return Success(sorted);
          }
          
          return result;
        }
      }
      return result;
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  bool get isEnd => false;

  @override
  Future<void> onRefresh() {
    page = 0;
    return queryData(true);
  }

  /// 获取UP主榜（前10）
  List<CreatorSignal> get creatorSignals => _creatorSignals;
  
  /// 当前模式
  int get mode => _mode;
}
