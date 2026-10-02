import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import '../models_new/today_watch/feedback_snapshot.dart';
import '../models_new/today_watch/plugin_config.dart';
import '../models_new/today_watch/video_candidate.dart';

/// 创作者信号，包含观看亲和度
class CreatorSignal {
  final int mid;
  final String name;
  final double score;
  final int watchCount;

  const CreatorSignal({
    required this.mid,
    this.name = '',
    required this.score,
    this.watchCount = 1,
  });
}

/// 负反馈信号
class PenaltySignals {
  final Set<String> consumedBvids;
  final Set<String> dislikedBvids;
  final Set<int> dislikedCreatorMids;
  final Set<String> dislikedKeywords;

  const PenaltySignals({
    this.consumedBvids = const {},
    this.dislikedBvids = const {},
    this.dislikedCreatorMids = const {},
    this.dislikedKeywords = const {},
  });
}

/// 今日推荐单计算结果
class TodayWatchPlan {
  final TodayWatchMode mode;
  final List<CreatorRank> upRanks;
  final List<TodayWatchVideoCandidate> videoQueue;
  final Map<String, String> explanationByBvid;
  final Map<String, double> scoreByBvid;
  final Map<String, double> confidenceByBvid;
  final int historySampleCount;
  final bool nightSignalUsed;
  final int generatedAt;

  const TodayWatchPlan({
    required this.mode,
    required this.upRanks,
    required this.videoQueue,
    required this.explanationByBvid,
    required this.scoreByBvid,
    required this.confidenceByBvid,
    required this.historySampleCount,
    this.nightSignalUsed = false,
    this.generatedAt = 0,
  });
}

/// UP 主排名
class CreatorRank {
  final int mid;
  final String name;
  final double score;
  final int watchCount;

  const CreatorRank({
    required this.mid,
    this.name = '',
    required this.score,
    this.watchCount = 1,
  });
}

/// 内部评分候选
class _ScoredCandidate {
  final RcmdVideoItemModel video;
  final int originalIndex;
  final double baseScore;
  final double confidence;
  final _CandidateFeatures features;
  final String explanation;

  _ScoredCandidate({
    required this.video,
    required this.originalIndex,
    required this.baseScore,
    required this.confidence,
    required this.features,
    required this.explanation,
  });
}

/// 候选视频特征
class _CandidateFeatures {
  final double creatorAffinity;
  final double topicAffinity;
  final double interest;
  final double modeFit;
  final double freshness;
  final double quality;
  final double exploration;
  final Set<String> topics;

  _CandidateFeatures({
    required this.creatorAffinity,
    required this.topicAffinity,
    required this.interest,
    required this.modeFit,
    required this.freshness,
    required this.quality,
    required this.exploration,
    this.topics = const {},
  });
}

/// 策略权重
class StrategyWeights {
  final double interest;
  final double mode;
  final double freshness;
  final double quality;
  final double exploration;
  final double diversity;

  const StrategyWeights(this.interest, this.mode, this.freshness, this.quality, this.exploration, this.diversity);
}

/// 构建今日推荐单计划
/// 
/// 基于观看历史与首页候选生成"今日推荐单"
TodayWatchPlan buildTodayWatchPlan({
  required List<HistoryItemModel> historyVideos,
  required List<RcmdVideoItemModel> candidateVideos,
  required TodayWatchMode mode,
  bool eyeCareNightActive = false,
  int nowEpochSec = 0,
  int upRankLimit = 5,
  int queueLimit = 20,
  List<CreatorSignal> creatorSignals = const [],
  PenaltySignals penaltySignals = const PenaltySignals(),
  TodayWatchStrategy strategy = TodayWatchStrategy.balanced,
}) {
  final now = nowEpochSec > 0 ? nowEpochSec : DateTime.now().millisecondsSinceEpoch ~/ 1000;
  
  // 清理并排序历史视频（按观看时间倒序）
  final cleanedHistory = historyVideos
      .where((h) => h.history.oid != null && h.history.oid! > 0)
      .toList()
    ..sort((a, b) => (b.viewAt ?? 0).compareTo(a.viewAt ?? 0));

  // 计算每个视频的完成度和创作者亲和度
  final recentCreatorScores = <int, double>{};
  final recentCreatorCounts = <int, int>{};
  final creatorNames = <int, String>{};
  final rawTopicScores = <String, double>{};

  for (final item in cleanedHistory) {
    final completion = _estimateCompletionRatio(item);
    final affinity = _watchAffinityScore(completion, _recencyBonus(item.viewAt ?? 0, now));
    
    if (item.authorMid != null && item.authorMid! > 0) {
      recentCreatorScores[item.authorMid!] = (recentCreatorScores[item.authorMid!] ?? 0.0) + affinity;
      recentCreatorCounts[item.authorMid!] = (recentCreatorCounts[item.authorMid!] ?? 0) + 1;
      creatorNames[item.authorMid!] = item.authorName ?? 'UP主${item.authorMid}';
    }
    
    // 主题偏好分析
    for (final topic in _resolveTopicKeys(item)) {
      rawTopicScores[topic] = (rawTopicScores[topic] ?? 0.0) + affinity;
    }
  }

  // 合并持久化创作者信号
  final persistedCreatorScores = <int, double>{};
  final persistedCreatorCounts = <int, int>{};
  for (final signal in creatorSignals.where((s) => s.mid > 0)) {
    persistedCreatorScores[signal.mid] = persistedCreatorScores[signal.mid] == null || persistedCreatorScores[signal.mid]! < signal.score
        ? signal.score
        : persistedCreatorScores[signal.mid]!;
    persistedCreatorCounts[signal.mid] = persistedCreatorCounts[signal.mid] == null || persistedCreatorCounts[signal.mid]! < signal.watchCount
        ? signal.watchCount
        : persistedCreatorCounts[signal.mid]!;
    creatorNames.putIfAbsent(signal.mid, () => signal.name.isNotEmpty ? signal.name : 'UP主${signal.mid}');
  }

  // 归一化创作者分数
  final normalizedRecentCreators = _normalizePositiveScores(recentCreatorScores);
  final normalizedPersistedCreators = _normalizePositiveScores(persistedCreatorScores);
  
  final creatorAffinity = <int, double>{};
  for (final mid in {...normalizedRecentCreators.keys, ...normalizedPersistedCreators.keys}) {
    final recent = normalizedRecentCreators[mid];
    final persisted = normalizedPersistedCreators[mid];
    if (recent != null && persisted != null) {
      creatorAffinity[mid] = recent * 0.65 + persisted * 0.35;
    } else if (recent != null) {
      creatorAffinity[mid] = recent;
    } else {
      creatorAffinity[mid] = persisted ?? 0.0;
    }
  }

  final topicAffinity = _normalizePositiveScores(rawTopicScores);

  // 构建创作者排名
  final creators = creatorAffinity.entries
      .map((e) => CreatorRank(
            mid: e.key,
            name: creatorNames[e.key] ?? 'UP主${e.key}',
            score: e.value,
            watchCount: (recentCreatorCounts[e.key] ?? 0) > (persistedCreatorCounts[e.key] ?? 0)
                ? recentCreatorCounts[e.key]!
                : persistedCreatorCounts[e.key] ?? 0,
          ))
      .toList()
    ..sort((a, b) {
      final scoreDiff = b.score.compareTo(a.score);
      return scoreDiff != 0 ? scoreDiff : b.watchCount.compareTo(a.watchCount);
    });

  // 过滤候选视频
  final normalizedDislikedKeywords = penaltySignals.dislikedKeywords
      .map((k) => k.trim().toLowerCase())
      .where((k) => k.isNotEmpty)
      .toSet();

  final eligibleCandidates = candidateVideos
      .where((v) => v.bvid != null && v.bvid!.isNotEmpty && v.title != null && v.title!.isNotEmpty)
      .where((v) => v.bvid == null || !penaltySignals.consumedBvids.contains(v.bvid))
      .where((v) => v.bvid == null || !penaltySignals.dislikedBvids.contains(v.bvid))
      .where((v) => v.owner?.mid == null || !penaltySignals.dislikedCreatorMids.contains(v.owner!.mid))
      .toList();

  // 评分
  final weights = _strategyWeights(strategy);
  final scoredCandidates = <_ScoredCandidate>[];

  for (var i = 0; i < eligibleCandidates.length; i++) {
    final video = eligibleCandidates[i];
    final topics = _resolveTopicKeysForRcmd(video);
    final creatorScore = creatorAffinity[video.owner?.mid] ?? 0.0;
    final topicScore = topics.isEmpty 
        ? 0.0 
        : topics.map((t) => topicAffinity[t] ?? 0.0).reduce((a, b) => a > b ? a : b);
    
    final interest = (creatorScore * 0.65 + topicScore * 0.35).clamp(0.0, 1.0);
    final modeFit = _modeFitScore(video, mode, eyeCareNightActive);
    final freshness = _continuousFreshnessScore(video.pubdate ?? 0, now);
    final quality = _buildCandidateQualityScore(video);
    final exploration = _explorationScore(creatorScore, topicScore, topics);

    final score = (interest * weights.interest +
            modeFit * weights.mode +
            freshness * weights.freshness +
            quality * weights.quality +
            exploration * weights.exploration)
        .clamp(0.0, 1.0);

    scoredCandidates.add(_ScoredCandidate(
      video: video,
      originalIndex: i,
      baseScore: score,
      confidence: score,
      features: _CandidateFeatures(
        creatorAffinity: creatorScore,
        topicAffinity: topicScore,
        interest: interest,
        modeFit: modeFit,
        freshness: freshness,
        quality: quality,
        exploration: exploration,
        topics: topics,
      ),
      explanation: _buildRecommendationExplanation(video, mode, eyeCareNightActive, 
          _CandidateFeatures(
        creatorAffinity: creatorScore,
        topicAffinity: topicScore,
        interest: interest,
        modeFit: modeFit,
        freshness: freshness,
        quality: quality,
        exploration: exploration,
        topics: topics,
      )),
    ));
  }

  // MMR 多样性排序
  final selected = _buildDiverseQueue(scoredCandidates, queueLimit.clamp(1, 60), weights.diversity);

  return TodayWatchPlan(
    mode: mode,
    upRanks: creators.take(upRankLimit.clamp(1, 20)).toList(),
    videoQueue: selected.map((s) => _rcmdToCandidate(s.video)).toList(),
    explanationByBvid: {for (final s in selected) (s.video.bvid ?? ''): s.explanation},
    scoreByBvid: {for (final s in selected) (s.video.bvid ?? ''): s.baseScore},
    confidenceByBvid: {for (final s in selected) (s.video.bvid ?? ''): s.confidence},
    historySampleCount: cleanedHistory.length,
    nightSignalUsed: eyeCareNightActive,
    generatedAt: DateTime.now().millisecondsSinceEpoch,
  );
}

TodayWatchVideoCandidate _rcmdToCandidate(RcmdVideoItemModel rcmd) {
  return TodayWatchVideoCandidate(
    bvid: rcmd.bvid ?? '',
    aid: rcmd.aid,
    title: rcmd.title ?? '',
    cover: rcmd.cover,
    duration: rcmd.duration ?? 0,
    pubdate: rcmd.pubdate,
    ownerMid: rcmd.owner?.mid ?? 0,
    ownerName: rcmd.owner?.name ?? '',
    viewCount: rcmd.stat?.view ?? 0,
    likeCount: rcmd.stat?.like ?? 0,
    coinCount: 0,
    favoriteCount: 0,
    shareCount: 0,
    replyCount: 0,
    danmakuCount: rcmd.stat?.danmu ?? 0,
    tid: 0,
    tname: '',
  );
}

// ==================== 辅助函数 ====================

double _estimateCompletionRatio(HistoryItemModel item) {
  if (item.progress == null) return 0.35;
  if (item.duration == null || item.duration == 0) return (item.progress!.toDouble() / 600.0).clamp(0.0, 1.0);
  return (item.progress!.toDouble() / item.duration!).clamp(0.0, 1.0);
}

double _watchAffinityScore(double completion, double recencyBonus) {
  final completionScore = completion >= 0.9 ? 1.85
      : completion >= 0.6 ? 0.9 + completion * 0.75
      : completion >= 0.3 ? 0.25 + completion * 0.45
      : 0.1;
  return completionScore + recencyBonus * (completion >= 0.6 ? 1.0 : 0.35);
}

double _recencyBonus(int viewAt, int now) {
  if (viewAt <= 0) return 0.25;
  final days = ((now - viewAt) / 86400.0).clamp(0.0, double.infinity);
  return days <= 1.0 ? 1.0
      : days <= 3.0 ? 0.8
      : days <= 7.0 ? 0.6
      : days <= 30.0 ? 0.35
      : 0.15;
}

Set<String> _resolveTopicKeys(HistoryItemModel item) {
  final keywords = '${item.title ?? ''} ${item.tagName ?? ''}'.toLowerCase();
  final topics = <String>{};
  if (item.kid != null && item.kid! > 0) topics.add('partition-id:${item.kid}');
  for (final entry in _TOPIC_KEYWORDS) {
    if (entry['keywords'] is List && (entry['keywords'] as List).any((k) => keywords.contains(k))) {
      topics.add('topic:${entry['topic']}');
    }
  }
  return topics;
}

Set<String> _resolveTopicKeysForRcmd(RcmdVideoItemModel video) {
  final keywords = '${video.title ?? ''}'.toLowerCase();
  final topics = <String>{};
  for (final entry in _TOPIC_KEYWORDS) {
    if (entry['keywords'] is List && (entry['keywords'] as List).any((k) => keywords.contains(k))) {
      topics.add('topic:${entry['topic']}');
    }
  }
  return topics;
}

double _modeFitScore(RcmdVideoItemModel video, TodayWatchMode mode, bool eyeCareNightActive) {
  final title = (video.title ?? '').toLowerCase();
  final durationMin = ((video.duration ?? 0) / 60.0).clamp(0.0, double.infinity);
  final intensity = (video.stat?.view != null && video.stat!.view! > 0)
      ? (video.stat!.danmu ?? 0).toDouble() / video.stat!.view!
      : 0.0;
  final relaxCue = _RELAX_KEYWORDS.any((k) => title.contains(k));
  final learnCue = _LEARN_KEYWORDS.any((k) => title.contains(k));

  double base;
  if (mode == TodayWatchMode.relax) {
    final durationFit = durationMin < 2.0 ? 0.3
        : durationMin <= 12.0 ? 1.0
        : durationMin <= 20.0 ? 0.75
        : durationMin <= 35.0 ? 0.45
        : 0.15;
    final calmFit = intensity < 0.004 ? 1.0 : intensity < 0.01 ? 0.65 : 0.2;
    base = (durationFit * 0.45 + calmFit * 0.25 + (relaxCue ? 0.30 : 0.12) - (learnCue ? 0.22 : 0.0)).clamp(0.0, 1.0);
  } else {
    final durationFit = durationMin < 5.0 ? 0.2
        : durationMin < 10.0 ? 0.55
        : durationMin <= 35.0 ? 1.0
        : durationMin <= 55.0 ? 0.7
        : 0.35;
    base = (durationFit * 0.55 + (learnCue ? 0.45 : 0.12) - (relaxCue && durationMin < 12.0 ? 0.2 : 0.0)).clamp(0.0, 1.0);
  }

  if (eyeCareNightActive) {
    final nightScore = _nightFriendlyScore(video);
    return (base * 0.75 + nightScore * 0.25).clamp(0.0, 1.0);
  }
  return base;
}

double _nightFriendlyScore(RcmdVideoItemModel video) {
  final durationMin = ((video.duration ?? 0) / 60.0).clamp(0.0, double.infinity);
  final intensity = (video.stat?.view != null && video.stat!.view! > 0)
      ? (video.stat!.danmu ?? 0).toDouble() / video.stat!.view!
      : 0.0;
  final durationFit = durationMin <= 15.0 ? 1.0 : durationMin <= 25.0 ? 0.7 : durationMin <= 45.0 ? 0.35 : 0.1;
  final calmFit = intensity < 0.006 ? 1.0 : intensity < 0.012 ? 0.6 : 0.2;
  return durationFit * 0.6 + calmFit * 0.4;
}

double _continuousFreshnessScore(int pubdate, int nowEpochSec) {
  if (pubdate <= 0) return 0.5;
  final ageDays = ((nowEpochSec - pubdate).clamp(0, 2147483647) / 86400.0);
  return (pow(2.0, -ageDays / 30.0)).clamp(0.0, 1.0);
}

double _explorationScore(double creatorAffinity, double topicAffinity, Set<String> topics) {
  final unseenCreator = creatorAffinity < 0.05 ? 1.0 : 0.0;
  final unseenTopic = topics.isEmpty || topicAffinity < 0.05 ? 1.0 : 0.0;
  return unseenCreator * 0.6 + unseenTopic * 0.4;
}

double _buildCandidateQualityScore(RcmdVideoItemModel video) {
  final viewLog = (video.stat?.view ?? 0).toDouble().log1p();
  final engagement = _smoothedEngagementRate(video);
  return (viewLog / 10.0).clamp(0.0, 1.0) * 0.6 + engagement * 0.4;
}

double _smoothedEngagementRate(RcmdVideoItemModel video) {
  final view = (video.stat?.view ?? 0).toDouble().clamp(0.0, double.infinity);
  final like = (video.stat?.like ?? 0).toDouble();
  final weightedEngagement = like; // Simplified
  return (weightedEngagement / (view + 2000.0)).clamp(0.0, 1.0);
}

Map<K, double> _normalizePositiveScores<K>(Map<K, double> scores) {
  if (scores.isEmpty) return {};
  double max = 0.0;
  for (final v in scores.values) {
    if (v > max) max = v;
  }
  if (max <= 0) return {};
  final result = <K, double>{};
  for (final entry in scores.entries) {
    result[entry.key] = (entry.value / max).clamp(0.0, 1.0);
  }
  return result;
}

StrategyWeights _strategyWeights(TodayWatchStrategy strategy) {
  switch (strategy) {
    case TodayWatchStrategy.balanced:
      return const StrategyWeights(0.34, 0.20, 0.16, 0.15, 0.15, 0.18);
    case TodayWatchStrategy.affinity:
      return const StrategyWeights(0.52, 0.18, 0.10, 0.15, 0.05, 0.08);
    case TodayWatchStrategy.explore:
      return const StrategyWeights(0.20, 0.18, 0.22, 0.15, 0.25, 0.30);
  }
}

List<_ScoredCandidate> _buildDiverseQueue(List<_ScoredCandidate> candidates, int queueLimit, double diversityStrength) {
  if (candidates.isEmpty) return [];
  
  final remaining = List<_ScoredCandidate>.from(candidates);
  final selected = <_ScoredCandidate>[];
  final creatorCounts = <int, int>{};
  final topicCounts = <String, int>{};
  const topPreviewLimit = 6;
  const topPreviewRepeatLimit = 2;

  while (selected.length < queueLimit && remaining.isNotEmpty) {
    List<_ScoredCandidate> pool;
    if (selected.length < topPreviewLimit) {
      pool = remaining.where((candidate) {
        final creatorMid = candidate.video.owner?.mid;
        final creatorAllowed = creatorMid == null || (creatorCounts[creatorMid] ?? 0) < topPreviewRepeatLimit;
        final primaryTopic = candidate.features.topics.isEmpty ? null : candidate.features.topics.first;
        final topicAllowed = primaryTopic == null || (topicCounts[primaryTopic] ?? 0) < topPreviewRepeatLimit;
        return creatorAllowed && topicAllowed;
      }).toList();
    } else {
      pool = remaining;
    }
    
    if (pool.isEmpty) pool = remaining;
    
    _ScoredCandidate picked = pool.first;
    double bestScore = double.negativeInfinity;
    for (final c in pool) {
      final score = c.baseScore - diversityStrength * _maximumSimilarity(c, selected);
      if (score > bestScore) {
        bestScore = score;
        picked = c;
      }
    }
    
    final adjusted = (picked.baseScore - diversityStrength * _maximumSimilarity(picked, selected)).clamp(0.0, 1.0);
    selected.add(_ScoredCandidate(
      video: picked.video,
      originalIndex: picked.originalIndex,
      baseScore: adjusted,
      confidence: adjusted,
      features: picked.features,
      explanation: picked.explanation,
    ));
    remaining.remove(picked);
    
    final creatorMid = picked.video.owner?.mid;
    if (creatorMid != null) {
      creatorCounts[creatorMid] = (creatorCounts[creatorMid] ?? 0) + 1;
    }
    if (picked.features.topics.isNotEmpty) {
      final primaryTopic = picked.features.topics.first;
      topicCounts[primaryTopic] = (topicCounts[primaryTopic] ?? 0) + 1;
    }
  }
  
  return selected;
}

double _maximumSimilarity(_ScoredCandidate candidate, List<_ScoredCandidate> selected) {
  if (selected.isEmpty) return 0.0;
  double maxSim = 0.0;
  for (final existing in selected) {
    final sameCreator = candidate.video.owner?.mid != null && 
        existing.video.owner?.mid != null &&
        candidate.video.owner!.mid == existing.video.owner!.mid;
    final topicOverlap = candidate.features.topics.isNotEmpty && 
        existing.features.topics.isNotEmpty &&
        candidate.features.topics.any((t) => existing.features.topics.contains(t));
    final sim = (sameCreator ? 0.6 : 0.0) + (topicOverlap ? 0.4 : 0.0);
    if (sim > maxSim) maxSim = sim;
  }
  return maxSim;
}

String _buildRecommendationExplanation(RcmdVideoItemModel video, TodayWatchMode mode, bool eyeCareNightActive, _CandidateFeatures features) {
  final reasons = <String>[];
  if (features.modeFit >= 0.7) reasons.add(mode == TodayWatchMode.relax ? '轻松向' : '学习向');
  if (features.freshness >= 0.75) reasons.add('近期更新');
  if (eyeCareNightActive && _nightFriendlyScore(video) >= 0.7) reasons.add('夜间友好');
  if (features.creatorAffinity >= 0.45) reasons.add('常看UP');
  if (features.topicAffinity >= 0.45) reasons.add('常看分区');
  if (features.exploration >= 0.8) reasons.add('新UP探索');
  if (features.quality >= 0.75) reasons.add('优质内容');
  
  if (reasons.isEmpty) reasons.add(mode == TodayWatchMode.relax ? '轻松向' : '学习向');
  
  // 去重并限制数量
  final seen = <String>{};
  return reasons.where((r) => seen.add(r)).take(3).join(' · ');
}

// ==================== 关键词常量 ====================

const _RELAX_KEYWORDS = ['音乐', 'vlog', '日常', '搞笑', '轻松', '治愈', 'asmr', '旅行', '美食', '游戏'];
const _LEARN_KEYWORDS = ['教程', '科普', '知识', '学习', '原理', '实战', '复盘', '编程', '数学', '英语', '课程', '技术', '分析', '入门', '进阶'];

const _TOPIC_KEYWORDS = [
  {'topic': 'music', 'keywords': ['音乐', '唱', '歌', '演奏', '翻唱', 'live']},
  {'topic': 'learn', 'keywords': ['教程', '科普', '知识', '学习', '原理', '实战', '复盘', '编程', '数学', '英语', '课程', '技术', '分析', '入门', '进阶', 'kotlin', 'android']},
  {'topic': 'game', 'keywords': ['游戏', '实况', '通关', '原神', '崩坏', 'minecraft']},
  {'topic': 'food', 'keywords': ['美食', '做饭', '料理', '探店']},
  {'topic': 'travel', 'keywords': ['旅行', '旅游', '城市', '徒步', '露营', 'vlog']},
  {'topic': 'relax', 'keywords': ['日常', '搞笑', '轻松', '治愈', 'asmr']},
];

// math utilities
double pow(double base, double exp) {
  return base.pow(exp);
}

extension on double {
  double log1p() => (1.0 + this).log();
  double pow(double exponent) => exp(exponent * ln());
}
