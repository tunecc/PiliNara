import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:PiliPlus/plugin/pl_player/models/double_tap_seek_layout.dart';
import 'package:PiliPlus/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class DoubleTapSeekZoneSettingPage extends StatefulWidget {
  const DoubleTapSeekZoneSettingPage({super.key});

  @override
  State<DoubleTapSeekZoneSettingPage> createState() =>
      _DoubleTapSeekZoneSettingPageState();
}

class _DoubleTapSeekZoneSettingPageState
    extends State<DoubleTapSeekZoneSettingPage> {
  static const double _handleWidth = 28;
  /// 区域内动作提示的最小显示宽度：低于阈值时只显示色带
  static const double _zoneIconMinWidth = 32;
  static const double _zoneTextMinWidth = 84;

  late double _backwardPercent;
  late double _forwardPercent;
  bool _isLandscape = false;
  final ValueNotifier<int> _dragRefresh = ValueNotifier<int>(0);

  DoubleTapSeekLayout get _layout => DoubleTapSeekLayout.normalize(
    backwardPercent: _backwardPercent.round(),
    forwardPercent: _forwardPercent.round(),
  );
  double get _centerPercent => 100 - _backwardPercent - _forwardPercent;
  double get _backwardFraction => _backwardPercent / 100;
  double get _centerFraction => _centerPercent / 100;
  double get _forwardFraction => _forwardPercent / 100;

  @override
  void initState() {
    super.initState();
    final layout = DoubleTapSeekLayout.normalize(
      backwardPercent: Pref.doubleTapBackwardZone,
      forwardPercent: Pref.doubleTapForwardZone,
    );
    _backwardPercent = layout.backwardPercent.toDouble();
    _forwardPercent = layout.forwardPercent.toDouble();
  }

  void _updateBackward(double nextValue) {
    final next = DoubleTapSeekLayout.clampBackwardPercentDouble(
      nextValue,
      forwardPercent: _forwardPercent,
    );
    if ((_backwardPercent - next).abs() < 0.001) {
      return;
    }
    _backwardPercent = next;
    _dragRefresh.value++;
  }

  void _updateForward(double nextValue) {
    final next = DoubleTapSeekLayout.clampForwardPercentDouble(
      nextValue,
      backwardPercent: _backwardPercent,
    );
    if ((_forwardPercent - next).abs() < 0.001) {
      return;
    }
    _forwardPercent = next;
    _dragRefresh.value++;
  }

  void _reset() {
    setState(() {
      _backwardPercent = DoubleTapSeekLayout.defaultBackwardPercent.toDouble();
      _forwardPercent = DoubleTapSeekLayout.defaultForwardPercent.toDouble();
    });
    _dragRefresh.value++;
  }

  void _save() {
    final layout = _layout;
    GStorage.setting
      ..put(SettingBoxKey.doubleTapBackwardZone, layout.backwardPercent)
      ..put(SettingBoxKey.doubleTapForwardZone, layout.forwardPercent);
    SmartDialog.showToast('双击区域已保存');
    Get.back(result: true);
  }

  /// 横屏预览复用播放器全屏的旋转与沉浸机制
  void _enterLandscape() {
    if (!PlatformUtils.isMobile) {
      return;
    }
    unawaited(hideSystemBar());
    if (Platform.isAndroid) {
      landscapeLeftMode();
    } else {
      landscapeRightMode();
    }
  }

  /// 恢复语义与播放器 resetScreenRotation 一致
  void _restorePortrait() {
    if (!PlatformUtils.isMobile) {
      return;
    }
    unawaited(showSystemBar());
    unawaited(Pref.horizontalScreen ? fullMode() : portraitUpMode());
  }

  void _setLandscape(bool value) {
    if (_isLandscape == value) {
      return;
    }
    setState(() => _isLandscape = value);
    if (value) {
      _enterLandscape();
    } else {
      _restorePortrait();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: _isLandscape
          ? _buildLandscapeBody()
          : _buildPortraitBody(context),
    );
  }

  Widget _buildModeToggle() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('竖屏预览'),
          icon: Icon(Icons.stay_current_portrait, size: 18),
        ),
        ButtonSegment(
          value: true,
          label: Text('横屏预览'),
          icon: Icon(Icons.stay_current_landscape, size: 18),
        ),
      ],
      selected: {_isLandscape},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => _setLandscape(selection.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0x331A73E8)
              : const Color(0x14FFFFFF),
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        side: const WidgetStatePropertyAll(
          BorderSide(color: Color(0x33FFFFFF)),
        ),
      ),
    );
  }

  /// 竖屏预览：模拟真实半屏播放状态（顶部 16:9 视频区 + 下方视频页内容）
  Widget _buildPortraitBody(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 56),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Center(child: _buildModeToggle()),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => ValueListenableBuilder(
                    valueListenable: _dragRefresh,
                    builder: (_, _, _) => _buildPortraitPreview(constraints),
                  ),
                ),
              ),
              ValueListenableBuilder(
                valueListenable: _dragRefresh,
                builder: (_, _, _) => _buildBottomPanel(context, _layout),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: Get.back,
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '双击快进/快退区域',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(onPressed: _reset, child: const Text('重置')),
                const SizedBox(width: 4),
                FilledButton(onPressed: _save, child: const Text('保存')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitPreview(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    var videoHeight = width * 9 / 16;
    // 空间极度受限时压缩视频区高度，保证下方模拟内容仍有展示空间
    if (constraints.maxHeight - videoHeight < 24) {
      videoHeight = math.max(120.0, constraints.maxHeight - 24);
    }
    return Column(
      children: [
        SizedBox(
          width: width,
          height: videoHeight,
          child: _buildCanvas(width, videoHeight),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: _buildMockVideoPage(),
          ),
        ),
      ],
    );
  }

  /// 模拟竖屏视频页：标题、作者、操作、简介与推荐占位，纯静态装饰
  Widget _buildMockVideoPage() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(child: _mockBar(double.infinity, 14)),
              const SizedBox(width: 12),
              _mockBar(48, 14),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0x1FFFFFFF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _mockBar(96, 11),
                    const SizedBox(height: 6),
                    _mockBar(64, 9),
                  ],
                ),
              ),
              _mockBar(64, 24, radius: 999),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Center(child: _mockBar(28, 10, radius: 999)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _mockBar(double.infinity, 10),
          const SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: 0.62,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _mockBar(double.infinity, 10),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                const Expanded(
                  child: _MockVideoCard(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _mockBar(
    double width,
    double height, {
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  /// 横屏预览：真实旋转后整页铺满，如全屏播放器
  Widget _buildLandscapeBody() {
    return LayoutBuilder(
      builder: (context, constraints) => ValueListenableBuilder(
        valueListenable: _dragRefresh,
        builder: (_, _, _) => Stack(
          children: [
            Positioned.fill(
              child: _buildCanvas(
                constraints.maxWidth,
                constraints.maxHeight,
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: Get.back,
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _setLandscape(false),
                        child: const Text('竖屏预览'),
                      ),
                      TextButton(onPressed: _reset, child: const Text('重置')),
                      FilledButton(onPressed: _save, child: const Text('保存')),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: math.max(12.0, MediaQuery.paddingOf(context).bottom),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Text(
                    '左 ${_layout.backwardPercent}% · 中 ${_layout.centerPercent}% · 右 ${_layout.forwardPercent}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas(double width, double height) {
    final layout = _layout;
    final backwardWidth = width * _backwardFraction;
    final centerWidth = width * _centerFraction;
    final forwardWidth = width * _forwardFraction;
    final backwardHandleLeft = backwardWidth - _handleWidth / 2;
    final forwardHandleLeft = backwardWidth + centerWidth - _handleWidth / 2;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF070707),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: backwardWidth,
            child: _PreviewSection(
              color: const Color(0x332968ff),
              width: backwardWidth,
              child: _buildZoneContent(
                width: backwardWidth,
                icon: Icons.fast_rewind_rounded,
                text: '快退 ${Pref.doubleTapBackwardDuration} 秒',
                percent: layout.backwardPercent,
              ),
            ),
          ),
          Positioned(
            left: backwardWidth,
            top: 0,
            bottom: 0,
            width: centerWidth,
            child: _PreviewSection(
              color: const Color(0x22111111),
              width: centerWidth,
              child: _buildCenterContent(
                width: centerWidth,
                percent: layout.centerPercent,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: forwardWidth,
            child: _PreviewSection(
              color: const Color(0x33ff7a00),
              width: forwardWidth,
              child: _buildZoneContent(
                width: forwardWidth,
                icon: Icons.fast_forward_rounded,
                text: '快进 ${Pref.doubleTapForwardDuration} 秒',
                percent: layout.forwardPercent,
              ),
            ),
          ),
          Positioned(
            left: backwardHandleLeft,
            top: 0,
            bottom: 0,
            child: _PreviewHandle(
              label: '快退',
              onHorizontalDragUpdate: (details) {
                if (width <= 0) {
                  return;
                }
                _updateBackward(
                  _backwardPercent + details.delta.dx / width * 100,
                );
              },
            ),
          ),
          Positioned(
            left: forwardHandleLeft,
            top: 0,
            bottom: 0,
            child: _PreviewHandle(
              label: '快进',
              onHorizontalDragUpdate: (details) {
                if (width <= 0) {
                  return;
                }
                _updateForward(
                  _forwardPercent - details.delta.dx / width * 100,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 区域内容随宽度自适应：窄到一定程度只显示色带，模仿真实播放器中
  /// 过窄区域不足以承载双击提示的情况
  Widget? _buildZoneContent({
    required double width,
    required IconData icon,
    required String text,
    required int percent,
  }) {
    if (width < _zoneIconMinWidth) {
      return null;
    }
    final showText = width >= _zoneTextMinWidth;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: showText ? 24 : 18),
        if (showText) ...[
          const SizedBox(height: 6),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$percent%',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ],
    );
  }

  Widget? _buildCenterContent({required double width, required int percent}) {
    if (width < _zoneIconMinWidth) {
      return null;
    }
    final showText = width >= _zoneTextMinWidth;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.play_arrow_rounded,
          color: Colors.white.withValues(alpha: 0.7),
          size: showText ? 40 : 24,
        ),
        if (showText) ...[
          const SizedBox(height: 4),
          Text(
            '$percent%',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomPanel(BuildContext context, DoubleTapSeekLayout layout) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '拖动提示',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '在预览的视频区域内拖动两条分隔线，实时预览双击命中范围；左侧分隔线控制“快退区”宽度，右侧分隔线控制“快进区”宽度；左右侧支持 1%~40%，中间区域自动保留为播放/暂停。横屏预览会像全屏播放器一样旋转手机，两种预览共用同一份区域配置。',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PercentChip(label: '左侧', value: layout.backwardPercent),
              _PercentChip(label: '中间', value: layout.centerPercent),
              _PercentChip(label: '右侧', value: layout.forwardPercent),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_isLandscape) {
      _restorePortrait();
    }
    _dragRefresh.dispose();
    super.dispose();
  }
}

class _MockVideoCard extends StatelessWidget {
  const _MockVideoCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 9,
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ],
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.color,
    required this.width,
    required this.child,
  });

  final Color color;
  final double width;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Center(
        child: child == null
            ? null
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: child,
              ),
      ),
    );
  }
}

class _PreviewHandle extends StatelessWidget {
  const _PreviewHandle({
    required this.label,
    required this.onHorizontalDragUpdate,
  });

  final String label;
  final GestureDragUpdateCallback onHorizontalDragUpdate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: onHorizontalDragUpdate,
      child: SizedBox(
        width: _DoubleTapSeekZoneSettingPageState._handleWidth,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xDD1A1A1A),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x44FFFFFF)),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PercentChip extends StatelessWidget {
  const _PercentChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x221A73E8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '$label $value%',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
