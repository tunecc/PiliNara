/// What is known about every CDN host, for one video session only. 1:1 port of
/// upstream `src/core/player/host-model.ts` (plus `withLoad` from engine.ts,
/// which the task groups here).
///
/// - Speed: per host and video, its recent first-byte times, transfer rates
///   and chunk gaps. An edge's speed depends on whether it has the video
///   cached, so the next video starts unmeasured.
/// - Reliability: cooldowns, files a host lacks, signature families it
///   refuses, dead addresses.
///
/// Upstream keeps these in module-global maps with flru LRU caches, because a
/// browser page outlives many videos. Here one [HostEstimateModel] belongs to
/// exactly one video session (nothing is reused across videos), so plain maps
/// are used; their size is bounded by the session's host/file count.
library;

import 'dart:math' as math;

import 'package:PiliPlus/services/thread_ripper/classify.dart' show SignatureFamily;

import 'package:PiliPlus/services/thread_ripper/outcome.dart';

/// What a request of `bytes` to a host is expected to take.
class HostEstimate {
  const HostEstimate({
    required this.ttfb,
    required this.rate,
    required this.eta,
    required this.measured,
    required this.gap,
  });

  /// ms
  final double ttfb;

  /// Bytes per ms of one request
  final double rate;

  /// Expected ms to receive `bytes`
  final double eta;

  /// This host's throughput on this video is known
  final bool measured;

  /// Usual gap between the chunks of a request, ms, `null` if unknown
  final double? gap;
}

/// The last [HostEstimateModel.samples] of one host on one video, newest last.
class _Speed {
  final List<double> ttfb = [];
  final List<double> rate = [];
  final List<double> gap = [];
}

/// One host's reliability. Times are session-clock ms (upstream
/// performance.now()).
class _HostRecord {
  /// Last request that ended: idle for `warmMs`, its connection is assumed
  /// closed
  double lastUsedAt = double.negativeInfinity;

  /// No new requests to the host until then
  int cooldownUntil = 0;

  /// Consecutive failures: grows the backoff, reset by a success
  int failureStreak = 0;

  /// Key of the last signed address this host served: tried first on it
  String? provenAddress;
  final Set<SignatureFamily> acceptedFamilies = {};

  /// Signature families this host refuses (Akamai with upos signatures), until
  final Map<SignatureFamily, int> refusedFamilies = {};
}

class HostEstimateModel {
  HostEstimateModel({required this._nowMs});

  /// Session monotonic clock (upstream performance.now()).
  final int Function() _nowMs;

  /// What a request is assumed to deliver before anything is measured
  static const double priorRate = 768 * 1024 / 1000; // bytes per ms
  static const int priorTtfb = 350;
  static const int samples = 8;

  /// A connection idle for longer is probably closed: a new one costs about
  /// another first byte
  static const int warmMs = 30 * 1000;

  /// Nothing arrived from any host for this long: failures are the viewer's
  /// network, not the hosts
  static const int networkDownMs = 3000;

  /// Failures that the viewer's own network going away produces on every host
  /// at once
  static const Set<MediaOutcome> connectionFailures = {
    MediaOutcome.connectFail,
    MediaOutcome.network,
    MediaOutcome.stall,
    MediaOutcome.truncated,
    MediaOutcome.reset,
  };

  final Map<String, _HostRecord> _hosts = {};

  /// file key -> hostname -> speed
  final Map<String, Map<String, _Speed>> _speeds = {};

  /// file key -> hostname -> excluded until
  final Map<String, Map<String, int>> _exclusions = {};

  /// Signed addresses (pathname + search) no host will serve
  final Set<String> _bannedAddresses = {};

  /// Signed addresses some host has served
  final Set<String> _acceptedAddresses = {};

  /// Last time bytes arrived from any host
  double _lastBytesAt = double.negativeInfinity;

  HostEstimate estimate(String hostname, String fileKey, int bytes) {
    final own = _speedsOf(fileKey)[hostname];
    final rate = own != null ? robust(own.rate, false) : null;
    final typical = typicalSpeed(fileKey);
    final cold = _nowMs() - _get(hostname).lastUsedAt > warmMs;
    final ttfb = ((own != null ? robust(own.ttfb, true) : null) ?? typical.ttfb) * (cold ? 2 : 1);
    return HostEstimate(
      ttfb: ttfb,
      rate: rate ?? typical.rate,
      eta: ttfb + bytes / (rate ?? typical.rate),
      measured: rate != null,
      gap: own != null ? robust(own.gap, true) : null,
    );
  }

  /// The median over the hosts measured on this video, else what is assumed.
  ({double ttfb, double rate}) typicalSpeed(String fileKey) {
    final ttfbs = <double>[];
    final rates = <double>[];
    for (final speed in _speedsOf(fileKey).values) {
      final ttfb = robust(speed.ttfb, true);
      final rate = robust(speed.rate, false);
      if (ttfb != null) ttfbs.add(ttfb);
      if (rate != null) rates.add(rate);
    }
    return (
      ttfb: ttfbs.isNotEmpty ? percentile(ttfbs, 50) : priorTtfb.toDouble(),
      rate: rates.isNotEmpty ? percentile(rates, 50) : priorRate,
    );
  }

  /// Bytes arrived from some host: the network works
  void noteBytes(int now) {
    _lastBytesAt = now.toDouble();
  }

  bool isCoolingDown(String hostname, int now) => _get(hostname).cooldownUntil > now;

  bool isExcluded(String hostname, String fileKey, int now) =>
      (_exclusions[fileKey]?[hostname] ?? 0) > now;

  bool isFamilyRefused(String hostname, SignatureFamily family, int now) =>
      (_get(hostname).refusedFamilies[family] ?? 0) > now;

  bool acceptsFamily(String hostname, SignatureFamily family) =>
      _get(hostname).acceptedFamilies.contains(family);

  bool isAddressBanned(String key) => _bannedAddresses.contains(key);

  String? provenAddress(String hostname) => _get(hostname).provenAddress;

  /// Records a speed sample.
  ///
  /// [ttfb] in ms, or how long it waited without one when that says the host
  /// is slow; [rate] in bytes per ms after the first chunk, [partial] when the
  /// transfer was cut short (only counted until a full one is known); [gap]
  /// in ms.
  void recordSpeed(
    String hostname,
    String fileKey, {
    required double? ttfb,
    required double? rate,
    required bool partial,
    required double? gap,
  }) {
    final byHost = _speedsOf(fileKey);
    final speed = byHost.putIfAbsent(hostname, _Speed.new);
    _push(speed.ttfb, ttfb);
    _push(speed.rate, rate != null && rate > 0 && (!partial || speed.rate.isEmpty) ? rate : null);
    _push(speed.gap, gap);
  }

  /// Records how a request ended.
  ///
  /// [alive]: another request to the host is delivering right now — a
  /// connection-level failure is then one bad connection, and the host stays
  /// available for the retry.
  void recordOutcome(
    String hostname,
    String fileKey, {
    required String addressKey,
    required SignatureFamily family,
    required MediaOutcome outcome,
    required int now,
    required bool alive,
  }) {
    final host = _get(hostname)
      ..lastUsedAt = now.toDouble();
    if (connectionFailures.contains(outcome) && (alive || now - _lastBytesAt > networkDownMs)) {
      return;
    }
    switch (outcome) {
      case MediaOutcome.ok:
        _lastBytesAt = now.toDouble();
        host.failureStreak = 0;
        host.acceptedFamilies.add(family);
        host.refusedFamilies.remove(family);
        host.provenAddress = addressKey;
        _acceptedAddresses.add(addressKey);
      case MediaOutcome.truncated:
      case MediaOutcome.reset:
      case MediaOutcome.stall:
        _cooldown(host, now, 500);
      case MediaOutcome.badRange:
      case MediaOutcome.staleObject:
      case MediaOutcome.noRange:
      case MediaOutcome.unverifiable:
      case MediaOutcome.redirect:
      case MediaOutcome.missing:
      case MediaOutcome.integrity:
        _exclude(hostname, fileKey, 0x7fffffffffffffff); // "Infinity"
      case MediaOutcome.expired:
        _bannedAddresses.add(addressKey);
      case MediaOutcome.refused:
        if (!_acceptedAddresses.contains(addressKey)) {
          if (host.acceptedFamilies.contains(family)) {
            // The host works and no host has served this address: the address
            // is the problem
            _bannedAddresses.add(addressKey);
          } else {
            _exclude(hostname, fileKey, now + 60 * 1000);
          }
        } else if (host.acceptedFamilies.contains(family)) {
          // Both work elsewhere: something between this host and this file,
          // not the address
          _exclude(hostname, fileKey, now + 60 * 1000);
        } else {
          // The address works elsewhere: this host refuses the whole signature
          // family (Akamai)
          host.refusedFamilies[family] = now + 30 * 60 * 1000;
        }
      case MediaOutcome.throttled:
        _cooldown(host, now, 2000 * math.pow(2, math.min(host.failureStreak, 3)).toInt());
      case MediaOutcome.serverError:
      case MediaOutcome.network:
        _cooldown(host, now, 1000 * math.pow(2, math.min(host.failureStreak, 5)).toInt());
      case MediaOutcome.connectFail:
        _cooldown(host, now, 60 * 1000 * math.pow(2, math.min(host.failureStreak, 2)).toInt());
      default:
        break;
    }
  }

  _HostRecord _get(String hostname) => _hosts.putIfAbsent(hostname, _HostRecord.new);

  Map<String, _Speed> _speedsOf(String fileKey) =>
      _speeds.putIfAbsent(fileKey, () => {});

  void _cooldown(_HostRecord host, int now, int ms) {
    host.failureStreak++;
    host.cooldownUntil = math.max(host.cooldownUntil, now + ms);
  }

  void _exclude(String hostname, String fileKey, int until) {
    final byHost = _exclusions.putIfAbsent(fileKey, () => {});
    byHost[hostname] = until;
  }
}

/// What one more request to a host would get: no more than its requests get
/// now. They share one connection (upstream: HTTP/2), so on a host whose
/// connection is the limit they slow each other down. [load] is
/// `(requests receiving, their bytes per ms together)`; `null` when the host
/// has none.
HostEstimate withLoad(HostEstimate estimate, (int, double)? load, int bytes) {
  final rate = load == null || load.$2 <= 0 ? estimate.rate : math.min(estimate.rate, load.$2 / load.$1);
  return rate == estimate.rate
      ? estimate
      : HostEstimate(
          ttfb: estimate.ttfb,
          rate: rate,
          eta: estimate.ttfb + bytes / rate,
          measured: estimate.measured,
          gap: estimate.gap,
        );
}

/// The median, but a sudden turn for the worse shows at once: the two latest,
/// both 2x worse than it. [higherIsWorse] selects the direction that means
/// degradation (ttfb: higher; rate: lower). Returns null without samples.
double? robust(List<double> samples, bool higherIsWorse) {
  final len = samples.length;
  if (len == 0) {
    return null;
  }
  final median = percentile(samples, 50);
  final latest = samples[len - 1];
  // Upstream reads samples[len - 2] (undefined, comparison-false for len < 2).
  final previous = len >= 2 ? samples[len - 2] : null;
  if (higherIsWorse && len >= 3 && latest > 2 * median && previous != null && previous > 2 * median) {
    return math.min(latest, previous);
  }
  if (!higherIsWorse && len >= 3 && latest < median / 2 && previous != null && previous < median / 2) {
    return math.max(latest, previous);
  }
  return median;
}

void _push(List<double> samples, double? value) {
  if (value != null) {
    samples.add(value);
    if (samples.length > HostEstimateModel.samples) {
      samples.removeRange(0, samples.length - HostEstimateModel.samples);
    }
  }
}

/// Nearest-rank percentile, matching the upstream `fast-percentile` package:
/// the `ceil(p * n / 100)`-th smallest of the samples (a sorted copy; the
/// input is left untouched). [samples] must not be empty.
double percentile(List<double> samples, int p) {
  assert(p > 0 && p < 100, 'fast-percentile only special-cases 0/100; use min/max instead');
  final sorted = List<double>.of(samples)..sort();
  final k = (p * sorted.length / 100).ceil();
  return sorted[k - 1];
}
