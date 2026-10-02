import 'package:dio/dio.dart';
import 'package:PiliPlus/services/plugin/api_rule_config.dart';

typedef RuleCancelToken = CancelToken;

class CaptchaRequiredException implements Exception {
  const CaptchaRequiredException(this.pluginName);
  final String pluginName;
  @override
  String toString() => 'CaptchaRequiredException: $pluginName requires captcha';
}

class NoResultException implements Exception {
  const NoResultException(this.pluginName);
  final String pluginName;
  @override
  String toString() => 'NoResultException: $pluginName returned no results';
}

class SearchErrorException implements Exception {
  const SearchErrorException(this.pluginName, {this.cause});
  final String pluginName;
  final Object? cause;
  @override
  String toString() =>
      'SearchErrorException: $pluginName search failed${cause != null ? ' ($cause)' : ''}';
}

class ChapterErrorException implements Exception {
  const ChapterErrorException(this.pluginName, {this.cause});
  final String pluginName;
  final Object? cause;
  @override
  String toString() =>
      'ChapterErrorException: $pluginName chapter query failed${cause != null ? ' ($cause)' : ''}';
}

class RuleExecutionConfig {
  const RuleExecutionConfig({
    required this.pluginName,
    required this.baseUrl,
    required this.usePost,
    required this.searchMode,
    required this.chapterMode,
    required this.searchUrl,
    required this.searchList,
    required this.searchName,
    required this.searchResult,
    required this.chapterRoads,
    required this.chapterResult,
    required this.searchApiConfig,
    required this.chapterApiConfig,
    required this.antiCrawlerConfig,
  });

  final String pluginName;
  final String baseUrl;
  final bool usePost;
  final String searchMode;
  final String chapterMode;
  final String searchUrl;
  final String searchList;
  final String searchName;
  final String searchResult;
  final String chapterRoads;
  final String chapterResult;
  final ApiSearchConfig searchApiConfig;
  final ApiChapterConfig chapterApiConfig;
  final AntiCrawlerConfig antiCrawlerConfig;
}

class PreparedRuleRequest {
  const PreparedRuleRequest({
    required this.method,
    required this.url,
    this.headers = const <String, dynamic>{},
    this.query = const <String, dynamic>{},
    this.bodyType = ApiBodyType.none,
    this.body,
    this.includeCookies = false,
  });
  final String method;
  final String url;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> query;
  final String bodyType;
  final Object? body;
  final bool includeCookies;
}

class RuleSearchParseResult {
  const RuleSearchParseResult({
    required this.items,
    this.matchedFragments = const <String>[],
    this.diagnostics = const <String>[],
  });
  final List<dynamic> items;
  final List<String> matchedFragments;
  final List<String> diagnostics;
}

class RuleChapterParseResult {
  const RuleChapterParseResult({
    required this.roads,
    this.diagnostics = const <String>[],
  });
  final List<dynamic> roads;
  final List<String> diagnostics;
}

class RuleSearchTrace {
  const RuleSearchTrace({
    required this.rawResponse,
    required this.response,
    required this.matchedFragments,
    required this.diagnostics,
  });
  final String rawResponse;
  final dynamic response;
  final List<String> matchedFragments;
  final List<String> diagnostics;
}

class RuleChapterTrace {
  const RuleChapterTrace({
    required this.rawResponse,
    required this.roads,
    required this.diagnostics,
  });
  final String rawResponse;
  final List<dynamic> roads;
  final List<String> diagnostics;
}
