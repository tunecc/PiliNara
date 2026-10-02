import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import '../../services/today_watch/algorithm.dart';
import '../../services/today_watch/storage.dart';
import '../../models_new/today_watch/plugin_config.dart';
import '../../models_new/today_watch/feedback_snapshot.dart';
import '../../models_new/today_watch/video_model.dart';

/// 今日推荐单控制器
class TodayWatchController extends GetxController {
  /// 当前配置
  late TodayWatchPluginConfig _config = TodayWatchStorage.loadConfig();
  
  /// 当前反馈数据
  late TodayWatchFeedbackSnapshot _feedback = TodayWatchStorage.loadFeedback();
  
  /// 推荐队列（内部用 TodayWatchVideoModel 以便复用 VideoCardV）
  final RxList<TodayWatchVideoModel> videoQueue = <TodayWatchVideoModel>[].obs;
  
  /// UP 主榜
  final RxList<CreatorRank> upRanks = <CreatorRank>[].obs;
  
  /// 加载状态
  final RxBool isLoading = false.obs;
  
  /// 错误信息
  final RxString? errorMessage = null.obs;
  
  /// 历史记录（用于推荐算法）
  final RxList<HistoryItemModel> historyVideos = <HistoryItemModel>[].obs;
  
  /// 首页候选视频
  final RxList<RcmdVideoItemModel> candidateVideos = <RcmdVideoItemModel>[].obs;
  
  /// 护眼模式状态
  final RxBool eyeCareNightActive = false.obs;
  
  /// 是否启用今日推荐单
  final RxBool enabled = false.obs;
  
  Timer? _debounceTimer;
  
  /// 暴露配置供视图使用
  TodayWatchPluginConfig get config => _config;
  
  /// 暴露评分说明
  Map<String, String> get explanationByBvid => _explanationByBvid;
  final Map<String, String> _explanationByBvid = {};
  
  /// 暴露评分
  Map<String, double> get scoreByBvid => _scoreByBvid;
  final Map<String, double> _scoreByBvid = {};
  
  @override
  void onInit() {
    super.onInit();
    _loadData();
  }
  
  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }
  
  /// 加载数据
  Future<void> _loadData() async {
    isLoading.value = true;
    errorMessage.value = null;
    
    try {
      // 加载配置
      _config = TodayWatchStorage.loadConfig();
      
      // 加载反馈数据
      _feedback = TodayWatchStorage.loadFeedback();
      
      // 加载历史记录
      await _loadHistory();
      
      // 如果候选视频已加载，重新计算推荐
      if (candidateVideos.isNotEmpty) {
        await _computeRecommendations();
      }
    } catch (e) {
      errorMessage.value = '加载失败: $e';
    } finally {
      isLoading.value = false;
    }
  }
  
  /// 加载观看历史
  Future<void> _loadHistory() async {
    try {
      // TODO: 从 Hive 或本地缓存加载历史记录
      // 暂时使用空列表
      historyVideos.value = [];
    } catch (e) {
      historyVideos.value = [];
    }
  }
  
  /// 设置候选视频并重新计算推荐
  void setCandidates(List<RcmdVideoItemModel> candidates) {
    candidateVideos.value = candidates;
    _computeRecommendations();
  }
  
  /// 计算推荐
  Future<void> _computeRecommendations() async {
    if (candidateVideos.isEmpty) {
      videoQueue.value = [];
      upRanks.value = [];
      _explanationByBvid.clear();
      _scoreByBvid.clear();
      return;
    }
    
    isLoading.value = true;
    
    try {
      final plan = buildTodayWatchPlan(
        historyVideos: historyVideos,
        candidateVideos: candidateVideos,
        mode: _config.mode,
        eyeCareNightActive: eyeCareNightActive.value,
        upRankLimit: _config.upRankLimit,
        queueLimit: _config.queueBuildLimit,
        strategy: _config.strategy,
        penaltySignals: PenaltySignals(
          dislikedBvids: _feedback.dislikedBvids,
          dislikedCreatorMids: _feedback.dislikedCreatorMids,
          dislikedKeywords: _feedback.dislikedKeywords,
        ),
      );
      
      // 转换为 UI 模型
      videoQueue.value = plan.videoQueue.map((v) => TodayWatchVideoModel(
        bvid: v.bvid,
        aid: v.aid,
        title: v.title,
        cover: v.cover,
        duration: v.duration,
        pubdate: v.pubdate,
        ownerMid: v.ownerMid,
        ownerName: v.ownerName,
        viewCount: v.viewCount,
        likeCount: v.likeCount,
        danmakuCount: v.danmakuCount,
      )).toList();
      
      upRanks.value = plan.upRanks;
      _explanationByBvid.clear();
      _explanationByBvid.addAll(plan.explanationByBvid);
      _scoreByBvid.clear();
      _scoreByBvid.addAll(plan.scoreByBvid);
    } catch (e) {
      errorMessage.value = '计算推荐失败: $e';
    } finally {
      isLoading.value = false;
    }
  }
  
  /// 更新配置
  void updateConfig(TodayWatchPluginConfig Function(TodayWatchPluginConfig) transform) {
    final updated = transform(_config).normalize();
    if (updated == _config) return;
    _config = updated;
    TodayWatchStorage.saveConfig(_config);
    _computeRecommendations();
  }
  
  /// 标记不感兴趣
  void markNotInterested(String bvid, {String title = '', int creatorMid = 0, String creatorName = '', Set<String> keywords = const {}}) {
    final updatedFeedback = TodayWatchStorage.addDislikedVideo(
      bvid: bvid,
      title: title,
      creatorMid: creatorMid,
      creatorName: creatorName,
      keywords: keywords,
    );
    _feedback = updatedFeedback;
    TodayWatchStorage.saveFeedback(_feedback);
    _computeRecommendations();
  }
  
  /// 移除不感兴趣标记
  void removeNotInterested(String bvid) {
    final updatedFeedback = TodayWatchStorage.removeDislikedVideo(bvid);
    _feedback = updatedFeedback;
    TodayWatchStorage.saveFeedback(_feedback);
    _computeRecommendations();
  }
  
  /// 清空画像数据
  void clearPersonalizationData() {
    TodayWatchStorage.clearAll();
    _feedback = TodayWatchFeedbackSnapshot();
    _config = TodayWatchPluginConfig();
    _computeRecommendations();
  }
  
  /// 切换护眼模式
  void toggleEyeCare(bool active) {
    eyeCareNightActive.value = active;
    _computeRecommendations();
  }
  
  /// 消费视频（播放后从队列移除）
  void consumeVideo(String bvid) {
    videoQueue.removeWhere((v) => v.bvid == bvid);
  }
  
  /// 刷新推荐
  void refresh() {
    _config = _config.copyWith(refreshTriggerToken: DateTime.now().millisecondsSinceEpoch);
    TodayWatchStorage.saveConfig(_config);
    _computeRecommendations();
  }
}
