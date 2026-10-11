/// Thread Ripper 的媒体直连 HTTP 客户端。
///
/// 复用 `Request.http11Dio` 的配置形态（HTTP/1.1、PC UA、bilibili
/// Referer），但不挂 RetryInterceptor / Cookie 等账户拦截器：媒体请求不
/// 重试整个请求、不携带登录态。底层用 dart:io HttpClient（本身即
/// HTTP/1.1、响应纯流式），供代理透传与多 CDN 调度器共用同一客户端形态。
library;

import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/constants.dart';

/// 一次媒体请求的响应：状态码、响应头（小写键）与原始字节流。
///
/// [stream] 必须被消费（或取消订阅），否则底层连接不会被复用/释放。
class MediaHttpResponse {
  const MediaHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.stream,
  });

  final int statusCode;

  /// 全部响应头，键为 dart:io 归一化的小写形式。
  final Map<String, List<String>> headers;

  /// 响应体字节流（HttpClientResponse 本体，即真实到达顺序）。
  final Stream<List<int>> stream;

  /// 取首个同名头；不存在返回 null。键不区分大小写（dart:io 已统一小写）。
  String? header(String name) {
    final values = headers[name.toLowerCase()];
    if (values == null || values.isEmpty) return null;
    return values.first;
  }

  /// 取同名全部头值；不存在返回空列表。
  List<String> headerValues(String name) =>
      headers[name.toLowerCase()] ?? const [];
}

/// 媒体下载专用 HTTP/1.1 客户端。
class MediaHttpClient {
  MediaHttpClient({HttpClient? client})
      : _client = client ?? _createDefaultClient();

  final HttpClient _client;

  static HttpClient _createDefaultClient() => HttpClient()
    ..idleTimeout = const Duration(seconds: 15)
    ..connectionTimeout = const Duration(milliseconds: 10000)
    // 媒体字节必须原样透传（byte-level cross-check 依赖），禁用透明解压
    ..autoUncompress = false;

  /// 发起媒体请求。
  ///
  /// [first]/[last] 为闭区间字节范围，生成 `Range: bytes=first-last`；
  /// 仅 [first] 时为开放右端 `bytes=first-`。任意形式（含后缀
  /// `bytes=-n`）可用 [rangeHeader] 原样指定，其优先级更高。代理透传时
  /// 可用 [method] 发 HEAD 请求。上游连接/协议错误按原样抛出，由调用方
  /// 决定降级路径。
  Future<MediaHttpResponse> fetch(
    String url, {
    int? first,
    int? last,
    String? rangeHeader,
    String method = 'GET',
  }) async {
    final request = await _client.openUrl(method, Uri.parse(url));
    request.headers.set(HttpHeaders.userAgentHeader, BrowserUa.pc);
    request.headers.set(HttpHeaders.refererHeader, HttpString.baseUrl);
    final range = rangeHeader ?? _rangeFrom(first, last);
    if (range != null) {
      request.headers.set(HttpHeaders.rangeHeader, range);
    }
    final response = await request.close();
    final collected = <String, List<String>>{};
    response.headers.forEach((name, values) => collected[name] = values);
    return MediaHttpResponse(
      statusCode: response.statusCode,
      headers: collected,
      stream: response,
    );
  }

  /// 关闭客户端并释放空闲连接（进行中的流不受影响）。
  void close() => _client.close();

  String? _rangeFrom(int? first, int? last) {
    if (first == null) return null;
    return 'bytes=$first-${last ?? ''}';
  }
}
