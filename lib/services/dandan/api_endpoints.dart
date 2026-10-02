/// DanDan (弹弹play) API endpoints.
///
/// Mirrors Kazumi's [ApiEndpoints] DanDan section so PiliNara can call
/// the DanDanPlay API without pulling in the rest of Kazumi.
abstract final class DandanApiEndpoints {
  static const String domain = 'https://api.dandanplay.net';

  /// Fetch comments for a specific episode.
  static const String comment = '/api/v2/comment/';

  /// Search episodes by anime title (v2 avoids the 25-result cap).
  static const String searchEpisodes = '/api/v2/search/episodes';

  /// Resolve bangumi metadata by DanDan anime ID.
  static const String bangumiInfo = '/api/v2/bangumi/';

  /// Resolve bangumi metadata via BGM.tv ID.
  static const String bangumiInfoByBgmId = '/api/v2/bangumi/bgmtv/{0}';

  /// Format a URL template with positional params.
  static String formatUrl(String template, List<dynamic> params) {
    var result = template;
    for (var i = 0; i < params.length; i++) {
      result = result.replaceAll('{$i}', params[i].toString());
    }
    return result;
  }
}
