/// How a media request ended, from the point of view of its host, address and
/// file. 1:1 port of the upstream `MediaOutcome` enum
/// (src/core/player/host-model.ts).
library;

enum MediaOutcome {
  /// Validated 206, complete
  ok('ok'),

  /// Aborted by us: race lost, piece done elsewhere, job over
  canceled('canceled'),

  /// Validated 206, but the body ended early
  truncated('truncated'),

  /// Validated 206, then the connection broke
  reset('reset'),

  badRange('bad-range'),

  /// The file's total size differs from what other hosts said: another
  /// version of the file
  staleObject('stale-object'),

  /// The request reaches past the end of the file
  eofClamp('eof-clamp'),

  /// 206 without a readable Content-Range
  unverifiable('unverifiable'),

  /// 200: Range ignored
  noRange('no-range'),

  /// Redirected off to a P2P CDN
  redirect('redirect'),

  /// 401 / 403 with a signature past its deadline
  expired('expired'),

  /// 401 / 403
  refused('refused'),

  /// 404 / 410
  missing('missing'),

  /// 412 / 429 / 503
  throttled('throttled'),

  serverError('server-error'),

  /// Connection-level failure before any header, fast: DNS / TLS
  connectFail('connect-fail'),

  /// Connection-level failure before any header
  network('network'),

  stall('stall'),

  /// Two hosts sent different bytes for the same range
  integrity('integrity');

  const MediaOutcome(this.wire);

  /// The upstream enum's string value, kept for log/debug parity.
  final String wire;
}

/// Why we aborted an attempt ourselves. Upstream narrows this to
/// `MediaOutcome.Canceled | MediaOutcome.Stall` (classify.ts `AbortReason`);
/// Dart has no union types, so the same values flow through [MediaOutcome].
typedef AbortReason = MediaOutcome;
