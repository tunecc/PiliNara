/// The boundary between the scheduler and the network: one ranged GET against
/// one candidate URL. This is the Dart stand-in for the userscript's
/// `fetch(candidate.href, { headers: { Range } })`.
library;

import 'dart:async';

import 'package:PiliPlus/services/thread_ripper/classify.dart' show MediaAbortedError;
import 'package:PiliPlus/services/thread_ripper/outcome.dart' show AbortReason;

/// One ranged GET the scheduler asks a transport to perform.
class MediaFetchRequest {
  const MediaFetchRequest({required this.url, required this.start, required this.end});

  /// The candidate URL to fetch.
  final String url;

  /// Inclusive first byte of the wanted range.
  final int start;

  /// Inclusive last byte of the wanted range.
  final int end;
}

/// Response headers and body of one ranged GET. The body is a single-subscription
/// stream: it ends at EOF and errors on read failures, exactly like the chunks
/// of a `fetch()` body reader.
class MediaUpstreamResponse {
  const MediaUpstreamResponse({
    required this.statusCode,
    required this.finalUrl,
    required this.redirected,
    required this.headers,
    required this.body,
  });

  final int statusCode;

  /// The URL the response finally landed on (after redirects).
  final String finalUrl;

  /// Whether at least one redirect was followed to get here.
  final bool redirected;

  /// Response headers, field names lower-cased.
  final Map<String, List<String>> headers;

  /// The response body bytes.
  final Stream<List<int>> body;
}

/// Scheduler-side abort handle: the port of the upstream AbortController.
/// The scheduler aborts with a reason (`Canceled` for a lost race, `Stall`
/// for silence); the transport wires its own cancellation to [attach].
class MediaAbortHandle {
  AbortReason? abortReason;
  void Function()? _onAbort;

  /// Registers the transport's cancellation callback. Called immediately when
  /// the handle was already aborted.
  void attach(void Function() onAbort) {
    _onAbort = onAbort;
    if (abortReason != null) {
      onAbort();
    }
  }

  void abort(AbortReason reason) {
    if (abortReason != null) {
      return;
    }
    abortReason = reason;
    _onAbort?.call();
  }
}

/// Issues ranged GETs. One instance serves a whole session; `open` may be
/// called any number of times concurrently. Implementations must honor
/// [MediaAbortHandle]: once aborted, `open` fails or the body stream errors,
/// and the failure carries [MediaAbortHandle.abortReason] back to the
/// scheduler.
abstract class MediaTransport {
  Future<MediaUpstreamResponse> open(MediaFetchRequest request, MediaAbortHandle abort);
}

/// An in-memory [MediaTransport] for tests. Every request is recorded as a
/// [MockMediaRequest] that the test drives by hand.
class MockMediaTransport implements MediaTransport {
  final List<MockMediaRequest> requests = [];

  int get openCalls => requests.length;

  Iterable<MockMediaRequest> requestsFrom(String host) =>
      requests.where((r) => Uri.parse(r.request.url).host == host);

  @override
  Future<MediaUpstreamResponse> open(MediaFetchRequest request, MediaAbortHandle abort) {
    final r = MockMediaRequest._(request, abort);
    requests.add(r);
    return r._headers.future;
  }
}

/// One request a test gets to script: complete the headers, then push body
/// chunks, close, or fail — at either stage.
class MockMediaRequest {
  MockMediaRequest._(this.request, this.abort) {
    _body = StreamController<List<int>>(sync: false);
    abort.attach(_onAbort);
  }

  final MediaFetchRequest request;
  final MediaAbortHandle abort;
  final Completer<MediaUpstreamResponse> _headers = Completer<MediaUpstreamResponse>();
  late final StreamController<List<int>> _body;

  bool get headersResponded => _headers.isCompleted;
  bool get bodyClosed => _body.isClosed;

  void _onAbort() {
    if (!_headers.isCompleted) {
      _headers.completeError(MediaAbortedError());
    }
    if (_body.hasListener && !_body.isClosed) {
      _body.addError(MediaAbortedError());
    }
  }

  /// Completes `open` with response headers. [extraHeaders] are merged into
  /// the default (content-range when given).
  void respond({
    int status = 206,
    String? contentRange,
    String? contentType,
    Map<String, String> extraHeaders = const {},
  }) {
    _headers.complete(
      MediaUpstreamResponse(
        statusCode: status,
        finalUrl: request.url,
        redirected: false,
        headers: {
          if (contentType != null) 'content-type': [contentType],
          if (contentRange != null) 'content-range': [contentRange],
          ...extraHeaders.map((k, v) => MapEntry(k.toLowerCase(), [v])),
        },
        body: _body.stream,
      ),
    );
  }

  /// Pushes one body chunk.
  void emit(List<int> bytes) => _body.add(bytes);

  /// Ends the body normally (EOF).
  void close() => _body.close();

  /// Fails the body read (after headers): a reset/truncated connection.
  void failBody(Object error) => _body.addError(error);

  /// Fails before any response header: a connection failure.
  void failHeaders([Object? error]) {
    _headers.completeError(error ?? Exception('connect failed'));
  }
}
