import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/utils/wbi_sign.dart';
import 'package:dio/dio.dart';

/// Queries a member's public activity: comments they posted and the danmaku
/// they sent (via the public danmakus.com mirror of Bilibili danmaku).
abstract final class MemberQueryHttp {
  /// Comments posted by [mid] across the site.
  ///
  /// Uses the comment area endpoint with `mid` filtering: when `mid` is
  /// present the server returns the comments that member wrote rather than
  /// the comments under an object.
  static Future<LoadingState<Map<String, dynamic>>> memberComments({
    required int mid,
    required int page,
  }) async {
    try {
      final params = await WbiSign.makSign({
        'type': 1,
        'oid': 0,
        'mid': mid,
        'mode': 3,
        'next': page,
        'ps': 20,
        'plat': 1,
        'web_location': 1315875,
      });
      final res = await Request().get(
        '/x/v2/reply/wbi/main',
        queryParameters: params,
      );
      final data = res.data;
      if (data is Map && data['code'] == 0) {
        return Success(Map<String, dynamic>.from(data['data'] as Map));
      }
      return Error((data is Map ? data['message'] : null)?.toString() ?? '请求失败');
    } catch (e) {
      return Error(e.toString());
    }
  }

  /// Danmaku sent by [uid], from the public danmakus.com service.
  static Future<LoadingState<List<dynamic>>> memberDanmaku({
    required int uid,
    required int page,
  }) async {
    try {
      final res = await Request().get(
        'https://danmakus.com/api/v2/user',
        queryParameters: {
          'uId': uid,
          'pageNum': page,
          'pageSize': 20,
          'target': -1,
          'useEmoji': true,
        },
        options: Options(
          headers: {'User-Agent': 'PiliNara/1.0'},
        ),
      );
      final data = res.data;
      if (data is Map) {
        final list = data['data'] ?? data['list'] ?? data['result'];
        if (list is List) return Success(list);
        if (data['code'] == 0 && data['data'] is List) {
          return Success(data['data'] as List);
        }
      }
      if (data is List) return Success(data);
      return const Error('弹幕查询失败');
    } catch (e) {
      return Error(e.toString());
    }
  }
}
