import 'dart:async';
import 'package:dio/dio.dart';
import 'package:PiliPlus/services/plugin/rule_engine_models.dart';

class PluginSiteClient {
  PluginSiteClient._();

  static final PluginSiteClient instance = PluginSiteClient._();

  static final _randomUAs = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.1',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
  ];
  static final _randomLangs = ['zh-CN,zh;q=0.9', 'zh-CN,zh;q=0.9,en;q=0.8', 'en-US,en;q=0.9'];

  String _randomUA() => _randomUAs[(DateTime.now().microsecondsSinceEpoch % _randomUAs.length).toInt()];
  String _randomLang() => _randomLangs[(DateTime.now().microsecondsSinceEpoch % _randomLangs.length).toInt()];

  Future<String> requestText(
    String url, {
    required String method,
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? data,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.request<String>(
        url,
        queryParameters: queryParameters,
        data: data,
        options: Options(
          method: method,
          responseType: ResponseType.plain,
          headers: _headers(headers),
        ),
        cancelToken: cancelToken,
      );
      return response.data ?? '';
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) throw const VideoSourceCancelledException();
      rethrow;
    }
  }

  Map<String, dynamic> _headers(Map<String, dynamic> headers) => {
        'user-agent': _randomUA(),
        'Accept-Language': _randomLang(),
        'Connection': 'keep-alive',
        ...headers,
      };
}

class VideoSourceCancelledException implements Exception {
  const VideoSourceCancelledException();
  @override
  String toString() => 'VideoSourceCancelledException: Resolution was cancelled';
}
