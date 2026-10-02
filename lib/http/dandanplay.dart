/// Dandanplay HTTP client for multi-source danmaku.
///
/// Mirrors animeko's dandanplay module.
/// API docs: https://github.com/qiniugeee/dandanpy
///
/// Note: Requires AppID and AppSecret from dandanplay.
/// Users can register at https://www.dandanplay.com/api-doc/

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DandanplayHttp {
  static const baseUrl = 'https://api.dandanplay.com';

  final String appId;
  final String appSecret;
  final Dio dio;

  DandanplayHttp({
    required this.appId,
    required this.appSecret,
    Dio? dio,
  }) : dio = dio ?? Dio();

  String _getToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final strToSign = '$appId$timestamp$appSecret';
    final bytes = utf8.encode(strToSign);
    final digest = sha1.convert(bytes);
    return '${timestamp}_${digest}';
  }

  /// Fetch danmaku for a specific episode.
  Future<List<DandanplayDanmaku>> getComments({
    required int episodeId,
    int commentVersion = 1,
  }) async {
    final token = _getToken();
    final resp = await dio.get(
      '$baseUrl/api/v2/comment/',
      queryParameters: {
        'episode': episodeId,
        'version': commentVersion,
        'format': 'json',
      },
      options: Options(
        headers: {
          'Authorization': 'Basic $token',
          'Appid': appId,
          'Authinfo': token,
        },
      ),
    );

    if (resp.data == null || resp.data['code'] != 0) {
      return [];
    }

    final comments = resp.data['comments'] as List? ?? [];
    return comments.map((c) => DandanplayDanmaku.fromJson(c as Map<String, dynamic>)).toList();
  }

  /// Search for dandanplay episode ID by anime title.
  Future<List<DandanplaySearchResult>> search(String keyword) async {
    final token = _getToken();
    final resp = await dio.get(
      '$baseUrl/api/v2/search/episode',
      queryParameters: {
        'keyword': keyword,
        'type': 1,
      },
      options: Options(
        headers: {
          'Authorization': 'Basic $token',
          'Appid': appId,
          'Authinfo': token,
        },
      ),
    );

    if (resp.data == null || resp.data['code'] != 0) {
      return [];
    }

    final results = resp.data['data'] as List? ?? [];
    return results.map((r) => DandanplaySearchResult.fromJson(r as Map<String, dynamic>)).toList();
  }
}

class DandanplayDanmaku {
  final double time;
  final int mode;
  final int color;
  final String text;
  final String pool;
  final int userId;

  const DandanplayDanmaku({
    required this.time,
    required this.mode,
    required this.color,
    required this.text,
    this.pool = '0',
    this.userId = 0,
  });

  factory DandanplayDanmaku.fromJson(Map<String, dynamic> json) {
    final parts = (json['p'] as String?)?.split(',') ?? [];
    return DandanplayDanmaku(
      time: double.tryParse(parts[0] ?? '0') ?? 0.0,
      mode: int.tryParse(parts[1] ?? '1') ?? 1,
      color: int.tryParse(json['e'] as String? ?? '16777215') ?? 16777215,
      text: json['m'] as String? ?? '',
      pool: json['pool'] as String? ?? '0',
      userId: int.tryParse(json['uid'] as String? ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toBilibiliFormat() {
    return {
      'mode': mode,
      'size': 25,
      'color': color,
      'timestamp': (time * 1000).toInt(),
      'pool': int.tryParse(pool) ?? 0,
      'content': text,
    };
  }
}

class DandanplaySearchResult {
  final int episodeId;
  final String title;
  final int type;
  final String? imageUrl;

  const DandanplaySearchResult({
    required this.episodeId,
    required this.title,
    required this.type,
    this.imageUrl,
  });

  factory DandanplaySearchResult.fromJson(Map<String, dynamic> json) {
    return DandanplaySearchResult(
      episodeId: json['episodeId'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      type: json['type'] as int? ?? 0,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
