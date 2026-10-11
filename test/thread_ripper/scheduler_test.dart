import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:PiliPlus/services/thread_ripper/contracts.dart';
import 'package:PiliPlus/services/thread_ripper/host_model.dart';
import 'package:PiliPlus/services/thread_ripper/media_transport.dart';
import 'package:PiliPlus/services/thread_ripper/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClock {
  int now = 0;
}

String urlFor(String host) => 'https://$host/upgcxcode/v/f.m4s?e=1&upsig=s';

MediaDescriptor descriptor({
  List<String> hosts = const [hA],
  int total = 1000,
  bool isAudio = false,
}) {
  final listed = hosts.isEmpty ? const [hA] : hosts;
  return MediaDescriptor(
    originalUrl: urlFor(listed.first),
    candidates: [for (final h in listed) MediaCandidate(url: urlFor(h), host: h)],
    isAudio: isAudio,
    totalSize: total,
  );
}

/// Drives microtasks so launched attempts progress.
Future<void> settle([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

(ThreadRipperSession, FakeClock) sessionWith(
  MockMediaTransport transport, {
  double? bandwidth,
  int? indexEnd,
  void Function(void Function() tick)? onTick,
}) {
  final clock = FakeClock();
  final session = ThreadRipperSession(
    transport: transport,
    nowMs: () => clock.now,
    wallMs: () => 1000000000000, // signatures never expired
    requiredRateOf: bandwidth == null ? null : ((d) => bandwidth),
    indexEndOf: indexEnd == null ? null : ((d) => indexEnd),
    onTickRegistered: onTick,
    delay: (ms) async {},
    random: math.Random(1),
  );
  return (session, clock);
}

String hostOf(MockMediaRequest r) => Uri.parse(r.request.url).host;

MockMediaRequest requestFor(MockMediaTransport t, String host, int start, int end) =>
    t.requests.firstWhere((r) => hostOf(r) == host && r.request.start == start && r.request.end == end);

List<int> patternBytes(int from, int count) =>
    [for (var i = 0; i < count; i++) (from + i) % 251];

Future<(List<List<int>>, List<Object>, bool)> drain(Stream<List<int>> stream) async {
  final data = <List<int>>[];
  final errors = <Object>[];
  var done = false;
  final sub = stream.listen(data.add, onError: errors.add, onDone: () => done = true);
  for (var i = 0; i < 200 && !done && errors.isEmpty; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  await sub.cancel();
  return (data, errors, done);
}

const hA = 'upos-sz-mirror0a.bilivideo.com';
const hB = 'upos-sz-mirror0b.bilivideo.com';
const hC = 'upos-sz-mirror0c.bilivideo.com';

/// The unmeasured-host priors of the host model, bytes per ms.
const double priorRate = HostEstimateModel.priorRate; // 768 KiB/s

void main() {
  group('piece math (engine.ts formulas)', () {
    const splitEstimate = HostEstimate(ttfb: 200, rate: 5, eta: 200, measured: true, gap: null);

    test('a range needing less than two round trips is one piece', () {
      // 2 * rate * ttfb = 2 * 786.432 * 350 = 550502.4, within [128 KiB, 1 MiB]
      expect(pieceCount(1000, priorRate, 350, 4), 1);
      expect(pieceCount(550502, priorRate, 350, 4), 1);
      // the 128 KiB lower clamp binds when hosts are extremely fast
      expect(pieceCount(131071, 1, 1, 4), 1); // 2*1*1 clamps up to 128 KiB
      expect(pieceCount(300000, 1, 1, 4), 2); // split at 192 KiB pieces
    });

    test('pieces are about a second of transfer, clamped', () {
      // pieceSize = clamp(786.432 * clamp(4*350=1400, 600, 1500), 192 KiB, 4 MiB)
      //           = 1101004.8
      expect(pieceCount(2000000, priorRate, 350, 4), 2); // ceil(2000000/1101004.8)
      // before anything is measured one host may carry the piece alone:
      // at most piecesPerHost = 4 pieces
      expect(pieceCount(10 * 1024 * 1024, priorRate, 350, 1), 4); // ceil(9.5)=10 -> 4
      // many measured hosts: at most maxPieces = 16
      expect(pieceCount(10 * 1024 * 1024, priorRate, 350, 8), 10);
      // a fast host widens the piece instead
      // pieceSize = clamp(1000 * clamp(4000, 600, 1500) = 1500000) = 1500000
      expect(pieceCount(3 * 1024 * 1024, 1000, 1000, 8), 3); // ceil(3145728/1500000)
    });

    test('splitPoint: both halves finish together, null when too small', () {
      // r=2 bytes/ms, ttfb 200 ms, rate 5 bytes/ms:
      // m = ceil(2 * (200 + 1000000/5) / (1 + 2/5)) = ceil(400400 / 1.4) = 286000
      expect(splitPoint(Segment(0, 999999), 2, splitEstimate), 286000);
      // too small to cut: either half would fall under STEAL_MIN
      expect(splitPoint(Segment(0, 999), 1, splitEstimate), isNull);
      // no rate yet: nothing to cut by
      expect(splitPoint(Segment(0, 999999), 0, splitEstimate), isNull);
    });
  });

  group('serve() entry guards', () {
    test('no candidates, unknown size, unsatisfiable or oversized range go direct', () {
      final transport = MockMediaTransport();
      final (session, _) = sessionWith(transport);

      expect(
        session.serve(
          MediaDescriptor(originalUrl: urlFor(hA), candidates: const [], isAudio: false, totalSize: 1000),
          const RangeRequest(first: 0, last: 999),
        ),
        isNull,
      );
      expect(
        session.serve(
          MediaDescriptor(
            originalUrl: urlFor(hA),
            candidates: [MediaCandidate(url: urlFor(hA), host: hA)],
            isAudio: false,
          ),
          const RangeRequest(first: 0, last: 999),
        ),
        isNull,
      );
      // 超长有界请求不再整单拒绝：按 maxServedLength 钳制分棒（A6），
      // AcceleratedResponse 报告完整请求区间
      final big = descriptor(total: 64 * 1024 * 1024 + 1);
      final clamped = session.serve(big, const RangeRequest(first: 0, last: 64 * 1024 * 1024));
      expect(clamped, isNotNull);
      expect(clamped!.first, 0);
      expect(clamped.last, 64 * 1024 * 1024);
      final small = descriptor(total: 1000);
      expect(session.serve(small, const RangeRequest(first: 2000, last: 2999)), isNull);
      expect(session.serve(small, const RangeRequest(suffixLength: -1)), isNull);
      // 被钳制的超长请求已启动第一棒（4 片）；其余拒绝未触网
      expect(transport.openCalls, 4);
    });
  });

  group('job assembly', () {
    test('two pieces delivered by different hosts come out in order', () async {
      final transport = MockMediaTransport();
      final (session, _) = sessionWith(transport);
      const total = 2000000;
      final desc = descriptor(hosts: const [hA, hB], total: total);
      final response = session.serve(desc, const RangeRequest(first: 0, last: total - 1))!;

      final collected = <List<int>>[];
      final errors = <Object>[];
      var done = false;
      response.stream.listen(collected.add, onError: errors.add, onDone: () => done = true);
      await settle();

      // Unmeasured hosts: pieceCount's host count is 1 -> ceil(2000000 /
      // 1101004.8) = 2 pieces; no speculative duplicates (no bitrate known).
      expect(transport.requests.length, 2);
      final ranges = transport.requests.map((r) => '${r.request.start}-${r.request.end}').toSet();
      // segment formula: start + floor(length * i / count)
      expect(ranges, {'0-999999', '1000000-1999999'});

      final first = requestFor(transport, hA, 0, 999999);
      final second = requestFor(transport, hB, 1000000, 1999999);
      first.respond(status: 206, contentRange: 'bytes 0-999999/2000000');
      second.respond(status: 206, contentRange: 'bytes 1000000-1999999/2000000');
      await settle();

      // the later piece arrives first: the stream must not skip ahead
      second.emit(patternBytes(1000000, 1000000));
      await settle();
      second.close();
      await settle();
      expect(collected, isEmpty, reason: 'nothing before the first byte of the range');

      first.emit(patternBytes(0, 1000000));
      await settle();
      first.close();
      await settle();

      expect(errors, isEmpty);
      expect(done, isTrue);
      final flat = [for (final c in collected) ...c];
      expect(flat, patternBytes(0, 2000000));
    });
  });

  group('region/family tiers', () {
    test('family/host mismatch ranks foreign (A5)', () {
      // upos 签名在 Akamai 主机：必 403，最后才尝试
      final candidate = ResolvedCandidate(const MediaCandidate(
        url: 'https://upos-hz-mirrorakam.akamaized.net/upgcxcode/v/f.m4s?e=1&upsig=s',
        host: 'upos-hz-mirrorakam.akamaized.net',
      ));
      expect(candidate.p2p, isFalse);
      expect(candidate.tier, CandidateTier.foreign);
    });

    test('matching family keeps the mirror tier', () {
      final candidate = ResolvedCandidate(MediaCandidate(
        url: 'https://upos-hz-mirrorakam.akamaized.net/upgcxcode/v/f.m4s?e=1&hdnts=exp=9999999999~a~b',
        host: 'upos-hz-mirrorakam.akamaized.net',
      ));
      expect(candidate.tier, CandidateTier.listedMirror);
    });
  });

  group('open-ended range takeover', () {
    test('oversized open-ended requests are clamped to 8MiB legs and chained by consumption (A6)', () async {
      final transport = MockMediaTransport();
      final (session, _) = sessionWith(transport);
      const leg = 8 * 1024 * 1024;
      final total = leg + 1024 * 1024; // 两棒：8MiB + 1MiB
      final desc = descriptor(hosts: const [hA], total: total);
      final response = session.serve(desc, const RangeRequest(first: 0))!;

      // Content-Range 报告完整请求区间
      expect(response.first, 0);
      expect(response.last, total - 1);
      expect(response.total, total);

      final collected = <List<int>>[];
      final errors = <Object>[];
      var done = false;
      response.stream.listen(collected.add, onError: errors.add, onDone: () => done = true);
      await settle();

      // 第一棒：单主机 4 片覆盖 [0, leg-1]
      final leg1 = transport.requests
          .map((r) => '${r.request.start}-${r.request.end}')
          .toSet();
      expect(leg1, {
        '0-${leg ~/ 4 - 1}',
        '${leg ~/ 4}-${leg ~/ 2 - 1}',
        '${leg ~/ 2}-${3 * leg ~/ 4 - 1}',
        '${3 * leg ~/ 4}-${leg - 1}',
      });

      // 逐片响应并按 1MiB 块发射（内容为 0，长度/顺序即契约）
      for (final r in transport.requests.toList()) {
        r.respond(status: 206, contentRange: 'bytes ${r.request.start}-${r.request.end}/$total');
        for (var off = r.request.start; off <= r.request.end; off += 1024 * 1024) {
          final size = math.min(1024 * 1024, r.request.end - off + 1);
          r.emit(Uint8List(size));
        }
        r.close();
        await settle();
      }

      // 第一棒完成；消费水位为 0 → 下一棒挂起（消费驱动预取）
      expect(
        transport.requests.where((r) => r.request.start >= leg).length,
        0,
        reason: '消费水位为 0 时不得预取下一棒',
      );

      // 播放器消费推进到 4MiB：水位 + 4MiB 提前量达到第二棒起点 → 续棒
      session.noteConsumed(desc.originalUrl, 4 * 1024 * 1024);
      for (var i = 0;
          i < 200 &&
              transport.requests
                  .where((r) => r.request.start >= leg)
                  .isEmpty;
          i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final leg2 = transport.requests
          .map((r) => '${r.request.start}-${r.request.end}')
          .where((s) => s.startsWith('$leg-'))
          .toSet();
      expect(leg2, {'$leg-${total - 1}'});

      final leg2Request = requestFor(transport, hA, leg, total - 1);
      leg2Request.respond(status: 206, contentRange: 'bytes $leg-${total - 1}/$total');
      leg2Request.emit(Uint8List(total - leg));
      leg2Request.close();
      for (var i = 0; i < 200 && !done; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(errors, isEmpty, reason: 'errors=' + errors.toString());
      expect(done, isTrue);
      final length = collected.fold<int>(0, (sum, c) => sum + c.length);
      expect(length, total, reason: '两棒字节必须连续覆盖整个请求区间');
    });

    test('draining an invalid response is capped (A7)', () async {
      var cancelled = false;
      final controller = StreamController<List<int>>(
        onCancel: () async {
          cancelled = true;
        },
      );
      var consumed = 0;
      final counted = controller.stream.map((chunk) {
        consumed += chunk.length;
        return chunk;
      });
      final response = MediaUpstreamResponse(
        statusCode: 200,
        finalUrl: 'https://upos-sz-mirror0a.bilivideo.com/upgcxcode/v/f.m4s?e=1&upsig=s',
        redirected: false,
        headers: const {},
        body: counted,
      );

      ThreadRipperSession.discardBody(response);
      controller.add(Uint8List(1024 * 1024));
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isFalse, reason: '第一块在限额内正常消费');
      controller.add(Uint8List(1024 * 1024));
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue, reason: '第二块越限，排水在此取消');
      final consumedAtCancel = consumed;
      controller.add(Uint8List(1024 * 1024));
      await Future<void>.delayed(Duration.zero);
      expect(consumed, consumedAtCancel, reason: '取消后不再消费');
      await controller.close();
    });
  });

  group('job assembly', () {
    test('a range starting above zero streams its own bytes', () async {
      final transport = MockMediaTransport();
      final (session, _) = sessionWith(transport);
      final desc = descriptor(hosts: const [hA], total: 3000);
      final response = session.serve(desc, const RangeRequest(first: 1000, last: 2999))!;
      await settle();
      expect(transport.openCalls, 1); // single host: no racer available
      requestFor(transport, hA, 1000, 2999)
        ..respond(status: 206, contentRange: 'bytes 1000-2999/3000')
        ..emit(patternBytes(1000, 2000))
        ..close();
      await settle();
      final (data, errors, done) = await drain(response.stream);
      expect(errors, isEmpty);
      expect(done, isTrue);
      final flat = [for (final c in data) ...c];
      expect(flat, patternBytes(1000, 2000));
    });
  });

  group('concurrency caps', () {
    test('global cap 32 and per-host cap 6 are never exceeded', () async {
      final transport = MockMediaTransport();
      final hosts = [hA, hB, hC, 'upos-sz-mirror0d.bilivideo.com', 'upos-sz-mirror0e.bilivideo.com', 'upos-sz-mirror0f.bilivideo.com', 'upos-sz-mirror0g.bilivideo.com', 'upos-sz-mirror0h.bilivideo.com'];
      final (session, _) = sessionWith(transport);

      final desc = descriptor(hosts: hosts, total: 16 * 1000);

      // Sixteen small ranges of the same file: each is one piece, raced by 2
      // (urgent width) -> 32 attempts wanted, capped at GLOBAL_CAP.
      for (var i = 0; i < 16; i++) {
        session.serve(desc, RangeRequest(first: i * 1000, last: i * 1000 + 999))!;
        await settle();
      }

      expect(transport.openCalls, 32); // GLOBAL_CAP
      for (final host in hosts) {
        expect(transport.requestsFrom(host).length, lessThanOrEqualTo(6)); // HOST_CAP
      }
    });
  });

  group('retries', () {
    test('a piece fails at most MAX_TRIES times, then the job gives up', () async {
      final transport = MockMediaTransport();
      final (session, _) = sessionWith(transport);
      final desc = descriptor(total: 2000);

      final response = session.serve(desc, const RangeRequest(first: 0, last: 999))!;
      await settle();
      while (transport.openCalls < maxTries) {
        transport.requests.last.failHeaders();
        await settle();
      }
      expect(transport.openCalls, maxTries);

      final errors = <Object>[];
      final data = <List<int>>[];
      var done = false;
      response.stream.listen(data.add, onError: errors.add, onDone: () => done = true);
      transport.requests.last.failHeaders();
      await settle();

      expect(done, isTrue);
      expect(errors, isNotEmpty);
      expect(data, isEmpty);
      // the failed range goes direct for a while...
      expect(session.serve(desc, const RangeRequest(first: 0, last: 999)), isNull);
      // ...another range of the same file is still accelerated
      expect(session.serve(desc, const RangeRequest(first: 1000, last: 1999)), isNotNull);
    });

    test('three failed jobs within a minute turn the session off for 30 s', () async {
      final transport = MockMediaTransport();
      final (session, clock) = sessionWith(transport);
      final desc = descriptor(total: 4000);

      for (var job = 0; job < 3; job++) {
        final response = session.serve(desc, RangeRequest(first: job * 1000, last: job * 1000 + 999))!;
        await settle();
        while (transport.openCalls < maxTries * (job + 1)) {
          transport.requests.last.failHeaders();
          await settle();
        }
        transport.requests.last.failHeaders();
        await settle();
        final errors = <Object>[];
        response.stream.listen((_) {}, onError: errors.add);
        await settle();
        expect(errors, isNotEmpty, reason: 'job $job failed');
      }

      // off until now + 30 s: a healthy range is refused too
      expect(session.serve(desc, const RangeRequest(first: 3000, last: 3999)), isNull);
      clock.now += 30 * 1000;
      expect(session.serve(desc, const RangeRequest(first: 3000, last: 3999)), isNotNull);
    });
  });

  group('racing (stuck pieces)', () {
    test('a stuck request gets a racer on a host not already on the piece', () async {
      final transport = MockMediaTransport();
      void Function()? tick;
      final (session, clock) = sessionWith(transport, onTick: (cb) => tick = cb);
      final desc = descriptor(hosts: const [hA, hB, hC]);
      session.serve(desc, const RangeRequest(first: 0, last: 999))!;
      await settle();
      // primary on mirror0a, racer (urgent width 2) on mirror0b
      expect(transport.requestsFrom(hA).length, 1);
      expect(transport.requestsFrom(hB).length, 1);
      final before = transport.openCalls;

      // ttfbSoft = clamp(2 * (350 * 2 cold), 250, 1200) = 1200; the urgent
      // factor 0.85 puts the threshold at 1020 ms.
      clock.now = 1100;
      tick!();
      await settle();

      expect(transport.openCalls, before + 1);
      expect(transport.requestsFrom(hC).length, 1);
      // the stuck piece got no second racer on the hosts it already occupies
      expect(transport.requestsFrom(hA).length, 1);
      expect(transport.requestsFrom(hB).length, 1);
    });
  });

  group('warm-up', () {
    test('at most WARMUP_CAP warm-ups run at once; the rest queue', () async {
      final transport = MockMediaTransport();
      final (session, _) = sessionWith(transport);
      final specs = [
        for (var i = 0; i < 5; i++)
          PreloadSpec(
            key: urlFor('upos-sz-mirror0$i.bilivideo.com'),
            descriptor: descriptor(hosts: ['upos-sz-mirror0$i.bilivideo.com'], total: 1000),
            indexEnd: 999,
          ),
      ];

      session.warmUp(specs);
      await settle();
      expect(transport.openCalls, 4); // WARMUP_CAP

      // one finishes; the queued fifth starts
      transport.requests.first
        ..respond(status: 206, contentRange: 'bytes 0-999/1000')
        ..emit(patternBytes(0, 1000))
        ..close();
      await settle();
      expect(transport.openCalls, 5);
    });

    test('pending warm-ups are capped at MAX_PENDING_WARMUPS, oldest dropped', () async {
      final transport = MockMediaTransport();
      final (session, _) = sessionWith(transport);
      final specs = [
        for (var i = 0; i < 20; i++)
          PreloadSpec(
            key: urlFor('upos-sz-mirror0$i.bilivideo.com'),
            descriptor: descriptor(hosts: ['upos-sz-mirror0$i.bilivideo.com'], total: 1000),
            indexEnd: 999,
          ),
      ];
      session.registerPreload(specs);
      expect(session.pendingPreloadCount, 16);

      // the player asks for the video: same-kind preloads warm up (4 in
      // flight), and none of the dropped (oldest four) specs is among them
      session.serve(descriptor(hosts: const [hA], total: 1000), const RangeRequest(first: 0, last: 999));
      await settle();
      final warmedHosts = transport.requests.map(hostOf).toSet();
      final dropped = {'upos-sz-mirror00.bilivideo.com', 'upos-sz-mirror01.bilivideo.com', 'upos-sz-mirror02.bilivideo.com', 'upos-sz-mirror03.bilivideo.com'};
      expect(warmedHosts.intersection(dropped), isEmpty);
    });

    test('a player range inside a finished warm-up is served from it', () async {
      final transport = MockMediaTransport();
      final (session, _) = sessionWith(transport);
      final desc = descriptor(hosts: const [hA], total: 1000);
      session.warmUp([PreloadSpec(key: urlFor(hA), descriptor: desc, indexEnd: 999)]);
      await settle();

      requestFor(transport, hA, 0, 999)
        ..respond(status: 206, contentRange: 'bytes 0-999/1000')
        ..emit(patternBytes(0, 1000))
        ..close();
      await settle();

      final openBefore = transport.openCalls;
      final response = session.serve(desc, const RangeRequest(first: 0, last: 999))!;
      final (data, errors, done) = await drain(response.stream);
      expect(errors, isEmpty);
      expect(done, isTrue);
      final flat = [for (final c in data) ...c];
      expect(flat, patternBytes(0, 1000));
      expect(transport.openCalls, openBefore, reason: 'served from the warm-up, no new fetch');
    });
  });

  group('hedge bookkeeping (mayDuplicate)', () {
    void deliver(Job job, int covered, List<(int, int)> samples) {
      job.covered = covered;
      job.meter
        ..clear()
        ..addAll(samples);
    }

    Job jobWith(double requiredRate) {
      final rc = ResolvedCandidate(MediaCandidate(url: urlFor(hA), host: hA));
      return Job(
        fileKey: 'f',
        range: (first: 0, last: 999),
        cls: urgent,
        createdAt: 0,
        requiredRate: requiredRate,
        length: 1000,
        candidates: {},
        requested: rc,
        descriptor: MediaDescriptor(originalUrl: urlFor(hA), candidates: [MediaCandidate(url: urlFor(hA), host: hA)], isAudio: false),
      );
    }

    test('no duplicates at 8x the required rate, in the cooldown window, or once saturated', () {
      final job = jobWith(10); // 8x = 80 bytes per ms

      // nothing delivered yet
      expect(mayDuplicate(job, 100), isTrue);

      // delivering 100 bytes/ms >= 8 * 10: no duplicate
      deliver(job, 40000, [(0, 0), (400, 40000)]);
      expect(mayDuplicate(job, 400), isFalse);

      // a duplicate within RATE_WINDOW_MS of the last one waits
      final job2 = jobWith(10);
      deliver(job2, 50000, [(0, 0), (400, 40000), (900, 50000)]);
      job2.lastDuplicate = (400, 10.0);
      expect(mayDuplicate(job2, 500), isFalse); // 500 < 400 + 500
      expect(mayDuplicate(job2, 950), isTrue); // past the window, rate rose

      // a duplicate that raised nothing latches the line as full
      final job3 = jobWith(10);
      deliver(job3, 900, [(0, 0), (500, 900)]);
      job3.lastDuplicate = (0, 100.0);
      expect(mayDuplicate(job3, 500), isFalse);
      expect(job3.saturated, isTrue);
      expect(mayDuplicate(job3, 5000), isFalse, reason: 'saturated latches for the job');
    });
  });

  group('writeChunk byte-level cross-check', () {
    (Job, Attempt, Attempt) makeFixture() {
      final rc = ResolvedCandidate(MediaCandidate(url: urlFor(hA), host: hA));
      final job = Job(
        fileKey: 'f',
        range: (first: 0, last: 199),
        cls: urgent,
        createdAt: 0,
        requiredRate: 0,
        length: 200,
        candidates: {},
        requested: rc,
        descriptor: MediaDescriptor(originalUrl: urlFor(hA), candidates: [MediaCandidate(url: urlFor(hA), host: hA)], isAudio: false),
      );
      final seg = Segment(0, 199);
      job.segments.add(seg);
      Attempt make(String host, String role) => Attempt(
            job: job,
            seg: seg,
            hostname: host,
            candidate: rc,
            role: role,
            controller: MediaAbortHandle(),
            ttfbSoft: 500,
            stallSoft: 600,
            startedAt: 0,
            probe: false,
          );
      return (job, make(hA, 'primary'), make('h2', 'dup'));
    }

    test('fresh bytes are written and the frontier moves', () {
      final (job, att, _) = makeFixture();
      expect(ThreadRipperSession.writeChunk(job, att, patternBytes(0, 100), 10), WriteVerdict.ok);
      expect(job.covered, 100);
      expect(att.seg.frontier, 100);
      expect(att.pos, 100);
      expect(job.bytes.sublist(0, 100), patternBytes(0, 100));
    });

    test('overlapping identical bytes compare clean and write nothing', () {
      final (job, att, other) = makeFixture();
      ThreadRipperSession.writeChunk(job, att, patternBytes(0, 100), 10);
      expect(ThreadRipperSession.writeChunk(job, other, patternBytes(0, 100), 11), WriteVerdict.ok);
      expect(job.covered, 100, reason: 'no double count');
      expect(other.pos, 100);
    });

    test('overlapping conflicting bytes are a mismatch', () {
      final (job, att, other) = makeFixture();
      ThreadRipperSession.writeChunk(job, att, patternBytes(0, 100), 10);
      final conflicting = patternBytes(0, 100);
      conflicting[50] = (conflicting[50] + 1) % 251;
      expect(ThreadRipperSession.writeChunk(job, other, conflicting, 11), WriteVerdict.mismatch);
    });

    test('a chunk straddling the frontier duplicates below and writes above', () {
      final (job, att, _) = makeFixture();
      ThreadRipperSession.writeChunk(job, att, patternBytes(0, 50), 10);
      // the attempt is at pos 50; its next chunk covers 50..149, of which
      // 50..99 sit below the frontier (compared) and 100..149 are fresh
      expect(ThreadRipperSession.writeChunk(job, att, patternBytes(50, 100), 20), WriteVerdict.ok);
      expect(job.covered, 150);
      expect(job.bytes.sublist(100, 150), patternBytes(100, 50));
    });

    test('past the piece end the attempt overruns; a long chunk writes its usable part', () {
      final (job, att, other) = makeFixture();
      ThreadRipperSession.writeChunk(job, att, patternBytes(0, 200), 10);
      expect(att.pos, 200);
      expect(ThreadRipperSession.writeChunk(job, att, patternBytes(200, 10), 20), WriteVerdict.overrun);
      // another attempt delivering a chunk that reaches past seg.end: writes
      // up to the end, reports overrun
      expect(ThreadRipperSession.writeChunk(job, other, patternBytes(0, 260), 30), WriteVerdict.overrun);
      expect(job.covered, 200);
    });
  });

  group('mismatch disables the session', () {
    test('conflicting bytes abort the response and flip the session to direct', () async {
      final transport = MockMediaTransport();
      final (session, _) = sessionWith(transport);
      final desc = descriptor(hosts: const [hA, hB], total: 100);
      final response = session.serve(desc, const RangeRequest(first: 0, last: 99))!;
      await settle();

      final a = requestFor(transport, hA, 0, 99);
      final b = requestFor(transport, hB, 0, 99);
      a.respond(status: 206, contentRange: 'bytes 0-99/100');
      b.respond(status: 206, contentRange: 'bytes 0-99/100');
      await settle();

      // the primary delivers half the piece; the racer is still on it
      a.emit(patternBytes(0, 50));
      await settle();

      final conflicting = patternBytes(0, 100);
      conflicting[30] = (conflicting[30] + 1) % 251; // inside the overlap
      b.emit(conflicting);
      await settle();

      final (data, errors, done) = await drain(response.stream);
      expect(data, isNotEmpty, reason: 'the valid bytes had been emitted');
      expect(errors, isNotEmpty, reason: 'the accelerated output is aborted');
      expect(done, isTrue);

      // every further request of this video goes direct
      expect(session.serve(desc, const RangeRequest(first: 0, last: 99)), isNull);
      expect(transport.openCalls, 2, reason: 'no more upstream attempts after the mismatch');
    });

    test('identical bytes from both hosts assemble exactly once', () async {
      final transport = MockMediaTransport();
      final (session, _) = sessionWith(transport);
      final desc = descriptor(hosts: const [hA, hB], total: 100);
      final response = session.serve(desc, const RangeRequest(first: 0, last: 99))!;
      await settle();
      for (final r in transport.requests) {
        r.respond(status: 206, contentRange: 'bytes 0-99/100');
      }
      await settle();
      transport.requests.first.emit(patternBytes(0, 100));
      transport.requests.last.emit(patternBytes(0, 100));
      await settle();
      transport.requests.first.close();
      transport.requests.last.close();
      await settle();

      final (data, errors, done) = await drain(response.stream);
      expect(errors, isEmpty);
      expect(done, isTrue);
      final flat = [for (final c in data) ...c];
      expect(flat, patternBytes(0, 100), reason: 'each byte exactly once, in order');
      // session is still healthy
      expect(session.serve(desc, const RangeRequest(first: 0, last: 99)), isNotNull);
    });
  });
}
