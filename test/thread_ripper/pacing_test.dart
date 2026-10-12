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

(ThreadRipperSession, FakeClock) sessionWith(
  MockMediaTransport transport, {
  double? bandwidth,
  void Function(void Function() tick)? onTick,
}) {
  final clock = FakeClock();
  final session = ThreadRipperSession(
    transport: transport,
    nowMs: () => clock.now,
    wallMs: () => 1000000000000,
    requiredRateOf: bandwidth == null ? null : ((d) => bandwidth),
    onTickRegistered: onTick,
    delay: (ms) async {},
    random: math.Random(1),
  );
  return (session, clock);
}

const hA = 'upos-sz-mirror0a.bilivideo.com';
const legBytes = 8 * 1024 * 1024;
const pieceBytes = legBytes ~/ 4;

/// 像真实播放器那样推进：把本棒已发起的片全部补完，并按实际交付量上报
/// 消费水位（代理 onConsumed 的等价物），再等门控放行后续片。
/// 渐进启动下这一步只补得完「已放行」的片，所以调用方要循环调用直到
/// 目标区间全部发起。
/// [report] 为 false 时只补完不上报水位：模拟"下载完成但播放器没消费"
/// （暂停/seek 后），用于验证消费停滞时下一棒挂起。
Future<int> pumpConsumption(
  MockMediaTransport transport,
  ThreadRipperSession session,
  String fileKey,
  int legStart,
  int legEnd, {
  bool report = true,
}) async {
  var delivered = 0;
  for (var round = 0; round < 8; round++) {
    final pieces = transport.requests
        .where((r) =>
            r.request.start >= legStart &&
            r.request.end <= legEnd &&
            !r.headersResponded)
        .toList();
    if (pieces.isEmpty) {
      // 本轮没有待补的片：可能是门控还没放行（水位刚推进），等一个周期
      // 再看，不要就此判定"已全部完成"
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final waiting = transport.requests
          .where((r) =>
              r.request.start >= legStart &&
              r.request.end <= legEnd &&
              !r.headersResponded)
          .length;
      if (waiting == 0 && round > 0) {
        break;
      }
      continue;
    }
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
      delivered += end - start + 1;
      // 每片补完即上报：播放器是边下边播的，水位持续推进才放行后续片
      if (report) {
        session.noteConsumed(fileKey, legStart + delivered);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
  return delivered;
}

void main() {
  test('A1: 开放末端请求首棒钳制为 8MiB（渐进启动）', () async {
    final transport = MockMediaTransport();
    final (session, _) = sessionWith(transport);
    final response = session.serve(bigDescriptor(), const RangeRequest(first: 0))!;

    // Content-Range 报告完整请求区间
    expect(response.first, 0);
    expect(response.last, 200 * 1024 * 1024 - 1);

    // 渐进启动：片 0（start 0）与片 1（start 2MiB ≤ 水位0 + 2MiB margin）
    await settle();
    final ranges = transport.requests
        .map((r) => '${r.request.start}-${r.request.end}')
        .toSet();
    expect(ranges, {
      '0-${2 * 1024 * 1024 - 1}',
      '${2 * 1024 * 1024}-${4 * 1024 * 1024 - 1}',
    });
    // 片 0 优先：第一个发起的上游请求必须是片 0（起播首字节不与其他片竞争）
    expect(transport.requests.first.request.start, 0, reason: '首个上游请求是片 0');
    for (final r in transport.requests) {
      expect(r.request.end, lessThan(8 * 1024 * 1024), reason: '首棒钳制 8MiB');
    }
  });

  test('A2: 消费驱动续棒——水位不足不预取，越过阈值自动续棒', () async {
    final transport = MockMediaTransport();
    final (session, _) = sessionWith(transport);
    final fileKey = urlFor(hA);
    final response = session.serve(bigDescriptor(), const RangeRequest(first: 0))!;

    final collected = <List<int>>[];
    final errors = <Object>[];
    response.stream.listen(collected.add, onError: errors.add);
    int overLegCount() => transport.requests
        .where((r) => r.request.start >= legBytes)
        .length;
    int gateCount() => transport.requests
        .where((r) => r.request.start >= pieceBytes * 2)
        .length;

    // 门控：首棒已放行片 0、片 1（水位 0 + 2MiB margin），片 2/3 被挡下
    await settle();
    expect(gateCount(), 0, reason: '水位(0)未达片 2 起点(4MiB)时门控挡下其余片');
    expect(overLegCount(), 0, reason: '消费水位(0)未达第二棒起点(8MiB)时不得预取');

    // 片级判定的中间态：只补完片 0 并把水位推到 2MiB——片 2（4MiB ≤
    // 2+2）应放行而片 3（6MiB > 4）仍被挡。若门控退化为按 job 判定
    //（任一片越界即挡整个 job），片 3 会连带挡死片 2，渐进启动推不动
    transport.requests
        .firstWhere((r) => r.request.start == 0 && !r.headersResponded)
      ..respond(status: 206, contentRange: 'bytes 0-${pieceBytes - 1}/209715200')
      ..emit(Uint8List(pieceBytes))
      ..close();
    await settle();
    session.noteConsumed(fileKey, pieceBytes);
    for (var i = 0;
        i < 40 && transport.requests.where((r) => r.request.start == pieceBytes * 2).isEmpty;
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    expect(
      transport.requests.where((r) => r.request.start == pieceBytes * 2).length,
      greaterThan(0),
      reason: '水位 2MiB 时片 2（起点 4MiB ≤ 水位+2MiB）应放行',
    );
    expect(
      transport.requests.where((r) => r.request.start == pieceBytes * 3).length,
      0,
      reason: '水位 2MiB 时片 3（起点 6MiB > 水位+2MiB）仍被门控挡下',
    );

    // 像 mpv 那样播放：补完已放行的片并上报水位 → 门控逐片放行 → 首棒完成
    await pumpConsumption(transport, session, fileKey, 0, legBytes - 1);
    expect(gateCount(), greaterThan(0), reason: '水位推进后其余片放行');

    // 首棒完成且水位已达 8MiB → 续棒（消费驱动预取）
    for (var i = 0; i < 40 && overLegCount() == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    expect(overLegCount(), greaterThan(0), reason: '水位越过阈值后续棒自动启动');

    // 第二棒补完但不上报水位（下载完成而播放器未消费）→ 第三棒挂起，
    // 流保持打开（spec: 全部已启动片完成且消费仍未推进 → 流保持打开）
    await pumpConsumption(transport, session, fileKey, legBytes, 2 * legBytes - 1, report: false);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final over2 = transport.requests
        .where((r) => r.request.start >= 2 * legBytes)
        .length;
    expect(over2, 0, reason: '消费未推进时第三棒保持挂起');
    expect(errors, isEmpty, reason: '消费停滞不是错误：流保持打开等待消费');
    expect(collected.isNotEmpty, isTrue, reason: '已交付的字节确实下发到了播放器');
  });

  test('A3: 消费持续推进时逐棒连续交付 24MiB，末棒后流保持打开', () async {
    final transport = MockMediaTransport();
    final (session, _) = sessionWith(transport);
    final fileKey = urlFor(hA);
    final response = session.serve(bigDescriptor(), const RangeRequest(first: 0))!;

    final collected = <List<int>>[];
    final errors = <Object>[];
    var done = false;
    response.stream.listen(collected.add, onError: errors.add, onDone: () => done = true);
    await settle();

    // 三棒逐棒补完并上报水位（模拟 mpv 连续播放）
    for (var leg = 0; leg < 3; leg++) {
      final legStart = leg * legBytes;
      final legEnd = legStart + legBytes - 1;
      await pumpConsumption(transport, session, fileKey, legStart, legEnd);
      for (var i = 0;
          i < 40 && transport.requests.where((r) => r.request.start >= legEnd + 1).isEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }
    for (var i = 0; i < 100 && !done; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final length = collected.fold<int>(0, (sum, c) => sum + c.length);
    expect(length, 3 * legBytes, reason: '三棒字节连续无缺口');
    expect(errors, isEmpty);
    expect(done, isFalse, reason: '第四棒等待消费，流保持打开');
  });
}
