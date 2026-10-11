import 'dart:math' as math;
import 'dart:typed_data';

import 'package:PiliPlus/services/thread_ripper/contracts.dart';
import 'package:PiliPlus/services/thread_ripper/media_transport.dart';
import 'package:PiliPlus/services/thread_ripper/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClock {
  int now = 0;
}

String urlFor(String host) => 'https://$host/upgcxcode/v/f.m4s?e=1&upsig=s';

MediaDescriptor bigDescriptor() => MediaDescriptor(
      originalUrl: urlFor(hA),
      candidates: [MediaCandidate(url: urlFor(hA), host: hA)],
      isAudio: false,
      totalSize: 200 * 1024 * 1024,
    );

Future<void> settle([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

(ThreadRipperSession, FakeClock) sessionWith(MockMediaTransport transport) {
  final clock = FakeClock();
  final session = ThreadRipperSession(
    transport: transport,
    nowMs: () => clock.now,
    wallMs: () => 1000000000000,
    delay: (ms) async {},
    random: math.Random(1),
  );
  return (session, clock);
}

const hA = 'upos-sz-mirror0a.bilivideo.com';
const legBytes = 8 * 1024 * 1024;
const pieceBytes = legBytes ~/ 4;

/// 完成一棒的全部 piece：按实际请求范围响应/发射/关闭
Future<void> completeLeg(
  MockMediaTransport transport,
  int legStart,
  int legEnd,
) async {
  final pieces = transport.requests
      .where((r) =>
          r.request.start >= legStart &&
          r.request.end <= legEnd &&
          !r.headersResponded)
      .toList();
  for (final r in pieces) {
    final start = r.request.start;
    final end = r.request.end;
    r.respond(status: 206, contentRange: 'bytes $start-$end/209715200');
    for (var off = start; off <= end; off += 1024 * 1024) {
      final size = math.min(1024 * 1024, end - off + 1);
      r.emit(Uint8List(size));
    }
    r.close();
    await settle();
  }
}

void main() {
  test('A1: 开放末端请求首棒钳制为 8MiB', () async {
    final transport = MockMediaTransport();
    final (session, _) = sessionWith(transport);
    final response = session.serve(bigDescriptor(), const RangeRequest(first: 0))!;

    expect(response.first, 0);
    expect(response.last, 200 * 1024 * 1024 - 1, reason: 'Content-Range 报完整请求区间');
    await settle();

    final ranges = transport.requests
        .map((r) => '${r.request.start}-${r.request.end}')
        .toSet();
    expect(ranges, {
      '0-${pieceBytes - 1}',
      '$pieceBytes-${2 * pieceBytes - 1}',
      '${2 * pieceBytes}-${3 * pieceBytes - 1}',
      '${3 * pieceBytes}-${legBytes - 1}',
    });
  });

  test('A2: 消费驱动续棒——水位不足不预取，越过阈值自动续棒', () async {
    final transport = MockMediaTransport();
    final (session, _) = sessionWith(transport);
    final fileKey = urlFor(hA);
    final response = session.serve(bigDescriptor(), const RangeRequest(first: 0))!;

    final collected = <List<int>>[];
    final errors = <Object>[];
    var done = false;
    response.stream.listen(collected.add, onError: errors.add, onDone: () => done = true);

    // 完成第一棒（此时播放器消费水位 = 0）
    await settle();
    await completeLeg(transport, 0, legBytes - 1);
    await settle();

    var leg2Count = transport.requests
        .where((r) => r.request.start >= legBytes)
        .length;
    expect(leg2Count, 0, reason: '消费水位为 0 时不得预取下一棒');

    // 播放器消费推进到 4MiB：水位 + 4MiB 提前量达到第二棒起点
    session.noteConsumed(fileKey, 4 * 1024 * 1024);
    // ignore: avoid_print
    print('TEST after noteConsumed reqs=' + transport.requests.length.toString());
    for (var i = 0; i < 50 && leg2Count == 0; i++) {
      await Future<void>.delayed(Duration.zero);
      leg2Count = transport.requests
          .where((r) => r.request.start >= legBytes)
          .length;
    }
    // ignore: avoid_print
    print('TEST after poll reqs=' + transport.requests.length.toString());
    expect(leg2Count, greaterThan(0), reason: '水位越过阈值后续棒自动启动');

    // 完成第二棒（消费水位未再推进）→ 第三棒挂起
    await completeLeg(transport, legBytes, 2 * legBytes - 1);
    await settle();
    final leg3Count = transport.requests
        .where((r) => r.request.start >= 2 * legBytes)
        .length;
    expect(leg3Count, 0, reason: '消费未推进时第三棒保持挂起');
    session.noteConsumed(fileKey, 12 * 1024 * 1024);
    for (var i = 0; i < 50 && leg3Count == 0; i++) {
      await Future<void>.delayed(Duration.zero);
      final n = transport.requests
          .where((r) => r.request.start >= 2 * legBytes)
          .length;
      if (n > 0) break;
    }

    // 完成第三棒：流保持连续，累计长度 = 24MiB（三棒），且流未关闭（还有后续）
    await completeLeg(transport, 2 * legBytes, 3 * legBytes - 1);
    for (var i = 0; i < 100 && done; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    final length = collected.fold<int>(0, (sum, c) => sum + c.length);
    expect(length, 3 * legBytes, reason: '三棒字节连续无缺口');
    expect(errors, isEmpty);
    expect(done, isFalse, reason: '第四棒仍在等待消费，流保持打开');
  });
}
