import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/pages/home_hero/controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'dart:math' as math;

/// Home Hero Section - 对标 Kototoro HomeHeroSection
/// 支持多种背景样式、自动轮播、视差效果
class HomeHeroSection extends StatelessWidget {
  const HomeHeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeHeroController());
    final size = MediaQuery.sizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final styleTokens = Pref.interfaceStyle;
    
    return Obx(() {
      if (controller.entries.isEmpty) return const SizedBox.shrink();
      
      return SizedBox(
        height: 240,
        child: Stack(
          children: [
            // Hero 轮播 - 带圆角
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(styleTokens.groupCornerRadius),
              ),
              child: PageView(
                onPageChanged: controller.setIndex,
                children: controller.entries.map((entry) => _HeroCard(
                  entry,
                  isDark: isDark,
                )).toList(),
              ),
            ),
            // 底部渐变遮罩 - 更平滑的过渡
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
                          ? Colors.black.withOpacity(0.85) 
                          : Colors.white.withOpacity(0.85),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            // 自动播放指示器
            if (controller.entries.length > 1)
              Positioned(
                bottom: 16,
                right: 20,
                child: _HeroIndicator(
                  count: controller.entries.length,
                  current: controller.currentIndex.value,
                  isDark: isDark,
                ),
              ),
            // 切换按钮
            if (controller.entries.length > 1)
              Positioned(
                bottom: 12,
                left: 20,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.play_arrow_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                        size: 20,
                      ),
                      onPressed: controller.toggleAutoAdvance,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      controller.isAutoAdvancing.value ? '自动播放' : '已暂停',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _HeroCard extends StatelessWidget {
  final HomeHeroEntry entry;
  final bool isDark;
  
  const _HeroCard(this.entry, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    final styleTokens = Pref.interfaceStyle;
    
    return GestureDetector(
      onTap: () => Get.toNamed(entry.route),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 封面图片 - 使用 BoxFit.cover 填充
          NetworkImgLayer(
            type: NetworkImgType.video,
            src: entry.coverUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          // 色调叠加（如果指定了 tonalColor）
          if (entry.tonalColor != null)
            Container(
              color: entry.tonalColor!.withOpacity(0.3),
            ),
          // 内容区域 - 左下对齐
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题 - 更大更醒目
                  Text(
                    entry.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 副标题/描述
                  if (entry.subtitle.isNotEmpty)
                    Text(
                      entry.subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 16),
                  // 操作按钮
                  Row(
                    children: [
                      // 主要按钮
                      ElevatedButton.icon(
                        onPressed: () => Get.toNamed(entry.route),
                        icon: const Icon(Icons.play_circle_filled, size: 20),
                        label: const Text('观看'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(styleTokens.controlCornerRadius),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 次要按钮
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add_outlined, size: 18),
                        label: const Text('收藏'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(styleTokens.controlCornerRadius),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 右上角徽章（如果有）
          if (entry.subtitle.isNotEmpty)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 轮播指示器 - 水平胶囊样式
class _HeroIndicator extends StatelessWidget {
  final int count;
  final int current;
  final bool isDark;

  const _HeroIndicator({
    required this.count,
    required this.current,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          count,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: index == current ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: index == current
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5)),
            ),
          ),
        ),
      ),
    );
  }
}
