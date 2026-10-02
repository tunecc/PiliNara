import 'dart:math';
import 'package:dio/dio.dart';
import 'api_endpoints.dart';
import 'crypto.dart';

/// Random user-agent list borrowed from Kazumi so DanDan API sees a normal browser.
const _kUserAgents = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.1',
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
];

String _randomUA() => _kUserAgents[Random().nextInt(_kUserAgents.length)];

/// Thin HTTP client for the DanDanPlay open API.
///
/// Wraps a Dio instance with the required auth headers (X-Auth, X-AppId,
/// X-Timestamp, X-Signature) and a randomized User-Agent to avoid bare-bot
/// filtering.
class DandanClient {
  DandanClient._();

  static final DandanClient instance = DandanClient._();

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: DandanApiEndpoints.domain,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'user-agent': _randomUA(), 'referer': ''},
    validateStatus: (status) => status != null && status >= 200 && status < 300,
  ));

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    if (!DandanCredentials.isEnabled) return null;
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final uri = Uri.parse(path);
    return _dio.get<dynamic>(
      uri.path,
      queryParameters: queryParameters,
      options: Options(
        headers: {
          'user-agent': _randomUA(),
          'referer': '',
          'X-Auth': 1,
          'X-AppId': DandanCredentials.appId,
          'X-Timestamp': timestamp,
          'X-Signature': generateDandanSignature(uri.path, timestamp),
        },
      ),
      cancelToken: cancelToken,
    ).then((r) => r.data);
  }
}
