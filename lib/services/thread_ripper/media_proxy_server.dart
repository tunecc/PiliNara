/// Thread Ripper 的本地回环媒体代理。
///
/// 拦截播放器的媒体 Range 请求：路径 `/tr/<base64urlNoPad(originalUrl)>/<token>`
/// 先经 [SessionRegistry] 反查 [MediaDescriptor]，注入了 [MediaAccelerator]
/// 且命中时按 [AcceleratedResponse] 输出 206；registry miss、无 Range、HEAD
/// 或加速器不接手时一律退化为对路径内原始 URL 的直接透传（[MediaHttpClient]）。
///
/// 优雅降级是硬约束（spec：playback never fails because of Thread Ripper）：
/// 绑定失败置 [ThreadRipperProxy.disabled] 并让调用方保持 URL 直连；请求处理
/// 中的任何异常都不会让播放器看到非 CDN 式错误——未提交响应时补一次透传，
/// 仍失败才按 HTTP 语义回 502。透传与加速路径均为流式，不做整段缓冲。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:PiliPlus/services/thread_ripper/contracts.dart';
import 'package:PiliPlus/services/thread_ripper/direct_fetcher.dart';
import 'package:PiliPlus/services/thread_ripper/proxy_url.dart';
import 'package:PiliPlus/services/thread_ripper/range_semantics.dart';
import 'package:PiliPlus/services/thread_ripper/session_registry.dart';

/// 透传时原样回拷给播放器的上游响应头（dart:io 归一化小写键）。
const _passthroughHeaderNames = [
  'accept-ranges',
  'content-range',
  'content-type',
  'etag',
  'last-modified',
];

class ThreadRipperProxy {
  ThreadRipperProxy._({
    MediaHttpClient? httpClient,
    SessionRegistry? registry,
    this.bindPort = 0,
  })  : httpClient = httpClient ?? MediaHttpClient(),
        registry = registry ?? SessionRegistry();

  /// 应用级单例：懒启动；绑定失败后 [disabled] 为 true，本次运行内
  /// 不再重试，URL 保持直连。
  static final ThreadRipperProxy instance = ThreadRipperProxy._();

  /// 测试专用独立实例，避免污染单例状态。
  @visibleForTesting
  factory ThreadRipperProxy.forTesting({
    MediaHttpClient? httpClient,
    SessionRegistry? registry,
    int bindPort = 0,
  }) =>
      ThreadRipperProxy._(
        httpClient: httpClient,
        registry: registry,
        bindPort: bindPort,
      );

  /// 透传与调度器共用的媒体 HTTP 客户端形态。
  final MediaHttpClient httpClient;

  /// token → descriptor 注册表；由视频会话在换片/销毁时 [SessionRegistry.clear]。
  final SessionRegistry registry;

  /// 每视频注入的加速器；null、serve 返回 null 或抛异常时一律透传。
  MediaAccelerator? accelerator;

  /// 仅测试可覆盖的绑定端口；生产恒为 0（临时端口）。
  final int bindPort;

  HttpServer? _server;
  int? _port;
  bool _disabled = false;

  /// 绑定失败后为 true：本次运行内永久禁用，调用方应保持 URL 直连。
  bool get disabled => _disabled;

  /// 当前监听端口；未启动时为 null。
  int? get port => _port;

  /// 懒启动本地代理并返回端口；已启动时幂等返回同端口。
  /// 绑定失败返回 null（不抛出）并置 [disabled]。
  Future<int?> start() async {
    final existing = _port;
    if (existing != null) return existing;
    if (_disabled) return null;
    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, bindPort);
    } catch (_) {
      // spec：本地端点不可用 → 改写对本次运行永久关闭
      _disabled = true;
      return null;
    }
    _server = server;
    _port = server.port;
    server.listen(_onRequest, onError: (_) {});
    return _port;
  }

  /// 干净关闭监听；已建立的响应允许自然结束。
  Future<void> close() async {
    final server = _server;
    _server = null;
    _port = null;
    if (server != null) {
      try {
        await server.close();
      } catch (_) {}
    }
  }

  Future<void> _onRequest(HttpRequest request) async {
    var committed = false;
    try {
      committed = await _dispatch(request);
      return;
    } catch (_) {
      // 代理内部异常：播放器绝不能看到非 CDN 式错误
    }
    if (committed) return; // 已开始输出，无法补救，交给播放器按 Range 重试
    // 尚未提交响应：按 spec 再给透传一次机会
    try {
      final parsed = parseProxyPath(request.uri.path);
      if (parsed == null) {
        await _sendStatus(request, HttpStatus.notFound);
        return;
      }
      committed = await _passthrough(
        request,
        parsed.url,
        rawRange: request.headers.value(HttpHeaders.rangeHeader),
      );
      if (committed) return;
    } catch (_) {}
    try {
      await _sendStatus(request, HttpStatus.badGateway);
    } catch (_) {}
  }

  /// 分发一个请求；返回响应是否已开始向播放器输出。
  Future<bool> _dispatch(HttpRequest request) async {
    final method = request.method;
    if (method != 'GET' && method != 'HEAD') {
      await _sendStatus(request, HttpStatus.methodNotAllowed);
      return true;
    }
    final parsed = parseProxyPath(request.uri.path);
    if (parsed == null) {
      await _sendStatus(request, HttpStatus.notFound);
      return true;
    }
    final rawRange = request.headers.value(HttpHeaders.rangeHeader);
    final range = parseRangeHeader(rawRange);
    // HEAD 与无（可解析）Range 的请求一律直接透传
    if (method == 'HEAD' || range == null) {
      return _passthrough(request, parsed.url, rawRange: rawRange);
    }
    final descriptor = registry.lookup(parsed.token);
    if (descriptor != null) {
      // total 已知且 Range 不可满足：按 HTTP 语义回 416，不打扰上游
      final total = descriptor.totalSize;
      if (total != null && range.resolve(total) == null) {
        await _sendUnsatisfiable(request, total);
        return true;
      }
      final accelerator = this.accelerator;
      if (accelerator != null) {
        AcceleratedResponse? accelerated;
        try {
          accelerated = accelerator.serve(descriptor, range);
        } catch (_) {
          accelerated = null; // 加速器内部错误一律降级透传
        }
        if (accelerated != null &&
            accelerated.last >= accelerated.first &&
            accelerated.total > 0) {
          await _serveAccelerated(
            request,
            accelerated,
            descriptor.contentType,
            parsed.url,
            rawRange,
          );
          return true;
        }
      }
    }
    return _passthrough(request, parsed.url, rawRange: rawRange);
  }

  /// 按 [AcceleratedResponse] 输出 206；流式回传，播放器 seek 断开属常态。
  /// Content-Type 用 descriptor 携带的播放信息 MIME（缺失回退通用二进制），
  /// 与直连响应保持一致，播放器无法据此区分。
  ///
  /// 响应头延迟到首个数据块到达时才写：dart:io 在 addStream 调用后即冻结
  /// 响应头，因此"加速流在首字节前失败 → 同请求内回退透传"（spec 的
  /// Stalled acceleration 场景）必须以手动订阅实现。首字节写出后失败则
  /// 连接按原样结束，由 mpv 按 Range 重连（上游同语义）。
  Future<void> _serveAccelerated(
    HttpRequest request,
    AcceleratedResponse accelerated,
    String? contentType,
    String originUrl,
    String? rawRange,
  ) async {
    final response = request.response;
    var committed = false;
    var delivered = accelerated.first;
    try {
      await for (final chunk in accelerated.stream) {
        if (!committed) {
          committed = true;
          response
            ..statusCode = HttpStatus.partialContent
            ..headers.set(
              HttpHeaders.contentRangeHeader,
              contentRangeHeader(
                accelerated.first,
                accelerated.last,
                accelerated.total,
              ),
            )
            ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes')
            ..headers.set(
              HttpHeaders.contentTypeHeader,
              contentType ?? 'application/octet-stream',
            )
            ..contentLength = accelerated.last - accelerated.first + 1;
        }
        response.add(chunk);
        delivered += chunk.length;
        // flush 提供背压：慢速播放器不会无限积压内存；flush 完成即把消费
        // 水位上报给调度器，驱动下一棒按需预取
        accelerated.onConsumed?.call(delivered);
        await response.flush();
      }
      if (committed) {
        await response.close();
        return;
      }
      // 零字节正常结束（不该发生）：同样按失败回退透传
    } catch (_) {
      // 首字节后失败：连接按已交付内容结束，mpv 按 Range 重连
    }
    if (committed) {
      try {
        await response.close();
      } catch (_) {}
      return;
    }
    try {
      await _passthrough(request, originUrl, rawRange: rawRange);
      return;
    } catch (_) {}
    try {
      await _sendStatus(request, HttpStatus.badGateway);
    } catch (_) {}
  }

  /// 对原始 URL 的直接透传；返回前上游已取到响应头（响应已开始输出）。
  Future<bool> _passthrough(
    HttpRequest request,
    String url, {
    String? rawRange,
  }) async {
    final upstream = await httpClient.fetch(
      url,
      method: request.method,
      rangeHeader: rawRange,
    );
    final response = request.response..statusCode = upstream.statusCode;
    for (final name in _passthroughHeaderNames) {
      for (final value in upstream.headerValues(name)) {
        response.headers.add(name, value);
      }
    }
    final lengthText = upstream.header(HttpHeaders.contentLengthHeader);
    final length = lengthText == null ? null : int.tryParse(lengthText);
    if (length != null && length >= 0) {
      // 固定长度输出，避免代理侧 chunked 重编码
      response.contentLength = length;
    }
    try {
      await response.addStream(upstream.stream);
    } catch (_) {
      // 播放器中断（mpv seek 即断开）或上游中断
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
    return true;
  }

  Future<void> _sendStatus(HttpRequest request, int status) async {
    final response = request.response
      ..statusCode = status
      ..contentLength = 0;
    await response.close();
  }

  Future<void> _sendUnsatisfiable(HttpRequest request, int total) async {
    final response = request.response
      ..statusCode = HttpStatus.requestedRangeNotSatisfiable
      ..headers.set(
        HttpHeaders.contentRangeHeader,
        unsatisfiableContentRange(total),
      )
      ..contentLength = 0;
    await response.close();
  }
}
