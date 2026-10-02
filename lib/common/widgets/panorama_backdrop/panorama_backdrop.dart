import 'dart:async';
import 'package:flutter/material.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

/// 全景背景组件 - 对标 Kototoro AnimatedPanoramaBackdrop
/// 支持视差滚动、模糊效果、动态透明度
class PanoramaBackdrop extends StatefulWidget {
  final String imageUrl;
  final double height;
  final ScrollController scrollController;
  final double blurAmount;
  final double opacity;
  final bool enableAnimation;
  final bool enableParallax;

  const PanoramaBackdrop({
    super.key,
    required this.imageUrl,
    required this.scrollController,
    this.height = 300,
    this.blurAmount = 35,
    this.opacity = 0.9,
    this.enableAnimation = true,
    this.enableParallax = true,
  });

  @override
  State<PanoramaBackdrop> createState() => _PanoramaBackdropState();
}

class _PanoramaBackdropState extends State<PanoramaBackdrop>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _blurAnimation;
  late Animation<double> _opacityAnimation;
  double _lastScrollOffset = 0;
  double _currentBlur = 35;
  double _currentOpacity = 0.9;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );
    
    widget.scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final currentOffset = widget.scrollController.offset;
    final delta = currentOffset - _lastScrollOffset;
    
    // 防抖处理
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (widget.enableAnimation && delta.abs() > 0.5) {
        _animationController.forward().then((_) {
          if (mounted) _animationController.reverse();
        });
      }
      
      // 更新模糊和透明度基于滚动位置
      final scrollProgress = (currentOffset / widget.height).clamp(0.0, 1.0);
      setState(() {
        _currentBlur = widget.blurAmount * (1 - scrollProgress * 0.5);
        _currentOpacity = widget.opacity * (1 - scrollProgress * 0.3);
      });
      
      _lastScrollOffset = currentOffset;
    });
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _debounceTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final styleTokens = Pref.interfaceStyle;
    
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(styleTokens.groupCornerRadius),
      ),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 背景图片 - 带视差效果
            if (widget.enableParallax)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, widget.scrollController.offset * 0.4),
                    child: child,
                  );
                },
                child: NetworkImgLayer(
                  type: NetworkImgType.video,
                  src: widget.imageUrl,
                  width: double.infinity,
                  height: widget.height * 1.6,
                  fit: BoxFit.cover,
                ),
              ),
            // 模糊效果层
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _currentBlur,
                sigmaY: _currentBlur,
              ),
              child: Container(
                color: Colors.black.withOpacity(_currentOpacity * 0.4),
              ),
            ),
            // 顶部渐变遮罩 - 更自然
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      isDark 
                          ? Colors.black.withOpacity(0.6) 
                          : Colors.white.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // 底部渐变遮罩 - 衔接内容区
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      isDark 
                          ? Colors.black.withOpacity(0.9) 
                          : Colors.white.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
