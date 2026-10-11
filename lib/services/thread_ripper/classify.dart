/// Verdicts on one upstream media response or failure. 1:1 port of upstream
/// `src/modules/thread-ripper/classify.ts`; the domain/family helpers port the
/// parts of `src/core/player/cdn-classify.ts` the engine needs.
library;

import 'package:PiliPlus/services/thread_ripper/contracts.dart' show ContentRange;
import 'package:PiliPlus/services/thread_ripper/outcome.dart';

/// Thrown by a [MediaTransport] when a request was canceled from outside the
/// scheduler (no scheduler-set abort reason). `classifyError` maps it to
/// [MediaOutcome.canceled] — the Dart stand-in for the browser's AbortError
/// (`isAbortErrorLike` upstream).
class MediaAbortedError extends Error {
  @override
  String toString() => 'MediaAbortedError';
}

/// What one response says about the request it answered.
class ResponseVerdict {
  const ResponseVerdict({required this.outcome, this.total});

  final MediaOutcome outcome;

  /// The file's total size, when the response is valid.
  final int? total;
}

/// Which hosts can verify the signature of an address (cdn-classify.ts).
enum SignatureFamily { upos, akam }

/// How a CDN URL is shaped (cdn-classify.ts `CdnUrlClass`).
enum CdnUrlClass { mirror, bcache, mcdnUpgcxcode, mcdnTf, szbdyd, unknown }

/// Classifies one media response.
///
/// Ported 1:1 from upstream `classifyResponse`. The browser checks
/// `response.type === 'opaqueredirect'` first; that type only arises from
/// `fetch(..., { redirect: 'manual' })`, while we follow redirects ourselves
/// (see media_transport_dart), so it cannot occur here and is not represented.
///
/// [finalUrl] is the URL the response finally landed on (after redirects),
/// [redirected] whether at least one redirect was followed.
ResponseVerdict classifyResponse({
  required int status,
  required bool redirected,
  required String finalUrl,
  required ContentRange? contentRange,
  required ({int start, int end, int? total, bool addressExpired}) expected,
}) {
  ResponseVerdict invalid(MediaOutcome outcome) => ResponseVerdict(outcome: outcome);

  if (redirected && isP2PCdnDomain(hostnameOf(finalUrl))) {
    return invalid(MediaOutcome.redirect);
  }

  if (status == 206) {
    // Without it, which bytes came back is unknown: every tested host exposes it
    if (contentRange == null) {
      return invalid(MediaOutcome.unverifiable);
    }
    if (contentRange.start != expected.start) {
      return invalid(MediaOutcome.badRange);
    }
    if (contentRange.end != expected.end) {
      return invalid(
        contentRange.end < expected.end &&
                contentRange.total != null &&
                contentRange.end == contentRange.total! - 1
            ? MediaOutcome.eofClamp
            : MediaOutcome.badRange,
      );
    }
    if (expected.total != null && contentRange.total != null && contentRange.total != expected.total) {
      return invalid(MediaOutcome.staleObject);
    }
    return ResponseVerdict(outcome: MediaOutcome.ok, total: contentRange.total ?? expected.total);
  }

  if (status == 200) return invalid(MediaOutcome.noRange);
  if (status == 401 || status == 403) {
    return invalid(expected.addressExpired ? MediaOutcome.expired : MediaOutcome.refused);
  }
  if (status == 404 || status == 410) return invalid(MediaOutcome.missing);
  if (status == 416) return invalid(MediaOutcome.eofClamp);
  if (status == 412 || status == 429 || status == 503) return invalid(MediaOutcome.throttled);
  return invalid(MediaOutcome.serverError);
}

/// A failed fetch or body read. [error] is whatever the transport threw;
/// [abortReason] is set when we aborted the attempt ourselves;
/// [headersReceived] tells a body-read failure from a connection failure;
/// [elapsedMs] how long the attempt ran.
MediaOutcome classifyError(
  Object error, {
  required MediaOutcome? abortReason,
  required int receivedBytes,
  required bool headersReceived,
  required int elapsedMs,
}) {
  if (abortReason != null) {
    return abortReason;
  }
  if (error is MediaAbortedError) {
    return MediaOutcome.canceled;
  }
  if (headersReceived) {
    return receivedBytes > 0 ? MediaOutcome.reset : MediaOutcome.truncated;
  }
  return elapsedMs < 150 ? MediaOutcome.connectFail : MediaOutcome.network;
}

/// Outcomes after which the same bytes are worth asking for again elsewhere.
bool isRetryable(MediaOutcome outcome) {
  return outcome != MediaOutcome.ok &&
      outcome != MediaOutcome.canceled &&
      outcome != MediaOutcome.integrity &&
      outcome != MediaOutcome.eofClamp;
}

// ---- Content-Range (ported from src/core/player/range.ts) ----

final RegExp _contentRangeRegex = RegExp(r'^bytes (\d+)-(\d+)\/(\d+|\*)$', caseSensitive: false);

/// Parses `Content-Range: bytes start-end/total`; `*` for an unknown total.
/// Returns null for garbage and for a total that is not above [end].
ContentRange? parseContentRange(String? value) {
  if (value == null) {
    return null;
  }
  final match = _contentRangeRegex.firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  final start = int.parse(match.group(1)!);
  final end = int.parse(match.group(2)!);
  if (end < start) {
    return null;
  }
  if (match.group(3) == '*') {
    return ContentRange(start: start, end: end);
  }
  final total = int.parse(match.group(3)!);
  if (total <= end) {
    return null;
  }
  return ContentRange(start: start, end: end, total: total);
}

// ---- URL / domain helpers (ported from cdn-classify.ts) ----

/// `''` for an invalid URL.
String hostnameOf(String url) {
  final uri = Uri.tryParse(url);
  return uri?.host ?? '';
}

/// Keyword containment list from upstream `knownP2pCdnDomainPattern`
/// (foxts/retrie keyword filter = substring match), plus the "302 inside the
/// first domain label" rule. The upstream code comments carry over:
/// - `upos-sz-302ppio.bilivideo.com` -> `*.nexusedgeio.com`
/// - `upos-sz-302kodo.bilivideo.com` -> `*.ahdohpiechei.com`
bool isP2PCdnDomain(String hostname) {
  const knownP2pKeywords = <String>[
    '302ppio',
    '302kodo',
    '.mcdn.bilivideo',
    'szbdyd.com',
    '.nexusedgeio.com',
    '.ahdohpiechei.com', // 七牛云 PCDN
    // B 站 PCDN 边缘交付域（os=mcdn + mcdnid，/v1/resource 传输层）：上游名单
    // 早于该形态，缺失会把 PCDN 边缘误判为自有 PoP（bcache）优先使用
    '.edge.mountaintoys.cn',
    // mirror type, upgcxcode, but it has no valid SSL cert; its SSL cert is
    // for PCDN (*.bilivideo.cn)
    'upos-sz-mirror14b.bilivideo.com',
  ];
  for (final keyword in knownP2pKeywords) {
    if (hostname.contains(keyword)) {
      return true;
    }
  }
  // `split0th(hostname, '.')`: the label before the first dot.
  final dot = hostname.indexOf('.');
  final subdomain = dot == -1 ? hostname : hostname.substring(0, dot);
  return subdomain.contains('302');
}

final RegExp _mirrorRegex = RegExp(
  r'^https?:\/\/(?:upos-\w+-(?!302)\w+|(?:upos|proxy)-tf-[^\/]+)\.(?:bilivideo|akamaized)\.(?:com|net)\/upgcxcode',
);

final RegExp _mCdnTfRegex = RegExp(
  r'^https?:\/\/(?:(?:\d{1,3}\.){3}\d{1,3}|[^\/]+\.mcdn\.bilivideo\.(?:com|cn|net))(?::\d{1,5})?\/v\d\/resource',
);

/// A host `mirrorRegex` accepts: an upgcxcode path on it is a mirror URL
/// (unless P2P).
bool isMirrorHost(String hostname) => _mirrorRegex.hasMatch('https://$hostname/upgcxcode/');

bool isAkamaiHost(String hostname) => hostname.endsWith('.akamaized.net');

/// Port of upstream `classifyCdnUrl` (used for candidate tiers).
CdnUrlClass classifyCdnUrl(Uri url) {
  final href = url.toString();
  if (href.contains('/upgcxcode/')) {
    if (_mirrorRegex.hasMatch(href)) {
      // A mirror type url may also be a p2p cdn (os=mcdn, or an HTTP-302 p2p
      // host).
      return (url.queryParameters['os'] != 'mcdn' && !isP2PCdnDomain(url.host))
          ? CdnUrlClass.mirror
          : CdnUrlClass.mcdnUpgcxcode;
    }
    return isP2PCdnDomain(url.host) ? CdnUrlClass.mcdnUpgcxcode : CdnUrlClass.bcache;
  }
  if (_mCdnTfRegex.hasMatch(href)) {
    return CdnUrlClass.mcdnTf;
  }
  if (href.contains('szbdyd.com')) {
    return CdnUrlClass.szbdyd;
  }
  return CdnUrlClass.unknown;
}

/// Akamai addresses carry its token (`hdnts`) on top of an upos `upsig`: the
/// token tells them apart, `upsig` does not.
SignatureFamily signatureFamilyOf(Uri url) {
  final params = url.queryParameters;
  return params.containsKey('hdnts') || (!params.containsKey('upsig') && isAkamaiHost(url.host))
      ? SignatureFamily.akam
      : SignatureFamily.upos;
}

final RegExp _v1ResourceWrapperPrefix = RegExp(r'^\/v\d\/resource(?=\/upgcxcode\/)');

/// Strips the `/v1/resource` transport wrapper from a PCDN edge URL so the
/// bare `/upgcxcode/` path can be host-swapped: the signature rides on the
/// query parameters only (an `os=mcdn` signature answers 206 on official
/// mirrors), while keeping the wrapper makes every mirror answer 404.
/// URLs without the wrapper are returned unchanged.
Uri normalizeUpgcxcodeUri(Uri url) {
  if (!_v1ResourceWrapperPrefix.hasMatch(url.path)) {
    return url;
  }
  final strippedPath = url.path.replaceFirst(_v1ResourceWrapperPrefix, '');
  return url.replace(path: strippedPath);
}

final RegExp _akamaiTokenExpiryRe = RegExp(r'(?:^|~)exp=(\d+)');

/// When the signed address expires, in unix seconds; `0` if unknown. An Akamai
/// address expires with its token (`hdnts=exp=<unix>~…`) if that comes before
/// `deadline`.
int signatureDeadlineOf(Uri url) {
  int unixSeconds(String? value) {
    final seconds = value == null ? null : int.tryParse(value);
    return seconds != null && seconds > 0 ? seconds : 0;
  }

  final deadline = unixSeconds(url.queryParameters['deadline']);
  final token = url.queryParameters['hdnts'];
  final tokenExpiry = token == null ? 0 : unixSeconds(_akamaiTokenExpiryRe.firstMatch(token)?.group(1));
  if (deadline == 0 || tokenExpiry == 0) {
    return deadline | tokenExpiry;
  }
  return deadline < tokenExpiry ? deadline : tokenExpiry;
}
