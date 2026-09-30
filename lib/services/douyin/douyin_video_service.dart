/// Douyin video data fetching service with fingerprint spoofing.
import 'dart:convert';
import 'package:PiliPlus/services/douyin/douyin_cookie_service.dart';
import 'package:PiliPlus/services/douyin/douyin_fingerprint.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:dio/dio.dart';

abstract final class DouyinVideoService {
  static Dio? _dio;

  static Dio get dio {
    _dio ??= Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: true,
      maxRedirects: 5,
    ));
    return _dio!;
  }

  static Future<DouyinVideoDetail?> getVideoDetail(String urlOrId) async {
    try {
      final videoId = _extractVideoId(urlOrId);
      if (videoId == null) return null;
      final params = {...DouyinFingerprint.buildCommonParams(), 'aweme_id': videoId};
      final response = await dio.get(
        'https://www.douyin.com/aweme/v1/web/aweme/detail/',
        queryParameters: params,
        options: Options(headers: DouyinFingerprint.buildHeaders(cookie: DouyinCookieService.cookie)),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final aweme = (response.data as Map<String, dynamic>)['aweme_detail'] as Map<String, dynamic>?;
        if (aweme != null) return DouyinVideoDetail.fromMap(aweme);
      }
    } catch (e) { logger.e('DouyinVideo.getVideoDetail failed: $e'); }
    return null;
  }

  static Future<List<DouyinVideoDetail>> getRecommendFeed({int count = 20}) async {
    try {
      final params = {...DouyinFingerprint.buildCommonParams(), 'count': count, 'cursor': 0};
      final response = await dio.get(
        'https://www.douyin.com/aweme/v1/web/tab/feed/',
        queryParameters: params,
        options: Options(headers: DouyinFingerprint.buildHeaders(cookie: DouyinCookieService.cookie)),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final list = (response.data as Map<String, dynamic>)['aweme_list'] as List<dynamic>?;
        if (list != null) return list.whereType<Map<String, dynamic>>().map(DouyinVideoDetail.fromMap).toList();
      }
    } catch (e) { logger.e('DouyinVideo.getRecommendFeed failed: $e'); }
    return [];
  }

  static Future<List<DouyinVideoDetail>> searchVideos(String keyword, {int count = 20}) async {
    try {
      final params = {...DouyinFingerprint.buildCommonParams(), 'keyword': keyword, 'search_channel': 'aweme_video_web', 'count': count, 'offset': 0};
      final response = await dio.get(
        'https://www.douyin.com/aweme/v1/web/general/search/single/',
        queryParameters: params,
        options: Options(headers: DouyinFingerprint.buildHeaders(cookie: DouyinCookieService.cookie)),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final dataList = (response.data as Map<String, dynamic>)['data'] as List<dynamic>?;
        if (dataList != null) {
          return dataList.whereType<Map<String, dynamic>>().where((e) => e['aweme_info'] != null)
            .map((e) => DouyinVideoDetail.fromMap(e['aweme_info'] as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) { logger.e('DouyinVideo.searchVideos failed: $e'); }
    return [];
  }

  static String? _extractVideoId(String input) {
    if (RegExp(r'^\d{15,}$').hasMatch(input.trim())) return input.trim();
    for (final p in [RegExp(r'video/(\d+)'), RegExp(r'note/(\d+)'), RegExp(r'modal_id=(\d+)'), RegExp(r'aweme_id=(\d+)')]) {
      final m = p.firstMatch(input); if (m != null) return m.group(1);
    }
    return null;
  }
}

class DouyinVideoDetail {
  final String id, desc, coverUrl, playUrl, authorName, authorAvatar, authorId;
  final int durationMs, diggCount, commentCount, shareCount;
  const DouyinVideoDetail({required this.id, required this.desc, required this.coverUrl, required this.playUrl,
    required this.durationMs, required this.authorName, required this.authorAvatar, required this.authorId,
    this.diggCount = 0, this.commentCount = 0, this.shareCount = 0});

  factory DouyinVideoDetail.fromMap(Map<String, dynamic> map) {
    final video = map['video'] as Map<String, dynamic>? ?? {};
    final author = map['author'] as Map<String, dynamic>? ?? {};
    final stats = map['statistics'] as Map<String, dynamic>? ?? {};
    final playAddr = video['play_addr'] as Map<String, dynamic>? ?? {};
    final urlList = playAddr['url_list'] as List<dynamic>? ?? [];
    final cover = video['cover'] as Map<String, dynamic>? ?? {};
    final coverList = cover['url_list'] as List<dynamic>? ?? [];
    return DouyinVideoDetail(
      id: map['aweme_id'] as String? ?? '', desc: map['desc'] as String? ?? '',
      coverUrl: coverList.isNotEmpty ? coverList[0] as String : '',
      playUrl: urlList.isNotEmpty ? urlList[0] as String : '',
      durationMs: video['duration'] as int? ?? 0,
      authorName: author['nickname'] as String? ?? '',
      authorAvatar: (author['avatar_thumb'] as Map<String, dynamic>?)?['url_list']?[0] as String? ?? '',
      authorId: author['sec_uid'] as String? ?? '',
      diggCount: stats['digg_count'] as int? ?? 0,
      commentCount: stats['comment_count'] as int? ?? 0,
      shareCount: stats['share_count'] as int? ?? 0,
    );
  }
}
