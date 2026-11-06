import 'dart:io';

import 'package:PiliPlus/models/common/floating_nav_bar_style.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  const boxName = 'test_setting_floating_nav_style';

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'pili_floating_nav_style_test',
    );
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox(boxName);
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk(boxName);
  });

  group('Pref floating nav bar style', () {
    test('storage key constant', () {
      expect(SettingBoxKey.floatingNavBarStyle, 'floatingNavBarStyle');
    });

    test('defaults to iconAndLabel on a fresh box', () {
      GStorage.setting.delete(SettingBoxKey.floatingNavBarStyle);
      expect(Pref.floatingNavBarStyle, FloatingNavBarStyle.iconAndLabel);
    });

    test('written value round-trips', () async {
      await GStorage.setting.put(
        SettingBoxKey.floatingNavBarStyle,
        FloatingNavBarStyle.labelOnly.index,
      );
      expect(Pref.floatingNavBarStyle, FloatingNavBarStyle.labelOnly);

      await GStorage.setting.put(
        SettingBoxKey.floatingNavBarStyle,
        FloatingNavBarStyle.iconOnly.index,
      );
      expect(Pref.floatingNavBarStyle, FloatingNavBarStyle.iconOnly);
    });

    test('out-of-range index falls back to iconAndLabel', () async {
      await GStorage.setting.put(SettingBoxKey.floatingNavBarStyle, 99);
      expect(Pref.floatingNavBarStyle, FloatingNavBarStyle.iconAndLabel);

      await GStorage.setting.put(SettingBoxKey.floatingNavBarStyle, -1);
      expect(Pref.floatingNavBarStyle, FloatingNavBarStyle.iconAndLabel);
    });

    test('non-int value falls back to iconAndLabel', () async {
      await GStorage.setting.put(SettingBoxKey.floatingNavBarStyle, 'bad');
      expect(Pref.floatingNavBarStyle, FloatingNavBarStyle.iconAndLabel);
    });
  });
}
