import 'package:PiliPlus/services/thread_ripper/classify.dart';
import 'package:PiliPlus/services/thread_ripper/contracts.dart' show ContentRange;
import 'package:PiliPlus/services/thread_ripper/outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyResponse', () {
    ResponseVerdict run({
      required int status,
      bool redirected = false,
      String finalUrl = 'https://upos-sz-mirror08c.bilivideo.com/upgcxcode/f',
      ContentRange? contentRange,
      int? total,
      bool addressExpired = false,
      int start = 100,
      int end = 199,
    }) {
      return classifyResponse(
        status: status,
        redirected: redirected,
        finalUrl: finalUrl,
        contentRange: contentRange,
        expected: (start: start, end: end, total: total, addressExpired: addressExpired),
      );
    }

    test('206 without Content-Range is unverifiable', () {
      expect(run(status: 206).outcome, MediaOutcome.unverifiable);
    });

    test('206 with start mismatch is badRange', () {
      expect(
        run(status: 206, contentRange: const ContentRange(start: 101, end: 199, total: 1000)).outcome,
        MediaOutcome.badRange,
      );
    });

    test('206 with end below expected and end == total-1 is eofClamp', () {
      // Asked for 100-999; the host clamps at EOF of a 500-byte file.
      final v = run(status: 206, end: 999, contentRange: const ContentRange(start: 100, end: 499, total: 500));
      expect(v.outcome, MediaOutcome.eofClamp);
      expect(v.total, isNull);
    });

    test('206 with end mismatch (not eof clamp) is badRange', () {
      final v = run(status: 206, contentRange: const ContentRange(start: 100, end: 150, total: 1000));
      expect(v.outcome, MediaOutcome.badRange);
    });

    test('206 with end above expected is badRange', () {
      expect(
        run(status: 206, contentRange: const ContentRange(start: 100, end: 250, total: 1000)).outcome,
        MediaOutcome.badRange,
      );
    });

    test('206 with different total than expected is staleObject', () {
      expect(
        run(
          status: 206,
          total: 1000,
          contentRange: const ContentRange(start: 100, end: 199, total: 2000),
        ).outcome,
        MediaOutcome.staleObject,
      );
    });

    test('206 matching with total returns Ok and the content-range total', () {
      final v = run(status: 206, total: 1000, contentRange: const ContentRange(start: 100, end: 199, total: 1000));
      expect(v.outcome, MediaOutcome.ok);
      expect(v.total, 1000);
    });

    test('206 matching without content-range total falls back to expected total', () {
      final v = run(status: 206, total: 1000, contentRange: const ContentRange(start: 100, end: 199));
      expect(v.outcome, MediaOutcome.ok);
      expect(v.total, 1000);
    });

    test('206 matching with no expected total and wildcard total gives null total', () {
      final v = run(status: 206, contentRange: const ContentRange(start: 100, end: 199));
      expect(v.outcome, MediaOutcome.ok);
      expect(v.total, isNull);
    });

    test('200 is noRange', () {
      expect(run(status: 200).outcome, MediaOutcome.noRange);
    });

    test('401/403 split on addressExpired', () {
      expect(run(status: 401, addressExpired: true).outcome, MediaOutcome.expired);
      expect(run(status: 401, addressExpired: false).outcome, MediaOutcome.refused);
      expect(run(status: 403, addressExpired: true).outcome, MediaOutcome.expired);
      expect(run(status: 403, addressExpired: false).outcome, MediaOutcome.refused);
    });

    test('404/410 is missing', () {
      expect(run(status: 404).outcome, MediaOutcome.missing);
      expect(run(status: 410).outcome, MediaOutcome.missing);
    });

    test('416 is eofClamp', () {
      expect(run(status: 416).outcome, MediaOutcome.eofClamp);
    });

    test('412/429/503 is throttled', () {
      expect(run(status: 412).outcome, MediaOutcome.throttled);
      expect(run(status: 429).outcome, MediaOutcome.throttled);
      expect(run(status: 503).outcome, MediaOutcome.throttled);
    });

    test('other statuses are serverError', () {
      expect(run(status: 500).outcome, MediaOutcome.serverError);
      expect(run(status: 502).outcome, MediaOutcome.serverError);
      expect(run(status: 302).outcome, MediaOutcome.serverError);
    });

    test('redirect landing on a P2P CDN domain is redirect', () {
      expect(
        run(
          status: 206,
          redirected: true,
          finalUrl: 'https://upos-sz-302ppio.bilivideo.com/upgcxcode/f',
          contentRange: const ContentRange(start: 100, end: 199, total: 1000),
        ).outcome,
        MediaOutcome.redirect,
      );
      expect(
        run(
          status: 200,
          redirected: true,
          finalUrl: 'https://xy.mcdn.bilivideo.com:4483/v1/resource/f',
        ).outcome,
        MediaOutcome.redirect,
      );
    });

    test('a redirect onto a normal host is classified by status, not redirect', () {
      final v = run(
        status: 206,
        redirected: true,
        finalUrl: 'https://upos-sz-mirrorhw.bilivideo.com/upgcxcode/f',
        contentRange: const ContentRange(start: 100, end: 199, total: 1000),
      );
      expect(v.outcome, MediaOutcome.ok);
    });

    test('a P2P host reached without redirect is not redirect', () {
      final v = run(
        status: 206,
        redirected: false,
        finalUrl: 'https://upos-sz-302ppio.bilivideo.com/upgcxcode/f',
        contentRange: const ContentRange(start: 100, end: 199, total: 1000),
      );
      expect(v.outcome, MediaOutcome.ok);
    });
  });

  group('classifyError', () {
    test('our own abort reason wins', () {
      expect(
        classifyError(
          StateError('any'),
          abortReason: MediaOutcome.stall,
          receivedBytes: 5,
          headersReceived: true,
          elapsedMs: 10000,
        ),
        MediaOutcome.stall,
      );
      expect(
        classifyError(
          StateError('any'),
          abortReason: MediaOutcome.canceled,
          receivedBytes: 0,
          headersReceived: false,
          elapsedMs: 1,
        ),
        MediaOutcome.canceled,
      );
    });

    test('an abort-like error without our reason is canceled', () {
      expect(
        classifyError(
          MediaAbortedError(),
          abortReason: null,
          receivedBytes: 0,
          headersReceived: false,
          elapsedMs: 10,
        ),
        MediaOutcome.canceled,
      );
    });

    test('after headers: bytes received means reset, none means truncated', () {
      expect(
        classifyError(
          Exception('socket closed'),
          abortReason: null,
          receivedBytes: 10,
          headersReceived: true,
          elapsedMs: 5000,
        ),
        MediaOutcome.reset,
      );
      expect(
        classifyError(
          Exception('socket closed'),
          abortReason: null,
          receivedBytes: 0,
          headersReceived: true,
          elapsedMs: 5000,
        ),
        MediaOutcome.truncated,
      );
    });

    test('before headers: fast failure is connectFail, slow is network', () {
      expect(
        classifyError(
          Exception('dns'),
          abortReason: null,
          receivedBytes: 0,
          headersReceived: false,
          elapsedMs: 149,
        ),
        MediaOutcome.connectFail,
      );
      expect(
        classifyError(
          Exception('dns'),
          abortReason: null,
          receivedBytes: 0,
          headersReceived: false,
          elapsedMs: 150,
        ),
        MediaOutcome.network,
      );
    });
  });

  group('isRetryable', () {
    test('everything but ok/canceled/integrity/eofClamp is retryable', () {
      const notRetryable = {MediaOutcome.ok, MediaOutcome.canceled, MediaOutcome.integrity, MediaOutcome.eofClamp};
      for (final outcome in MediaOutcome.values) {
        expect(isRetryable(outcome), !notRetryable.contains(outcome), reason: outcome.name);
      }
    });
  });

  group('parseContentRange', () {
    test('parses bytes a-b/total', () {
      final cr = parseContentRange('bytes 0-1011/2097152');
      expect(cr, isNotNull);
      expect(cr!.start, 0);
      expect(cr.end, 1011);
      expect(cr.total, 2097152);
    });

    test('case-insensitive with surrounding whitespace', () {
      expect(parseContentRange('  BYTES 5-9/100 ')!.total, 100);
    });

    test('wildcard total', () {
      final cr = parseContentRange('bytes 0-9/*');
      expect(cr, isNotNull);
      expect(cr!.total, isNull);
      expect(cr.end, 9);
    });

    test('total <= end is invalid', () {
      expect(parseContentRange('bytes 0-9/9'), isNull);
      expect(parseContentRange('bytes 0-9/5'), isNull);
    });

    test('garbage is null', () {
      expect(parseContentRange(null), isNull);
      expect(parseContentRange(''), isNull);
      expect(parseContentRange('bytes 0-'), isNull);
      expect(parseContentRange('bytes -5/10'), isNull);
      expect(parseContentRange('bytes 10-0/100'), isNull);
      expect(parseContentRange('items 0-9/100'), isNull);
    });
  });

  group('isP2PCdnDomain', () {
    test('known P2P keywords', () {
      expect(isP2PCdnDomain('upos-sz-302ppio.bilivideo.com'), isTrue);
      expect(isP2PCdnDomain('upos-sz-302kodo.bilivideo.com'), isTrue);
      expect(isP2PCdnDomain('xy.mcdn.bilivideo.com'), isTrue);
      expect(isP2PCdnDomain('xy.mcdn.bilivideo.cn'), isTrue);
      expect(isP2PCdnDomain('pcdn.szbdyd.com'), isTrue);
      expect(isP2PCdnDomain('cache.nexusedgeio.com'), isTrue);
      expect(isP2PCdnDomain('node.ahdohpiechei.com'), isTrue);
      // mirror with an invalid cert that actually fronts a PCDN
      expect(isP2PCdnDomain('upos-sz-mirror14b.bilivideo.com'), isTrue);
    });

    test('the 302-in-first-label rule', () {
      expect(isP2PCdnDomain('upos-sz-upflowe302.bilivideo.com'), isTrue);
      expect(isP2PCdnDomain('upos-sz-mirrorcoso1.bilivideo.com'), isFalse);
      expect(isP2PCdnDomain('upos-sz-mirror08c.bilivideo.com'), isFalse);
    });

    test('normal hosts are not P2P', () {
      expect(isP2PCdnDomain('upos-sz-mirrorhw.bilivideo.com'), isFalse);
      expect(isP2PCdnDomain('upos-hz-mirrorakam.akamaized.net'), isFalse);
      expect(isP2PCdnDomain('cn-sccd-cu-01-01.bilivideo.com'), isFalse);
      expect(isP2PCdnDomain(''), isFalse);
    });

    test('mountaintoys PCDN edges (postdates the upstream list)', () {
      expect(isP2PCdnDomain('29e749o.edge.mountaintoys.cn'), isTrue);
      expect(isP2PCdnDomain('b-baaa93cg2y85fbm6d2wwavz6ydx6f.edge.mountaintoys.cn'), isTrue);
      expect(isP2PCdnDomain('upos-sz-mirrorhw.bilivideo.com'), isFalse);
    });
  });

  group('classifyCdnUrl mountaintoys', () {
    test('upgcxcode path on mountaintoys is mcdnUpgcxcode (with or without os=mcdn)', () {
      expect(
        classifyCdnUrl(Uri.parse('https://29e749o.edge.mountaintoys.cn/upgcxcode/99/91/x/x-1-30080.m4s?e=1&upsig=s')),
        CdnUrlClass.mcdnUpgcxcode,
      );
      expect(
        classifyCdnUrl(Uri.parse('https://29e749o.edge.mountaintoys.cn/upgcxcode/99/91/x/x-1-30080.m4s?e=1&os=mcdn&upsig=s')),
        CdnUrlClass.mcdnUpgcxcode,
      );
    });
  });

  group('normalizeUpgcxcodeUri', () {
    test('strips the /v1/resource transport wrapper', () {
      final normalized = normalizeUpgcxcodeUri(Uri.parse(
          'https://xy220x202x9x135xy.mcdn.bilivideo.cn:8082/v1/resource/upgcxcode/99/91/x/x-1-30080.m4s?e=x&os=mcdn&upsig=y'));
      expect(normalized.path, '/upgcxcode/99/91/x/x-1-30080.m4s');
      expect(normalized.host, 'xy220x202x9x135xy.mcdn.bilivideo.cn');
      expect(normalized.port, 8082);
      expect(normalized.query, 'e=x&os=mcdn&upsig=y');
    });

    test('leaves bare upgcxcode and unrelated paths unchanged', () {
      final bare = Uri.parse('https://upos-sz-mirrorali.bilivideo.com/upgcxcode/99/91/x.m4s?e=1');
      expect(normalizeUpgcxcodeUri(bare), same(bare));
      final other = Uri.parse('https://host.example/v1/resource/other/file');
      expect(normalizeUpgcxcodeUri(other), same(other));
    });
  });

  group('hostnameOf', () {
    test('extracts the host of a URL, empty for garbage', () {
      expect(hostnameOf('https://upos-sz-mirrorhw.bilivideo.com/x?y=1'), 'upos-sz-mirrorhw.bilivideo.com');
      expect(hostnameOf('not a url'), '');
    });
  });

  group('signature helpers', () {
    test('family: hdnts means akam, upsig means upos, akamai host without upsig is akam', () {
      expect(
        signatureFamilyOf(Uri.parse('https://upos-sz-mirrorhw.bilivideo.com/a?e=1&upsig=abc')),
        SignatureFamily.upos,
      );
      expect(
        signatureFamilyOf(Uri.parse('https://upos-sz-mirrorhw.bilivideo.com/a?e=1&hdnts=exp=1~h=2')),
        SignatureFamily.akam,
      );
      expect(
        signatureFamilyOf(Uri.parse('https://upos-hz-mirrorakam.akamaized.net/a?e=1')),
        SignatureFamily.akam,
      );
    });

    test('deadline: deadline param, hdnts exp, the earlier one', () {
      expect(signatureDeadlineOf(Uri.parse('https://h/a?deadline=1234')), 1234);
      expect(signatureDeadlineOf(Uri.parse('https://h/a?hdnts=exp=5678~h=1')), 5678);
      expect(signatureDeadlineOf(Uri.parse('https://h/a?deadline=9999&hdnts=exp=5678~h=1')), 5678);
      expect(signatureDeadlineOf(Uri.parse('https://h/a?deadline=1000&hdnts=exp=5678~h=1')), 1000);
      expect(signatureDeadlineOf(Uri.parse('https://h/a')), 0);
      expect(signatureDeadlineOf(Uri.parse('https://h/a?hdnts=h=1')), 0);
    });
  });
}
