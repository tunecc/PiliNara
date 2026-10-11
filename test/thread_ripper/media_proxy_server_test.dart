import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/services/thread_ripper/contracts.dart';
import 'package:PiliPlus/services/thread_ripper/media_proxy_server.dart';
import 'package:PiliPlus/services/thread_ripper/proxy_url.dart';
import 'package:flutter_test/flutter_test.dart';

/// 恒返回固定 AcceleratedResponse 的假加速器。
class FakeAccelerator implements MediaAccelerator {
  FakeAccelerator(this.onServe);

  final AcceleratedResponse? Function(MediaDescriptor, RangeRequest) onServe;
  int calls = 0;

  @override
  AcceleratedResponse? serve(MediaDescriptor descriptor, RangeRequest range) {
    calls++;
    return onServe(descriptor, range);
  }
}

void main() {
  late HttpServer upstream;
  late String originBase;
  final seenUpstream = <HttpRequest>[];
  FutureOr<void> Function(HttpRequest) upstreamHandler = (req) {};
  late HttpClient testClient;

  setUp(() async {
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    originBase = 'http://127.0.0.1:${upstream.port}';
    seenUpstream.clear();
    upstreamHandler = (req) {};
    upstream.listen((req) async {
      seenUpstream.add(req);
      try {
        await upstreamHandler(req);
      } finally {
        await req.response.close().catchError((_) {});
      }
    });
    testClient = HttpClient()..autoUncompress = false;
  });

  tearDown(() async {
    testClient.close(force: true);
    await upstream.close(force: true);
  });

  Future<ThreadRipperProxy> startProxy([MediaAccelerator? accelerator]) async {
    final proxy = ThreadRipperProxy.forTesting()..accelerator = accelerator;
    final port = await proxy.start();
    expect(port, isNotNull, reason: '回环临时端口绑定不应失败');
    return proxy;
  }

  MediaDescriptor descriptorOf(String url, {int? totalSize}) =>
      MediaDescriptor(
        originalUrl: url,
        candidates: const [],
        isAudio: false,
        totalSize: totalSize,
      );

  /// 向代理发请求并排空响应体。
  Future<({int status, String? contentRange, List<int> body})> request(
    String proxyUrl, {
    String? range,
    String method = 'GET',
  }) async {
    final req = await testClient.openUrl(method, Uri.parse(proxyUrl));
    if (range != null) req.headers.set('range', range);
    final resp = await req.close().timeout(const Duration(seconds: 10));
    final contentRange = resp.headers.value('content-range');
    final body = await resp
        .fold<List<int>>([], (a, b) => a..addAll(b))
        .timeout(const Duration(seconds: 10));
    return (status: resp.statusCode, contentRange: contentRange, body: body);
  }

  group('端口绑定', () {
    test('start() 绑定 127.0.0.1 临时端口，幂等返回同端口', () async {
      final proxy = await startProxy();
      addTearDown(proxy.close);
      expect(proxy.port, greaterThan(0));
      expect(await proxy.start(), proxy.port);
    });

    test('绑定失败时 disabled=true，本次运行内永久禁用', () async {
      final occupied = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final proxy = ThreadRipperProxy.forTesting(bindPort: occupied.port);
      try {
        expect(await proxy.start(), isNull, reason: '端口被占用应绑定失败');
        expect(proxy.disabled, isTrue);
        expect(await proxy.start(), isNull, reason: 'disabled 后不得重试');
      } finally {
        await occupied.close(force: true);
        await proxy.close();
      }
    });

    test('close() 后端口不再接受连接', () async {
      final proxy = await startProxy();
      final port = proxy.port!;
      await proxy.close();
      final probe = HttpClient();
      try {
        await expectLater(
          probe.openUrl('GET', Uri.parse('http://127.0.0.1:$port/')),
          throwsA(anything),
        );
      } finally {
        probe.close(force: true);
      }
    });
  });

  group('请求分发', () {
    test('未知路径 404', () async {
      final proxy = await startProxy();
      addTearDown(proxy.close);
      final r = await request('http://127.0.0.1:${proxy.port}/whatever');
      expect(r.status, 404);
      expect(seenUpstream, isEmpty);
    });

    test('非法代理路径（坏 base64）404', () async {
      final proxy = await startProxy();
      addTearDown(proxy.close);
      final r = await request(
        'http://127.0.0.1:${proxy.port}/tr/!!/deadbeef',
        range: 'bytes=0-9',
      );
      expect(r.status, 404);
      expect(seenUpstream, isEmpty);
    });

    test('非 GET/HEAD 方法 405', () async {
      final proxy = await startProxy();
      addTearDown(proxy.close);
      final r = await request(
        'http://127.0.0.1:${proxy.port}/tr/aa/token',
        method: 'POST',
      );
      expect(r.status, 405);
      expect(seenUpstream, isEmpty);
    });

    test('无 Range 头的 GET 直接透传', () async {
      final proxy = await startProxy();
      addTearDown(proxy.close);
      upstreamHandler = (req) {
        req.response.headers.set('content-type', 'video/mp4');
        req.response.add(List.filled(64, 7));
      };
      final descriptor = descriptorOf('$originBase/video.m4s?e=abc');
      final token = proxy.registry.register(descriptor);
      final url = buildProxyUrl(proxy.port!, descriptor, token);
      final r = await request(url);
      expect(r.status, 200);
      expect(r.body, hasLength(64));
      expect(r.body.every((b) => b == 7), isTrue);
      expect(seenUpstream.single.uri.path, '/video.m4s');
      expect(seenUpstream.single.uri.query, 'e=abc');
      expect(seenUpstream.single.headers.value('range'), isNull);
    });

    test('HEAD 透传', () async {
      final proxy = await startProxy();
      addTearDown(proxy.close);
      upstreamHandler = (req) {
        req.response.headers.set('content-length', '4096');
      };
      final descriptor = descriptorOf('$originBase/video.m4s');
      final token = proxy.registry.register(descriptor);
      final url = buildProxyUrl(proxy.port!, descriptor, token);
      final r = await request(url, method: 'HEAD');
      expect(r.status, 200);
      expect(r.body, isEmpty);
      expect(seenUpstream.single.method, 'HEAD');
    });

    test('registry miss（token 未注册）透传，即便已注入 accelerator', () async {
      final accelerator = FakeAccelerator(
        (_, _) => AcceleratedResponse(
          first: 0,
          last: 9,
          total: 100,
          stream: Stream.value(List.filled(10, 1)),
        ),
      );
      final proxy = await startProxy(accelerator);
      addTearDown(proxy.close);
      upstreamHandler = (req) async {
        req.response.statusCode = 206;
        req.response.headers.set('content-range', 'bytes 100-199/1000');
        await req.response.addStream(
          Stream.fromIterable([List.filled(100, 3)]),
        );
      };
      final descriptor = descriptorOf('$originBase/video.m4s');
      final url = buildProxyUrl(proxy.port!, descriptor, 'not-registered');
      final r = await request(url, range: 'bytes=100-199');
      expect(r.status, 206);
      expect(r.contentRange, 'bytes 100-199/1000');
      expect(r.body, hasLength(100));
      expect(accelerator.calls, 0);
      expect(seenUpstream.single.headers.value('range'), 'bytes=100-199');
    });

    test('accelerator 返回 null 时透传原始 Range', () async {
      final accelerator = FakeAccelerator((_, _) => null);
      final proxy = await startProxy(accelerator);
      addTearDown(proxy.close);
      upstreamHandler = (req) async {
        req.response.statusCode = 206;
        req.response.headers.set('content-range', 'bytes 100-199/1000');
        req.response.headers.set('accept-ranges', 'bytes');
        await req.response.addStream(
          Stream.fromIterable([List.filled(100, 3)]),
        );
      };
      final descriptor = descriptorOf('$originBase/video.m4s');
      final token = proxy.registry.register(descriptor);
      final url = buildProxyUrl(proxy.port!, descriptor, token);
      final r = await request(url, range: 'bytes=100-199');
      expect(r.status, 206);
      expect(r.contentRange, 'bytes 100-199/1000');
      expect(r.body, hasLength(100));
      expect(accelerator.calls, 1);
      expect(seenUpstream.single.headers.value('range'), 'bytes=100-199');
    });

    test('accelerator 命中时按 AcceleratedResponse 回 206，不请求上游', () async {
      final accelerator = FakeAccelerator(
        (_, _) => AcceleratedResponse(
          first: 0,
          last: 255,
          total: 4096,
          stream: Stream.fromIterable([
            List.filled(128, 7),
            List.filled(128, 9),
          ]),
        ),
      );
      final proxy = await startProxy(accelerator);
      addTearDown(proxy.close);
      final descriptor = descriptorOf('$originBase/video.m4s', totalSize: 4096);
      final token = proxy.registry.register(descriptor);
      final url = buildProxyUrl(proxy.port!, descriptor, token);
      final r = await request(url, range: 'bytes=0-255');
      expect(r.status, 206);
      expect(r.contentRange, 'bytes 0-255/4096');
      expect(r.body, hasLength(256));
      expect(r.body.take(128).every((b) => b == 7), isTrue);
      expect(r.body.skip(128).every((b) => b == 9), isTrue);
      expect(accelerator.calls, 1);
      expect(seenUpstream, isEmpty, reason: '加速命中不得回源');
    });

    test('accelerator 抛异常时降级透传', () async {
      final accelerator = FakeAccelerator((_, _) => throw StateError('boom'));
      final proxy = await startProxy(accelerator);
      addTearDown(proxy.close);
      upstreamHandler = (req) async {
        req.response.statusCode = 206;
        req.response.headers.set('content-range', 'bytes 0-9/1000');
        await req.response.addStream(
          Stream.fromIterable([List.filled(10, 5)]),
        );
      };
      final descriptor = descriptorOf('$originBase/video.m4s');
      final token = proxy.registry.register(descriptor);
      final url = buildProxyUrl(proxy.port!, descriptor, token);
      final r = await request(url, range: 'bytes=0-9');
      expect(r.status, 206);
      expect(r.contentRange, 'bytes 0-9/1000');
      expect(r.body, hasLength(10));
      expect(seenUpstream, hasLength(1));
    });

    test('totalSize 已知且 Range 不可满足时回 416，不回源', () async {
      final accelerator = FakeAccelerator(
        (_, _) => AcceleratedResponse(
          first: 0,
          last: 0,
          total: 1,
          stream: Stream.value([1]),
        ),
      );
      final proxy = await startProxy(accelerator);
      addTearDown(proxy.close);
      final descriptor = descriptorOf('$originBase/video.m4s', totalSize: 1000);
      final token = proxy.registry.register(descriptor);
      final url = buildProxyUrl(proxy.port!, descriptor, token);
      final r = await request(url, range: 'bytes=1000-');
      expect(r.status, 416);
      expect(r.contentRange, 'bytes */1000');
      expect(r.body, isEmpty);
      expect(accelerator.calls, 0, reason: '416 应在 accelerator 之前短路');
      expect(seenUpstream, isEmpty);
    });

    test('透传是流式的（256 KiB 分块）', () async {
      final proxy = await startProxy();
      addTearDown(proxy.close);
      const chunkSize = 256 * 1024;
      final secondChunkWritten = Completer<void>();
      final firstChunkReceived = Completer<void>();
      upstreamHandler = (req) async {
        req.response.headers.contentLength = chunkSize * 2;
        req.response.add(List.filled(chunkSize, 7));
        await req.response.flush();
        await firstChunkReceived.future;
        req.response.add(List.filled(chunkSize, 9));
        secondChunkWritten.complete();
      };
      final descriptor = descriptorOf('$originBase/video.m4s');
      final token = proxy.registry.register(descriptor);
      final url = buildProxyUrl(proxy.port!, descriptor, token);
      final req = await testClient.openUrl('GET', Uri.parse(url));
      final resp = await req.close().timeout(const Duration(seconds: 10));
      var received = 0;
      await for (final chunk
          in resp.timeout(const Duration(seconds: 5))) {
        received += chunk.length;
        if (!firstChunkReceived.isCompleted) {
          expect(secondChunkWritten.isCompleted, isFalse);
          firstChunkReceived.complete();
        }
      }
      expect(received, chunkSize * 2);
    });

    test('上游不可达时代理最终回 502（兜底透传后仍失败）', () async {
      final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = dead.port;
      await dead.close(force: true);
      final accelerator = FakeAccelerator((_, _) => null);
      final proxy = await startProxy(accelerator);
      addTearDown(proxy.close);
      final descriptor = descriptorOf('http://127.0.0.1:$deadPort/video.m4s');
      final token = proxy.registry.register(descriptor);
      final url = buildProxyUrl(proxy.port!, descriptor, token);
      final r = await request(url, range: 'bytes=0-9');
      expect(r.status, 502);
    });
  });
}
