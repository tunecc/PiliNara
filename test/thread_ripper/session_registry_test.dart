import 'package:PiliPlus/services/thread_ripper/contracts.dart';
import 'package:PiliPlus/services/thread_ripper/session_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MediaDescriptor descriptor(String url) => MediaDescriptor(
        originalUrl: url,
        candidates: const [],
        isAudio: false,
      );

  group('SessionRegistry', () {
    test('register 返回 token，lookup 取回同一 descriptor', () {
      final registry = SessionRegistry();
      final d = descriptor('https://cdn.example/a.m4s');
      final token = registry.register(d);
      expect(registry.lookup(token), same(d));
    });

    test('token 是不重复的十六进制串', () {
      final registry = SessionRegistry();
      final tokens = <String>{
        for (var i = 0; i < 200; i++)
          registry.register(descriptor('https://cdn.example/$i.m4s')),
      };
      expect(tokens, hasLength(200));
      for (final token in tokens) {
        expect(token, matches(RegExp(r'^[0-9a-f]+$')));
      }
    });

    test('lookup 未知 token 返回 null', () {
      final registry = SessionRegistry()
        ..register(descriptor('https://cdn.example/a.m4s'));
      expect(registry.lookup('ffffffffffffffff'), isNull);
      expect(registry.lookup(''), isNull);
    });

    test('clear 后全部失效，可继续注册新条目', () {
      final registry = SessionRegistry();
      final token = registry.register(descriptor('https://cdn.example/a.m4s'));
      registry.clear();
      expect(registry.lookup(token), isNull);
      final token2 = registry.register(descriptor('https://cdn.example/b.m4s'));
      expect(registry.lookup(token2), isNotNull);
    });
  });
}
