import 'dart:convert';
import 'dart:math' show max;

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/models/common/danmaku_source.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Fetches danmaku from third-party libraries and converts them to the
/// internal [DanmakuElem] shape used by the player.
abstract final class ThirdPartyDanmakuService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'User-Agent': 'PiliNara/1.0'},
    ),
  );

  /// Merged danmaku from every enabled third-party source.
  static Future<List<DanmakuElem>> fetch({
    required String keyword,
    int? episode,
    Set<String>? sources,
  }) async {
    if (keyword.trim().isEmpty) return const [];
    final enabled = sources ?? Pref.danmakuSources;
    final result = <DanmakuElem>[];
    if (enabled.contains(DanmakuSource.gamer)) {
      result.addAll(await _fetchGamer(keyword, episode));
    }
    if (enabled.contains(DanmakuSource.dandanplay)) {
      result.addAll(await _fetchDandanplay(keyword, episode));
    }
    return result;
  }

  // --- Gamer (巴哈姆特動畫瘋) ---

  static Future<List<DanmakuElem>> _fetchGamer(
    String keyword,
    int? episode,
  ) async {
    try {
      final search = await _dio.get<dynamic>(
        'https://api.gamer.com.tw/anime/v1/search',
        queryParameters: {'keyword': keyword},
      );
      final data = search.data;
      final list = data is Map ? (data['data']?['anime'] as List?) : null;
      if (list == null || list.isEmpty) return const [];
      final first = list.first;
      final sn = first is Map ? (first['animeSn'] as num?)?.toInt() : null;
      if (sn == null) return const [];

      final res = await _dio.get<dynamic>(
        'https://ani.gamer.com.tw/ajax/danmuGet.php',
        queryParameters: {'sn': sn},
      );
      final items = res.data;
      if (items is! List) return const [];
      return [
        for (final item in items)
          if (item is Map)
            DanmakuElem(
              content: item['text']?.toString() ?? '',
              // Gamer reports time in seconds.
              progress:
                  (((item['time'] as num?)?.toDouble() ?? 0) * 1000).round(),
              mode: (item['position'] as num?)?.toInt() ?? 1,
              fontsize: (item['size'] as num?)?.toInt() ?? 25,
              color: _parseColor(item['color']?.toString()),
            ),
      ];
    } catch (e) {
      logger.w('gamer danmaku failed: $e');
      return const [];
    }
  }

  // --- 弹弹play ---

  static Future<List<DanmakuElem>> _fetchDandanplay(
    String keyword,
    int? episode,
  ) async {
    // 使用公共API，无需凭据
    try {
      final search = await _dio.get<dynamic>(
        'https://api.dandanplay.net/api/v2/search/episodes',
        queryParameters: {'anime': keyword},
      );
      final data = search.data;
      final animes = data is Map ? (data['animes'] as List?) : null;
      if (animes == null || animes.isEmpty) return const [];

      final target = _pickEpisode(animes, episode);
      if (target == null) return const [];
      final episodeId = (target['episodeId'] as num?)?.toInt();
      if (episodeId == null) return const [];

      final comment = await _dio.get<dynamic>(
        'https://api.dandanplay.net/api/v2/comment/$episodeId',
        queryParameters: {'withRelated': 'true'},
      );
      final body = comment.data;
      final comments = body is Map ? (body['comments'] as List?) : null;
      if (comments == null) return const [];
      final result = <DanmakuElem>[];
      for (final c in comments) {
        if (c is! Map) continue;
        final p = c['p']?.toString() ?? '';
        final parts = p.split(',');
        if (parts.length < 3) continue;
        final seconds = double.tryParse(parts[0]) ?? 0;
        final mode = int.tryParse(parts[1]) ?? 1;
        final color = int.tryParse(parts[2]) ?? 0xFFFFFF;
        result.add(
          DanmakuElem(
            content: c['m']?.toString() ?? '',
            progress: (seconds * 1000).round(),
            mode: mode,
            fontsize: 25,
            color: color,
          ),
        );
      }
      return result;
    } catch (e) {
      logger.w('dandanplay danmaku failed: $e');
      return const [];
    }
  };
    }
    try {
      final headers = _dandanplayHeaders(appId, appSecret);
      final search = await _dio.get<dynamic>(
        'https://api.dandanplay.net/api/v2/search/episodes',
        queryParameters: {'anime': keyword},
        options: Options(headers: headers),
      );
      final data = search.data;
      final animes = data is Map ? (data['animes'] as List?) : null;
      if (animes == null || animes.isEmpty) return const [];

      final target = _pickEpisode(animes, episode);
      if (target == null) return const [];
      final episodeId = (target['episodeId'] as num?)?.toInt();
      if (episodeId == null) return const [];

      final comment = await _dio.get<dynamic>(
        'https://api.dandanplay.net/api/v2/comment/$episodeId',
        queryParameters: {'withRelated': 'true'},
        options: Options(headers: headers),
      );
      final body = comment.data;
      final comments = body is Map ? (body['comments'] as List?) : null;
      if (comments == null) return const [];
      final result = <DanmakuElem>[];
      for (final c in comments) {
        if (c is! Map) continue;
        final p = c['p']?.toString() ?? '';
        final parts = p.split(',');
        if (parts.length < 3) continue;
        final seconds = double.tryParse(parts[0]) ?? 0;
        final mode = int.tryParse(parts[1]) ?? 1;
        final color = int.tryParse(parts[2]) ?? 0xFFFFFF;
        result.add(
          DanmakuElem(
            content: c['m']?.toString() ?? '',
            progress: (seconds * 1000).round(),
            mode: mode,
            fontsize: 25,
            color: color,
          ),
        );
      }
      return result;
    } catch (e) {
      logger.w('dandanplay danmaku failed: $e');
      return const [];
    }
  }

  /// Picks the episode matching [episode], else the first one.
  static Map? _pickEpisode(List animes, int? episode) {
    for (final anime in animes) {
      if (anime is! Map) continue;
      final episodes = anime['episodes'];
      if (episodes is! List || episodes.isEmpty) continue;
      if (episode != null) {
        for (final ep in episodes) {
          if (ep is Map &&
              (ep['episodeNumber'] as num?)?.toInt() == episode) {
            return Map<String, dynamic>.from(ep);
          }
        }
      }
      final first = episodes.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  static Map<String, String> _dandanplayHeaders(
    String appId,
    String secret,
  ) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signature = base64.encode(
      md5.convert(utf8.encode('$appId$timestamp$secret')).bytes,
    );
    return {
      'X-AppId': appId,
      'X-Signature': signature,
      'X-Timestamp': timestamp.toString(),
    };
  }

  static int _parseColor(String? value) {
    if (value == null || value.isEmpty) return 0xFFFFFF;
    final hex = value.replaceFirst('#', '');
    return int.tryParse(hex, radix: 16) ?? 0xFFFFFF;
  }

  /// Ensures a value is non-negative before use as a danmaku position.
  static int clampProgress(int value) => max(0, value);
}
