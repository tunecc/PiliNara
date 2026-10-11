import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:PiliPlus/services/thread_ripper/contracts.dart';
import 'package:PiliPlus/services/thread_ripper/media_proxy_server.dart';
import 'package:PiliPlus/services/thread_ripper/media_transport_dio.dart';
import 'package:PiliPlus/services/thread_ripper/proxy_url.dart';
import 'package:PiliPlus/services/thread_ripper/scheduler.dart';
import 'package:PiliPlus/services/thread_ripper/session_registry.dart';
import 'package:PiliPlus/services/thread_ripper/thread_ripper_manager.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 端到端组合验证：真实回环代理 + 真实调度会话 + 本地 mock CDN。
/// 模拟播放器（mpv）对代理 URL 的原始 HTTP 请求路径。
///
/// 路径判别说明：透传只转发关键响应头，无法用自定义头区分两条路径；
/// 竞速策略由调度器单测覆盖。这里用行为判别：慢速 host A + 快速 host B，
/// 调度器参与时总耗时必然显著低于纯 A 透传。
void main() {
  const total = 1 << 20; // 1 MiB
  final counts = <String, int>{};

  int byteAt(int i) => (i * 31 + 7) % 251;

  Future<HttpServer> startFakeCdn(
    String tag, {
    Duration perChunkDelay = Duration.zero,
  }) async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((req) {
      counts[tag] = (counts[tag] ?? 0) + 1;
      const contentType = 'video/mp4';
      final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
      var first = 0;
      var last = total - 1;
      var status = 200;
      if (rangeHeader != null) {
        final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
        if (m != null) {
          first = int.parse(m.group(1)!);
          last = m.group(2)!.isEmpty ? total - 1 : int.parse(m.group(2)!);
          status = 206;
        }
      }
      req.response.statusCode = status;
      req.response.headers.set(HttpHeaders.contentTypeHeader, contentType);
      req.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      if (status == 206) {
        req.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $first-$last/$total',
        );
      }
      final length = last - first + 1;
      req.response.contentLength = length;
      // 以 64 KiB 分片写出，模拟真实 CDN 的流式行为
      unawaited(() async {
        for (var sent = 0; sent < length; sent += 64 * 1024) {
          final n = math.min(64 * 1024, length - sent);
          if (perChunkDelay != Duration.zero) {
            await Future<void>.delayed(perChunkDelay);
          }
          req.response.add([
            for (var i = 0; i < n; i++) byteAt(first + sent + i),
          ]);
        }
        await req.response.close();
      }());
    });
    return server;
  }

  Uri fakeCdnUri(HttpServer server, String path) =>
      Uri.parse('http://127.0.0.1:${server.port}/$path');

  setUpAll(() async {
    // Manager 用例需要 Pref（Hive）；其余用例不依赖
    final tempDir = await Directory.systemTemp.createTemp(
      'pili_thread_ripper_e2e',
    );
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('test_setting_tr_e2e');
  });
  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('test_setting_tr_e2e');
  });

  test('proxy + scheduler: fast second CDN wins, bytes exact', () async {
    // A：每 64 KiB 延迟 500ms（纯透传 1 MiB 约需 8s）；B：不限速
    final hostA = await startFakeCdn(
      'A',
      perChunkDelay: const Duration(milliseconds: 500),
    );
    final hostB = await startFakeCdn('B');
    final urlA = fakeCdnUri(hostA, 'seg.m4s');
    final urlB = fakeCdnUri(hostB, 'seg.m4s');

    final registry = SessionRegistry();
    final proxy = ThreadRipperProxy.forTesting(registry: registry);
    final session = ThreadRipperSession(transport: DioMediaTransport());
    proxy.accelerator = session;
    final port = (await proxy.start())!;
    addTearDown(() async {
      session.dispose();
      await proxy.close();
      await hostA.close(force: true);
      await hostB.close(force: true);
    });

    final descriptor = MediaDescriptor(
      originalUrl: urlA.toString(),
      candidates: [
        MediaCandidate(url: urlA.toString(), host: urlA.host),
        MediaCandidate(url: urlB.toString(), host: urlB.host),
      ],
      isAudio: false,
      totalSize: total,
      contentType: 'video/mp4',
    );
    final token = registry.register(descriptor);
    final proxyUrl = buildProxyUrl(port, descriptor, token);

    final client = HttpClient();
    addTearDown(client.close);
    const first = 100;
    const length = 99904;
    const last = first + length - 1;
    final watch = Stopwatch()..start();
    final request = await client.getUrl(Uri.parse(proxyUrl));
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$first-$last');
    final response = await request.close();

    expect(response.statusCode, 206);
    expect(
      response.headers.value(HttpHeaders.contentRangeHeader),
      'bytes $first-$last/$total',
    );
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    watch.stop();
    expect(bytes.length, length);
    for (var i = 0; i < length; i++) {
      if (bytes[i] != byteAt(first + i)) {
        fail('byte mismatch at offset ${first + i}');
      }
    }
    expect(response.headers.value(HttpHeaders.contentTypeHeader), 'video/mp4');
    // 调度器参与：快速 host B 被纳入，整体耗时应远低于纯 A 透传（约 8s）
    expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
  });

  test('manager: unknown total → first serve, probe learns, stays correct',
      () async {
    final hostA = await startFakeCdn('M');
    final urlA = fakeCdnUri(hostA, 'probe.m4s');
    addTearDown(() => hostA.close(force: true));

    Pref.enableThreadRipper = true;
    final manager = ThreadRipperManager.I;
    final proxy = ThreadRipperProxy.instance;
    manager
      ..beginVideo()
      ..warm();
    for (var i = 0; i < 100 && proxy.port == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(proxy.port, isNotNull);
    addTearDown(manager.endVideo);

    final proxyUrl = manager.rewritePlayable(
      candidateUrls: [urlA.toString()],
      isAudio: false,
      fallback: urlA.toString(),
    );
    expect(proxyUrl, isNotNull);

    final client = HttpClient();
    addTearDown(client.close);
    Future<List<int>> serve(int first, int last) async {
      final request = await client.getUrl(Uri.parse(proxyUrl!));
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$first-$last');
      final response = await request.close();
      expect(response.statusCode, 206);
      final body = <int>[];
      await for (final c in response) {
        body.addAll(c);
      }
      expect(body.length, last - first + 1);
      return body;
    }

    // 第一次：总大小未知（退直连/透传），答案必须正确
    final body1 = await serve(0, 99);
    for (var i = 0; i < 100; i++) {
      expect(body1[i], byteAt(i));
    }

    // 探测（bytes=0-0）学到总大小并回填注册表
    for (var i = 0;
        i < 150 && manager.totalFor(urlA.toString()) == null;
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(manager.totalFor(urlA.toString()), total);

    // 学到之后同一 URL 的请求仍然正确（此时已可加速）
    final body2 = await serve(0, 99);
    for (var i = 0; i < 100; i++) {
      expect(body2[i], byteAt(i));
    }
  });

  test('unknown token falls back to path URL pass-through', () async {
    final hostA = await startFakeCdn('A3');
    final urlA = fakeCdnUri(hostA, 'lost.m4s');

    final proxy = ThreadRipperProxy.forTesting();
    final port = (await proxy.start())!;
    addTearDown(() async {
      await proxy.close();
      await hostA.close(force: true);
    });

    final encoded =
        base64Url.encode(utf8.encode(urlA.toString())).replaceAll('=', '');
    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port/tr/$encoded/unknown0123'),
    );
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=10-19');
    final response = await request.close();
    expect(response.statusCode, 206);
    final body = <int>[];
    await for (final c in response) {
      body.addAll(c);
    }
    expect(body.length, 10);
    for (var i = 0; i < 10; i++) {
      expect(body[i], byteAt(10 + i));
    }
  });
}
