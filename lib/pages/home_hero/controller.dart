import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Home Hero 条目数据
class HomeHeroEntry {
  final String title;
  final String subtitle;
  final String coverUrl;
  final String route;
  final Color? tonalColor;

  const HomeHeroEntry({
    required this.title,
    required this.coverUrl,
    this.subtitle = '',
    required this.route,
    this.tonalColor,
  });
}

/// Home Hero 控制器
class HomeHeroController extends GetxController {
  final RxInt currentIndex = 0.obs;
  final RxBool isAutoAdvancing = true.obs;
  
  // Hero 条目列表（可从远程配置加载）
  final RxList<HomeHeroEntry> entries = <HomeHeroEntry>[].obs;
  
  Timer? _autoAdvanceTimer;
  static const _autoAdvanceInterval = Duration(seconds: 5);

  @override
  void onInit() {
    super.onInit();
    _loadDefaultEntries();
  }

  void _loadDefaultEntries() {
    // TODO: 从远程配置或本地数据加载
    entries.value = [
      const HomeHeroEntry(
        title: '热门动画',
        coverUrl: 'https://i0.hdslb.com/bfs/archive/12345.jpg',
        route: '/rcmd',
      ),
      const HomeHeroEntry(
        title: '最新番剧',
        coverUrl: 'https://i0.hdslb.com/bfs/archive/67890.jpg',
        route: '/pgc',
      ),
    ];
  }

  void setIndex(int index) {
    currentIndex.value = index;
  }

  void navigateTo(String route) {
    Get.toNamed(route);
  }

  void toggleAutoAdvance() {
    isAutoAdvancing.value = !isAutoAdvancing.value;
    if (isAutoAdvancing.value) {
      _startAutoAdvance();
    } else {
      _stopAutoAdvance();
    }
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(_autoAdvanceInterval, (_) {
      if (entries.isNotEmpty && isAutoAdvancing.value) {
        final next = (currentIndex.value + 1) % entries.length;
        currentIndex.value = next;
      }
    });
  }

  void _stopAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
  }

  @override
  void onClose() {
    _stopAutoAdvance();
    super.onClose();
  }
}
