import 'dart:io';

import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'pili_thread_ripper_setting_test',
    );
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('test_setting_thread_ripper');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('test_setting_thread_ripper');
  });

  group('Thread Ripper setting', () {
    test('storage key constant', () {
      expect(SettingBoxKey.enableThreadRipper, 'enableThreadRipper');
    });

    test('defaults to OFF on a fresh box', () {
      expect(Pref.enableThreadRipper, isFalse);
    });

    test('written value round-trips', () {
      Pref.enableThreadRipper = true;
      expect(Pref.enableThreadRipper, isTrue);
      Pref.enableThreadRipper = false;
      expect(Pref.enableThreadRipper, isFalse);
    });
  });
}
