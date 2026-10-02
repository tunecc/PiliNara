import 'dart:async';
import 'package:dio/dio.dart';
import 'package:PiliPlus/plugins/api_rule_config.dart';
import 'package:PiliPlus/services/plugin/api_rule_strategy.dart';
import 'package:PiliPlus/services/plugin/plugin_search_module.dart';
import 'package:PiliPlus/services/plugin/rule_engine_models.dart';
import 'package:PiliPlus/services/plugin/xpath_rule_strategy.dart';
import 'package:flutter/foundation.dart';

abstract interface class RuleRequestExecutor {
  Future<String> execute(PreparedRuleRequest request, RuleExecutionConfig config, {CancelToken? cancelToken});
}

class RuleEngine {
  RuleEngine({
    RuleRequestExecutor? requestExecutor,
    ApiRuleStrategy apiStrategy = const ApiRuleStrategy(),
    XPathRuleStrategy xpathStrategy = const XPathRuleStrategy(),
    bool logFailures = true,
  })  : _requestExecutor = requestExecutor ?? _DefaultRuleRequestExecutor(),
        _apiStrategy = apiStrategy,
        _xpathStrategy = xpathStrategy,
        _logFailures = logFailures;

  final RuleRequestExecutor _requestExecutor;
  final ApiRuleStrategy _apiStrategy;
  final XPathRuleStrategy _xpathStrategy;
  final bool _logFailures;

  Future<RuleSearchTrace> search(RuleExecutionConfig config, String keyword, {CancelToken? cancelToken}) async {
    late final PreparedRuleRequest request;
    try {
      request = config.searchMode == RuleMode.api
          ? _apiStrategy.prepareRequest(config.searchApiConfig.request, <String, Object?>{'keyword': keyword})
          : _xpathStrategy.prepareSearchRequest(config, keyword);
    } catch (error, stackTrace) {
      _logFailure(config, 'search request preparation', error);
      throw SearchErrorException(config.pluginName, cause: error);
    }
    late final String raw;
    try {
      raw = await _executeRequest(request, config, phase: 'search request', wrapError: (e) => SearchErrorException(config.pluginName, cause: e), cancelToken: cancelToken);
    } on CaptchaRequiredException {
      rethrow;
    } on NoResultException {
      rethrow;
    } on SearchErrorException catch (error) {
      rethrow;
    } catch (error) {
      if (_isCancellation(error)) rethrow;
      _logFailure(config, 'search request', error);
      throw SearchErrorException(config.pluginName, cause: error);
    }
    try {
      final parsed = config.searchMode == RuleMode.api
          ? _apiStrategy.parseSearch(raw, config.searchApiConfig)
          : _xpathStrategy.parseSearch(raw, config);
      if (parsed.items.isEmpty) throw NoResultException(config.pluginName);
      final items = parsed.items.whereType<SearchItem>().toList();
      return RuleSearchTrace(
        rawResponse: raw,
        response: PluginSearchResponse(pluginName: config.pluginName, data: items),
        matchedFragments: parsed.matchedFragments,
        diagnostics: parsed.diagnostics,
      );
    } on NoResultException {
      rethrow;
    } catch (error, stackTrace) {
      if (_isCancellation(error)) rethrow;
      _logFailure(config, 'search response parsing', error);
      throw SearchErrorException(config.pluginName, cause: error);
    }
  }

  Future<RuleChapterTrace> queryChapters(RuleExecutionConfig config, String source, {CancelToken? cancelToken}) async {
    late final PreparedRuleRequest request;
    try {
      request = config.chapterMode == RuleMode.api
          ? _apiStrategy.prepareRequest(config.chapterApiConfig.request, <String, Object?>{'source': source})
          : _xpathStrategy.prepareChapterRequest(config, source);
    } catch (error, stackTrace) {
      _logFailure(config, 'chapter request preparation', error);
      throw ChapterErrorException(config.pluginName, cause: error);
    }
    final raw = await _executeRequest(request, config, phase: 'chapter request', wrapError: (e) => ChapterErrorException(config.pluginName, cause: e), cancelToken: cancelToken);
    try {
      final parsed = config.chapterMode == RuleMode.api
          ? _apiStrategy.parseChapters(raw, config.chapterApiConfig, source: source, baseUrl: config.baseUrl)
          : _xpathStrategy.parseChapters(raw, config);
      if (parsed.roads.isEmpty) throw ChapterErrorException(config.pluginName);
      final roads = parsed.roads.whereType<Road>().toList();
      return RuleChapterTrace(rawResponse: raw, roads: roads, diagnostics: parsed.diagnostics);
    } on ChapterErrorException {
      rethrow;
    } catch (error, stackTrace) {
      if (_isCancellation(error)) rethrow;
      _logFailure(config, 'chapter response parsing', error);
      throw ChapterErrorException(config.pluginName, cause: error);
    }
  }

  Future<String> _executeRequest(PreparedRuleRequest request, RuleExecutionConfig config, {required String phase, required Object Function(Object error) wrapError, CancelToken? cancelToken}) async {
    try {
      return await _requestExecutor.execute(request, config, cancelToken: cancelToken);
    } catch (error, stackTrace) {
      if (_isCancellation(error)) rethrow;
      _logFailure(config, phase, error);
      throw wrapError(error);
    }
  }

  bool _isCancellation(Object error) => error is DioException && error.type == DioExceptionType.cancel;

  void _logFailure(RuleExecutionConfig config, String phase, Object error) {
    if (!_logFailures) return;
    debugPrint('[Plugin: ${config.pluginName}] $phase failed: $error');
  }
}

class _DefaultRuleRequestExecutor implements RuleRequestExecutor {
  @override
  Future<String> execute(PreparedRuleRequest request, RuleExecutionConfig config, {CancelToken? cancelToken}) async {
    final headers = <String, dynamic>{
      'referer': '${config.baseUrl}/',
      for (final entry in request.headers.entries) entry.key.toLowerCase(): entry.value,
    };
    if (request.method == 'POST') {
      switch (request.bodyType) {
        case ApiBodyType.json: headers['content-type'] = 'application/json'; break;
        case ApiBodyType.form: headers['content-type'] = 'application/x-www-form-urlencoded'; break;
        default: break;
      }
    }
    return PluginSiteClient.instance.requestText(
      request.url,
      method: request.method,
      headers: headers,
      queryParameters: request.query,
      data: request.method == 'POST' ? request.body : null,
      cancelToken: cancelToken,
    );
  }
}
