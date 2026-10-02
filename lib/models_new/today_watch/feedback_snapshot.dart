import 'dart:convert';
import 'package:hive_ce/hive.dart';

/// 用户不感兴趣反馈快照
/// 对应 BiliPai 的 TodayWatchFeedbackSnapshot
class TodayWatchFeedbackSnapshot extends HiveObject {
  Set<String> dislikedBvids;
  Set<int> dislikedCreatorMids;
  Set<String> dislikedKeywords;
  List<DislikedVideoEntry> recentDislikedVideos;

  TodayWatchFeedbackSnapshot({
    this.dislikedBvids = const {},
    this.dislikedCreatorMids = const {},
    this.dislikedKeywords = const {},
    this.recentDislikedVideos = const [],
  });

  factory TodayWatchFeedbackSnapshot.fromJson(Map<String, dynamic> json) {
    return TodayWatchFeedbackSnapshot(
      dislikedBvids: (json['dislikedBvids'] as List?)?.cast<String>().toSet() ?? {},
      dislikedCreatorMids: (json['dislikedCreatorMids'] as List?)?.cast<int>().toSet() ?? {},
      dislikedKeywords: (json['dislikedKeywords'] as List?)?.cast<String>().toSet() ?? {},
      recentDislikedVideos: (json['recentDislikedVideos'] as List?)
          ?.map((e) => DislikedVideoEntry.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'dislikedBvids': dislikedBvids.toList(),
    'dislikedCreatorMids': dislikedCreatorMids.toList(),
    'dislikedKeywords': dislikedKeywords.toList(),
    'recentDislikedVideos': recentDislikedVideos.map((e) => e.toJson()).toList(),
  };

  @override
  String toString() => 'TodayWatchFeedbackSnapshot('
      'dislikedBvids: ${dislikedBvids.length}, '
      'dislikedCreatorMids: ${dislikedCreatorMids.length}, '
      'dislikedKeywords: ${dislikedKeywords.length}, '
      'recentDislikedVideos: ${recentDislikedVideos.length}'
      ')';
}

/// 单条不感兴趣视频记录
class DislikedVideoEntry {
  final String bvid;
  final String title;
  final int creatorMid;
  final String creatorName;
  final int dislikedAtMillis;

  DislikedVideoEntry({
    required this.bvid,
    this.title = '',
    this.creatorMid = 0,
    this.creatorName = '',
    this.dislikedAtMillis = 0,
  });

  factory DislikedVideoEntry.fromJson(Map<String, dynamic> json) {
    return DislikedVideoEntry(
      bvid: json['bvid'] as String? ?? '',
      title: json['title'] as String? ?? '',
      creatorMid: json['creatorMid'] as int? ?? 0,
      creatorName: json['creatorName'] as String? ?? '',
      dislikedAtMillis: json['dislikedAtMillis'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'bvid': bvid,
    'title': title,
    'creatorMid': creatorMid,
    'creatorName': creatorName,
    'dislikedAtMillis': dislikedAtMillis,
  };
}
