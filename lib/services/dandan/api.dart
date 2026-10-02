import 'package:dio/dio.dart';
import 'api_endpoints.dart';
import 'client.dart';

/// Episode entry returned by the DanDan search API.
class DandanAnime {
  final int animeId;
  final String animeTitle;
  final String typeDescription;

  const DandanAnime({
    required this.animeId,
    required this.animeTitle,
    required this.typeDescription,
  });

  factory DandanAnime.fromJson(Map<String, dynamic> json) {
    return DandanAnime(
      animeId: json['animeId'] as int? ?? 0,
      animeTitle: json['animeTitle'] as String? ?? '',
      typeDescription: json['typeDescription'] as String? ?? '',
    );
  }
}

/// Response of `/api/v2/search/episodes`.
class DandanSearchResponse {
  final List<DandanAnime> animes;
  final bool hasMore;

  const DandanSearchResponse({
    required this.animes,
    required this.hasMore,
  });

  factory DandanSearchResponse.fromJson(dynamic json) {
    if (json == null) return const DandanSearchResponse(animes: [], hasMore: false);
    final list = json['animes'] as List? ?? <dynamic>[];
    return DandanSearchResponse(
      animes: list.map((e) => DandanAnime.fromJson(e as Map<String, dynamic>)).toList(),
      hasMore: (json['hasMore'] as num?)?.toInt() == 1,
    );
  }
}

/// Episode info within a bangumi result.
class DandanEpisode {
  final int episodeId;
  final String episodeTitle;

  const DandanEpisode({
    required this.episodeId,
    required this.episodeTitle,
  });

  factory DandanEpisode.fromJson(Map<String, dynamic> json) {
    return DandanEpisode(
      episodeId: json['episodeId'] as int? ?? 0,
      episodeTitle: json['episodeTitle'] as String? ?? '',
    );
  }
}

/// Bangumi metadata response from `/api/v2/bangumi/{id}`.
class DandanBangumiResponse {
  final int bangumiId;
  final List<DandanEpisode> episodes;
  final bool success;

  const DandanBangumiResponse({
    required this.bangumiId,
    required this.episodes,
    required this.success,
  });

  factory DandanBangumiResponse.fromJson(dynamic json) {
    if (json == null) return const DandanBangumiResponse(bangumiId: 0, episodes: [], success: false);
    final bangumi = json['bangumi'] as Map<String, dynamic>? ?? {};
    final list = bangumi['episodes'] as List? ?? <dynamic>[];
    return DandanBangumiResponse(
      bangumiId: bangumi['animeId'] as int? ?? 0,
      episodes: list.map((e) => DandanEpisode.fromJson(e as Map<String, dynamic>)).toList(),
      success: (json['success'] as num?)?.toInt() == 1,
    );
  }
}

/// Parsed comment entry from DanDan.
///
/// Format: `time,type,colorFlag,source` (comma-separated) + message body.
class DandanComment {
  final double time;
  final int type;
  final int color;
  final String source;
  final String message;

  const DandanComment({
    required this.time,
    required this.type,
    required this.color,
    required this.source,
    required this.message,
  });

  factory DandanComment.fromJson(dynamic commentJson) {
    final parts = (commentJson['p'] as String?)?.split(',') ?? const <String>[];
    final message = commentJson['m'] as String? ?? '';
    return DandanComment(
      time: double.tryParse(parts.getOrElse(0, () => '0')) ?? 0.0,
      type: int.tryParse(parts.getOrElse(1, () => '1')) ?? 1,
      color: int.tryParse(parts.getOrElse(2, () => '7706950')) ?? 7706950,
      source: parts.length > 3 ? parts[3] : 'DanDan',
      message: message,
    );
  }
}

/// DanDan API service — search, resolve, fetch.
abstract final class DandanApi {
  static final DandanClient _client = DandanClient.instance;

  /// Search for an anime by title. Returns up to ~50 results (v2 endpoint).
  static Future<DandanSearchResponse> searchAnime(String title) async {
    if (!DandanCredentials.isEnabled) return const DandanSearchResponse(animes: [], hasMore: false);
    final json = await _client.get(
      DandanApiEndpoints.searchEpisodes,
      queryParameters: {'anime': title, 'v2': 'true'},
    );
    return DandanSearchResponse.fromJson(json);
  }

  /// Resolve DanDan bangumi ID from a BGM.tv ID (Kazumi-compatible flow).
  static Future<int> getBangumiIdByBgmId(int bgmId) async {
    if (!DandanCredentials.isEnabled) return 0;
    final path = DandanApiEndpoints.formatUrl(
      DandanApiEndpoints.bangumiInfoByBgmId,
      [bgmId],
    );
    final json = await _client.get(path);
    return DandanBangumiResponse.fromJson(json).bangumiId;
  }

  /// Get episode list for a DanDan bangumi ID.
  static Future<List<DandanEpisode>> getEpisodes(int bangumiId) async {
    if (!DandanCredentials.isEnabled) return [];
    final path = '${DandanApiEndpoints.bangumiInfo}$bangumiId';
    final json = await _client.get(path);
    return DandanBangumiResponse.fromJson(json).episodes;
  }

  /// Fetch comments for a specific episode ID.
  static Future<List<DandanComment>> getComments(int episodeId) async {
    if (!DandanCredentials.isEnabled) return [];
    final path = DandanApiEndpoints.comment;
    final json = await _client.get(
      '$path$episodeId',
      queryParameters: {'withRelated': 'true', 'chConvert': '0'},
    );
    final comments = (json?['comments'] as List?) ?? <dynamic>[];
    return comments.map((e) => DandanComment.fromJson(e)).toList();
  }

  /// Fetch comments by combining BGM ID → DanDan bangumi ID → episode lookup.
  ///
  /// [episode] is 1-based episode number.
  static Future<List<DandanComment>> getCommentsByBgmId(int bgmId, int episode) async {
    if (!DandanCredentials.isEnabled) return [];
    final danDanBangumiId = await getBangumiIdByBgmId(bgmId);
    if (danDanBangumiId == 0) return [];
    // DanDan episode ID convention: bangumiId + zero-padded 4-digit episode
    final episodeId = int.parse('${danDanBangumiId}${episode.toString().padLeft(4, '0')}');
    return getComments(episodeId);
  }
}
