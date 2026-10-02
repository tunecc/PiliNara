import 'dart:convert';
import 'package:hive_ce/hive.dart';
import 'package:PiliPlus/utils/storage.dart';
import '../models_new/today_watch/box_type.dart';
import '../models_new/today_watch/feedback_snapshot.dart';
import '../models_new/today_watch/plugin_config.dart';

/// 今日推荐单本地存储服务
/// 对应 BiliPai 的 TodayWatchFeedbackStore 和 TodayWatchProfileStore
class TodayWatchStorage {
  static const String _configKey = 'today_watch_config_v1';
  static const String _feedbackKey = 'today_watch_feedback_v1';
  
  /// 最大存储限制
  static const int maxDislikedBvids = 200;
  static const int maxDislikedCreatorMids = 120;
  static const int maxDislikedKeywords = 80;
  static const int maxRecentDislikedVideos = 24;

  /// 加载插件配置
  static TodayWatchPluginConfig loadConfig() {
    try {
      final raw = GStorage.setting.get(_configKey);
      if (raw == null || raw is! String || raw.isEmpty) {
        return TodayWatchPluginConfig();
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return TodayWatchPluginConfig.fromJson(json).normalize();
    } catch (e) {
      return TodayWatchPluginConfig();
    }
  }

  /// 保存插件配置
  static void saveConfig(TodayWatchPluginConfig config) {
    try {
      GStorage.setting.put(_configKey, jsonEncode(config.toJson()));
    } catch (e) {
      // Silently fail
    }
  }

  /// 加载负反馈快照
  static TodayWatchFeedbackSnapshot loadFeedback() {
    try {
      final raw = GStorage.localCache.get(_feedbackKey);
      if (raw == null || raw is! String || raw.isEmpty) {
        return TodayWatchFeedbackSnapshot();
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return TodayWatchFeedbackSnapshot.fromJson(json);
    } catch (e) {
      return TodayWatchFeedbackSnapshot();
    }
  }

  /// 保存负反馈快照
  static void saveFeedback(TodayWatchFeedbackSnapshot snapshot) {
    try {
      GStorage.localCache.put(_feedbackKey, jsonEncode(snapshot.toJson()));
    } catch (e) {
      // Silently fail
    }
  }

  /// 清空配置
  static void clearConfig() {
    try {
      GStorage.setting.delete(_configKey);
    } catch (e) {
      // Silently fail
    }
  }

  /// 清空反馈数据
  static void clearFeedback() {
    try {
      GStorage.localCache.delete(_feedbackKey);
    } catch (e) {
      // Silently fail
    }
  }

  /// 清空所有数据
  static void clearAll() {
    clearConfig();
    clearFeedback();
  }

  /// 添加不感兴趣视频
  static TodayWatchFeedbackSnapshot addDislikedVideo({
    required String bvid,
    String title = '',
    int creatorMid = 0,
    String creatorName = '',
    Set<String> keywords = const {},
  }) {
    final snapshot = loadFeedback();
    final normalizedBvid = bvid.trim();
    if (normalizedBvid.isEmpty) return snapshot;

    final normalizedTitle = title.trim();
    final normalizedCreatorName = creatorName.trim();
    
    // 更新最近不感兴趣视频列表
    final recentVideos = List.from(snapshot.recentDislikedVideos)
      ..removeWhere((v) => v.bvid == normalizedBvid);
    recentVideos.insert(0, DislikedVideoEntry(
      bvid: normalizedBvid,
      title: normalizedTitle,
      creatorMid: creatorMid,
      creatorName: normalizedCreatorName,
      dislikedAtMillis: DateTime.now().millisecondsSinceEpoch,
    ));
    if (recentVideos.length > maxRecentDislikedVideos) {
      recentVideos.removeRange(maxRecentDislikedVideos, recentVideos.length);
    }

    // 更新集合
    final dislikedBvids = Set<String>.from(snapshot.dislikedBvids)
      ..add(normalizedBvid);
    if (dislikedBvids.length > maxDislikedBvids) {
      final sorted = dislikedBvids.toList()..sort();
      dislikedBvids.clear();
      dislikedBvids.addAll(sorted.skip(dislikedBvids.length - maxDislikedBvids));
    }

    final dislikedCreatorMids = Set<int>.from(snapshot.dislikedCreatorMids);
    if (creatorMid > 0) {
      dislikedCreatorMids.add(creatorMid);
    }
    if (dislikedCreatorMids.length > maxDislikedCreatorMids) {
      final sorted = dislikedCreatorMids.toList()..sort();
      dislikedCreatorMids.clear();
      dislikedCreatorMids.addAll(sorted.skip(dislikedCreatorMids.length - maxDislikedCreatorMids));
    }

    final dislikedKeywords = Set<String>.from(snapshot.dislikedKeywords);
    for (final kw in keywords) {
      final normalized = kw.trim().toLowerCase();
      if (normalized.isNotEmpty) {
        dislikedKeywords.add(normalized);
      }
    }
    if (dislikedKeywords.length > maxDislikedKeywords) {
      final sorted = dislikedKeywords.toList()..sort();
      dislikedKeywords.clear();
      dislikedKeywords.addAll(sorted.skip(dislikedKeywords.length - maxDislikedKeywords));
    }

    return TodayWatchFeedbackSnapshot(
      dislikedBvids: dislikedBvids,
      dislikedCreatorMids: dislikedCreatorMids,
      dislikedKeywords: dislikedKeywords,
      recentDislikedVideos: recentVideos,
    );
  }

  /// 移除不感兴趣的视频
  static TodayWatchFeedbackSnapshot removeDislikedVideo(String bvid) {
    final snapshot = loadFeedback();
    final normalizedBvid = bvid.trim();
    if (normalizedBvid.isEmpty) return snapshot;

    return TodayWatchFeedbackSnapshot(
      dislikedBvids: Set<String>.from(snapshot.dislikedBvids)..remove(normalizedBvid),
      dislikedCreatorMids: snapshot.dislikedCreatorMids,
      dislikedKeywords: snapshot.dislikedKeywords,
      recentDislikedVideos: snapshot.recentDislikedVideos
        ..removeWhere((v) => v.bvid == normalizedBvid),
    );
  }
}
