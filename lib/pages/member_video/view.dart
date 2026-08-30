import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart'
    show ReloadScrollPhysics;
import 'package:PiliPlus/common/widgets/sliver/sliver_floating_header.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/member/contribute_type.dart';
import 'package:PiliPlus/models_new/space/space_archive/item.dart';
import 'package:PiliPlus/pages/common/fab_mixin.dart';
import 'package:PiliPlus/pages/member/controller.dart';
import 'package:PiliPlus/pages/member_video/controller.dart';
import 'package:PiliPlus/pages/member_video/widgets/member_video_filter_dialog.dart';
import 'package:PiliPlus/pages/member_video/widgets/video_card_h_member_video.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class MemberVideo extends StatefulWidget {
  const MemberVideo({
    super.key,
    required this.type,
    required this.heroTag,
    required this.mid,
    this.seasonId,
    this.seriesId,
    this.title,
    this.isSingle = false,
  });

  final ContributeType type;
  final String? heroTag;
  final int mid;
  final int? seasonId;
  final int? seriesId;
  final String? title;
  final bool isSingle;

  @override
  State<MemberVideo> createState() => _MemberVideoState();
}

class _MemberVideoState extends State<MemberVideo>
    with
        AutomaticKeepAliveClientMixin,
        GridMixin,
        SingleTickerProviderStateMixin,
        BaseFabMixin,
        LazyFabMixin {
  @override
  bool get wantKeepAlive => true;

  late final MemberVideoCtr _controller;

  void _jumpToIndex(int index) {
    final scrollOffset = gridDelegate.layoutCache!
        .getGeometryForChildIndex(index)
        .scrollOffset;
    try {
      final state = Get.find<MemberController>(
        tag: widget.heroTag,
      ).scrollKey.currentState;
      if (state != null && state.mounted) {
        state.innerNestedPositions.first.localJumpTo(scrollOffset);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('jump error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      MemberVideoCtr(
        type: widget.type,
        mid: widget.mid,
        seasonId: widget.seasonId,
        seriesId: widget.seriesId,
        username: Get.find<MemberController>(tag: widget.heroTag).username,
        title: widget.title,
      ),
      tag:
          '${widget.heroTag}${widget.type.name}${widget.seasonId}${widget.seriesId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final child = refreshIndicator(
      onRefresh: () async {
        final count = _controller.loadingState.value.dataOrNull?.length;
        await _controller.onRefresh();
        if (_controller.isLocating.value && mounted) {
          final newCount = _controller.loadingState.value.dataOrNull?.length;
          if (count != null && newCount != null && newCount > count) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              _jumpToIndex(newCount - count);
            });
          }
        }
      },
      child: CustomScrollView(
        physics: ReloadScrollPhysics(controller: _controller),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(bottom: padding.bottom + 100),
            sliver: Obx(
              () => _buildBody(theme, _controller.loadingState.value),
            ),
          ),
        ],
      ),
    );
    if (_controller.isVideo && _controller.fromViewAid?.isNotEmpty == true) {
      return ScaffoldLayout(
        body: fabAnimWrapper(child: child),
        fab: Obx(
          () => !_controller.isLocating.value
              ? SlideTransition(
                  position: fabAnimation,
                  child: Padding(
                    padding: .only(
                      right: kFloatingActionButtonMargin,
                      bottom: kFloatingActionButtonMargin + padding.bottom,
                    ),
                    child: FloatingActionButton.extended(
                      onPressed: () {
                        final fromViewAid = _controller.fromViewAid;
                        _controller.isLocating.value = true;
                        final locatedIndex = _controller.indexOfFromViewAid();
                        if (locatedIndex == -1) {
                          _controller
                            ..lastAid = fromViewAid
                            ..reload = true
                            ..page = 0
                            ..loadingState.value = LoadingState.loading()
                            ..queryData();
                        } else {
                          _jumpToIndex(locatedIndex);
                        }
                      },
                      label: const Text('定位至上次观看'),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      );
    }
    return child;
  }

  @override
  Widget get gridSkeleton => SliverPadding(
    padding: widget.isSingle ? const EdgeInsets.only(top: 7) : EdgeInsets.zero,
    sliver: super.gridSkeleton,
  );

  Widget _buildBody(
    ThemeData theme,
    LoadingState<List<SpaceArchiveItem>?> loadingState,
  ) {
    return switch (loadingState) {
      Loading() => gridSkeleton,
      Success() => Obx(() {
        final list = _controller.filteredList;
        if (list.isEmpty) {
          if (_controller.isEnd) {
            return _buildFilteredOutEnd(theme);
          }
          if (_controller.hasActiveFilter) {
            return _buildFilteredOutAutoLoading(theme);
          }
          return HttpError(onReload: _controller.onReload);
        }
        return SliverMainAxisGroup(
          slivers: [
            _buildHeader(theme),
            SliverGrid.builder(
              gridDelegate: gridDelegate,
              itemBuilder: (context, index) {
                if (index == list.length - 1) {
                  if (widget.type == .season) {
                    // 合集类型无分页，到底即结束
                  } else if (!_controller.hasActiveFilter) {
                    _controller.onLoadMore();
                  } else {
                    // 过滤开启时尾项触发手动加载（节流），加载后自动重新过滤
                    _controller.manualLoadMore();
                  }
                }
                return VideoCardHMemberVideo(
                  videoItem: list[index],
                  fromViewAid: _controller.fromViewAid,
                );
              },
              itemCount: list.length,
            ),
          ],
        );
      }),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _controller.onReload,
      ),
    };
  }
  Widget _buildFilteredOutAutoLoading(ThemeData theme) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 12),
            Text(
              _controller.isAutoLoading.value
                  ? '当前内容已被过滤，正在加载更多…'
                  : '当前过滤条件下暂无内容，可调整过滤或上拉加载更多',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.outline,
              ),
            ),
            if (!_controller.isAutoLoading.value) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => MemberVideoFilterDialog.show(
                  context,
                  _controller.filter,
                ).whenComplete(_controller.onFilterChanged),
                child: const Text('调整过滤条件'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 已到列表末尾且无符合项
  Widget _buildFilteredOutEnd(ThemeData theme) {
    // 无过滤时 isEnd 且空 = 真空数据态，恢复原版「没有数据 + 重试」
    if (!_controller.hasActiveFilter) {
      return HttpError(onReload: _controller.onReload);
    }
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              '没有更多了',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () =>
                  MemberVideoFilterDialog.show(context, _controller.filter)
                      .whenComplete(_controller.onFilterChanged),
              child: const Text('调整过滤条件'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return SliverFloatingHeaderWidget(
      backgroundColor: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 2.5, 8, 2.5),
        child: Row(
          children: [
            ?_buildCount(),
            ?_buildEpisodeBtn(theme),
            const Spacer(),
            _buildFilterBtn(theme),
            const SizedBox(width: 4),
            _buildSortBtn(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBtn(ThemeData theme) {
    // 依赖父级 Obx（filterActive/filteredList）重建，弹窗关闭后 onFilterChanged 会刷新列表
    return IconButton(
      tooltip: '筛选',
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      onPressed: () => MemberVideoFilterDialog.show(
        context,
        _controller.filter,
      ).whenComplete(_controller.onFilterChanged),
      icon: Obx(() {
        final hasFilter = _controller.filterActive.value;
        return Icon(
          hasFilter ? Icons.filter_list : Icons.filter_list_off,
          size: 18,
          color: hasFilter
              ? theme.colorScheme.primary
              : theme.colorScheme.secondary,
        );
      }),
    );
  }

  Widget? _buildCount() {
    final count = _controller.count;
    if (count != null) {
      return Text(
        '共$count视频',
        style: const TextStyle(fontSize: 13),
      );
    }
    return null;
  }

  Widget? _buildEpisodeBtn(ThemeData theme) {
    final episodicButton = _controller.episodicButton;
    if (episodicButton?.uri?.isNotEmpty ?? false) {
      return Padding(
        padding: EdgeInsets.only(
          left: _controller.count != null ? 6 : 0,
        ),
        child: TextButton.icon(
          style: Style.buttonStyle,
          onPressed: _controller.toViewPlayAll,
          icon: Icon(
            Icons.play_circle_outline_rounded,
            size: 16,
            color: theme.colorScheme.secondary,
          ),
          label: Text(
            episodicButton?.text ?? '播放全部',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
      );
    }
    return null;
  }

  Widget _buildSortBtn(ThemeData theme) {
    return TextButton.icon(
      style: Style.buttonStyle,
      onPressed: _controller.queryBySort,
      icon: Icon(
        Icons.sort,
        size: 16,
        color: theme.colorScheme.secondary,
      ),
      label: Text(
        _controller.isVideo ? _controller.order.label : _controller.sort.label,
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.secondary,
        ),
      ),
    );
  }
}
