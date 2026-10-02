import 'dart:convert';
import 'package:hive_ce/hive.dart';

/// 今日推荐单插件配置
/// 对应 BiliPai 的 TodayWatchPluginConfig
class TodayWatchPluginConfig extends HiveObject {
  /// 当前模式：RELAX（轻松看）或 LEARN（深度学习）
  TodayWatchMode mode;
  
  /// 推荐策略
  TodayWatchStrategy strategy;
  
  /// UP 主榜数量
  int upRankLimit;
  
  /// 队列生成长度
  int queueBuildLimit;
  
  /// 卡片展示条数
  int queuePreviewLimit;
  
  /// 历史样本量
  int historySampleLimit;
  
  /// 是否联动护眼信号
  bool linkEyeCareSignal;
  
  /// 是否显示模式说明
  bool showReasonHint;
  
  /// 是否显示 UP 主榜
  bool showUpRank;
  
  /// 瀑布展开动画
  bool enableWaterfallAnimation;
  
  /// 动画曲率
  double waterfallExponent;
  
  /// 刷新触发 token（用于检测变化）
  int refreshTriggerToken;

  TodayWatchPluginConfig({
    this.mode = TodayWatchMode.relax,
    this.strategy = TodayWatchStrategy.balanced,
    this.upRankLimit = 5,
    this.queueBuildLimit = 20,
    this.queuePreviewLimit = 6,
    this.historySampleLimit = 80,
    this.linkEyeCareSignal = true,
    this.showReasonHint = true,
    this.showUpRank = true,
    this.enableWaterfallAnimation = true,
    this.waterfallExponent = 1.38,
    this.refreshTriggerToken = 0,
  });

  factory TodayWatchPluginConfig.fromJson(Map<String, dynamic> json) {
    return TodayWatchPluginConfig(
      mode: TodayWatchMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => TodayWatchMode.relax,
      ),
      strategy: TodayWatchStrategy.values.firstWhere(
        (e) => e.name == json['strategy'],
        orElse: () => TodayWatchStrategy.balanced,
      ),
      upRankLimit: json['upRankLimit'] as int? ?? 5,
      queueBuildLimit: json['queueBuildLimit'] as int? ?? 20,
      queuePreviewLimit: json['queuePreviewLimit'] as int? ?? 6,
      historySampleLimit: json['historySampleLimit'] as int? ?? 80,
      linkEyeCareSignal: json['linkEyeCareSignal'] as bool? ?? true,
      showReasonHint: json['showReasonHint'] as bool? ?? true,
      showUpRank: json['showUpRank'] as bool? ?? true,
      enableWaterfallAnimation: json['enableWaterfallAnimation'] as bool? ?? true,
      waterfallExponent: (json['waterfallExponent'] as num?)?.toDouble() ?? 1.38,
      refreshTriggerToken: json['refreshTriggerToken'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'strategy': strategy.name,
    'upRankLimit': upRankLimit,
    'queueBuildLimit': queueBuildLimit,
    'queuePreviewLimit': queuePreviewLimit,
    'historySampleLimit': historySampleLimit,
    'linkEyeCareSignal': linkEyeCareSignal,
    'showReasonHint': showReasonHint,
    'showUpRank': showUpRank,
    'enableWaterfallAnimation': enableWaterfallAnimation,
    'waterfallExponent': waterfallExponent,
    'refreshTriggerToken': refreshTriggerToken,
  };

  TodayWatchPluginConfig copyWith({
    TodayWatchMode? mode,
    TodayWatchStrategy? strategy,
    int? upRankLimit,
    int? queueBuildLimit,
    int? queuePreviewLimit,
    int? historySampleLimit,
    bool? linkEyeCareSignal,
    bool? showReasonHint,
    bool? showUpRank,
    bool? enableWaterfallAnimation,
    double? waterfallExponent,
    int? refreshTriggerToken,
  }) {
    return TodayWatchPluginConfig(
      mode: mode ?? this.mode,
      strategy: strategy ?? this.strategy,
      upRankLimit: upRankLimit ?? this.upRankLimit,
      queueBuildLimit: queueBuildLimit ?? this.queueBuildLimit,
      queuePreviewLimit: queuePreviewLimit ?? this.queuePreviewLimit,
      historySampleLimit: historySampleLimit ?? this.historySampleLimit,
      linkEyeCareSignal: linkEyeCareSignal ?? this.linkEyeCareSignal,
      showReasonHint: showReasonHint ?? this.showReasonHint,
      showUpRank: showUpRank ?? this.showUpRank,
      enableWaterfallAnimation: enableWaterfallAnimation ?? this.enableWaterfallAnimation,
      waterfallExponent: waterfallExponent ?? this.waterfallExponent,
      refreshTriggerToken: refreshTriggerToken ?? this.refreshTriggerToken,
    );
  }

  /// 归一化配置值到有效范围
  TodayWatchPluginConfig normalize() {
    return copyWith(
      upRankLimit: upRankLimit.clamp(1, 12),
      queueBuildLimit: queueBuildLimit.clamp(6, 40),
      queuePreviewLimit: queuePreviewLimit.clamp(3, 12).clamp(3, queueBuildLimit),
      historySampleLimit: historySampleLimit.clamp(20, 120),
      waterfallExponent: waterfallExponent.clamp(1.0, 2.2),
    );
  }
}

/// 推荐模式
enum TodayWatchMode {
  relax,  // 今晚轻松看
  learn,  // 深度学习看
}

/// 推荐策略
enum TodayWatchStrategy {
  balanced,  // 均衡推荐
  affinity,  // 兴趣优先
  explore,   // 探索优先
}
