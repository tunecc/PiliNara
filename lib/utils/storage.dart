import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models/user/danmaku_rule_adapter.dart';
import 'package:PiliPlus/models/video_bookmark_adapter.dart';
import 'package:PiliPlus/models/user/info.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account_adapter.dart';
import 'package:PiliPlus/utils/accounts/account_type_adapter.dart';
import 'package:PiliPlus/utils/accounts/cookie_jar_adapter.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/set_int_adapter.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as path;

abstract final class GStorage {
  static late final Box<UserInfoData> userInfo;
  static late final Box<dynamic> historyWord;
  static late final Box<dynamic> localCache;
  static late final Box<dynamic> setting;
  static late final Box<dynamic> video;
  static late final Box<int> watchProgress;
  static const exportableLocalCacheKeys = [
    'historyPause',
    'blackMids',
    'dynamicsBlockedMids',
    'whitelistMids',
    'recommendBlockedMids',
    'replyBlockedMids',
    'remarkMids',
  ];

  /// 不参与导出的设置项：本机临时缓存，换设备/重装后导入无意义
  static const nonExportableSettingKeys = {
    SettingBoxKey.aiModelListCache,
    SettingBoxKey.aiModelListCacheTime,
  };
  static late final Box<Uint8List>? reply;

  static Future<void> init() async {
    Hive.init(path.join(appSupportDirPath, 'hive'));
    regAdapter();

    await Future.wait([
      // 登录用户信息
      Hive.openBox<UserInfoData>(
        'userInfo',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 2;
        },
      ).then((res) => userInfo = res),
      // 本地缓存
      Hive.openBox(
        'localCache',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 4;
        },
      ).then((res) => localCache = res),
      // 设置
      Hive.openBox('setting').then((res) => setting = res),
      // 搜索历史
      Hive.openBox(
        'historyWord',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 10;
        },
      ).then((res) => historyWord = res),
      // 视频设置
      Hive.openBox('video').then((res) => video = res),
      Hive.openBox('playbackStats').then((res) => playbackStats = res),
      Hive.openBox('playbackArchive').then((res) => playbackArchive = res),
      Hive.openBox('playbackStatsPending').then(
        (res) => playbackStatsPending = res,
      ),
      Hive.openBox(cdnDiagnosticsBoxName).then((res) => cdnDiagnostics = res),
      Hive.openBox(cdnDiagnosticsHistoryBoxName).then(
        (res) => cdnDiagnosticsHistory = res,
      ),
      Accounts.init(),
      Hive.openBox<int>(
        'watchProgress',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 4;
        },
      ).then((res) => watchProgress = res),
    ]);

    if (Pref.saveReply) {
      reply = await Hive.openBox<Uint8List>(
        'reply',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 10;
        },
      );
    } else {
      reply = null;
    }
  }

  static String exportAllSettings() {
    // 导出需要保存的 localCache 数据，排除临时数据
    final localCacheData = <String, dynamic>{};
    for (final key in exportableLocalCacheKeys) {
      final value = localCache.get(key);
      if (value != null) {
        localCacheData[key] = _encodeLocalCacheValue(key, value);
      }
    }

    // 导出设置项时排除本机临时缓存
    final settingData = Map<String, dynamic>.from(setting.toMap())
      ..removeWhere((key, _) => nonExportableSettingKeys.contains(key));

    return Utils.jsonEncoder.convert({
      setting.name: settingData,
      video.name: video.toMap(),
      localCache.name: localCacheData,
    });
  }

  static Future<void> importAllSettings(String data) =>
      importAllJsonSettings(jsonDecode(data));

  static Future<List<void>> importAllJsonSettings(
    Map<String, dynamic> map,
  ) {
    final futures = <Future<void>>[
      setting.clear().then((_) => setting.putAll(map[setting.name])),
      video.clear().then((_) => video.putAll(map[video.name])),
    ];

    // 导入 localCache 数据（如果存在）
    if (map.containsKey(localCache.name)) {
      final localCacheMap = map[localCache.name] as Map<String, dynamic>;
      for (final entry in localCacheMap.entries) {
        if (!exportableLocalCacheKeys.contains(entry.key)) {
          continue;
        }
        futures.add(
          localCache.put(
            entry.key,
            _decodeLocalCacheValue(entry.key, entry.value),
          ),
        );
      }
    }

    return Future.wait(futures);
  }

  static void regAdapter() {
    Hive
      ..registerAdapter(OwnerAdapter())
      ..registerAdapter(UserInfoDataAdapter())
      ..registerAdapter(LevelInfoAdapter())
      ..registerAdapter(BiliCookieJarAdapter())
      ..registerAdapter(LoginAccountAdapter())
      ..registerAdapter(AccountTypeAdapter())
      ..registerAdapter(SetIntAdapter())
      ..registerAdapter(RuleFilterAdapter())
      ..registerAdapter(VideoBookmarkAdapter());
  }

  static dynamic _encodeLocalCacheValue(String key, dynamic value) {
    return switch (key) {
      'blackMids' ||
      'dynamicsBlockedMids' => value is Set ? value.toList() : value,
      'whitelistMids' ||
      'recommendBlockedMids' ||
      'replyBlockedMids' ||
      'remarkMids' =>
        value is Map ? value.map((k, v) => MapEntry(k.toString(), v)) : value,
      _ => value,
    };
  }

  static dynamic _decodeLocalCacheValue(String key, dynamic value) {
    return switch (key) {
      'blackMids' || 'dynamicsBlockedMids' =>
        value is List ? value.whereType<int>().toSet() : value,
      'whitelistMids' ||
      'recommendBlockedMids' ||
      'replyBlockedMids' ||
      'remarkMids' =>
        value is Map
            ? value.map(
                (k, v) =>
                    MapEntry(k.toString(), v is String ? v : v.toString()),
              )
            : value,
      _ => value,
    };
  }

  static Future<List<void>> compact() {
    return Future.wait([
      userInfo.compact(),
      historyWord.compact(),
      localCache.compact(),
      setting.compact(),
      video.compact(),
      Accounts.account.compact(),
      playbackStats.compact(),
      playbackArchive.compact(),
      cdnDiagnostics.compact(),
      cdnDiagnosticsHistory.compact(),
      watchProgress.compact(),
      ?reply?.compact(),
    ]);
  }

  static Future<List<void>> close() {
    return Future.wait([
      userInfo.close(),
      historyWord.close(),
      localCache.close(),
      setting.close(),
      video.close(),
      Accounts.account.close(),
      playbackStats.close(),
      playbackArchive.close(),
      cdnDiagnostics.close(),
      cdnDiagnosticsHistory.close(),
      watchProgress.close(),
      ?reply?.close(),
    ]);
  }

  static Future<List<void>> clear() {
    return Future.wait([
      userInfo.clear(),
      historyWord.clear(),
      localCache.clear(),
      setting.clear(),
      video.clear(),
      Accounts.clear(),
      playbackStats.clear(),
      playbackArchive.clear(),
      cdnDiagnostics.clear(),
      cdnDiagnosticsHistory.clear(),
      watchProgress.clear(),
      ?reply?.clear(),
    ]);
  }

  // === Playback statistics + cold archive (self-contained Hive boxes) ===
  static late final Box<dynamic> playbackStats;
  static late final Box<dynamic> playbackArchive;
  static late final Box<dynamic> playbackStatsPending;

  static File get playbackStatsHiveFile => _hiveFile('playbackStats');
  static File get playbackArchiveHiveFile => _hiveFile('playbackArchive');
  static File get playbackStatsPendingHiveFile =>
      _hiveFile('playbackStatsPending');

  static File _hiveFile(String name) =>
      File(path.join(appSupportDirPath, 'hive', '$name.hive'));

  static bool get playbackStatsReady =>
      setting.get(SettingBoxKey.playbackStatsReady, defaultValue: false);

  static set playbackStatsReady(bool value) =>
      setting.put(SettingBoxKey.playbackStatsReady, value);

  static bool get playbackArchiveDue =>
      setting.get(SettingBoxKey.playbackArchiveDue, defaultValue: false);

  static set playbackArchiveDue(bool value) =>
      setting.put(SettingBoxKey.playbackArchiveDue, value);

  static int? get playbackArchiveId =>
      setting.get(SettingBoxKey.playbackArchiveId);

  static set playbackArchiveId(int? value) =>
      setting.put(SettingBoxKey.playbackArchiveId, value);

  static Future<void> initializePlaybackStats() async {
    playbackStats = await Hive.openBox('playbackStats');
    playbackArchive = await Hive.openBox('playbackArchive');
    playbackStatsPending = await Hive.openBox('playbackStatsPending');
    playbackStatsReady = true;
  }

  static Future<void> rotatePlaybackStats() async =>
      playbackStats.clear();

  static Future<int> preparePlaybackArchiveId() async {
    final id = (playbackArchiveId ?? 0) + 1;
    playbackArchiveId = id;
    return id;
  }

  static Future<void> completePlaybackArchive() async =>
      playbackArchiveId = null;

  static Future<void> finishPlaybackArchive() async =>
      playbackArchiveDue = false;

  static Future<void> markPlaybackArchiveReset() async =>
      playbackArchiveId = null;

  static Future<void> discardOrphanPlaybackArchiveId() async =>
      playbackArchiveId = null;

  static Future<void> restorePlaybackStatsHive(File? source) async {
    if (source == null) return;
    await playbackStats.close();
    if (await playbackStatsHiveFile.exists()) {
      await playbackStatsHiveFile.delete();
    }
    await source.copy(playbackStatsHiveFile.path);
    playbackStats = await Hive.openBox('playbackStats');
  }

  static Future<void> restorePlaybackArchiveHive(File? source) async {
    if (source == null) return;
    await playbackArchive.close();
    if (await playbackArchiveHiveFile.exists()) {
      await playbackArchiveHiveFile.delete();
    }
    await source.copy(playbackArchiveHiveFile.path);
    playbackArchive = await Hive.openBox('playbackArchive');
  }

  // === CDN diagnostics (latest snapshot + append-only history) ===
  static const cdnDiagnosticsBoxName = 'cdnDiagnostics';
  static const cdnDiagnosticsHistoryBoxName = 'cdnDiagnosticsHistory';
  static late final Box<dynamic> cdnDiagnostics;
  static late final Box<dynamic> cdnDiagnosticsHistory;

  static Future<void> initCdnDiagnostics() async {
    cdnDiagnostics = await Hive.openBox(cdnDiagnosticsBoxName);
    cdnDiagnosticsHistory = await Hive.openBox(cdnDiagnosticsHistoryBoxName);
  }

  static List<({String id, Map<String, dynamic> record})>
      readCdnDiagnosticsSync() => [
    for (final entry in cdnDiagnostics.toMap().entries)
      (
        id: entry.key.toString(),
        record: Map<String, dynamic>.from(entry.value as Map),
      ),
  ];

  static List<({String id, Map<String, dynamic> record})>
      readCdnDiagnosticsHistorySync() => [
    for (final entry in cdnDiagnosticsHistory.toMap().entries)
      (
        id: entry.key.toString(),
        record: Map<String, dynamic>.from(entry.value as Map),
      ),
  ];

  static Future<void> replaceCdnDiagnostics(
    List<({String id, Map<String, dynamic> record})> entries,
  ) async {
    await cdnDiagnostics.clear();
    await cdnDiagnostics.putAll({
      for (final entry in entries) entry.id: entry.record,
    });
  }

  static Future<void> replaceCdnDiagnosticsHistory(
    List<({String id, Map<String, dynamic> record})> entries,
  ) async {
    await cdnDiagnosticsHistory.clear();
    await cdnDiagnosticsHistory.putAll({
      for (final entry in entries) entry.id: entry.record,
    });
  }

  static Future<void> appendCdnDiagnosticsHistory(
    List<({String id, Map<String, dynamic> record})> entries,
  ) async {
    await cdnDiagnosticsHistory.putAll({
      for (final entry in entries) entry.id: entry.record,
    });
  }

  static int _intStrDescKeyComparator(dynamic k1, dynamic k2) {
    if (k1 is int) {
      if (k2 is int) {
        return k2.compareTo(k1);
      } else {
        return -1;
      }
    } else if (k2 is String) {
      final lenCompare = k2.length.compareTo((k1 as String).length);
      if (lenCompare == 0) {
        return k2.compareTo(k1);
      } else {
        return lenCompare;
      }
    } else {
      return 1;
    }
  }
}
