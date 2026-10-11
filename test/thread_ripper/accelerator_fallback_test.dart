import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/services/thread_ripper/contracts.dart';
import 'package:PiliPlus/services/thread_ripper/media_proxy_server.dart';
import 'package:PiliPlus/services/thread_ripper/session_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// 回归（CRITICAL 修复）：加速流在任何字节写出前失败时，代理必须在
/// 同一请求内回退透传（spec: Stalled acceleration），而不是给播放器一个
/// 截断的 206。
const total = 1 << 20;

int byteAt(int i) => (i * 31 + 7) % 251;

void main() {
  late final HttpServer origin;
  setUp(() async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((req) {
      final range = req.headers.value(HttpHeaders.rangeHeader) ?? '';
      final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range);
      final first = m == null ? 0 : int.parse(m.group(1)!);
      final last =
          m == null || m.group(2)!.isEmpty ? total - 1 : int.parse(m.group(2)!);
      req.response
        ..statusCode = 206
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $first-$last/$total',
        )
        ..contentLength = last - first + 1;
      req.response.add([
        for (var i = first; i <= last; i++) byteAt(i),
      ]);
      req.response.close();
    });
    origin = server;
  });
  tearDown(() => origin.close(force: true));

  test('zero-byte accelerated failure falls back to passthrough', () async {
    final registry = SessionRegistry();
    final proxy = ThreadRipperProxy.forTesting(registry: registry)
      // 加速器立即失败（模拟 commit 超时/全部候选被排除后的 giveUp）
      ..accelerator = _FailingAccelerator();
    final port = (await proxy.start())!;
    addTearDown(proxy.close);

    final url = 'http://127.0.0.1:${origin.port}/seg.m4s';
    final descriptor = MediaDescriptor(
      originalUrl: url,
      candidates: [MediaCandidate(url: url, host: '127.0.0.1')],
      isAudio: false,
      totalSize: total,
      contentType: 'video/mp4',
    );
    final token = registry.register(descriptor);
    final proxyUrl = 'http://127.0.0.1:$port/tr/${_b64(url)}/$token';

    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.getUrl(Uri.parse(proxyUrl));
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=100-199');
    final response = await request.close();

    expect(response.statusCode, 206);
    expect(
      response.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 100-199/$total',
      reason: '回退透传必须给出源站的 Content-Range，而非加速响应的残留头',
    );
    final body = <int>[];
    await for (final chunk in response) {
      body.addAll(chunk);
    }
    expect(body.length, 100);
    for (var i = 0; i < 100; i++) {
      expect(body[i], byteAt(100 + i));
    }
  });
}

class _FailingAccelerator implements MediaAccelerator {
  @override
  AcceleratedResponse? serve(MediaDescriptor descriptor, RangeRequest range) {
    final resolved = range.resolve(descriptor.totalSize ?? total)!;
    return AcceleratedResponse(
      first: resolved.first,
      last: resolved.last,
      total: descriptor.totalSize ?? total,
      stream: Stream<List<int>>.error(StateError('accelerated job gave up')),
    );
  }
}

String _b64(String url) =>
    base64Url.encode(utf8.encode(url)).replaceAll('=', '');
