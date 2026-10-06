import 'package:PiliPlus/plugin/pl_player/models/double_tap_seek_layout.dart';
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
  /// 竖屏预览模仿竖屏播放页画布，横屏预览模仿横屏播放器画布
  static const double _portraitAspect = 9 / 16;
  static const double _landscapeAspect = 16 / 9;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 56),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Center(
                    child: _buildModeToggle(),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => ValueListenableBuilder(
                      valueListenable: _dragRefresh,
                      builder: (_, _, _) => _buildPreview(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      ),
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
      ),
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
      onSelectionChanged: (selection) =>
          setState(() => _isLandscape = selection.first),
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

  Widget _buildPreview(double maxWidth, double maxHeight) {
    if (maxWidth <= 0 || maxHeight <= 0) {
      return const SizedBox.shrink();
    }
    const hPadding = 16.0;
    const vPadding = 8.0;
    final availableWidth = maxWidth - hPadding * 2;
    final availableHeight = maxHeight - vPadding * 2;
    if (availableWidth <= 0 || availableHeight <= 0) {
      return const SizedBox.shrink();
    }
    final aspect = _isLandscape ? _landscapeAspect : _portraitAspect;
    double canvasWidth;
    double canvasHeight;
    if (availableWidth / availableHeight > aspect) {
      canvasHeight = availableHeight;
      canvasWidth = canvasHeight * aspect;
    } else {
      canvasWidth = availableWidth;
      canvasHeight = canvasWidth / aspect;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: hPadding,
          vertical: vPadding,
        ),
        child: SizedBox(
          width: canvasWidth,
          height: canvasHeight,
          child: _buildCanvas(canvasWidth, canvasHeight),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                  text:
                      '快退 ${Pref.doubleTapBackwardDuration} 秒',
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
                  text:
                      '快进 ${Pref.doubleTapForwardDuration} 秒',
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
            '拖动两条分隔线，实时预览双击命中范围；左侧分隔线控制“快退区”宽度，右侧分隔线控制“快进区”宽度；左右侧支持 1%~40%，中间区域自动保留为播放/暂停。横屏与竖屏预览共用同一份区域配置。',
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
    _dragRefresh.dispose();
    super.dispose();
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
