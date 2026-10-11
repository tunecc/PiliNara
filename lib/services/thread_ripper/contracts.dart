/// Shared contracts for the Thread Ripper feature.
///
/// The loopback media proxy (media_proxy_server.dart) and the download
/// accelerator (scheduler.dart) meet here. The proxy owns URL/Range parsing;
/// the accelerator owns chunked multi-CDN fetching. A `MediaAccelerator`
/// returning null always means "fall back to direct pass-through".
library;

/// One CDN host offering the same media file.
class MediaCandidate {
  const MediaCandidate({required this.url, required this.host});

  /// Full https URL of the media file on this host.
  final String url;

  /// Host name of [url] (used for per-host bookkeeping).
  final String host;
}

/// Everything known about one media stream (video or audio) of the playing
/// video. Registered with the session before the player opens the URL.
class MediaDescriptor {
  const MediaDescriptor({
    required this.originalUrl,
    required this.candidates,
    required this.isAudio,
    this.totalSize,
    this.contentType,
    this.bandWidth,
    this.indexEnd,
  });

  /// The URL the player would have used without Thread Ripper (after Bilibili
  /// playinfo resolution, before any CDN host replacement). Always fetchable
  /// directly; used as the fallback path in proxy URLs.
  final String originalUrl;

  /// All candidate hosts for this file (playinfo `baseUrl`/`backupUrl`
  /// variants and CDN pool rewrites). The first entry should be
  /// [originalUrl]'s own.
  final List<MediaCandidate> candidates;

  final bool isAudio;

  /// Expected file size when known from the playinfo, null otherwise.
  final int? totalSize;

  /// MIME type from the playinfo when known (DASH `mimeType`), echoed on
  /// accelerated responses so the player cannot tell them apart.
  final String? contentType;

  /// Declared bitrate in bits per second (DASH `bandwidth`) when known;
  /// drives the racer saturation rules (stop when buffered ≥ 8× bitrate).
  final int? bandWidth;

  /// Last byte offset of the stream's segment index (`segmentBase.indexRange`
  /// end) when known; requests within it use the critical urgency class.
  final int? indexEnd;
}

/// A parsed player range request: `bytes=first-last`, open-ended
/// `bytes=first-`, or suffix form `bytes=-n` (last n bytes).
class RangeRequest {
  const RangeRequest({this.first, this.last, this.suffixLength});

  /// Start offset; null only for a pure suffix request (`bytes=-n`).
  final int? first;

  /// Inclusive end offset as requested, null for open-ended.
  final int? last;

  /// Original suffix length when the request was `bytes=-n`, else null.
  final int? suffixLength;

  bool get isSatisfiableForm =>
      (suffixLength != null && suffixLength! > 0) ||
      ((suffixLength == null) && (first == null || (first! >= 0 && (last == null || last! >= first!))));

  /// Resolve against a file size into concrete inclusive bounds.
  /// Returns null when the request is unsatisfiable (caller answers 416).
  ({int first, int last})? resolve(int total) {
    if (total <= 0) return null;
    if (suffixLength != null) {
      final n = suffixLength!;
      if (n <= 0) return null;
      final f = n >= total ? 0 : total - n;
      return (first: f, last: total - 1);
    }
    final f = first ?? 0;
    if (f < 0 || f >= total) return null;
    final l = (last != null && last! < total - 1) ? last! : total - 1;
    if (l < f) return null;
    return (first: f, last: l);
  }
}

/// Parsed `Content-Range: bytes start-end/total` of an upstream response.
class ContentRange {
  const ContentRange({
    required this.start,
    required this.end,
    this.total,
  });

  final int start;
  final int end;

  /// Total file size, null when the host sent `*`.
  final int? total;
}

/// What an accelerator hands back to the proxy for one range request.
class AcceleratedResponse {
  const AcceleratedResponse({
    required this.first,
    required this.last,
    required this.total,
    required this.stream,
    this.onConsumed,
  });

  /// Inclusive bounds of the served range (what the proxy echoes in
  /// `Content-Range`).
  final int first;
  final int last;
  final int total;

  /// 代理每向播放器交付一段后回调（参数为已交付的绝对偏移），调度器据此
  /// 做消费驱动续棒。
  final void Function(int consumedAbsolute)? onConsumed;

  /// The exact bytes of [first]..[last], in order.
  final Stream<List<int>> stream;
}

/// Per-video accelerator. One instance per loaded video; `serve` must never
/// throw (internal failures return null so the proxy passes through), and
/// must not block the player: returning null is always cheap.
abstract class MediaAccelerator {
  AcceleratedResponse? serve(
    MediaDescriptor descriptor,
    RangeRequest range,
  );
}
