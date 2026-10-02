/// Bangumi.tv API client for anime metadata and watch progress sync.
///
/// Provides access to Bangumi subject information, ratings, and user collections.
/// API docs: https://github.com/bangumi/api

import 'package:dio/dio.dart';

class BangumiHttp {
  static const baseUrl = 'https://api.bangumi.tv';

  final Dio dio;

  BangumiHttp({Dio? dio}) : dio = dio ?? Dio();

  /// Search for anime subjects by keyword.
  Future<List<BangumiSubject>> search({
    required String keyword,
    int page = 1,
    int max = 20,
  }) async {
    final resp = await dio.get(
      '$baseUrl/v0/search/subject',
      queryParameters: {
        'keyword': keyword,
        'target_type': 2,
        'page': page,
        'max': max,
      },
    );

    if (resp.data == null || resp.data['code'] != 0) {
      return [];
    }

    final items = resp.data['data'] as List? ?? [];
    return items.map((item) => BangumiSubject.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Get subject details by Bangumi ID.
  Future<BangumiSubject?> getSubject(int subjectId) async {
    try {
      final resp = await dio.get('$baseUrl/v0/subject/$subjectId');
      if (resp.data == null || resp.data['code'] != 0) {
        return null;
      }
      return BangumiSubject.fromJson(resp.data['data'] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Get user's collection status for a subject.
  Future<BangumiCollection?> getCollection({
    required String username,
    required int subjectId,
  }) async {
    try {
      final resp = await dio.get('$baseUrl/v0/user/$username/collection/$subjectId');
      if (resp.data == null || resp.data['code'] != 0) {
        return null;
      }
      return BangumiCollection.fromJson(resp.data['data'] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Update user's collection status for a subject.
  Future<bool> updateCollection({
    required String username,
    required int subjectId,
    required BangumiCollectionType type,
    String? comment,
  }) async {
    try {
      final resp = await dio.put(
        '$baseUrl/v0/user/$username/collection/$subjectId',
        data: {
          'type': type.value,
          if (comment != null) 'comment': comment,
        },
      );
      return resp.data?['code'] == 0;
    } catch (e) {
      return false;
    }
  }

  /// Get user's anime watch history (collection list).
  Future<List<BangumiCollection>> getHistory({
    required String username,
    int page = 1,
    int max = 20,
  }) async {
    try {
      final resp = await dio.get(
        '$baseUrl/v0/user/$username/collection',
        queryParameters: {'page': page, 'max': max},
      );
      if (resp.data == null || resp.data['code'] != 0) {
        return [];
      }
      final items = resp.data['data'] as List? ?? [];
      return items.map((item) => BangumiCollection.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
}

enum BangumiCollectionType {
  watch(3),
  wantWatch(2),
  watching(1),
  onHold(4),
  dropped(5);

  final int value;
  const BangumiCollectionType(this.value);
}

class BangumiSubject {
  final int id;
  final String name;
  final String nameCN;
  final String? summary;
  final String? imageUrl;
  final double? rating;
  final int? totalEpisodes;
  final List<BangumiEpisode>? episodes;
  final List<String> tags;

  const BangumiSubject({
    required this.id,
    required this.name,
    required this.nameCN,
    this.summary,
    this.imageUrl,
    this.rating,
    this.totalEpisodes,
    this.episodes,
    this.tags = const [],
  });

  factory BangumiSubject.fromJson(Map<String, dynamic> json) {
    return BangumiSubject(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      nameCN: (json['name_cn'] as String?) ?? (json['name'] as String? ?? ''),
      summary: json['summary'] as String?,
      imageUrl: (json['images'] as Map?)?.toString(),
      rating: (json['rating'] as Map?)?['rank']?.toDouble(),
      totalEpisodes: json['eps'] as int?,
      episodes: (json['ep_list'] as List?)
          ?.map((e) => BangumiEpisode.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List?)?.map((t) => t as String).toList() ?? [],
    );
  }
}

class BangumiEpisode {
  final int epId;
  final int num;
  final String name;
  final String? nameCN;
  final String? broadcast;

  const BangumiEpisode({
    required this.epId,
    required this.num,
    required this.name,
    this.nameCN,
    this.broadcast,
  });

  factory BangumiEpisode.fromJson(Map<String, dynamic> json) {
    return BangumiEpisode(
      epId: json['id'] as int? ?? 0,
      num: json['ep'] as int? ?? json['sort'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      nameCN: json['name_cn'] as String?,
      broadcast: json['broadcast'] as String?,
    );
  }
}

class BangumiCollection {
  final int subjectId;
  final BangumiCollectionType type;
  final String? comment;
  final DateTime? rateDate;
  final BangumiSubject? subject;

  const BangumiCollection({
    required this.subjectId,
    required this.type,
    this.comment,
    this.rateDate,
    this.subject,
  });

  factory BangumiCollection.fromJson(Map<String, dynamic> json) {
    return BangumiCollection(
      subjectId: json['subject_id'] as int? ?? 0,
      type: BangumiCollectionType.values.firstWhere(
        (t) => t.value == (json['type'] as int? ?? 0),
        orElse: () => BangumiCollectionType.watching,
      ),
      comment: json['comment'] as String?,
      rateDate: json['rate'] != null ? DateTime.tryParse(json['rate'] as String? ?? '') : null,
      subject: json['subject'] != null
          ? BangumiSubject.fromJson(json['subject'] as Map<String, dynamic>)
          : null,
    );
  }
}
