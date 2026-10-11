import 'package:PiliPlus/services/thread_ripper/contracts.dart';
import 'package:PiliPlus/services/thread_ripper/range_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseRangeHeader', () {
    test('bytes=a-b 闭区间', () {
      final r = parseRangeHeader('bytes=0-99');
      expect(r, isNotNull);
      expect(r!.first, 0);
      expect(r.last, 99);
      expect(r.suffixLength, isNull);
    });

    test('bytes=a- 开放右端', () {
      final r = parseRangeHeader('bytes=100-');
      expect(r, isNotNull);
      expect(r!.first, 100);
      expect(r.last, isNull);
      expect(r.suffixLength, isNull);
    });

    test('bytes=-n 后缀形式', () {
      final r = parseRangeHeader('bytes=-500');
      expect(r, isNotNull);
      expect(r!.first, isNull);
      expect(r.last, isNull);
      expect(r.suffixLength, 500);
    });

    test('单位与空白不敏感', () {
      expect(parseRangeHeader(' BYTES=0-9 '), isNotNull);
      expect(parseRangeHeader(' bytes=0-9\t'), isNotNull);
    });

    test('无 Range 头返回 null（调用方透传）', () {
      expect(parseRangeHeader(null), isNull);
      expect(parseRangeHeader(''), isNull);
      expect(parseRangeHeader('   '), isNull);
    });

    test('非 bytes 单位返回 null', () {
      expect(parseRangeHeader('items=0-9'), isNull);
      expect(parseRangeHeader('bytes'), isNull);
    });

    test('多段 range 不支持，返回 null（透交上游处理）', () {
      expect(parseRangeHeader('bytes=0-1,5-6'), isNull);
    });

    test('语法非法返回 null', () {
      expect(parseRangeHeader('bytes=abc'), isNull);
      expect(parseRangeHeader('bytes=-'), isNull);
      expect(parseRangeHeader('bytes=5-2'), isNull); // end < start
      expect(parseRangeHeader('bytes=1e9-'), isNull);
      // 超过 int64 上限视为非法
      expect(parseRangeHeader('bytes=0-99999999999999999999'), isNull);
      expect(parseRangeHeader('bytes=-1.5'), isNull);
    });

    test('bytes=-0 保留为不可满足形态（total 已知时应回 416）', () {
      final r = parseRangeHeader('bytes=-0');
      expect(r, isNotNull);
      expect(r!.suffixLength, 0);
      expect(r.isSatisfiableForm, isFalse);
    });
  });

  group('RangeRequest.resolve 与 416 判定', () {
    test('闭区间原样解析', () {
      expect(
        const RangeRequest(first: 100, last: 199).resolve(1000),
        (first: 100, last: 199),
      );
    });

    test('开放右端截断到 total-1', () {
      expect(const RangeRequest(first: 100).resolve(1000), (first: 100, last: 999));
    });

    test('last 越界截断到 total-1', () {
      expect(
        const RangeRequest(first: 900, last: 2000).resolve(1000),
        (first: 900, last: 999),
      );
    });

    test('后缀形式换算起点', () {
      expect(const RangeRequest(suffixLength: 500).resolve(1000), (first: 500, last: 999));
      expect(const RangeRequest(suffixLength: 5000).resolve(1000), (first: 0, last: 999));
    });

    test('不可满足返回 null（调用方回 416）', () {
      expect(const RangeRequest(first: 1000).resolve(1000), isNull); // 起点=total
      expect(const RangeRequest(first: 2000).resolve(1000), isNull);
      expect(const RangeRequest(suffixLength: 0).resolve(1000), isNull);
      expect(const RangeRequest(first: 0, last: 999).resolve(0), isNull);
    });
  });

  group('响应头构造', () {
    test('contentRangeHeader 输出 bytes first-last/total', () {
      expect(contentRangeHeader(0, 99, 1000), 'bytes 0-99/1000');
      expect(contentRangeHeader(500, 999, 1000), 'bytes 500-999/1000');
    });

    test('unsatisfiableContentRange 输出 bytes */total', () {
      expect(unsatisfiableContentRange(1000), 'bytes */1000');
    });
  });

  group('parseContentRange（上游响应校验用）', () {
    test('标准形式', () {
      final cr = parseContentRange('bytes 0-99/1000');
      expect(cr, isNotNull);
      expect(cr!.start, 0);
      expect(cr.end, 99);
      expect(cr.total, 1000);
    });

    test('大小写与空白不敏感', () {
      expect(parseContentRange(' Bytes 10-19/* ')!.total, isNull);
    });

    test('total 为 * 时为 null', () {
      final cr = parseContentRange('bytes 0-99/*');
      expect(cr, isNotNull);
      expect(cr!.total, isNull);
    });

    test('非法形态返回 null', () {
      expect(parseContentRange(null), isNull);
      expect(parseContentRange('bytes 99-0/1000'), isNull); // end < start
      expect(parseContentRange('bytes 0-99/50'), isNull); // total <= end
      expect(parseContentRange('bytes 0-99'), isNull);
      expect(parseContentRange('chunks 0-99/1000'), isNull);
    });
  });
}
