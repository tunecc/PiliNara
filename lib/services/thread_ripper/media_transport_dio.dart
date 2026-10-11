/// The production [MediaTransport]: ranged GETs over a dedicated dio instance.
///
/// Kept separate from `Request.http11Dio` on purpose (deviation note):
/// - the shared instance carries a retry interceptor and the account/cookie
///   interceptor; media chunks need neither, and the scheduler runs its own
///   per-piece retry policy (MAX_TRIES), so double retries would distort it;
/// - `Request.dio`'s `validateStatus` and `responseDecoder` assume API
///   payloads; media must come back as untouched bytes with every status
///   (classification happens in classifyResponse, like the browser's
///   fetch()),
/// - `accept-encoding` is never sent (`autoUncompress = false`): a CDN must
///   not hand back br/gzip-encoded range bytes,
/// - redirects are followed manually so a landing on a P2P CDN domain is
///   detectable. Upstream fetches with `redirect: 'follow'` and inspects
///   `response.redirected`/`response.url`; dart:io hides the landing URL when
///   it follows redirects itself.
///
/// What stays the same as the app's HTTP/1.1 media path: HTTP/1.1, pooled
/// connections, PC browser UA and `Referer: https://www.bilibili.com`.
library;

import 'dart:async';
import 'dart:io' show HttpClient;

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/services/thread_ripper/classify.dart' show MediaAbortedError;
import 'package:PiliPlus/services/thread_ripper/media_transport.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class DioMediaTransport implements MediaTransport {
  DioMediaTransport({Dio? dio, this.maxRedirects = 5})
      : _ownsDio = dio == null,
        _dio = dio ?? _createDefault();

  final Dio _dio;
  final bool _ownsDio;
  final int maxRedirects;

  static Dio _createDefault() {
    final options = BaseOptions(
      connectTimeout: const Duration(milliseconds: 10000),
      headers: {
        'user-agent': BrowserUa.pc,
        'referer': HttpString.baseUrl,
      },
    )
      // Every status comes back as a response; classifyResponse judges it.
      ..validateStatus = ((_) => true)
      // Followed manually in open(): the landing host must be classifiable.
      ..followRedirects = false
      ..maxRedirects = 0;
    final dio = Dio(options)
      ..httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()
        ..idleTimeout = const Duration(seconds: 15)
        // No automatic Accept-Encoding, no decoding: raw media bytes.
        ..autoUncompress = false,
    );
    return dio;
  }

  @override
  Future<MediaUpstreamResponse> open(MediaFetchRequest request, MediaAbortHandle abort) async {
    final token = CancelToken();
    abort.attach(token.cancel);
    var url = request.url;
    for (var hop = 0;; hop++) {
      final Response<ResponseBody> resp;
      try {
        resp = await _dio.get<ResponseBody>(
          url,
          options: Options(
            headers: {'range': 'bytes=${request.start}-${request.end}'},
            responseType: ResponseType.stream,
            validateStatus: (_) => true,
            followRedirects: false,
          ),
          cancelToken: token,
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel || abort.abortReason != null) {
          throw MediaAbortedError();
        }
        rethrow; // classified by the scheduler: no headers received
      }
      final status = resp.statusCode ?? 0;
      final location = resp.headers.value('location');
      if (_isRedirect(status) && location != null) {
        _drain(resp.data);
        if (hop >= maxRedirects) {
          // fetch() throws a TypeError past the redirect limit.
          throw StateError('too many redirects');
        }
        url = Uri.parse(url).resolveUri(Uri.parse(location)).toString();
        continue;
      }
      return MediaUpstreamResponse(
        statusCode: status,
        finalUrl: url,
        redirected: hop > 0,
        headers: {
          for (final entry in resp.headers.map.entries) entry.key.toLowerCase(): entry.value,
        },
        body: resp.data?.stream ?? const Stream<List<int>>.empty(),
      );
    }
  }

  static bool _isRedirect(int status) =>
      status == 301 || status == 302 || status == 303 || status == 307 || status == 308;

  /// Consume and discard a (small) unwanted body to release the connection.
  static void _drain(ResponseBody? body) {
    if (body != null) {
      body.stream.listen(
        (_) {},
        onDone: () {},
        onError: (Object _) {},
        cancelOnError: true,
      );
    }
  }

  /// Releases the pooled connections (session teardown).
  void close({bool force = false}) {
    if (_ownsDio) {
      _dio.httpClientAdapter.close(force: force);
    }
  }
}
