import 'dart:io';

import 'package:PiliPlus/models/common/video/author_play_speed.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'pili_author_speed_pref_test',
    );
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('test_setting_author_speed');
    GStorage.video = await Hive.openBox('test_video_author_speed');
  });

  group('Pref author play speed storage', () {
    test('upsert adds and updates the entry for one author', () {
      Pref.authorPlaySpeeds = {};

      Pref.upsertAuthorPlaySpeed(
        const AuthorPlaySpeed(mid: 42, name: 'UP主', speed: 2.0),
      );
      expect(Pref.authorPlaySpeeds[42]?.speed, 2.0);
      expect(Pref.authorPlaySpeeds[42]?.name, 'UP主');

      Pref.upsertAuthorPlaySpeed(
        const AuthorPlaySpeed(mid: 42, name: 'UP主', speed: 1.5),
      );
      expect(Pref.authorPlaySpeeds[42]?.speed, 1.5);
      expect(Pref.authorPlaySpeeds.length, 1);
    });

    test('upsert keeps other authors intact', () {
      Pref.authorPlaySpeeds = {
        42: const AuthorPlaySpeed(mid: 42, name: 'A', speed: 1.5),
      };

      Pref.upsertAuthorPlaySpeed(
        const AuthorPlaySpeed(mid: 43, name: 'B', speed: 3.0),
      );

      expect(Pref.authorPlaySpeeds.length, 2);
      expect(Pref.authorPlaySpeeds[42]?.speed, 1.5);
      expect(Pref.authorPlaySpeeds[43]?.speed, 3.0);
    });

    test('remove deletes only the target author and is idempotent', () {
      Pref.authorPlaySpeeds = {
        42: const AuthorPlaySpeed(mid: 42, name: 'A', speed: 1.5),
        43: const AuthorPlaySpeed(mid: 43, name: 'B', speed: 3.0),
      };

      Pref.removeAuthorPlaySpeed(42);
      expect(Pref.authorPlaySpeeds.containsKey(42), isFalse);
      expect(Pref.authorPlaySpeeds[43]?.speed, 3.0);

      Pref.removeAuthorPlaySpeed(42);
      expect(Pref.authorPlaySpeeds.length, 1);
    });

    test('playSpeedForAuthor falls back to global default', () {
      Pref.authorPlaySpeeds = {
        42: const AuthorPlaySpeed(mid: 42, name: 'A', speed: 1.5),
      };

      expect(Pref.playSpeedForAuthor(42), 1.5);
      expect(Pref.playSpeedForAuthor(999), Pref.playSpeedDefault);
      expect(Pref.playSpeedForAuthor(null), Pref.playSpeedDefault);
    });
  });
}
