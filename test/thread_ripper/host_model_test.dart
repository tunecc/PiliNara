import 'package:PiliPlus/services/thread_ripper/classify.dart' show SignatureFamily;
import 'package:PiliPlus/services/thread_ripper/host_model.dart';
import 'package:PiliPlus/services/thread_ripper/outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fake clock: performance.now() ms.
  var now = 100000;
  late HostEstimateModel model;

  setUp(() {
    now = 100000;
    model = HostEstimateModel(nowMs: () => now);
  });

  MediaOutcome record(
    MediaOutcome outcome, {
    String hostname = 'a.bilivideo.com',
    String fileKey = 'file1',
    String addressKey = '/a?sig=1',
    SignatureFamily family = SignatureFamily.upos,
    bool alive = false,
    int? at,
  }) {
    model.recordOutcome(
      hostname,
      fileKey,
      addressKey: addressKey,
      family: family,
      outcome: outcome,
      now: at ?? now,
      alive: alive,
    );
    return outcome;
  }

  group('priors and estimation', () {
    test('unmeasured host gets the priors, ttfb doubled while cold', () {
      final e = model.estimate('h1', 'file1', 1000);
      expect(e.rate, HostEstimateModel.priorRate);
      expect(e.measured, isFalse);
      // priorTtfb 350, cold (never used) -> x2
      expect(e.ttfb, 700);
      expect(e.eta, 700 + 1000 / HostEstimateModel.priorRate);
      expect(e.gap, isNull);
    });

    test('recorded samples make a host measured; ttfb doubles only while cold', () {
      model.recordSpeed('h1', 'file1', ttfb: 120, rate: 100, partial: false, gap: 40);
      final warm = model.estimate('h1', 'file1', 1000);
      expect(warm.measured, isTrue);
      expect(warm.rate, 100);
      // never used yet (recordSpeed alone does not warm the connection record)
      expect(warm.ttfb, 240);
      expect(warm.gap, 40);

      now += 1000;
      record(MediaOutcome.ok, hostname: 'h1', fileKey: 'file1');
      final used = model.estimate('h1', 'file1', 1000);
      expect(used.ttfb, 120);
      expect(used.eta, 120 + 1000 / 100);
    });

    test('rate falls back to typical when the host only has a ttfb', () {
      model.recordSpeed('h1', 'file1', ttfb: 100, rate: null, partial: false, gap: null);
      final e = model.estimate('h1', 'file1', 0);
      expect(e.measured, isFalse);
      expect(e.rate, HostEstimateModel.priorRate);
    });

    test('robust median: latest two suddenly 2x worse replace the median', () {
      for (final ttfb in [50.0, 50.0, 50.0, 150.0, 160.0]) {
        model.recordSpeed('h1', 'file1', ttfb: ttfb, rate: null, partial: false, gap: null);
      }
      final e = model.estimate('h1', 'file1', 0);
      // median 50, latest(160) and previous(150) both > 100 -> min = 150
      expect(e.ttfb, 300); // 150 * 2 (still cold)
    });

    test('robust median: latest two suddenly 2x better replace the median (rate)', () {
      for (final rate in [100.0, 100.0, 100.0, 20.0, 10.0]) {
        model.recordSpeed('h1', 'file1', ttfb: null, rate: rate, partial: false, gap: null);
      }
      final e = model.estimate('h1', 'file1', 0);
      // median 100, latest(10) and previous(20) both < 50 -> max = 20
      expect(e.rate, 20);
    });

    test('partial rates are absorbed only until a full transfer is known', () {
      model.recordSpeed('h1', 'file1', ttfb: null, rate: 10, partial: true, gap: null);
      // no full sample yet: the partial is all we have
      expect(model.estimate('h1', 'file1', 0).rate, 10);
      model
        ..recordSpeed('h1', 'file1', ttfb: null, rate: 100, partial: false, gap: null)
        ..recordSpeed('h1', 'file1', ttfb: null, rate: 7, partial: true, gap: null)
        ..recordSpeed('h1', 'file1', ttfb: null, rate: 100, partial: false, gap: null);
      // rate samples [10, 100, 100] -> median 100; the partial 7 never entered
      expect(model.estimate('h1', 'file1', 0).rate, 100);
    });

    test('at most SAMPLES=8 samples are kept, newest last', () {
      for (var i = 1; i <= 10; i++) {
        model.recordSpeed('h1', 'file1', ttfb: null, rate: i.toDouble(), partial: false, gap: null);
      }
      // median of [3..10] = p50 over 8 -> k=ceil(4)=4th smallest = 6
      expect(model.estimate('h1', 'file1', 0).rate, 6);
    });

    test('typicalSpeed: median over measured hosts, else priors', () {
      var typical = model.typicalSpeed('file1');
      expect(typical.ttfb, HostEstimateModel.priorTtfb);
      expect(typical.rate, HostEstimateModel.priorRate);

      model
        ..recordSpeed('h1', 'file1', ttfb: 100, rate: 100, partial: false, gap: null)
        ..recordSpeed('h2', 'file1', ttfb: 300, rate: 300, partial: false, gap: null);
      typical = model.typicalSpeed('file1');
      // nearest-rank p50 of [100, 300]: k = ceil(1) = 1 -> the smaller
      expect(typical.ttfb, 100);
      expect(typical.rate, 100);
    });

    test('speeds are per video (file key) and never leak across files', () {
      model.recordSpeed('h1', 'file1', ttfb: 100, rate: 100, partial: false, gap: null);
      final other = model.typicalSpeed('file2');
      expect(other.rate, HostEstimateModel.priorRate);
      expect(model.estimate('h1', 'file2', 0).measured, isFalse);
    });
  });

  group('recordOutcome reliability bookkeeping', () {
    test('ok: resets streak, proves the address and the family', () {
      record(MediaOutcome.throttled, hostname: 'h1');
      record(MediaOutcome.throttled, hostname: 'h1');
      record(MediaOutcome.ok, hostname: 'h1', addressKey: '/a?sig=1');
      // cooldown cleared by a new ok? upstream keeps cooldownUntil, but the
      // streak resets: a fresh failure starts at its base duration again.
      now += 5000; // past the 2000ms cooldown anyway
      record(MediaOutcome.throttled, hostname: 'h1');
      expect(model.isCoolingDown('h1', now + 2000), isFalse);
      expect(model.provenAddress('h1'), '/a?sig=1');
      expect(model.acceptsFamily('h1', SignatureFamily.upos), isTrue);
      expect(model.isAddressBanned('/a?sig=1'), isFalse);
    });

    test('throttled backoff: 2000 * 2^min(streak, 3)', () {
      record(MediaOutcome.throttled, hostname: 'h1');
      expect(model.isCoolingDown('h1', now + 1999), isTrue);
      expect(model.isCoolingDown('h1', now + 2000), isFalse);
      now += 3000;
      record(MediaOutcome.throttled, hostname: 'h1'); // streak 1 -> 4000ms
      expect(model.isCoolingDown('h1', now + 3999), isTrue);
      expect(model.isCoolingDown('h1', now + 4000), isFalse);
      now += 5000;
      record(MediaOutcome.throttled, hostname: 'h1'); // streak 2 -> 8000ms
      expect(model.isCoolingDown('h1', now + 8000), isFalse);
      expect(model.isCoolingDown('h1', now + 7999), isTrue);
    });

    test('serverError/network backoff: 1000 * 2^min(streak, 5)', () {
      record(MediaOutcome.serverError, hostname: 'h1');
      expect(model.isCoolingDown('h1', now + 1000), isFalse);
      now += 2000;
      // network is a connection failure: only penalized while the network
      // looks otherwise alive (bytes arrived recently from some host)
      model.noteBytes(now - 100);
      record(MediaOutcome.network, hostname: 'h1');
      expect(model.isCoolingDown('h1', now + 2000), isFalse);
      expect(model.isCoolingDown('h1', now + 1999), isTrue);
    });

    test('connectFail backoff: 60s * 2^min(streak, 2)', () {
      model.noteBytes(now - 100);
      record(MediaOutcome.connectFail, hostname: 'h1');
      expect(model.isCoolingDown('h1', now + 59999), isTrue);
      expect(model.isCoolingDown('h1', now + 60000), isFalse);
    });

    test('truncated/reset/stall: short 500ms cooldown', () {
      model.noteBytes(now - 100);
      record(MediaOutcome.truncated, hostname: 'h1');
      expect(model.isCoolingDown('h1', now + 499), isTrue);
      expect(model.isCoolingDown('h1', now + 500), isFalse);
    });

    test('connection failures are excused while the host is alive or the network is down', () {
      record(MediaOutcome.network, hostname: 'h1', alive: true);
      expect(model.isCoolingDown('h1', now + 1), isFalse);

      // Bytes arrived a moment ago and nothing is alive: one bad connection.
      model.noteBytes(now - 1000);
      record(MediaOutcome.reset, hostname: 'h1', alive: false);
      expect(model.isCoolingDown('h1', now + 499), isTrue);

      // No bytes for a long while: the viewer's network is at fault.
      now += 10000;
      model.noteBytes(now - 5000);
      record(MediaOutcome.stall, hostname: 'h1', alive: false);
      expect(model.isCoolingDown('h1', now + 1), isFalse);
    });

    test('unacceptable-response outcomes exclude the host for the file forever', () {
      for (final outcome in [
        MediaOutcome.badRange,
        MediaOutcome.staleObject,
        MediaOutcome.noRange,
        MediaOutcome.unverifiable,
        MediaOutcome.redirect,
        MediaOutcome.missing,
        MediaOutcome.integrity,
      ]) {
        final m = HostEstimateModel(nowMs: () => now)
          ..recordOutcome(
            'h1',
            'file1',
            addressKey: '/a?sig=1',
            family: SignatureFamily.upos,
            outcome: outcome,
            now: now,
            alive: false,
          );
        expect(m.isExcluded('h1', 'file1', now + 24 * 3600 * 1000), isTrue, reason: outcome.wire);
        expect(m.isExcluded('h2', 'file1', now), isFalse, reason: 'other host untouched');
      }
    });

    test('expired bans the address itself', () {
      record(MediaOutcome.expired, addressKey: '/a?sig=1');
      expect(model.isAddressBanned('/a?sig=1'), isTrue);
      expect(model.isExcluded('h1', 'file1', now), isFalse);
    });

    test('refused: host works but no host served the address -> the address is bad', () {
      record(MediaOutcome.ok, hostname: 'h1', addressKey: '/other?sig=2');
      record(MediaOutcome.refused, hostname: 'h1', addressKey: '/a?sig=1');
      expect(model.isAddressBanned('/a?sig=1'), isTrue);
      expect(model.isExcluded('h1', 'file1', now), isFalse);
    });

    test('refused: address served elsewhere, family unknown here -> host refuses the family', () {
      record(MediaOutcome.ok, hostname: 'h2', addressKey: '/a?sig=1');
      record(MediaOutcome.refused, hostname: 'h1', addressKey: '/a?sig=1');
      expect(model.isFamilyRefused('h1', SignatureFamily.upos, now + 30 * 60 * 1000 - 1), isTrue);
      expect(model.isFamilyRefused('h1', SignatureFamily.upos, now + 30 * 60 * 1000), isFalse);
      expect(model.isExcluded('h1', 'file1', now), isFalse);
      expect(model.isAddressBanned('/a?sig=1'), isFalse);
    });

    test('refused: both address and family accepted elsewhere -> exclude the host for 60s', () {
      record(MediaOutcome.ok, hostname: 'h2', addressKey: '/a?sig=1');
      record(MediaOutcome.ok, hostname: 'h1', addressKey: '/other?sig=2');
      record(MediaOutcome.refused, hostname: 'h1', addressKey: '/a?sig=1');
      expect(model.isExcluded('h1', 'file1', now + 59999), isTrue);
      expect(model.isExcluded('h1', 'file1', now + 60000), isFalse);
    });

    test('refused: fresh host, fresh address -> excluded for 60s, not banned', () {
      record(MediaOutcome.refused, hostname: 'h1', addressKey: '/a?sig=1');
      expect(model.isExcluded('h1', 'file1', now + 59999), isTrue);
      expect(model.isAddressBanned('/a?sig=1'), isFalse);
    });
  });

  group('withLoad', () {
    test('a new request gets no more than its hosts requests get together', () {
      const base = HostEstimate(ttfb: 100, rate: 100, eta: 110, measured: true, gap: null);
      final loaded = withLoad(base, (2, 80.0), 400);
      expect(loaded.rate, 40); // 80 / 2
      expect(loaded.eta, 100 + 400 / 40);
      expect(loaded.ttfb, 100);
      expect(loaded.measured, isTrue);
      expect(identical(loaded, base), isFalse);
    });

    test('no load or a zero rate leaves the estimate untouched', () {
      const base = HostEstimate(ttfb: 100, rate: 100, eta: 110, measured: true, gap: 5);
      expect(identical(withLoad(base, null, 400), base), isTrue);
      expect(identical(withLoad(base, (3, 0.0), 400), base), isTrue);
      // faster than estimated alone: still capped at the estimate
      final capped = withLoad(base, (2, 1000.0), 400);
      expect(capped.rate, 100);
      expect(identical(capped, base), isTrue);
    });
  });
}
