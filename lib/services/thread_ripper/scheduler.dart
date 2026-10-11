/// The serve phase: a media range the player asks for is split into pieces,
/// fetched from many interchangeable CDN hosts at once, checked, and put
/// together as the player's response.
///
/// 1:1 port of upstream `src/modules/thread-ripper/engine.ts` (commit
/// a31eea9). Constants, formulas, thresholds and decision branches carry over
/// unchanged; only the browser integration is remapped:
/// - the XHR sink becomes the [AcceleratedResponse.stream] (bytes stream out
///   as they are written, in order — upstream hands the page the whole buffer
///   at the end; the buffer contents are identical),
/// - `performance.now()` / `Date.now()` become injected clocks,
/// - `setInterval(tick, TICK_MS)` goes through an injectable ticker.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:PiliPlus/services/thread_ripper/classify.dart';
import 'package:PiliPlus/services/thread_ripper/contracts.dart';
import 'package:PiliPlus/services/thread_ripper/host_model.dart';
import 'package:PiliPlus/services/thread_ripper/media_transport.dart';
import 'package:PiliPlus/services/thread_ripper/outcome.dart';

const int kKiB = 1024;
const int kMiB = 1024 * kKiB;

/// Attempts in flight across all jobs
const int globalCap = 32;

/// Slots only critical and urgent work may take
const int urgentReserve = 2;

///
/// Attempts in flight per host (upstream comment: Chrome opens at most six
/// connections to one host, and a seventh would wait inside the browser. The
/// CDN throttles per request, so several to one host add up)
const int hostCap = 6;

/// Pieces per host that may carry them on its own
const int piecesPerHost = 4;
const int maxPieces = 16;
const int minPiece = 192 * kKiB;
const int maxPiece = 4 * kMiB;

/// The longest range one response may serve
/// 开放末端/超长请求的分棒服务长度：小棒让预取有界、跟随播放消费
const int openEndedLegBytes = 8 * kMiB;

/// 续棒提前量：播放器消费水位逼近下一棒起点不足该值时，下一棒挂起
const int consumptionLookaheadBytes = 4 * kMiB;

/// 异常响应排水的上限（约 1 MiB）：释放连接即可，不必替异常主机读完整个
/// 响应体
const int discardCapBytes = 1024 * 1024;

/// Failed attempts per piece before the job falls back or fails
const int maxTries = 6;

/// No validated 206 from any host by then, when the player set no timeout
const int commitTimeoutMs = 4800;

/// Committed, but no byte arrived for this long: unfinished pieces go to the
/// player's own URL
const int jobStallMs = 8000;

///
/// A job delivering this many times the stream's bitrate gets no more
/// speculative duplicates. High on purpose: a saturated line shows itself
/// when a duplicate raises nothing (`mayDuplicate`)
const int hedgeHeadroom = 8;

/// The delivered rate is read over this long
const int rateWindowMs = 500;
const int tickMs = 50;

/// Duplicates per piece at most
const int maxExtra = 2;

/// A racer this far behind the leader is only comparing bytes
const int laggardBytes = 64 * kKiB;

/// A racer on a host never measured runs at least this far, enough to measure
/// the host
const int probeBytes = 64 * kKiB;

/// A request waits this long for a warm-up still on its way, then fetches by
/// itself
const int warmupWaitMs = 1500;

/// Init segments and indexes kept, the oldest dropped first
const int maxHeaders = 64;

/// Warm-up requests in flight at most: they must not take slots from what
/// plays
const int warmupCap = 4;

/// Files whose candidates came, but the player has not asked for yet
const int maxPendingWarmups = 16;

/// A piece this small is about latency: it goes to the host expected to
/// finish it first
const int smallPiece = 256 * kKiB;

///
/// A piece goes on its own only to a host expected to finish it within this
/// factor of the best one: on a slower host the whole request would wait for
/// that piece
const double etaBand = 1.25;

/// Neither half of a split is smaller
const int stealMin = 192 * kKiB;

/// Speed samples from shorter transfers are mostly round trip; below
/// `fullSample`, cut short
const int minSample = 16 * kKiB;
const int fullSample = 48 * kKiB;

/// A host delivered bytes this recently: it works, and a failure is that one
/// request's
const int aliveMs = 2000;

/// After a failed job, the player's retry of the same range goes to the
/// browser
const int nativeRetryMs = 30 * 1000;

/// This many failed jobs within a minute: the player fetches directly for 30 s
const int failuresToTurnOff = 3;

/// A signature must stay valid at least this long to be used (candidates.ts)
const int deadlineMarginMs = 60 * 1000;

/// Urgency, most urgent first: init and index, what the player asked for, the
/// warm-up
const int critical = 0;
const int urgent = 1;
const int relaxed = 2;

/// Scales the timeouts: critical work is helped sooner
const List<double> urgencyFactor = [0.7, 0.85, 2];

/// Hosts a request in one piece starts on
const List<int> raceWidth = [3, 2, 1];

/// How long after its start a job's bytes are wanted
const List<int> deadlineMs = [0, 1500, 5000];

double _clamp(double value, double lo, double hi) =>
    value < lo ? lo : (value > hi ? hi : value);

int _clampInt(int value, int lo, int hi) => value < lo ? lo : (value > hi ? hi : value);

/// Which job's waiting piece goes first: the more urgent, then the older
bool before(Job a, Job b) => a.cls < b.cls || (a.cls == b.cls && a.createdAt < b.createdAt);

///
/// How many pieces a range is split into. A range whose transfer takes less
/// than two round trips is not worth splitting; otherwise each piece keeps its
/// request busy for a good part of a second, with no more than
/// `piecesPerHost` per host that may carry one
int pieceCount(int length, double rate, double ttfb, int hosts) {
  if (length < _clamp(2 * rate * ttfb, 128 * kKiB.toDouble(), kMiB.toDouble())) {
    return 1;
  }
  final pieceSize =
      _clamp(rate * _clamp(4 * ttfb, 600, 1500), minPiece.toDouble(), maxPiece.toDouble());
  return _clampInt(
    (length / pieceSize).ceil(),
    1,
    math.min(maxPieces, hosts * piecesPerHost),
  );
}

///
/// Where to split a piece so both halves finish together: the running attempt
/// (rate `r`) keeps `[frontier, m)`, the new host takes `[m, end]`. `null`
/// when either half would be too small
int? splitPoint(Segment seg, double r, HostEstimate estimate) {
  if (r <= 0) {
    return null;
  }
  final remaining = seg.end + 1 - seg.frontier;
  final m = seg.frontier + (r * (estimate.ttfb + remaining / estimate.rate) / (1 + r / estimate.rate)).ceil();
  // The running attempt must still have work while the new one waits for its
  // first byte
  return seg.end + 1 - m < stealMin || m - seg.frontier < math.max(stealMin, r * estimate.ttfb)
      ? null
      : m;
}

/// Finish this much before the deadline to count as in time
double hedgeSlack(double typicalTtfb) => _clamp(2 * typicalTtfb, 500, 1500);

/// Bytes written for the job over the last `rateWindowMs`, per ms
double deliveredRate(Job job, int now) {
  final meter = job.meter;
  var base = meter[0];
  for (var i = 1; i < meter.length && meter[i].$1 <= now - rateWindowMs; i++) {
    base = meter[i];
  }
  return (job.covered - base.$2) / math.max(1, now - base.$1);
}

/// An attempt's speed over the last half second, or since its first byte when
/// the history is short
double recentRate(Attempt att, int now) {
  final meter = att.meter;
  if (meter.isEmpty) {
    return 0;
  }
  final last = meter.last;
  for (final (time, bytes) in meter) {
    if (now - time <= 500 && last.$1 - time >= 100) {
      return (last.$2 - bytes) / math.max(1, now - time);
    }
  }
  return att.firstByteAt == 0 || now <= att.firstByteAt
      ? 0
      : (att.bytes - att.firstChunkBytes) / (now - att.firstByteAt);
}

///
/// Whether a receiving piece with one attempt needs relief: none while it
/// finishes in time (by the job's deadline less `slack`). Then, if it is
/// slower than requests usually are, or than the host a racer would go to (or
/// that host was never measured); or, spending one of the job's rescues, if
/// it crawls (`straggler`) or will miss the deadline anyway (`stale`)
ReliefKind? needsRelief(
  Attempt att,
  int now,
  double typicalRate,
  HostEstimate? Function() alternativeOf,
  double slack,
) {
  final job = att.job;
  final seg = att.seg;
  if (now - att.firstByteAt < 250) {
    return null;
  }
  final rate = recentRate(att, now);
  final eta = now + (seg.end - seg.frontier + 1) / rate;
  if (eta <= job.deadline - slack) {
    return null;
  }
  if (eta >= job.deadline && rate < 0.5 * typicalRate && eta - now >= 500 && job.rescuesStraggler > 0) {
    return ReliefKind.straggler;
  }
  if (rate < 0.6 * typicalRate) {
    return ReliefKind.help;
  }
  final alternative = alternativeOf();
  if (alternative != null && (!alternative.measured || alternative.rate > 1.5 * rate)) {
    return ReliefKind.help;
  }
  return eta > job.deadline && job.rescuesStale > 0 ? ReliefKind.stale : null;
}

///
/// A speculative duplicate takes bandwidth from the pieces that matter: none
/// while the job already delivers `hedgeHeadroom` times what the stream
/// needs, none for a job whose last duplicate raised nothing (the line is
/// full), and the last one gets `rateWindowMs` to show before the next
bool mayDuplicate(Job job, int now) {
  final rate = deliveredRate(job, now);
  final last = job.lastDuplicate;
  if (job.saturated || rate >= hedgeHeadroom * job.requiredRate || (last != null && now - last.$1 < rateWindowMs)) {
    return false;
  }
  if (last != null && last.$2 > 0 && rate <= last.$2) {
    job.saturated = true;
    return false;
  }
  return true;
}

/// The kind of help `needsRelief` asks for.
enum ReliefKind { help, straggler, stale }

/// Whom a duplicate (racer) is for: a host never measured first, or the
/// fastest measured one.
enum RacerKind { explore, rescue }

/// What `writeChunk` did with a chunk.
enum WriteVerdict { ok, overrun, mismatch }

/// How a job stands.
enum JobState { running, done, failed }

/// How much of a candidate URL the scheduler has derived: the port of
/// upstream `MediaCandidate` (candidates.ts) over the app's
/// [MediaCandidate].
class ResolvedCandidate {
  ResolvedCandidate(MediaCandidate listed)
      : listed = listed,
        href = listed.url,
        hostname = listed.host,
        key = _addressKey(Uri.parse(listed.url)),
        family = signatureFamilyOf(Uri.parse(listed.url)),
        deadline = signatureDeadlineOf(Uri.parse(listed.url)) {
    final cls = classifyCdnUrl(Uri.parse(listed.url));
    p2p = isP2PCdnDomain(hostname) ||
        cls == CdnUrlClass.mcdnUpgcxcode ||
        cls == CdnUrlClass.mcdnTf ||
        cls == CdnUrlClass.szbdyd;
    if (p2p) {
      tier = CandidateTier.p2p;
    } else if ((family == SignatureFamily.akam) != isAkamaiHost(hostname)) {
      // 签名家族与主机家族不匹配（upos 签名在 Akamai、或反之）：该主机必然
      // 403（upstream tierOnHost 的 foreign 档），最后才尝试
      tier = CandidateTier.foreign;
    } else if (_proxyHostRe.hasMatch(hostname)) {
      tier = CandidateTier.proxy;
    } else if (cls == CdnUrlClass.bcache) {
      tier = CandidateTier.listedBcache;
    } else {
      tier = CandidateTier.listedMirror;
    }
  }

  static final RegExp _proxyHostRe = RegExp(r'^(?:upos|proxy)-tf-');

  static String _addressKey(Uri uri) =>
      uri.path + (uri.hasQuery ? '?${uri.query}' : '');

  /// The candidate as the app listed it (fetch this URL).
  final MediaCandidate listed;
  final String href;
  final String hostname;

  /// pathname + search: the signed address, whatever the host
  final String key;
  final SignatureFamily family;

  /// When the signature expires, unix seconds, `0` if unknown
  final int deadline;
  late final CandidateTier tier;
  late final bool p2p;
}

/// How much a host with no measurement is preferred, lower first (candidates.ts).
enum CandidateTier {
  listedMirror(0),
  listedBcache(1),
  mirror(2),
  bcache(3),
  source(4),
  proxy(5),
  p2p(6),
  foreign(7);

  const CandidateTier(this.rank);
  final int rank;
}

/// One piece of a job's range (engine.ts `Segment`).
class Segment {
  Segment(this.start, this.end)
      : frontier = start,
        attempts = {},
        tries = 0,
        tried = {},
        extra = 0,
        queued = false,
        isFinal = false;

  /// Inclusive first offset (kept for contiguous-progress tracking; upstream
  /// infers it from `frontier`, which moves).
  final int start;

  /// Inclusive. Moves in when its tail is split off
  int end;

  /// Everything below it is written. Only ever moves forward
  int frontier;

  /// In flight: one, more while raced
  final Set<Attempt> attempts;

  /// Failed attempts
  int tries;

  /// Hosts tried since the piece last made progress
  final Set<String> tried;

  /// Duplicates started for it
  int extra;

  /// Waiting for a slot
  bool queued;

  /// Last resort: the player's own URL
  bool isFinal;
}

/// One ranged fetch of (the rest of) a piece from one host (engine.ts
/// `Attempt`). Times are session-clock ms, `0` = not yet.
class Attempt {
  Attempt({
    required this.job,
    required this.seg,
    required this.hostname,
    required this.candidate,
    required this.role,
    required this.controller,
    required this.ttfbSoft,
    required this.stallSoft,
    required this.startedAt,
    required this.probe,
  })  : abortReason = null,
        headersAt = 0,
        firstByteAt = 0,
        firstChunkBytes = 0,
        lastByteAt = 0,
        bytes = 0,
        pos = seg.frontier,
        meter = [],
        gaps = [];

  final Job job;
  final Segment seg;
  final String hostname;
  final ResolvedCandidate candidate;
  final String role; // 'primary' | 'dup' | 'final'

  /// Set when we abort it ourselves (upstream AbortController + reason)
  final MediaAbortHandle controller;
  AbortReason? abortReason;

  /// No first byte after `ttfbSoft`, or silence after bytes flowed for
  /// `stallSoft`: a racer goes on. Silent for twice `stallSoft`, the request
  /// goes. Before the job's urgency scales them
  final double ttfbSoft;
  final double stallSoft;
  final int startedAt;

  /// A validated response arrived
  int headersAt;
  int firstByteAt;

  /// Left out of speed measurements: it arrives with the first byte
  int firstChunkBytes;
  int lastByteAt;

  /// Received so far, bytes other attempts already wrote included
  int bytes;

  /// Absolute offset of the next byte it receives
  int pos;

  /// Recent (time, bytes) samples, for its current speed
  final List<(int, int)> meter;

  /// Gaps between chunks, for its host's stall threshold
  final List<int> gaps;

  /// Its host was never measured: it is not cut loose before `probeBytes`, so
  /// that it gets measured
  final bool probe;
}

/// The player-facing end of one job: bytes stream out in order as they are
/// written. The port of upstream `SyntheticXhrSink`: where the userscript
/// handed the page the whole buffer once complete, the proxy consumes the
/// same bytes as a stream (same contents, earlier availability).
class ResponseSink {
  ResponseSink() {
    _controller = StreamController<List<int>>(
      onCancel: () {
        _onCancel?.call();
      },
    );
  }

  late final StreamController<List<int>> _controller;
  Job? _job;

  /// 请求区间的起点：续棒时后继 Job 的 range.first 会前移，发射偏移一律以
  /// 请求起点为基准绝对计算
  int _requestFirst = 0;
  int _emitted = 0;
  bool _finished = false;

  /// Set by the scheduler: the consumer went away before the job ended.
  void Function()? _onCancel;

  Stream<List<int>> get stream => _controller.stream;

  /// The job's contiguous progress advanced.
  void progress() => _emitAvailable();

  /// 冲刷指定 Job 已写入但尚未发射的字节（_complete 的调用点在最后一次
  /// 写入之后、跳过了末次 progress，续棒/挂起前必须先冲刷）。
  void flush(Job job) => _emitFromJob(job);

  /// 换入开放末端请求的下一棒：先冲刷上一棒尚未发射的尾字节（_complete 的
  /// 调用点在最后一次写入之后、可能已跳过末次 progress），再切换绝对偏移
  /// 基准继续发射。
  void attach(Job job) {
    final previous = _job;
    if (previous != null) {
      _emitFromJob(previous);
    }
    _job = job;
    _emitFromJob(job);
  }

  /// The job is done: everything is there.
  void done() {
    _emitAvailable();
    _finished = true;
    _controller.close();
  }

  /// The job failed: the consumer falls back to a direct request.
  void error() {
    if (_finished) {
      return;
    }
    _finished = true;
    _controller
      ..addError(StateError('thread-ripper: job failed'))
      ..close();
  }

  void _emitAvailable() {
    final job = _job;
    if (job != null) {
      _emitFromJob(job);
    }
  }

  void _emitFromJob(Job job) {
    if (_finished) {
      return;
    }
    final contiguous = _contiguous(job);
    final jobStartOffset = job.range.first - _requestFirst;
    final absoluteEnd = jobStartOffset + contiguous;
    if (absoluteEnd > _emitted) {
      final startRel = _emitted - jobStartOffset;
      if (startRel < 0) {
        // 续棒前上一棒已冲刷，理论上不可达；宁可断言也不跨棒错位
        throw StateError(
          'thread-ripper: sink emission gap (emitted=$_emitted, job starts at ${job.range.first})',
        );
      }
      final chunk = Uint8List.sublistView(job.bytes, startRel, contiguous);
      _emitted = absoluteEnd;
      _controller.add(chunk);
    }
  }

  /// Offset relative to the range start (exclusive) of the byte run written
  /// from the start of the range. Upstream needs no such pointer (it serves
  /// the whole buffer at the end); a stream must not skip ahead over holes.
  /// Segments whose start is still ahead of the run are skipped, not a stop:
  /// a split-off tail can sit later in the list than a later piece.
  static int _contiguous(Job job) {
    var p = job.range.first;
    for (final seg in job.segments) {
      if (seg.start > p) {
        continue;
      }
      if (seg.frontier > p) {
        p = seg.frontier;
      }
    }
    return math.min(p, job.range.first + job.length) - job.range.first;
  }
}

/// One range the player asked for, or a warm-up, answered by many attempts
/// across hosts (engine.ts `Job`).
class Job {
  Job({
    required this.fileKey,
    required this.range,
    required this.cls,
    required this.createdAt,
    required this.requiredRate,
    required this.length,
    required this.candidates,
    required this.requested,
    required this.descriptor,
    this.chainRequestLast,
    this.timeout = 0,
    this.sink,
  })  : deadline = createdAt + deadlineMs[cls],
        rescuesStraggler = 0,
        rescuesStale = 0,
        bytes = Uint8List(length),
        state = JobState.running,
        committed = false,
        total = null,
        covered = 0,
        lastProgressAt = createdAt,
        meter = [(createdAt, 0)],
        lastDuplicate = null,
        saturated = false;

  final String fileKey;
  final ({int first, int last}) range;
  final int length;

  /// 原始描述符与分棒链的请求末端：续棒（Job 链）重建下一棒参数用
  final MediaDescriptor descriptor;
  final int? chainRequestLast;

  /// The more urgent, the sooner it is helped (`critical`/`urgent`/`relaxed`).
  /// Upstream promotes a warm-up job to critical when the player asks for its
  /// range; mutable for that.
  int cls;
  final int createdAt;

  /// When its bytes are wanted: past its start by how urgent it is
  int deadline;

  /// Help it may get for pieces on pace but late anyway (`needsRelief`)
  int rescuesStraggler;
  int rescuesStale;

  /// The player's own request timeout, `0` for none
  final int timeout;

  /// Every acceptable URL of the file, by host
  final Map<String, List<ResolvedCandidate>> candidates;

  /// The URL the player asked for (the warm-up's own pick): the last resort
  final ResolvedCandidate requested;

  /// Where the served bytes go (null for a warm-up)
  final ResponseSink? sink;
  String contentType = '';
  JobState state;

  /// Headers went to the player: the request can no longer be taken back
  bool committed;

  /// The whole file's size, from the first valid Content-Range
  int? total;
  final Uint8List bytes;

  /// The range split into pieces, in order
  final List<Segment> segments = [];

  /// Distinct bytes written
  int covered;
  int lastProgressAt;

  /// What the stream needs, bytes per ms: the file's bitrate from the
  /// playinfo (`bandwidth / 8000`)
  final double requiredRate;

  /// Recent (time, covered) samples: the delivered rate
  final List<(int, int)> meter;

  /// The last speculative duplicate: when, and the delivered rate then
  (int, double)? lastDuplicate;

  /// A duplicate did not raise the delivered rate: the line is full
  bool saturated;
}

/// A host that could take a piece, with the URL it would get.
class HostOption {
  const HostOption({
    required this.hostname,
    required this.candidate,
    required this.estimate,
    required this.active,
  });

  final String hostname;
  final ResolvedCandidate candidate;
  final HostEstimate estimate;

  /// Attempts in flight on it
  final int active;
}

/// One file's init segment and index, fetched ahead of the player. The port
/// of upstream's warm-up inputs: upstream learns files and their
/// `SegmentBase` from playinfos it sees; here the session creator supplies
/// them through [ThreadRipperSession.registerPreload].
class PreloadSpec {
  const PreloadSpec({required this.key, required this.descriptor, required this.indexEnd});

  /// The file key (the descriptor's original URL).
  final String key;

  /// Candidates and size of the file to warm.
  final MediaDescriptor descriptor;

  /// Inclusive end of the init segment + index (`SegmentBase.index.end`);
  /// warm-ups are skipped when unknown (upstream: `segmentBase === null`).
  final int indexEnd;
}

/// One media file warmed ahead of the player.
class _CachedHeader {
  _CachedHeader({required this.range, required this.job});

  final ({int first, int last}) range;
  Uint8List? bytes;
  int? total;
  String contentType = '';
  final Completer<bool> ready = Completer<bool>();

  /// Settles when the fetch is over: `true` with bytes.
  void settle(bool ok) {
    if (!ready.isCompleted) {
      ready.complete(ok);
    }
  }

  final Job job;
}

/// Per-video accelerator: owns the scheduler state of one playing video and
/// implements [MediaAccelerator]. One instance per loaded video; video and
/// audio share its global concurrency budget, like upstream shares one budget
/// per page.
class ThreadRipperSession implements MediaAccelerator {
  ThreadRipperSession({
    required this._transport,
    this._nowMs,
    this._wallMs,
    this._requiredRateOf,
    this._indexEndOf,
    @visibleForTesting void Function(void Function())? onTickRegistered,
    @visibleForTesting Future<void> Function(int ms)? delay,
    @visibleForTesting math.Random? random,
  })  : _delay = delay ?? ((ms) => Future<void>.delayed(Duration(milliseconds: ms))),
        _random = random ?? math.Random() {
    _tickerHook = onTickRegistered;
  }

  final MediaTransport _transport;

  /// Session monotonic clock (upstream performance.now()) and wall clock
  /// (upstream Date.now()); real time when not injected.
  final int Function()? _nowMs;
  final int Function()? _wallMs;
  final double Function(MediaDescriptor descriptor)? _requiredRateOf;
  final int Function(MediaDescriptor descriptor)? _indexEndOf;
  final Future<void> Function(int ms) _delay;
  final math.Random _random;
  void Function(void Function())? _tickerHook;

  /// Per-video host model (upstream: module-global per page). Late so it can
  /// use the injected clock.
  late final HostEstimateModel _model = HostEstimateModel(
    nowMs: _nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
  );

  final Set<Job> _jobs = {};

  /// file key -> init segment and index, insertion ordered: the oldest goes
  /// first
  final Map<String, _CachedHeader> _headers = {};

  /// Preload specs waiting until the player asks for the video
  final List<PreloadSpec> _pendingWarmups = [];

  /// file key -> file size, as every host must agree on it
  final Map<String, int> _totals = {};

  /// `file key:first-last` -> until when a retry of a failed range goes
  /// direct
  final Map<String, int> _nativeRetry = {};

  /// 开放末端请求分棒服务的后继参数：本棒完成后由 _complete 续接同一响应流
  final Map<Job, JobParams> _successorParams = {};

  /// 每文件已交付到播放器的绝对偏移（代理回调上报的消费水位）
  final Map<String, int> _consumedByFile = {};
  ({JobParams params, ResponseSink sink})? _pendingSuccessor;

  /// 代理上报：某文件已交付到播放器的绝对偏移（消费水位）。
  @visibleForTesting
  void noteConsumed(String fileKey, int absoluteOffset) {
    if (absoluteOffset > (_consumedByFile[fileKey] ?? 0)) {
      _consumedByFile[fileKey] = absoluteOffset;
    }
    _flushPendingSuccessor();
  }

  /// 消费驱动续棒：水位 + 提前量达到下一棒起点才启动；否则挂起待 tick。
  /// 启动的棒若未到请求末端，登记再下一棒（完成时继续按水位续接）。
  void _continueChain(JobParams next, ResponseSink sink) {
    final consumed = _consumedByFile[next.fileKey] ?? 0;
    if (consumed + consumptionLookaheadBytes >= next.range.first) {
      final successor = _start(next, sink);
      sink.attach(successor);
      _registerFollowingLeg(successor);
    } else {
      _pendingSuccessor = (params: next, sink: sink);
    }
  }

  /// 为刚启动的棒登记再下一棒参数（逐棒链式，直到请求末端）
  void _registerFollowingLeg(Job leg) {
    final requestLast = leg.chainRequestLast;
    if (requestLast == null || leg.range.last >= requestLast) {
      return;
    }
    final nextFirst = leg.range.last + 1;
    final nextLast = math.min(requestLast, nextFirst + openEndedLegBytes - 1);
    _successorParams[leg] = _jobParams(
      fileKey: leg.fileKey,
      descriptor: leg.descriptor,
      range: (first: nextFirst, last: nextLast),
      cls: leg.cls,
      timeout: 0,
      candidates: leg.descriptor.candidates,
      requestedUrl: leg.descriptor.originalUrl,
      chainRequestLast: requestLast,
    );
  }

  void _flushPendingSuccessor() {
    final pending = _pendingSuccessor;
    if (pending == null || _disposed) {
      return;
    }
    _pendingSuccessor = null;
    _continueChain(pending.params, pending.sink);
  }
  final List<int> _recentFailures = [];
  int _offUntil = 0;
  bool _integrityFailed = false;
  bool _disposed = false;

  /// hostname -> attempts in flight
  final Map<String, int> _busy = {};

  /// hostname -> when bytes last arrived from it
  final Map<String, double> _lastDelivery = {};

  /// Spreads a host's requests over the file's signatures
  int _rotation = 0;

  /// Pieces waiting for a slot, in arrival order: the most urgent, then the
  /// oldest job's go first
  final List<(Job, Segment)> _queue = [];
  final Set<Attempt> _running = {};
  bool _pumping = false;
  void Function()? _cancelTicker;

  int _now() => _nowMs?.call() ?? DateTime.now().millisecondsSinceEpoch;

  int _wall() => _wallMs?.call() ?? DateTime.now().millisecondsSinceEpoch;

  // ---- Serving (the port of the upstream `serve` phase entry) ----

  @override
  AcceleratedResponse? serve(MediaDescriptor descriptor, RangeRequest range) {
    try {
      return _serve(descriptor, range);
    } catch (_) {
      // Contract: serve must never throw; any internal failure degrades to a
      // direct request.
      return null;
    }
  }

  AcceleratedResponse? _serve(MediaDescriptor descriptor, RangeRequest range) {
    final now = _now();
    // descriptor 未带总大小时采纳会话学到的值（warmup/首个响应都会写入
    // _totals；上游语义即"从首个响应学 total 后回头服务"）。这让 DASH
    // 下预热过的其他清晰度可以直接命中，而不必等探测回填。
    final total = descriptor.totalSize ?? _totals[descriptor.originalUrl];

    // Left to the player. The requested URL is the last resort: not
    // acceptable, the player keeps it.
    String? reason;
    ({int first, int last})? resolved;

    /// 玩家请求的末端（钳制前）。超过 maxServedLength 的请求按上限分棒服务，
    /// Content-Range/流仍覆盖完整请求区间。
    int? requestLast;
    if (_disposed) {
      reason = 'session disposed';
    } else if (_integrityFailed || now < _offUntil) {
      reason = 'off after failures';
    } else if (!range.isSatisfiableForm) {
      reason = 'not a single byte range';
    } else if (descriptor.candidates.isEmpty) {
      reason = 'no candidates';
    } else if (total == null) {
      // Port addition: upstream learns the file size from the first response
      // before sending headers to the page; our serve() must return the total
      // up front, so a file of unknown size is left direct.
      reason = 'the file size is unknown';
    } else {
      resolved = range.resolve(total);
      if (resolved == null) {
        reason = 'unsatisfiable range';
      } else {
        requestLast = resolved.last;
        if (resolved.last - resolved.first + 1 > openEndedLegBytes) {
          // mpv 对点播发的是开放末端/超长 Range：不整单拒绝，按棒长分棒
          // 服务；本棒完成后由 _complete 按播放消费水位无缝续棒
          // （spec: 消费驱动预取），预取量始终有界
          resolved = (first: resolved.first, last: resolved.first + openEndedLegBytes - 1);
        }
        if ((_nativeRetry['${descriptor.originalUrl}:${resolved.first}-${resolved.last}'] ?? 0) > now) {
          reason = 'it failed just now';
        }
      }
    }
    if (reason != null || resolved == null || total == null) {
      return null;
    }

    // The player plays this video: warm up what it asks for of the same kind.
    _flushPendingWarmups(descriptor);

    final fileKey = descriptor.originalUrl;
    final indexEnd = _indexEndOf?.call(descriptor);
    final params = _jobParams(
      fileKey: fileKey,
      descriptor: descriptor,
      range: resolved,
      cls: indexEnd != null && resolved.last <= indexEnd ? critical : urgent,
      timeout: 0,
      candidates: descriptor.candidates,
      requestedUrl: descriptor.originalUrl,
    );

    final header = _headers[fileKey];
    if (header != null &&
        resolved.first >= header.range.first &&
        resolved.last <= header.range.last) {
      return _serveFromHeader(header, params, total);
    }

    final sink = ResponseSink();
    final job = _start(params, sink);
    sink
      .._job = job
      .._requestFirst = resolved.first
      .._onCancel = () {
        if (job.state == JobState.running) {
          _stop(job, false);
        }
        if (_pendingSuccessor?.sink == sink) {
          _pendingSuccessor = null;
        }
      };
    if (requestLast != null && requestLast > resolved.last) {
      // 记录下一棒参数（一棒长）：本棒完成后由 _complete 按消费水位续接
      // 同一响应流，逐棒推进到请求末端
      _successorParams[job] = _jobParams(
        fileKey: fileKey,
        descriptor: descriptor,
        range: (
          first: resolved.last + 1,
          last: math.min(requestLast, resolved.last + openEndedLegBytes),
        ),
        cls: params.cls,
        timeout: 0,
        candidates: descriptor.candidates,
        requestedUrl: descriptor.originalUrl,
        chainRequestLast: requestLast,
      );
    }
    return AcceleratedResponse(
      first: resolved.first,
      last: requestLast ?? resolved.last,
      total: total,
      stream: sink.stream,
      onConsumed: (consumedAbsolute) =>
          noteConsumed(fileKey, consumedAbsolute),
    );
  }

  JobParams _jobParams({
    required String fileKey,
    required MediaDescriptor descriptor,
    required ({int first, int last}) range,
    required int cls,
    required int timeout,
    required List<MediaCandidate> candidates,
    required String requestedUrl,
    int? chainRequestLast,
  }) {
    final resolved = <ResolvedCandidate>[];
    final seen = <String>{};
    ResolvedCandidate? requested;
    for (final c in candidates) {
      final r = ResolvedCandidate(c);
      if (seen.add(r.href)) {
        resolved.add(r);
      }
      if (requested == null && c.url == requestedUrl) {
        requested = r;
      }
    }
    if (requested == null) {
      requested = ResolvedCandidate(MediaCandidate(url: requestedUrl, host: Uri.parse(requestedUrl).host));
      resolved.add(requested);
    }
    return JobParams(
      fileKey: fileKey,
      range: range,
      cls: cls,
      timeout: timeout,
      candidates: _byHost(resolved),
      requested: requested,
      requiredRate: (_requiredRateOf?.call(descriptor) ?? 0) / 8000,
      descriptor: descriptor,
      sourceCandidates: candidates,
      chainRequestLast: chainRequestLast,
    );
  }

  // ---- Jobs ----

  Job _start(JobParams params, ResponseSink? sink) {
    final now = _now();
    final length = params.range.last - params.range.first + 1;
    final job = Job(
      fileKey: params.fileKey,
      range: params.range,
      cls: params.cls,
      createdAt: now,
      requiredRate: params.requiredRate,
      length: length,
      timeout: params.timeout,
      candidates: params.candidates,
      requested: params.requested,
      descriptor: params.descriptor,
      chainRequestLast: params.chainRequestLast,
      sink: sink,
    );
    final priorTotal = _totals[params.fileKey];
    job.total = priorTotal;
    _jobs.add(job);

    // No more pieces than the hosts that may carry one alone can take
    final typical = _model.typicalSpeed(params.fileKey);
    final owners = _ownersOf(job, math.min(length, kMiB), now);
    final count = pieceCount(length, typical.rate, typical.ttfb, owners?.length ?? 1);
    // One rescue of each kind per four pieces, up to four
    job.rescuesStraggler = math.min(4, (count / 4).ceil());
    job.rescuesStale = job.rescuesStraggler;
    for (var i = 0; i < count; i++) {
      job.segments.add(
        Segment(
          params.range.first + (length * i / count).floor(),
          params.range.first + (length * (i + 1) / count).floor() - 1,
        ),
      );
    }
    for (var i = 0; i < count; i++) {
      _enqueue(job, job.segments[i]);
    }
    if (count == 1) {
      _race(job);
    } else if (job.segments[count - 1].attempts.isNotEmpty && mayDuplicate(job, now)) {
      // One piece is raced on a host never measured, if any: that measures
      // it, at no risk to the request (`chooseRacer`)
      final seg = job.segments[count - 1];
      if (_eligible(job, seg, true, 0, null).any((option) => !option.estimate.measured)) {
        _duplicate(job, seg, true);
      }
    }
    return job;
  }

  /// Every piece on a few hosts at once: a slow first byte is covered from
  /// the start
  void _race(Job job) {
    for (var i = 0; i < job.segments.length; i++) {
      for (var j = 1; j < raceWidth[job.cls]; j++) {
        _duplicate(job, job.segments[i], true);
      }
    }
  }

  void _stop(Job job, bool done) {
    job.state = done ? JobState.done : JobState.failed;
    _jobs.remove(job);
    _queue.removeWhere((unit) => unit.$1 == job);
    _successorParams.remove(job);
    for (final att in _running.toList()) {
      // Not those already past their end: they finish on their own
      if (att.job == job && att.pos <= att.seg.end) {
        _abortAttempt(att, MediaOutcome.canceled);
      }
    }
  }

  void _complete(Job job) {
    final next = _successorParams.remove(job);
    _stop(job, true);
    final sink = job.sink;
    if (sink != null) {
      // 最后一次写入走的是 _complete 分支（跳过 progress），先冲刷尾部字节
      // 再决定续棒/挂起——否则消费水位永远到不了阈值（挂起死锁）
      sink.flush(job);
      if (next != null) {
        // 开放末端请求的下一棒：同一响应流续写，Content-Range 语义不变；
        // 是否立即启动由播放器消费水位决定（消费驱动预取）
        _continueChain(next, sink);
        return;
      }
      sink.done();
      return;
    }
    final header = _headers[job.fileKey];
    if (header != null && header.bytes == null) {
      header
        ..bytes = Uint8List.fromList(job.bytes)
        ..total = job.total
        ..contentType = job.contentType
        ..settle(true);
    }
  }

  /// Before the response reaches the player the request could be taken back
  /// (upstream: fallbackToNative); here serve() already returned a response,
  /// so failure always surfaces through the stream, and the player's retry of
  /// the range goes direct (`nativeRetry`).
  void _giveUp(Job job, String reason) {
    final now = _now();
    _stop(job, false);
    if (job.sink == null) {
      // A warm-up: nothing to serve from, the request fetches it the normal
      // way
      final header = _headers[job.fileKey];
      if (header != null && header.bytes == null) {
        _headers.remove(job.fileKey);
        header.settle(false);
      }
      return;
    }
    // upstream: recentFailures.filter(at => now - at < 60 * 1000) — keep the
    // failures of the last minute
    _recentFailures.removeWhere((at) => now - at >= 60 * 1000);
    _recentFailures.add(now);
    if (_recentFailures.length >= failuresToTurnOff) {
      _offUntil = now + 30 * 1000;
      _recentFailures.clear();
    }
    _nativeRetry['${job.fileKey}:${job.range.first}-${job.range.last}'] = now + nativeRetryMs;
    if (_pendingSuccessor?.sink == job.sink) {
      _pendingSuccessor = null;
    }
    job.sink!.error();
  }

  /// Stops every job, aborts all attempts, drops pending preloads and
  /// terminates in-flight response streams. Called when the video page
  /// changes or is disposed; the session serves nothing afterwards.
  void dispose() {
    _disposed = true;
    _cancelTicker?.call();
    _cancelTicker = null;
    for (final att in _running.toList()) {
      _abortAttempt(att, MediaOutcome.canceled);
    }
    _running.clear();
    _queue.clear();
    for (final job in _jobs.toList()) {
      job.state = JobState.failed;
      job.sink?.error();
    }
    _jobs.clear();
    _successorParams.clear();
    _consumedByFile.clear();
    _pendingSuccessor = null;
    _pendingWarmups.clear();
    for (final header in _headers.values.toList()) {
      if (header.bytes == null) {
        header.settle(false);
      }
    }
    _headers.clear();
    _busy.clear();
    _nativeRetry.clear();
  }

  // ---- Attempts: one ranged fetch from one host ----

  Future<MediaOutcome> _fetchRange(Attempt att) async {
    final start = att.pos;
    final end = att.seg.end;
    MediaUpstreamResponse response;
    try {
      response = await _transport.open(
        MediaFetchRequest(url: att.candidate.href, start: start, end: end),
        att.controller,
      );
    } catch (e) {
      return classifyError(
        e,
        abortReason: att.controller.abortReason,
        receivedBytes: att.bytes,
        headersReceived: false,
        elapsedMs: _now() - att.startedAt,
      );
    }

    final verdict = classifyResponse(
      status: response.statusCode,
      redirected: response.redirected,
      finalUrl: response.finalUrl,
      contentRange: parseContentRange(response.headers['content-range']?.firstOrNull),
      expected: (
        start: start,
        end: end,
        total: att.job.total,
        addressExpired:
            att.candidate.deadline != 0 && att.candidate.deadline * 1000 <= _wall(),
      ),
    );
    if (verdict.outcome != MediaOutcome.ok) {
      // The browser cancels the unwanted body; we drain it to release the
      // connection.
      discardBody(response);
      return verdict.outcome;
    }
    att.headersAt = _now();
    _commit(att.job, response, verdict.total);

    try {
      await for (final chunk in response.body) {
        final now = _now();
        if (att.firstByteAt == 0) {
          att
            ..firstByteAt = now
            ..firstChunkBytes = chunk.length;
        } else if (att.gaps.length < 256) {
          att.gaps.add(now - att.lastByteAt);
        }
        att.lastByteAt = now;
        _lastDelivery[att.hostname] = now.toDouble();
        att.bytes += chunk.length;
        att.meter.add((now, att.bytes));
        if (att.meter.length > 32) {
          att.meter.removeRange(0, att.meter.length - 32);
        }

        final written = _onChunk(att, chunk);
        if (written == WriteVerdict.mismatch) {
          // Leaving await-for cancels the body subscription (reader.cancel).
          return MediaOutcome.integrity;
        }
        // Past the piece's end (its tail went elsewhere, or the job is over),
        // or all asked for is here
        if (written == WriteVerdict.overrun || att.pos > att.seg.end) {
          att.abortReason ??= MediaOutcome.canceled;
          return att.pos > att.seg.end ? MediaOutcome.ok : MediaOutcome.canceled;
        }
      }
    } catch (e) {
      return classifyError(
        e,
        abortReason: att.controller.abortReason,
        receivedBytes: att.bytes,
        headersReceived: true,
        elapsedMs: _now() - att.startedAt,
      );
    }
    return att.pos > att.seg.end ? MediaOutcome.ok : MediaOutcome.truncated;
  }

  /// 上游直接 cancel body；我们的传输要消费完才能复用底层连接，但异常
  /// 主机可能把整个文件灌下来——排水设上限（约 1 MiB / 2 s），到限即断。
  @visibleForTesting
  static void discardBody(MediaUpstreamResponse response) {
    var received = 0;
    response.body
        .takeWhile((chunk) {
          received += chunk.length;
          return received <= discardCapBytes;
        })
        .timeout(
          const Duration(seconds: 2),
          onTimeout: (sink) => sink.close(),
        )
        .drain<void>()
        .ignore();
  }

  /// The first validated response fixes the file's size for everyone.
  void _commit(Job job, MediaUpstreamResponse response, int? total) {
    if (total != null && job.total == null) {
      job.total = total;
      _totals[job.fileKey] = total;
    }
    if (job.committed || job.state != JobState.running) {
      return;
    }
    job
      ..committed = true
      ..contentType = response.headers['content-type']?.firstOrNull ?? '';
    // Upstream pushes the 206 headers to the page here; our response object
    // was already handed out by serve(), so there is nothing left to send.
  }

  WriteVerdict _onChunk(Attempt att, List<int> chunk) {
    final job = att.job;
    final seg = att.seg;
    _model.noteBytes(_now());
    final result = writeChunk(job, att, chunk, _now());
    if (result != WriteVerdict.mismatch && job.state == JobState.running) {
      if (seg.frontier > seg.end) {
        // The race is over for this piece
        for (final other in seg.attempts.toList()) {
          if (other != att) {
            _abortAttempt(other, MediaOutcome.canceled);
          }
        }
      }
      if (job.segments.every((piece) => piece.frontier > piece.end)) {
        _complete(job);
      } else {
        job.sink?.progress();
      }
    }
    return result;
  }

  ///
  /// Take a chunk an attempt received. Every attempt starts at or below its
  /// piece's frontier and the frontier only moves forward, so a piece always
  /// holds a contiguous run: bytes below the frontier were written by another
  /// attempt and are compared instead, bytes above it are written.
  ///
  /// - `overrun`: the attempt is past its piece's end (the piece is done or
  ///   shrunk), stop it
  /// - `mismatch`: two responses disagree about the file's content
  static WriteVerdict writeChunk(Job job, Attempt att, List<int> chunk, int now) {
    final seg = att.seg;
    final pos = att.pos;
    final usable = job.state == JobState.running ? math.min(chunk.length, seg.end + 1 - pos) : 0;
    if (usable <= 0) {
      return WriteVerdict.overrun;
    }
    final base = job.range.first;
    final duplicateEnd = math.min(pos + usable, seg.frontier);
    for (var offset = pos; offset < duplicateEnd; offset++) {
      if (job.bytes[offset - base] != chunk[offset - pos]) {
        return WriteVerdict.mismatch;
      }
    }
    if (pos + usable > seg.frontier) {
      final freshLen = pos + usable - seg.frontier;
      job.bytes.setRange(seg.frontier - base, seg.frontier - base + freshLen, chunk, seg.frontier - pos);
      job.covered += freshLen;
      seg.frontier = pos + usable;
      seg.tried.clear();
      job.lastProgressAt = now;
      // One sample at or before the window's start stays, see `deliveredRate`
      final meter = job.meter
        ..add((now, job.covered));
      var stale = 0;
      while (stale < meter.length - 1 && meter[stale + 1].$1 <= now - rateWindowMs) {
        stale++;
      }
      meter.removeRange(0, stale);
    }
    att.pos = pos + usable;
    return usable < chunk.length ? WriteVerdict.overrun : WriteVerdict.ok;
  }

  void _onAttemptEnd(Attempt att, MediaOutcome outcome) {
    final job = att.job;
    final seg = att.seg;
    if (outcome == MediaOutcome.integrity) {
      _integrityFailed = true;
      if (job.state == JobState.running) {
        _giveUp(job, 'integrity');
      }
      return;
    }
    if (job.state != JobState.running || seg.frontier > seg.end || seg.queued) {
      return;
    }
    if (seg.attempts.isNotEmpty) {
      // A racer is still on the piece. It covers a lost race, but not a
      // failed primary: left to a racer on a worse host, the piece would
      // crawl. A fresh primary joins, settling keeps the one ahead
      if (att.role == 'primary' && isRetryable(outcome) && !seg.isFinal && ++seg.tries < maxTries) {
        _enqueue(job, seg);
      }
      return;
    }
    if (outcome != MediaOutcome.canceled && !isRetryable(outcome)) {
      _giveUp(job, outcome.wire);
      return;
    }
    if (seg.isFinal) {
      _giveUp(job, "the player's own URL failed as well: ${outcome.wire}");
      return;
    }
    // Canceled by us (a race settled, a tail split off) is no failure of the
    // piece
    if (outcome != MediaOutcome.canceled) {
      seg.tries++;
    }
    if (seg.tries >= maxTries) {
      if (!job.committed) {
        _giveUp(job, 'a piece failed ${seg.tries} times, last: ${outcome.wire}');
        return;
      }
      seg.isFinal = true;
    }
    _enqueue(job, seg);
  }

  /// What the attempt's end says about its host, into the host model
  void _learn(Attempt att, MediaOutcome outcome) {
    final hostname = att.hostname;
    final job = att.job;
    final now = _now();
    // A slow first byte or a stall on a host that delivered just now is that
    // request's, not the host's
    _model.recordOutcome(
      hostname,
      job.fileKey,
      addressKey: att.candidate.key,
      family: att.candidate.family,
      outcome: outcome,
      now: now,
      alive: now - (_lastDelivery[hostname] ?? double.negativeInfinity) < aliveMs,
    );

    final received = att.bytes - att.firstChunkBytes;
    final delivered = outcome == MediaOutcome.ok || outcome == MediaOutcome.canceled;
    final rate = delivered && received >= minSample && att.lastByteAt > att.firstByteAt
        ? received / (att.lastByteAt - att.firstByteAt)
        : null;

    // No validated response yet: what it waited is a lower bound of its first
    // byte. A racer canceled before it waited as long as requests usually
    // take says nothing
    final waited = now - att.startedAt;
    double? ttfb = att.headersAt == 0 ? null : (att.headersAt - att.startedAt).toDouble();
    if (ttfb == null && outcome == MediaOutcome.canceled && waited > _model.typicalSpeed(job.fileKey).ttfb) {
      ttfb = waited.toDouble();
    }
    _model.recordSpeed(
      hostname,
      job.fileKey,
      ttfb: ttfb,
      rate: rate,
      partial: outcome != MediaOutcome.ok || att.bytes < fullSample,
      gap: att.gaps.isEmpty ? null : percentile([for (final g in att.gaps) g.toDouble()], 90),
    );
  }

  // ---- Scheduling ----

  void _enqueue(Job job, Segment seg) {
    if (!seg.queued) {
      seg.queued = true;
      _queue.add((job, seg));
      _ensureTicker();
      _pump();
    }
  }

  /// Start what waits, most urgent first, as slots and hosts allow
  void _pump() {
    if (_pumping) {
      return;
    }
    _pumping = true;
    try {
      final blocked = <Segment>{};
      for (;;) {
        var next = -1;
        for (var i = 0; i < _queue.length; i++) {
          if (!blocked.contains(_queue[i].$2) && (next == -1 || before(_queue[i].$1, _queue[next].$1))) {
            next = i;
          }
        }
        if (next == -1 || !_hasSlot(_queue[next].$1)) {
          break;
        }
        final (job, seg) = _queue[next];
        HostOption? target;
        if (job.state == JobState.running && seg.frontier <= seg.end) {
          target = seg.isFinal ? _ownUrl(job) : _pickHost(job, seg, null);
          if (target == null) {
            blocked.add(seg);
            continue;
          }
        }
        _queue.removeAt(next);
        seg.queued = false;
        if (target != null) {
          _launch(job, seg, seg.isFinal ? 'final' : 'primary', target);
        }
      }
    } finally {
      _pumping = false;
    }
  }

  /// Within `globalCap`, leaving room for what is urgent
  bool _hasSlot(Job job) {
    if (job.cls != relaxed) {
      return _running.length < globalCap;
    }
    var warming = 0;
    for (final att in _running) {
      if (att.job.cls == relaxed) {
        warming++;
      }
    }
    return warming < warmupCap && _running.length < globalCap - urgentReserve;
  }

  ///
  /// Race a piece on a host not already on it, if one has room: on one
  /// connection a hung request hangs every request to its host. To `explore`,
  /// a host never measured first; else (a rescue) the fastest measured one
  /// first
  bool _duplicate(Job job, Segment seg, bool explore) {
    final target =
        seg.extra < maxExtra && _hasSlot(job) ? _pickHost(job, seg, explore ? RacerKind.explore : RacerKind.rescue) : null;
    if (target != null) {
      seg.extra++;
      _launch(job, seg, 'dup', target);
    }
    return target != null;
  }

  void _launch(Job job, Segment seg, String role, HostOption target) {
    final att = Attempt(
      job: job,
      seg: seg,
      hostname: target.hostname,
      candidate: target.candidate,
      role: role,
      controller: MediaAbortHandle(),
      // A few times what the host usually takes
      ttfbSoft: _clamp(2 * target.estimate.ttfb, 250, 1200),
      stallSoft: target.estimate.gap == null ? 600 : _clamp(4 * target.estimate.gap!, 300, 1000),
      startedAt: _now(),
      probe: !target.estimate.measured,
    );
    _rotation++;
    _busy[target.hostname] = (_busy[target.hostname] ?? 0) + 1;
    _running.add(att);
    seg.attempts.add(att);
    seg.tried.add(target.hostname);
    _ensureTicker();

    unawaited(() async {
      MediaOutcome outcome;
      try {
        outcome = await _fetchRange(att);
      } catch (_) {
        outcome = MediaOutcome.network; // attempt crashed
      }
      _busy.update(att.hostname, (v) => v - 1, ifAbsent: () => 0);
      _running.remove(att);
      seg.attempts.remove(att);
      _learn(att, outcome);
      try {
        _onAttemptEnd(att, outcome);
      } finally {
        _pump();
      }
    }());
  }

  void _abortAttempt(Attempt att, AbortReason reason) {
    if (att.abortReason == null) {
      att.abortReason = reason;
      att.controller.abort(reason);
    }
  }

  /// Every `tickMs` while there is work
  void _tick() {
    final now = _now();
    for (final att in _running.toList()) {
      // A slow first byte is never given up on: an edge without the file is
      // pulling it from upstream, and another one would start over. Its
      // racer takes over once that one delivers (`settleRace`)
      if (att.abortReason != null || att.firstByteAt == 0) {
        continue;
      }
      // Gone silent after bytes flowed, and so has its host: one silent
      // while the host delivers to its other requests only waits its turn on
      // their shared connection, and its racer takes over (`settleRace`).
      // Only when something else can carry its bytes, else the piece would
      // only go to whatever racer is on it, there because it was the worse
      // choice
      final job = att.job;
      final seg = att.seg;
      final silence = 2 * att.stallSoft * urgencyFactor[job.cls];
      if (now - att.lastByteAt > silence &&
          now - (_lastDelivery[att.hostname] ?? double.negativeInfinity) > silence &&
          (seg.attempts.length > 1 || _hasAlternative(job, seg, now) || now - att.startedAt > jobStallMs)) {
        _abortAttempt(att, MediaOutcome.stall);
      }
    }

    _flushPendingSuccessor();
    try {
      for (final job in _jobs.toList()) {
        _tickJob(job, now);
      }
      if (_queue.isEmpty && _running.length < globalCap) {
        _endgame(now);
      }
    } catch (_) {
      // (upstream logs 'tick failed'; the session keeps serving)
    }
    // Hosts cool down and slots free up: what waits may go now
    _pump();

    if (_running.isEmpty && _queue.isEmpty && _jobs.isEmpty) {
      _cancelTicker?.call();
      _cancelTicker = null;
    }
  }

  void _tickJob(Job job, int now) {
    if (!job.committed) {
      // Never hand back while a host is left to try, except to leave the
      // other half of the player's own timeout
      if (now - job.createdAt > (job.timeout > 0 ? job.timeout / 2 : commitTimeoutMs)) {
        _giveUp(job, 'no CDN host answered in time');
        return;
      }
    } else if (now - job.lastProgressAt > jobStallMs) {
      // Unfinished pieces go to the player's own URL; if they went there
      // already, the job fails
      final stuck = job.segments.where((seg) => seg.frontier <= seg.end && !seg.isFinal).toList();
      if (stuck.isEmpty) {
        _giveUp(job, 'no progress');
        return;
      }
      for (var i = 0; i < stuck.length; i++) {
        stuck[i].isFinal = true;
        for (final att in stuck[i].attempts.toList()) {
          _abortAttempt(att, MediaOutcome.stall);
        }
        _enqueue(job, stuck[i]);
      }
      job.lastProgressAt = now;
      return;
    }

    final typical = _model.typicalSpeed(job.fileKey);
    final slack = hedgeSlack(typical.ttfb);
    for (var i = 0; i < job.segments.length; i++) {
      final seg = job.segments[i];
      if (seg.frontier > seg.end) {
        continue;
      }
      if (seg.attempts.length > 1) {
        _settleRace(seg);
        // Every request on it still waits for a first byte: one more host
        // races it
        Attempt? newest;
        var waiting = true;
        for (final att in seg.attempts) {
          waiting = waiting && att.firstByteAt == 0 && att.abortReason == null;
          if (newest == null || att.startedAt > newest.startedAt) {
            newest = att;
          }
        }
        if (waiting && newest != null && job.cls != relaxed && _isStuck(newest, now)) {
          _rescue(newest, now);
        }
        continue;
      }
      final att = seg.attempts.isEmpty ? null : seg.attempts.first;
      if (att == null || att.abortReason != null) {
        continue;
      }
      // No first byte yet, or it stopped: another host may do better at once
      if (job.cls != relaxed && _isStuck(att, now)) {
        _rescue(att, now);
      } else {
        final relief = needsRelief(att, now, typical.rate, () => _alternativeOf(job, seg), slack);
        final started = relief != null && _relieve(att, now);
        if (started && relief != ReliefKind.help) {
          if (relief == ReliefKind.straggler) {
            job.rescuesStraggler--;
          } else {
            job.rescuesStale--;
          }
        }
      }
    }
  }

  /// No first byte, or silent after bytes flowed, past its soft threshold
  bool _isStuck(Attempt att, int now) {
    final factor = urgencyFactor[att.job.cls];
    return att.firstByteAt == 0
        ? now - att.startedAt >= att.ttfbSoft * factor
        : now - att.lastByteAt >= att.stallSoft * factor;
  }

  /// A racer on another host for a stuck request's piece
  void _rescue(Attempt att, int now) {
    _duplicate(att.job, att.seg, false);
  }

  ///
  /// A race is for the first byte. Once both racers are receiving, the one
  /// behind only competes with the leader for the same line and bytes: it
  /// goes, whatever the speeds. One still without a first byte goes once the
  /// leader has `laggardBytes`
  void _settleRace(Segment seg) {
    Attempt? leader;
    for (final att in seg.attempts) {
      if (leader == null || att.pos > leader.pos) {
        leader = att;
      }
    }
    for (final att in seg.attempts.toList()) {
      if (att != leader &&
          (!att.probe || att.bytes >= probeBytes) &&
          (att.firstByteAt == 0 ? leader!.bytes >= laggardBytes : att.pos < leader!.pos)) {
        _abortAttempt(att, MediaOutcome.canceled);
      }
    }
  }

  /// Free slots and nothing waiting: the piece with the most time left is
  /// relieved
  void _endgame(int now) {
    Attempt? slowest;
    var slowestMs = 0.0;
    final etas = <double>[];
    for (final att in _running) {
      final job = att.job;
      final seg = att.seg;
      if (job.state != JobState.running ||
          seg.attempts.length != 1 ||
          att.abortReason != null ||
          seg.frontier > seg.end) {
        continue;
      }
      final rate = recentRate(att, now);
      final ms = rate > 0 ? (seg.end - seg.frontier + 1) / rate : double.infinity;
      etas.add(ms);
      if (slowest == null || ms > slowestMs) {
        slowest = att;
        slowestMs = ms;
      }
    }
    // A piece too small to cut is raced only when well behind the others, or
    // late
    if (slowest != null &&
        (slowest.seg.end - slowest.seg.frontier + 1 >= 2 * stealMin ||
            slowestMs > math.max(300.0, 1.3 * percentile(etas, 50)) ||
            now + slowestMs >
                slowest.job.deadline - hedgeSlack(_model.typicalSpeed(slowest.job.fileKey).ttfb))) {
      _relieve(slowest, now);
    }
  }

  ///
  /// A piece's tail goes to an owner, cut so both finish together; one that
  /// cannot be cut is raced
  ///
  /// @returns whether help started
  bool _relieve(Attempt att, int now) {
    final job = att.job;
    final seg = att.seg;
    final target =
        seg.end - seg.frontier + 1 >= 2 * stealMin && _hasSlot(job) ? _pickHost(job, seg, null) : null;
    final at = target != null ? splitPoint(seg, recentRate(att, now), target.estimate) : null;
    if (target != null && at != null) {
      final tail = Segment(at, seg.end);
      seg.end = at - 1;
      job.segments.add(tail);
      _launch(job, tail, 'primary', target);
      return true;
    }
    if (mayDuplicate(job, now) && _duplicate(job, seg, true)) {
      job.lastDuplicate = (now, deliveredRate(job, now));
      return true;
    }
    return false;
  }

  // ---- Hosts ----

  ///
  /// Where a piece goes. A primary (`racer` null) only to a host that may
  /// carry it alone (`ownersOf`), relaxed work anywhere, to explore; a racer
  /// anywhere it is not running already (`chooseRacer`). Hosts not tried
  /// since the piece last made progress first
  HostOption? _pickHost(Job job, Segment seg, RacerKind? racer) {
    final bytes = seg.end - seg.frontier + 1;
    final dup = racer != null;
    final owners = dup || job.cls == relaxed ? null : _ownersOf(job, bytes, _now());
    final all = _eligible(job, seg, dup, bytes, owners);
    final untried = all.where((option) => !seg.tried.contains(option.hostname)).toList();
    final options = untried.isEmpty ? all : untried;
    if (options.isEmpty) {
      return null;
    }
    final chosen = racer == null ? _choosePrimary(options, job, bytes) : _chooseRacer(options, racer == RacerKind.explore);
    if (seg.tried.contains(chosen.hostname)) {
      // Every usable host was tried: a new round starts with this one
      seg.tried.clear();
    }
    return chosen;
  }

  /// The host a racer exploring for the piece would go to
  HostEstimate? _alternativeOf(Job job, Segment seg) {
    final options = _eligible(job, seg, true, seg.end - seg.frontier + 1, null);
    return options.isNotEmpty ? _chooseRacer(options, true).estimate : null;
  }

  bool _hasAlternative(Job job, Segment seg, int now) {
    return _eligible(job, seg, true, seg.end - seg.frontier + 1, null, now).isNotEmpty;
  }

  /// Hosts with room that could take the piece now, of `only` if given, not
  /// those on it when `avoidPiece`
  List<HostOption> _eligible(
    Job job,
    Segment seg,
    bool avoidPiece,
    int bytes,
    Set<String>? only, [
    int? nowOverride,
  ]) {
    final now = nowOverride ?? _now();
    final nowSec = _wall() / 1000;
    final loads = _hostLoads(now);
    final options = <HostOption>[];
    for (final entry in job.candidates.entries) {
      final hostname = entry.key;
      final listed = entry.value;
      final active = _busy[hostname] ?? 0;
      if (active >= hostCap ||
          (only != null && !only.contains(hostname)) ||
          _model.isCoolingDown(hostname, now)) {
        continue;
      }
      var onPiece = false;
      for (final att in seg.attempts) {
        onPiece = onPiece || att.hostname == hostname;
      }
      final candidate = avoidPiece && onPiece ? null : _pickCandidate(hostname, listed, job.fileKey, now, nowSec);
      if (candidate != null) {
        options.add(
          HostOption(
            hostname: hostname,
            candidate: candidate,
            estimate: withLoad(_model.estimate(hostname, job.fileKey, bytes), loads[hostname], bytes),
            active: active,
          ),
        );
      }
    }
    return options;
  }

  ///
  /// The hosts a piece of `bytes` may go to on its own, busy or not: the
  /// measured ones expected to finish it within `etaBand` of the best. `null`
  /// when none is measured: any host may take it
  Set<String>? _ownersOf(Job job, int bytes, int now) {
    final nowSec = _wall() / 1000;
    final loads = _hostLoads(now);
    final measured = <(String, double)>[];
    var best = double.infinity;
    for (final entry in job.candidates.entries) {
      if (_model.isCoolingDown(entry.key, now) ||
          _pickCandidate(entry.key, entry.value, job.fileKey, now, nowSec) == null) {
        continue;
      }
      final estimate =
          withLoad(_model.estimate(entry.key, job.fileKey, bytes), loads[entry.key], bytes);
      if (estimate.measured) {
        measured.add((entry.key, estimate.eta));
        best = math.min(best, estimate.eta);
      }
    }
    final owners = <String>{};
    for (var i = 0; i < measured.length; i++) {
      if (measured[i].$2 <= best * etaBand) {
        owners.add(measured[i].$1);
      }
    }
    return owners.isNotEmpty ? owners : null;
  }

  /// hostname -> (its requests receiving, the bytes per ms they get together)
  Map<String, (int, double)> _hostLoads(int now) {
    final loads = <String, (int, double)>{};
    for (final att in _running) {
      if (att.firstByteAt != 0 && att.abortReason == null) {
        final load = loads[att.hostname] ?? (0, 0.0);
        loads[att.hostname] = (load.$1 + 1, load.$2 + recentRate(att, now));
      }
    }
    return loads;
  }

  /// For one host: the signature it served last, else one of a family it
  /// accepts, else any, in turn
  ResolvedCandidate? _pickCandidate(String hostname, List<ResolvedCandidate> listed, String fileKey, int now, double nowSec) {
    final proven = _model.provenAddress(hostname);
    final usable = <ResolvedCandidate>[];
    for (var i = 0; i < listed.length; i++) {
      if (_isCandidateUsable(listed[i], fileKey, now, nowSec)) {
        if (listed[i].key == proven) {
          return listed[i];
        }
        usable.add(listed[i]);
      }
    }
    final accepted = usable.where((candidate) => _model.acceptsFamily(hostname, candidate.family)).toList();
    final list = accepted.isNotEmpty ? accepted : usable;
    return list.isNotEmpty ? list[_rotation % list.length] : null;
  }

  /// Not banned, not about to expire, and this host neither refuses its
  /// signature nor lacks the file (candidates.ts `isCandidateUsable`)
  bool _isCandidateUsable(ResolvedCandidate candidate, String fileKey, int now, double nowSec) {
    return !_model.isAddressBanned(candidate.key) &&
        (candidate.deadline == 0 || (candidate.deadline - nowSec) * 1000 > deadlineMarginMs) &&
        !_model.isFamilyRefused(candidate.hostname, candidate.family, now) &&
        !_model.isExcluded(candidate.hostname, fileKey, now);
  }

  ///
  /// Among the hosts that may carry a piece: before anything is measured (and
  /// for relaxed work, exploring) the least busy unmeasured one; a small
  /// piece, or a request in one piece, to the one expected to finish first;
  /// otherwise the least busy
  HostOption _choosePrimary(List<HostOption> options, Job job, int bytes) {
    final unmeasured = options.where((option) => !option.estimate.measured).toList();
    if (unmeasured.length == options.length || (job.cls == relaxed && unmeasured.isNotEmpty)) {
      return _leastBusy(_preferred(unmeasured));
    }
    return bytes < smallPiece || job.segments.length == 1 ? _fastest(options) : _leastBusy(options);
  }

  ///
  /// Among hosts nothing is measured on yet: the addresses the playinfo
  /// issued for this file first (upstream `preferred`: listed mirror, then
  /// listed bcache), then the signatures moved onto other hosts, last the
  /// rest. Mirror and bcache hosts are peers at every step
  List<HostOption> _preferred(List<HostOption> options) {
    final listed = options.where((option) => option.candidate.tier.rank <= CandidateTier.listedBcache.rank).toList();
    if (listed.isNotEmpty) {
      return listed;
    }
    final moved = options.where((option) => option.candidate.tier.rank <= CandidateTier.bcache.rank).toList();
    return moved.isNotEmpty ? moved : options;
  }

  ///
  /// A host never measured is unknown: its speed depends on whether its edge
  /// has the file and on the path to it, so it is never ranked against
  /// measured ones. To `explore`, such a host first (the addresses the
  /// playinfo listed, then the least busy); else the fastest measured one
  /// first
  HostOption _chooseRacer(List<HostOption> options, bool explore) {
    final untested = options.where((option) => !option.estimate.measured).toList();
    final measured = options.where((option) => option.estimate.measured).toList();
    if (untested.isNotEmpty && (explore || measured.isEmpty)) {
      return _leastBusy(_preferred(untested));
    }
    return _fastest(measured);
  }

  HostOption _leastBusy(List<HostOption> options) {
    return options.reduce(
      (best, option) =>
          option.active < best.active || (option.active == best.active && option.estimate.eta < best.estimate.eta)
              ? option
              : best,
    );
  }

  HostOption _fastest(List<HostOption> options) {
    return options.reduce((best, option) => option.estimate.eta < best.estimate.eta ? option : best);
  }

  /// The player's own URL, the last resort, within its host's slots
  HostOption? _ownUrl(Job job) {
    final hostname = job.requested.hostname;
    final active = _busy[hostname] ?? 0;
    return active < hostCap
        ? HostOption(
            hostname: hostname,
            candidate: job.requested,
            estimate: _model.estimate(hostname, job.fileKey, 0),
            active: active,
          )
        : null;
  }

  // ---- Warm-up: every representation's init segment and index, ahead of the
  // player ----

  /// Kept until the player asks for the video (upstream `onPlayinfo`, keyed
  /// per video; this session is one video).
  void registerPreload(List<PreloadSpec> specs) {
    if (specs.isEmpty) {
      return;
    }
    _pendingWarmups.addAll(specs);
    if (_pendingWarmups.length > maxPendingWarmups) {
      _pendingWarmups.removeRange(0, _pendingWarmups.length - maxPendingWarmups);
    }
  }

  /// Consumes the pending preloads of the kind the player asked for (upstream
  /// splits by kind and codec family; only the kind is known here — the
  /// codec is not part of the session's contracts, so same-kind files are
  /// warmed).
  void _flushPendingWarmups(MediaDescriptor descriptor) {
    if (_pendingWarmups.isEmpty) {
      return;
    }
    final alike = <PreloadSpec>[];
    final rest = <PreloadSpec>[];
    for (var i = 0; i < _pendingWarmups.length; i++) {
      (_pendingWarmups[i].descriptor.isAudio == descriptor.isAudio ? alike : rest).add(_pendingWarmups[i]);
    }
    _pendingWarmups
      ..clear()
      ..addAll(rest);
    warmUp(alike);
  }

  void warmUp(List<PreloadSpec> specs) {
    final now = _now();
    for (var i = 0; i < specs.length; i++) {
      final spec = specs[i];
      if (spec.indexEnd < 0 || _headers.containsKey(spec.key)) {
        continue;
      }
      final resolved = <ResolvedCandidate>[];
      final seen = <String>{};
      for (final c in spec.descriptor.candidates) {
        final r = ResolvedCandidate(c);
        if (seen.add(r.href)) {
          resolved.add(r);
        }
      }
      if (resolved.isEmpty) {
        continue;
      }
      // Its own last resort, as the player would pick it
      final requested = _defaultCandidate(resolved, spec.key, now);
      if (requested == null) {
        continue;
      }
      final range = (first: 0, last: spec.indexEnd);
      // Nothing ends synchronously: the entry is there before the job is over
      final job = _start(
        JobParams(
          fileKey: spec.key,
          range: range,
          cls: relaxed,
          timeout: 0,
          candidates: _byHost(resolved),
          requested: requested,
          descriptor: spec.descriptor,
          sourceCandidates: resolved.map((r) => r.listed).toList(),
          chainRequestLast: null,
          requiredRate: (_requiredRateOf?.call(spec.descriptor) ?? 0) / 8000,
        ),
        null,
      );
      _headers[spec.key] = _CachedHeader(range: range, job: job);
      if (_headers.length > maxHeaders) {
        _headers.remove(_headers.keys.first);
      }
    }
  }

  /// A usable candidate of the lowest tier, at random, on a host not cooling
  /// down if there is one: what the player fetches when the requested URL is
  /// not acceptable (candidates.ts `defaultCandidate`)
  ResolvedCandidate? _defaultCandidate(List<ResolvedCandidate> candidates, String fileKey, int now) {
    final nowSec = _wall() / 1000;
    final usable = candidates.where((c) => _isCandidateUsable(c, fileKey, now, nowSec)).toList();
    final available = usable.where((c) => !_model.isCoolingDown(c.hostname, now)).toList();
    final options = available.isNotEmpty ? available : usable;
    if (options.isEmpty) {
      return null;
    }
    var best = options.first.tier.rank;
    for (final o in options) {
      if (o.tier.rank < best) {
        best = o.tier.rank;
      }
    }
    final bests = options.where((o) => o.tier.rank == best).toList();
    return bests[_random.nextInt(bests.length)];
  }

  /// A request inside the init and index fetched ahead: served from them, as
  /// a copy
  AcceleratedResponse _serveFromHeader(_CachedHeader header, JobParams params, int total) {
    final length = params.range.last - params.range.first + 1;
    var aborted = false;
    final controller = StreamController<List<int>>(
      onCancel: () {
        aborted = true;
      },
    );
    unawaited(() async {
      try {
        final waitedFrom = _now();
        final job = header.job;
        // The player asks for what a warm-up is still fetching: it becomes
        // critical, and is raced
        if (job.cls != critical && job.state == JobState.running) {
          job
            ..cls = critical
            ..deadline = waitedFrom;
          _race(job);
        }
        // `ready` resolves true exactly when the bytes are there
        final ok = header.bytes != null || await _waitForHeader(header);
        if (aborted) {
          return;
        }
        if (!ok) {
          final sink = ResponseSink();
          final fresh = _start(params, sink);
          sink
            .._job = fresh
            .._onCancel = () {
              if (fresh.state == JobState.running) {
                _stop(fresh, false);
              }
            };
          await controller.addStream(sink.stream);
          // addStream 不负责关闭：这里必须显式收口，否则代理侧请求悬挂
          if (!controller.isClosed) {
            await controller.close();
          }
          return;
        }
        final body = Uint8List.sublistView(
          header.bytes!,
          params.range.first - header.range.first,
          params.range.first - header.range.first + length,
        );
        controller.add(body);
        await controller.close();
      } catch (_) {
        if (!aborted && !controller.isClosed) {
          controller.addError(StateError('thread-ripper: failed to serve from the warm-up'));
          await controller.close();
        }
      }
    }());
    return AcceleratedResponse(
      first: params.range.first,
      last: params.range.last,
      total: total,
      stream: controller.stream,
    );
  }

  /// `header.ready` vs `wait(warmupWaitMs) -> false`.
  Future<bool> _waitForHeader(_CachedHeader header) {
    final c = Completer<bool>();
    unawaited(
      header.ready.future.then((v) {
        if (!c.isCompleted) {
          c.complete(v);
        }
      }),
    );
    unawaited(
      _delay(warmupWaitMs).then((_) {
        if (!c.isCompleted) {
          c.complete(false);
        }
      }),
    );
    return c.future;
  }

  Map<String, List<ResolvedCandidate>> _byHost(List<ResolvedCandidate> candidates) {
    final grouped = <String, List<ResolvedCandidate>>{};
    for (var i = 0; i < candidates.length; i++) {
      grouped.putIfAbsent(candidates[i].hostname, () => []).add(candidates[i]);
    }
    return grouped;
  }

  // ---- Test/inspection seams ----

  void _ensureTicker() {
    if (_cancelTicker == null) {
      final hook = _tickerHook;
      if (hook != null) {
        hook(_tick);
      } else {
        final timer = Timer.periodic(const Duration(milliseconds: tickMs), (_) => _tick());
        _cancelTicker = timer.cancel;
      }
    }
  }

  @visibleForTesting
  int get pendingPreloadCount => _pendingWarmups.length;

  /// 会话内已学到的文件总大小（warmup/首个响应写入）；未知为 null。
  /// 加速器据此判断 serve 能否立即接受未知 totalSize 的 descriptor。
  int? knownTotal(String fileKey) => _totals[fileKey];

  @visibleForTesting
  int get runningCount => _running.length;

  @visibleForTesting
  int busyCount(String hostname) => _busy[hostname] ?? 0;

  @visibleForTesting
  void tickForTest() => _tick();
}

/// Everything `start` needs for one job (engine.ts `JobParams`).
class JobParams {
  const JobParams({
    required this.fileKey,
    required this.range,
    required this.cls,
    required this.timeout,
    required this.candidates,
    required this.requested,
    required this.requiredRate,
    required this.descriptor,
    required this.sourceCandidates,
    this.chainRequestLast,
  });

  final String fileKey;
  final ({int first, int last}) range;
  final int cls;
  final int timeout;
  final Map<String, List<ResolvedCandidate>> candidates;
  final ResolvedCandidate requested;

  /// 原始描述符与候选地址列表：开放末端请求分棒续链时重建下一棒参数用
  final MediaDescriptor descriptor;
  final List<MediaCandidate> sourceCandidates;

  /// 分棒链的请求末端（含）：本棒完成后续下一棒直到该值；null 表示非链式
  final int? chainRequestLast;

  /// What the stream needs, bytes per ms (upstream: `file.bandwidth / 8000`).
  final double requiredRate;
}
