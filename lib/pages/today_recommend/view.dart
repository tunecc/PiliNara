import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/home_tab_type.dart';
import 'package:PiliPlus/app/app_model/app_model.video_item.dart';
import 'package:PiliPlus/models/model_rcmd_video_item.dart';
import 'package:PiliPlus/pages/today_recommend/controller.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class TodayRecommendPage extends StatefulWidget {
  const TodayRecommendPage({super.key});

  @override
  State<TodayRecommendPage> createState() => _TodayRecommendPageState();
}

class _TodayRecommendPageState extends State<TodayRecommendPage>
    with AutomaticKeepAliveClientMixin, GridMixin {
  final TodayRecommendController _rcmd = Get.put(TodayRecommendController());

  @override
  bool get wantKeepAlive => true;

  /// 今日日期标签
  String get _dateLabel {
    final now = DateTime.now();
    final weekdays = ['日', '一', '二', '三', '四', '五', '六'];
    return '${now.month}月${now.day}日 · 周${weekdays[now.weekday % 7]}';
  }

  @override
  void initState() {
    super.initState();
    _rcmd.refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return SimpleScaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 20),
            const SizedBox(width: 6),
            Text('今日推荐', style: theme.textTheme.titleLarge),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _dateLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // 刷新
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _rcmd.onRefresh,
            tooltip: '刷新',
          ),
          // 订阅保存
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _subscribeToday,
            tooltip: '保存今日推荐单',
          ),
          // 分享
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareToday,
            tooltip: '分享',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: refreshIndicator(
        onRefresh: _rcmd.onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _rcmd.scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(top: 7, bottom: 100),
              sliver: Obx(
                () => _buildBody(_rcmd.loadingState.value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(LoadingState<List<RcmdItem>?> loadingState) {
    return switch (loadingState) {
      Loading() => gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  if (index == response.length - 1) {
                    _rcmd.onLoadMore();
                  }
                  final hModel = response[index].toHorizontalVideoModel();
                  return VideoCardH(
                    video: hModel,
                    onRemove: () {
                      final data = _rcmd.loadingState.value.data;
                      if (data != null && index < data.length) {
                        data.removeAt(index);
                        _rcmd.loadingState.refresh();
                      }
                    },
                  );
                },
                itemCount: response.length,
              )
            : HttpError(onReload: _rcmd.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _rcmd.onReload,
      ),
    };
  }

  /// 保存今日推荐单到本地收藏夹
  Future<void> _subscribeToday() async {
    final data = _rcmd.loadingState.value.data;
    if (data == null || data.isEmpty) {
      SmartDialog.showToast('暂无可保存的推荐视频');
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存今日推荐单'),
        content: Text('将保存 ${data.length} 个视频到本地收藏，确定？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == 'save' && mounted) {
      final ids = data.map((v) => v.cid).whereType<int>().toList();
      await GStorage.setting.put(SettingBoxKey.todayRecommendSaved, {
        'date': DateTime.now().toIso8601String(),
        'ids': ids,
        'count': ids.length,
      });
      SmartDialog.showToast('已保存 ${ids.length} 个视频到今日收藏');
    }
  }

  /// 分享今日推荐单
  Future<void> _shareToday() async {
    final data = _rcmd.loadingState.value.data;
    if (data == null || data.isEmpty) return;
    final sb = StringBuffer();
    sb.writeln('📺 B站今日推荐（$_dateLabel）');
    sb.writeln('=' * 30);
    for (final v in data.take(10)) {
      sb.writeln(v.title ?? '');
      if (v.owner != null) sb.writeln('  ${v.owner!.name}');
      sb.writeln('  https://b23.tv/${v.bvid}');
    }
    if (data.length > 10) sb.writeln('... 等共${data.length}个视频');
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (mounted) SmartDialog.showToast('已复制到剪贴板');
  }
}
