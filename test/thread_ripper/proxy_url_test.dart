import 'dart:convert';

import 'package:PiliPlus/services/thread_ripper/contracts.dart';
import 'package:PiliPlus/services/thread_ripper/proxy_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const descriptor = MediaDescriptor(
    originalUrl:
        'https://upos-sz-mirror08c.bilivideo.com/upgcxcode/31/22/abc/video.m4s?e=ig8vxBB8&uipq=1&deadline=1760000000',
    candidates: [],
    isAudio: false,
    totalSize: 123456,
  );

  group('buildProxyUrl', () {
    test('生成 /tr/<base64urlNoPad(originalUrl)>/<token> 形式', () {
      final url = buildProxyUrl(18080, descriptor, 'feedc0de');
      expect(url, startsWith('http://127.0.0.1:18080/tr/'));
      expect(url, endsWith('/feedc0de'));
      final encoded = url.split('/tr/')[1].split('/')[0];
      // base64url 无填充字符集：不含 '='、'+'、'/'，mpv/edl:// 路径安全
      expect(encoded, isNot(contains('=')));
      expect(encoded, isNot(contains('+')));
      expect(encoded, isNot(contains('/')));
      expect(encoded, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      expect(
        utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
        descriptor.originalUrl,
      );
    });
  });

  group('parseProxyPath', () {
    test('buildProxyUrl 产物 round-trip', () {
      final url = buildProxyUrl(18080, descriptor, 'feedc0de');
      final parsed = parseProxyPath(Uri.parse(url).path);
      expect(parsed, isNotNull);
      expect(parsed!.url, descriptor.originalUrl);
      expect(parsed.token, 'feedc0de');
    });

    test('原始 URL 含查询参数与保留字符时 round-trip 无损', () {
      const tricky = MediaDescriptor(
        originalUrl:
            'https://host/upgcxcode/a b/c.m4s?x=%20&y=中文&z=1+2#frag?more',
        candidates: [],
        isAudio: true,
      );
      final url = buildProxyUrl(80, tricky, 'beef00');
      final parsed = parseProxyPath(Uri.parse(url).path);
      expect(parsed, isNotNull);
      expect(parsed!.url, tricky.originalUrl);
      expect(parsed.token, 'beef00');
    });

    test('路径前缀不是 /tr/ 时返回 null', () {
      expect(parseProxyPath('/other/abc/token'), isNull);
      expect(parseProxyPath('/'), isNull);
    });

    test('路径段数量不符时返回 null', () {
      expect(parseProxyPath('/tr/only-one-segment'), isNull);
      expect(parseProxyPath('/tr/a/b/c'), isNull);
      expect(parseProxyPath('/tr//token'), isNull);
    });

    test('坏 base64 编码返回 null', () {
      // '!!' 不是合法 base64url 字符
      expect(parseProxyPath('/tr/!!/token'), isNull);
    });

    test('解码后不是 http(s) URL 时返回 null', () {
      final encoded = base64Url
          .encode(utf8.encode('ftp://evil.example/file'))
          .replaceAll('=', '');
      expect(parseProxyPath('/tr/$encoded/token'), isNull);
    });

    test('空 token 段返回 null', () {
      final url = buildProxyUrl(80, descriptor, 'feedc0de');
      final path = '${Uri.parse(url).path}/'; // 追加空段
      expect(parseProxyPath(path), isNull);
    });
  });
}
