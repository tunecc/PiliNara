import 'package:PiliPlus/plugin/pl_player/models/double_tap_seek_layout.dart';
import 'package:PiliPlus/plugin/pl_player/models/double_tap_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DoubleTapSeekLayout', () {
    test('normalizes side regions and keeps center at least 20 percent', () {
      final layout = DoubleTapSeekLayout.normalize(
        backwardPercent: 70,
        forwardPercent: 40,
      );

      expect(layout.backwardPercent, 40);
      expect(layout.forwardPercent, 40);
      expect(layout.centerPercent, 20);
    });

    test('allows side regions as low as 1 percent', () {
      final layout = DoubleTapSeekLayout.normalize(
        backwardPercent: 1,
        forwardPercent: 1,
      );

      expect(layout.backwardPercent, 1);
      expect(layout.forwardPercent, 1);
      expect(layout.centerPercent, 98);
    });

    test('resolves left center right zones from tap position', () {
      const layout = DoubleTapSeekLayout(
        backwardPercent: 25,
        forwardPercent: 25,
      );

      expect(
        layout.resolveType(tapPosition: 10, width: 100),
        DoubleTapType.left,
      );
      expect(
        layout.resolveType(tapPosition: 50, width: 100),
        DoubleTapType.center,
      );
      expect(
        layout.resolveType(tapPosition: 90, width: 100),
        DoubleTapType.right,
      );
    });

    test('resolves custom zone boundaries from configured percents', () {
      const layout = DoubleTapSeekLayout(
        backwardPercent: 10,
        forwardPercent: 15,
      );

      expect(
        layout.resolveType(tapPosition: 9.9, width: 100),
        DoubleTapType.left,
      );
      // 左边界恰好落在快退宽度上时归中间区
      expect(
        layout.resolveType(tapPosition: 10, width: 100),
        DoubleTapType.center,
      );
      // 快进起点在 85 附近（受浮点噪声影响不取精确边界值）
      expect(
        layout.resolveType(tapPosition: 84.9, width: 100),
        DoubleTapType.center,
      );
      expect(
        layout.resolveType(tapPosition: 86, width: 100),
        DoubleTapType.right,
      );
    });

    test('falls back to center when width is invalid', () {
      const layout = DoubleTapSeekLayout(
        backwardPercent: 25,
        forwardPercent: 25,
      );

      expect(
        layout.resolveType(tapPosition: 5, width: 0),
        DoubleTapType.center,
      );
    });
  });
}
