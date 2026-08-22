import 'package:PiliPlus/models_new/space/space_archive/item.dart';
import 'package:PiliPlus/pages/member_video/video_filter.dart';
import 'package:flutter_test/flutter_test.dart';

SpaceArchiveItem _item({
  required int play,
  int? progress,
  int? duration,
}) {
  return SpaceArchiveItem.fromJson({
    'title': 'test',
    'play': play,
    if (progress != null || duration != null)
      'history': {'progress': progress, 'duration': duration},
  });
}

void main() {
  group('MemberVideoFilter.shouldHide', () {
    test('no active filter hides nothing', () {
      final filter = MemberVideoFilter();
      expect(filter.hasActiveFilter, isFalse);
      expect(filter.shouldHide(_item(play: 0)), isFalse);
      expect(filter.shouldHide(_item(play: 999999999, progress: 10)), isFalse);
    });

    test('min play threshold hides lower plays (A1)', () {
      final filter = MemberVideoFilter()
        ..enableMinPlay = true
        ..minPlay = 100000;
      expect(filter.shouldHide(_item(play: 99999)), isTrue);
      expect(filter.shouldHide(_item(play: 100000)), isFalse);
      expect(filter.shouldHide(_item(play: 100001)), isFalse);
    });

    test('max play threshold hides higher plays (A2)', () {
      final filter = MemberVideoFilter()
        ..enableMaxPlay = true
        ..maxPlay = 500000;
      expect(filter.shouldHide(_item(play: 500001)), isTrue);
      expect(filter.shouldHide(_item(play: 500000)), isFalse);
      expect(filter.shouldHide(_item(play: 499999)), isFalse);
    });

    test('min and max combine as interval', () {
      final filter = MemberVideoFilter()
        ..enableMinPlay = true
        ..minPlay = 10000
        ..enableMaxPlay = true
        ..maxPlay = 1000000;
      expect(filter.shouldHide(_item(play: 9999)), isTrue);
      expect(filter.shouldHide(_item(play: 1000001)), isTrue);
      expect(filter.shouldHide(_item(play: 500000)), isFalse);
    });

    test('null view is not hidden by play thresholds (A17)', () {
      final filter = MemberVideoFilter()
        ..enableMinPlay = true
        ..enableMaxPlay = true;
      // stat.view == null 时两个阈值都不隐藏
      final item = SpaceArchiveItem.fromJson({'title': 'x', 'play': null});
      expect(item.stat.view, isNull);
      expect(filter.shouldHide(item), isFalse);
    });

    test('hideCompleted hides fully watched (A3/A13)', () {
      final filter = MemberVideoFilter()..hideCompleted = true;
      expect(
        filter.shouldHide(_item(play: 1, progress: 100, duration: 100)),
        isTrue,
      );
      expect(
        filter.shouldHide(_item(play: 1, progress: 30, duration: 100)),
        isFalse,
      );
      expect(filter.shouldHide(_item(play: 1)), isFalse);
    });

    test('hideInProgress hides partially watched (A3/A14)', () {
      final filter = MemberVideoFilter()..hideInProgress = true;
      expect(
        filter.shouldHide(_item(play: 1, progress: 30, duration: 100)),
        isTrue,
      );
      expect(
        filter.shouldHide(_item(play: 1, progress: 100, duration: 100)),
        isFalse,
      );
      expect(filter.shouldHide(_item(play: 1)), isFalse);
    });

    test('both watched switches hide all watched (A15)', () {
      final filter = MemberVideoFilter()
        ..hideCompleted = true
        ..hideInProgress = true;
      expect(
        filter.shouldHide(_item(play: 1, progress: 100, duration: 100)),
        isTrue,
      );
      expect(
        filter.shouldHide(_item(play: 1, progress: 30, duration: 100)),
        isTrue,
      );
      expect(filter.shouldHide(_item(play: 1)), isFalse);
    });

    test('incomplete history data is not watched (A17)', () {
      final filter = MemberVideoFilter()
        ..hideCompleted = true
        ..hideInProgress = true;
      expect(filter.shouldHide(_item(play: 1, progress: 100)), isFalse);
      expect(filter.shouldHide(_item(play: 1, duration: 100)), isFalse);
    });

    test('reset clears all switches', () {
      final filter = MemberVideoFilter()
        ..enableMinPlay = true
        ..enableMaxPlay = true
        ..hideCompleted = true
        ..hideInProgress = true;
      expect(filter.hasActiveFilter, isTrue);
      filter.reset();
      expect(filter.hasActiveFilter, isFalse);
      expect(filter.shouldHide(_item(play: 1, progress: 1, duration: 2)), isFalse);
    });
  });
}
