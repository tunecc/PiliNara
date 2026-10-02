class RuleMode {
  static const String xpath = 'xpath';
  static const String api = 'api';

  static String normalize(Object? value) => value == api ? api : xpath;
}

class ApiBodyType {
  static const String none = 'none';
  static const String json = 'json';
  static const String form = 'form';

  static String normalize(Object? value) =>
      value == json ? json : value == form ? form : none;
}

class ApiChapterFormat {
  static const String nested = 'nested';
  static const String delimited = 'delimited';

  static String normalize(Object? value) =>
      value == delimited ? delimited : nested;
}

class ApiRequestConfig {
  String method;
  String url;
  Map<String, dynamic> headers;
  Map<String, dynamic> query;
  String bodyType;
  dynamic body;

  ApiRequestConfig({
    this.method = 'GET',
    this.url = '',
    Map<String, dynamic>? headers,
    Map<String, dynamic>? query,
    this.bodyType = ApiBodyType.none,
    this.body,
  })  : headers = headers ?? {},
        query = query ?? {};

  factory ApiRequestConfig.fromJson(Map<String, dynamic> json) {
    return ApiRequestConfig(
      method: ((json['method'] as String?) ?? 'GET').toUpperCase(),
      url: json['url'] as String? ?? '',
      headers: _asStringMap(json['headers']),
      query: _asStringMap(json['query']),
      bodyType: ApiBodyType.normalize(json['bodyType']),
      body: json['body'],
    );
  }

  Map<String, dynamic> toJson() => {
        'method': method.toUpperCase(),
        'url': url,
        if (headers.isNotEmpty) 'headers': headers,
        if (query.isNotEmpty) 'query': query,
        if (bodyType != ApiBodyType.none) 'bodyType': bodyType,
        if (bodyType != ApiBodyType.none && body != null) 'body': body,
      };
}

class ApiSearchConfig {
  ApiRequestConfig request;
  String listPath;
  String namePath;
  String sourcePath;

  ApiSearchConfig({
    ApiRequestConfig? request,
    this.listPath = r'$.data[*]',
    this.namePath = r'$.name',
    this.sourcePath = r'$.url',
  }) : request = request ?? ApiRequestConfig();

  factory ApiSearchConfig.fromJson(Map<String, dynamic> json) {
    return ApiSearchConfig(
      request: ApiRequestConfig.fromJson(_asStringMap(json['request'])),
      listPath: json['listPath'] as String? ?? r'$.data[*]',
      namePath: json['namePath'] as String? ?? r'$.name',
      sourcePath: json['sourcePath'] as String? ?? r'$.url',
    );
  }

  Map<String, dynamic> toJson() => {
        'request': request.toJson(),
        'listPath': listPath,
        'namePath': namePath,
        'sourcePath': sourcePath,
      };
}

class ApiEpisodePageConfig {
  String url;
  Map<String, dynamic> query;

  ApiEpisodePageConfig({this.url = '', Map<String, dynamic>? query})
      : query = query ?? {};

  factory ApiEpisodePageConfig.fromJson(Map<String, dynamic> json) {
    return ApiEpisodePageConfig(
      url: json['url'] as String? ?? '',
      query: _asStringMap(json['query']),
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'query': query};
}

class ApiChapterConfig {
  ApiRequestConfig request;
  String format;
  String roadsPath;
  String roadNamePath;
  String episodesPath;
  String episodeNamePath;
  String episodeUrlPath;
  String roadNamesPath;
  String roadEpisodesPath;
  String roadSeparator;
  String episodeSeparator;
  String fieldSeparator;
  Map<String, String> variables;
  ApiEpisodePageConfig? episodePage;

  ApiChapterConfig({
    ApiRequestConfig? request,
    this.format = ApiChapterFormat.nested,
    this.roadsPath = r'$.data.roads[*]',
    this.roadNamePath = r'$.name',
    this.episodesPath = r'$.episodes[*]',
    this.episodeNamePath = r'$.name',
    this.episodeUrlPath = r'$.url',
    this.roadNamesPath = '',
    this.roadEpisodesPath = '',
    this.roadSeparator = r'$$$',
    this.episodeSeparator = '#',
    this.fieldSeparator = r'$',
    Map<String, String>? variables,
    this.episodePage,
  })  : request = request ?? ApiRequestConfig(),
        variables = variables ?? {};

  factory ApiChapterConfig.fromJson(Map<String, dynamic> json) {
    final rawVars = _asStringMap(json['variables']);
    return ApiChapterConfig(
      request: ApiRequestConfig.fromJson(_asStringMap(json['request'])),
      format: ApiChapterFormat.normalize(json['format']),
      roadsPath: json['roadsPath'] as String? ?? r'$.data.roads[*]',
      roadNamePath: json['roadNamePath'] as String? ?? r'$.name',
      episodesPath: json['episodesPath'] as String? ?? r'$.episodes[*]',
      episodeNamePath: json['episodeNamePath'] as String? ?? r'$.name',
      episodeUrlPath: json['episodeUrlPath'] as String? ?? r'$.url',
      roadNamesPath: json['roadNamesPath'] as String? ?? '',
      roadEpisodesPath: json['roadEpisodesPath'] as String? ?? '',
      roadSeparator: json['roadSeparator'] as String? ?? r'$$$',
      episodeSeparator: json['episodeSeparator'] as String? ?? '#',
      fieldSeparator: json['fieldSeparator'] as String? ?? r'$',
      variables: rawVars.map((k, v) => MapEntry(k, v.toString())),
      episodePage: json['episodePage'] is Map
          ? ApiEpisodePageConfig.fromJson(_asStringMap(json['episodePage']))
          : null,
    );
  }

  bool get _hasNestedConfig =>
      roadsPath != r'$.data.roads[*]' ||
      roadNamePath != r'$.name' ||
      episodesPath != r'$.episodes[*]' ||
      episodeNamePath != r'$.name' ||
      episodeUrlPath != r'$.url';

  bool get _hasDelimitedConfig =>
      roadNamesPath.isNotEmpty || roadEpisodesPath.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'request': request.toJson(),
        'format': format,
        if (format == ApiChapterFormat.nested || _hasNestedConfig) ...{
          'roadsPath': roadsPath,
          'roadNamePath': roadNamePath,
          'episodesPath': episodesPath,
          'episodeNamePath': episodeNamePath,
          'episodeUrlPath': episodeUrlPath,
        },
        if (format == ApiChapterFormat.delimited || _hasDelimitedConfig) ...{
          'roadNamesPath': roadNamesPath,
          'roadEpisodesPath': roadEpisodesPath,
          'roadSeparator': roadSeparator,
          'episodeSeparator': episodeSeparator,
          'fieldSeparator': fieldSeparator,
        },
        if (variables.isNotEmpty) 'variables': variables,
        if (episodePage != null) 'episodePage': episodePage!.toJson(),
      };
}

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is! Map) return {};
  return value.map((k, v) => MapEntry(k.toString(), v));
}
