import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/services/thread_ripper/direct_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// 本地 mock 上游 CDN；所有请求都只走 127.0.0.1，不访问真实网络。
void main() {
  late HttpServer upstream;
  late String base;
  final seenRequests = <HttpRequest>[];
  FutureOr<void> Function(HttpRequest req) handler = (req) {};

  setUp(() async {
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${upstream.port}';
    seenRequests.clear();
    handler = (req) {};
    upstream.listen((req) async {
      seenRequests.add(req);
      try {
        await handler(req);
      } finally {
        await req.response.close().catchError((_) {});
      }
    });
  });

  tearDown(() async {
    await upstream.close(force: true);
  });

  group('MediaHttpClient.fetch', () {
    test('携带 PC UA 与 bilibili Referer，不携带 Cookie，HTTP/1.1', () async {
      handler = (req) {
        req.response.writeln('ok');
      };
      final client = MediaHttpClient();
      final resp = await client.fetch('$base/file.m4s');
      expect(resp.statusCode, 200);
      final req = seenRequests.single;
      expect(req.headers.value('user-agent'), BrowserUa.pc);
      expect(req.headers.value('referer'), HttpString.baseUrl);
      expect(req.headers.value('cookie'), isNull);
      expect(req.protocolVersion, '1.1');
      expect(await utf8.decoder.bind(resp.stream).first, 'ok\n');
      client.close();
    });

    test('first/last 生成 Range: bytes=a-b；仅 first 生成 bytes=a-', () async {
      handler = (req) async {
        req.response.statusCode = 206;
        await req.response.addStream(
          Stream.fromIterable([
            [1, 2, 3],
          ]),
        );
      };
      final client = MediaHttpClient();
      await client.fetch('$base/a.m4s', first: 10, last: 19);
      await client.fetch('$base/a.m4s', first: 5);
      expect(seenRequests[0].headers.value('range'), 'bytes=10-19');
      expect(seenRequests[1].headers.value('range'), 'bytes=5-');
      client.close();
    });

    test('rangeHeader 原样透传', () async {
      handler = (req) {
        req.response.writeln('ok');
      };
      final client = MediaHttpClient();
      await client.fetch('$base/a.m4s', rangeHeader: 'bytes=-500');
      expect(seenRequests.single.headers.value('range'), 'bytes=-500');
      client.close();
    });

    test('回传上游状态码与关键响应头', () async {
      handler = (req) async {
        req.response.statusCode = 206;
        req.response.headers.set('content-type', 'video/mp4');
        req.response.headers.set('content-range', 'bytes 0-2/100');
        req.response.headers.set('accept-ranges', 'bytes');
        req.response.headers.set('etag', '"abc123"');
        await req.response.addStream(
          Stream.fromIterable([
            [1, 2, 3],
          ]),
        );
      };
      final client = MediaHttpClient();
      final resp = await client.fetch('$base/a.m4s');
      expect(resp.statusCode, 206);
      expect(resp.header('content-type'), 'video/mp4');
      expect(resp.header('content-range'), 'bytes 0-2/100');
      expect(resp.header('accept-ranges'), 'bytes');
      expect(resp.header('etag'), '"abc123"');
      expect(
        await resp.stream.fold<List<int>>([], (a, b) => a..addAll(b)),
        [1, 2, 3],
      );
      client.close();
    });

    test('响应按块流式到达，不整段缓冲', () async {
      // 256 KiB 与媒体分块同量级；极小块会命中 dart:io 客户端的合包优化
      const chunkSize = 256 * 1024;
      final firstChunkReceived = Completer<void>();
      handler = (req) async {
        req.response.headers.contentLength = chunkSize * 2;
        req.response.add(List.filled(chunkSize, 7));
        await req.response.flush();
        await firstChunkReceived.future; // 等接收方确认后再写第二块
        req.response.add(List.filled(chunkSize, 9));
      };
      final client = MediaHttpClient();
      final resp = await client.fetch('$base/a.m4s');
      var received = 0;
      // 超时兜底：若客户端整段缓冲，此处会快速失败而非挂死
      await for (final chunk in resp.stream.timeout(const Duration(seconds: 5))) {
        received += chunk.length;
        if (!firstChunkReceived.isCompleted) {
          // 第一块已送达播放器侧，而上游还没写第二块 —— 流式成立
          expect(received, chunkSize);
          firstChunkReceived.complete();
        }
      }
      expect(received, chunkSize * 2);
      client.close();
    });

    test('HEAD 请求无响应体', () async {
      handler = (req) {
        req.response.headers.set('content-length', '1024');
      };
      final client = MediaHttpClient();
      final resp = await client.fetch('$base/a.m4s', method: 'HEAD');
      expect(resp.statusCode, 200);
      expect(seenRequests.single.method, 'HEAD');
      expect((await resp.stream.toList()), isEmpty);
      client.close();
    });

    test('上游连接失败时抛出，不吞异常', () async {
      // 找一个确定没人监听的端口：先绑再关
      final doomed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = doomed.port;
      await doomed.close(force: true);
      final client = MediaHttpClient();
      await expectLater(
        client.fetch('http://127.0.0.1:$port/gone.m4s'),
        throwsA(anything),
      );
      client.close();
    });
  });
}
