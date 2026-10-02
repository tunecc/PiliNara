import 'package:PiliPlus/services/plugin/plugin_search_module.dart';
import 'package:PiliPlus/services/plugin/road_module.dart';
import 'package:PiliPlus/services/plugin/rule_engine_models.dart';
import 'package:PiliPlus/services/plugin/rule_engine.dart';
import 'package:PiliPlus/plugins/api_rule_config.dart';
import 'package:PiliPlus/plugins/anti_crawler_config.dart';
import 'package:PiliPlus/services/plugin/plugin_site_client.dart' show PluginSiteClient;

String pluginNameKey(String name) => name.toLowerCase();

class Plugin {
  static final RuleEngine _ruleEngine = RuleEngine();

  String api;
  String type;
  String name;
  String version;
  bool muliSources;
  bool useWebview;
  bool useNativePlayer;
  bool usePost;
  bool useLegacyParser;
  bool adBlocker;
  String userAgent;
  String baseUrl;
  String searchURL;
  String searchList;
  String searchName;
  String searchResult;
  String chapterRoads;
  String chapterResult;
  String referer;
  String searchMode;
  String chapterMode;
  ApiSearchConfig searchApiConfig;
  ApiChapterConfig chapterApiConfig;
  AntiCrawlerConfig antiCrawlerConfig;

  Plugin({
    required this.api,
    required this.type,
    required this.name,
    required this.version,
    required this.muliSources,
    required this.useWebview,
    required this.useNativePlayer,
    required this.usePost,
    required this.useLegacyParser,
    required this.adBlocker,
    required this.userAgent,
    required this.baseUrl,
    required this.searchURL,
    required this.searchList,
    required this.searchName,
    required this.searchResult,
    required this.chapterRoads,
    required this.chapterResult,
    required this.referer,
    this.searchMode = RuleMode.xpath,
    this.chapterMode = RuleMode.xpath,
    ApiSearchConfig? searchApiConfig,
    ApiChapterConfig? chapterApiConfig,
    AntiCrawlerConfig? antiCrawlerConfig,
  })  : searchApiConfig = searchApiConfig ?? ApiSearchConfig(),
        chapterApiConfig = chapterApiConfig ?? ApiChapterConfig(),
        antiCrawlerConfig = antiCrawlerConfig ?? AntiCrawlerConfig.empty();

  factory Plugin.fromJson(Map<String, dynamic> json) {
    return Plugin(
      api: json['api']?.toString() ?? '5',
      type: json['type'] as String? ?? 'anime',
      name: json['name'] as String? ?? '',
      version: json['version']?.toString() ?? '',
      muliSources: json['muliSources'] as bool? ?? true,
      useWebview: json['useWebview'] as bool? ?? true,
      useNativePlayer: json['useNativePlayer'] as bool? ?? true,
      usePost: json['usePost'] ?? false,
      useLegacyParser: json['useLegacyParser'] ?? false,
      adBlocker: json['adBlocker'] ?? false,
      userAgent: json['userAgent'] as String? ?? '',
      baseUrl: json['baseURL'] as String? ?? '',
      searchURL: json['searchURL'] as String? ?? '',
      searchList: json['searchList'] as String? ?? '',
      searchName: json['searchName'] as String? ?? '',
      searchResult: json['searchResult'] as String? ?? '',
      chapterRoads: json['chapterRoads'] as String? ?? '',
      chapterResult: json['chapterResult'] as String? ?? '',
      referer: json['referer'] ?? '',
      searchMode: RuleMode.normalize(json['searchMode']),
      chapterMode: RuleMode.normalize(json['chapterMode']),
      searchApiConfig: json['searchApiConfig'] is Map
          ? ApiSearchConfig.fromJson(Map<String, dynamic>.from(json['searchApiConfig']))
          : ApiSearchConfig(),
      chapterApiConfig: json['chapterApiConfig'] is Map
          ? ApiChapterConfig.fromJson(Map<String, dynamic>.from(json['chapterApiConfig']))
          : ApiChapterConfig(),
      antiCrawlerConfig: json['antiCrawlerConfig'] != null
          ? AntiCrawlerConfig.fromJson(Map<String, dynamic>.from(json['antiCrawlerConfig']))
          : AntiCrawlerConfig.empty(),
    );
  }

  factory Plugin.fromTemplate() => Plugin(
    api: '5', type: 'anime', name: '', version: '',
    muliSources: true, useWebview: true, useNativePlayer: true,
    usePost: false, useLegacyParser: false, adBlocker: false,
    userAgent: '', baseUrl: '', searchURL: '', searchList: '',
    searchName: '', searchResult: '', chapterRoads: '', chapterResult: '',
    referer: '',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'api': api, 'type': type, 'name': name, 'version': version,
    'muliSources': muliSources, 'useWebview': useWebview, 'useNativePlayer': useNativePlayer,
    'usePost': usePost, 'useLegacyParser': useLegacyParser, 'adBlocker': adBlocker,
    'userAgent': userAgent, 'baseURL': baseUrl,
    'searchURL': searchURL, 'searchList': searchList, 'searchName': searchName,
    'searchResult': searchResult, 'chapterRoads': chapterRoads, 'chapterResult': chapterResult,
    'referer': referer, 'searchMode': searchMode, 'chapterMode': chapterMode,
    if (searchMode == RuleMode.api || searchApiConfig.request.url.isNotEmpty) 'searchApiConfig': searchApiConfig.toJson(),
    if (chapterMode == RuleMode.api || chapterApiConfig.request.url.isNotEmpty) 'chapterApiConfig': chapterApiConfig.toJson(),
    'antiCrawlerConfig': antiCrawlerConfig.toJson(),
  };

  bool get usesApiSearch => searchMode == RuleMode.api;

  RuleExecutionConfig get _executionConfig => RuleExecutionConfig(
    pluginName: name, baseUrl: baseUrl, usePost: usePost,
    searchMode: searchMode, chapterMode: chapterMode,
    searchUrl: searchURL, searchList: searchList, searchName: searchName,
    searchResult: searchResult, chapterRoads: chapterRoads, chapterResult: chapterResult,
    searchApiConfig: searchApiConfig, chapterApiConfig: chapterApiConfig,
    antiCrawlerConfig: antiCrawlerConfig,
  );

  Future<RuleSearchTrace> traceSearch(String keyword, {CancelToken? cancelToken}) {
    return _ruleEngine.search(_executionConfig, keyword, cancelToken: cancelToken);
  }

  Future<RuleChapterTrace> traceChapters(String source, {CancelToken? cancelToken}) {
    return _ruleEngine.queryChapters(_executionConfig, source, cancelToken: cancelToken);
  }

  Future<PluginSearchResponse> queryBangumi(String keyword, {bool shouldRethrow = false, CancelToken? cancelToken}) async {
    try {
      return (await traceSearch(keyword, cancelToken: cancelToken)).response;
    } on CaptchaRequiredException {
      rethrow;
    } on NoResultException {
      rethrow;
    } on SearchErrorException {
      if (shouldRethrow) rethrow;
      return PluginSearchResponse(pluginName: name, data: []);
    }
  }

  Future<List<Road>> queryChapterRoads(String source, {CancelToken? cancelToken}) async {
    return (await traceChapters(source, cancelToken: cancelToken)).roads;
  }

  String buildFullUrl(String urlItem) => urlItem.trim().isEmpty ? '' : '$baseUrl${urlItem.startsWith('/') ? '' : '/'}${urlItem.replaceAll(RegExp(r'^/+'), '')}';

  Map<String, String> buildHttpHeaders() => {
    'user-agent': userAgent.isEmpty ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36' : userAgent,
    if (referer.isNotEmpty) 'referer': referer,
  };
}
