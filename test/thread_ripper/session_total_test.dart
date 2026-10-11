import 'package:PiliPlus/services/thread_ripper/contracts.dart';
import 'package:PiliPlus/services/thread_ripper/media_transport.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scheduler_test.dart';

/// 回归：_serve 在 descriptor.totalSize 为 null 时采纳会话学到的
/// _totals（预热/首个响应写入），让 DASH 预热过的清晰度直接命中。
void main() {
  test('knownTotal exposes the learned size after a completed job', () async {
    final transport = MockMediaTransport();
    final (session, _) = sessionWith(transport);
    const fileKey = 'https://upos-sz-mirror0a.bilivideo.com/upgcxcode/a.m4s';
    const descriptor = MediaDescriptor(
      originalUrl: fileKey,
      candidates: [MediaCandidate(url: fileKey, host: hA)],
      isAudio: false,
      totalSize: 1000,
    );

    final response = session.serve(descriptor, const RangeRequest(first: 0));
    expect(response, isNotNull);
    await settle();
    transport.requests.first.respond(contentRange: 'bytes 0-999/1000');
    await settle();
    transport.requests.first.emit(patternBytes(0, 1000));
    transport.requests.first.close();
    final received = <int>[];
    await for (final chunk in response!.stream) {
      received.addAll(chunk);
    }
    expect(received.length, 1000);
    expect(session.knownTotal(fileKey), 1000);
  });

  test('serve accepts a total-less descriptor once the size is learned',
      () async {
    final transport = MockMediaTransport();
    final (session, _) = sessionWith(transport);
    const fileKey = 'https://upos-sz-mirror0a.bilivideo.com/upgcxcode/b.m4s';

    // 预热路径：显式范围请求先学 total（构造 warmup 场景过于间接，
    // 这里直接用一个带 total 的 serve 完成学习）
    const warmDescriptor = MediaDescriptor(
      originalUrl: fileKey,
      candidates: [MediaCandidate(url: fileKey, host: hA)],
      isAudio: false,
      totalSize: 1000,
    );
    final warm = session.serve(warmDescriptor, const RangeRequest(first: 0));
    await settle();
    transport.requests.first.respond(contentRange: 'bytes 0-999/1000');
    await settle();
    transport.requests.first.emit(patternBytes(0, 1000));
    transport.requests.first.close();
    await warm!.stream.drain<void>();
    expect(session.knownTotal(fileKey), 1000);

    // 画质切换后的 descriptor 不带 totalSize（DASH 恒 null）
    const switched = MediaDescriptor(
      originalUrl: fileKey,
      candidates: [MediaCandidate(url: fileKey, host: hA)],
      isAudio: false,
      totalSize: null,
    );
    final response = session.serve(switched, const RangeRequest(first: 0));
    expect(
      response,
      isNotNull,
      reason: 'totalSize 为 null 但会话已学到 total 时应可加速',
    );
    await settle();
    // 新 job 的上游请求：RangeRequest(first: 0) 按 total=1000 解析为 0-999
    transport.requests.last.respond(contentRange: 'bytes 0-999/1000');
    await settle();
    transport.requests.last.emit(patternBytes(0, 1000));
    transport.requests.last.close();
    final received = <int>[];
    await for (final chunk in response!.stream) {
      received.addAll(chunk);
    }
    expect(received, patternBytes(0, 1000));
  });
}
