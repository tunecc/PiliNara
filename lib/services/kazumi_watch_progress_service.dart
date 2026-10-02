/// Watch progress persistence service ported from Kazumi.
import 'package:PiliPlus/utils/storage.dart';
import 'package:hive_ce/hive.dart';

abstract final class KazumiWatchProgressService {
  static const _boxName = 'kazumi_watch_progress';
  static Box<int>? _box;

  static Future<void> init() async {
    _box ??= await Hive.openBox<int>(_boxName);
  }

  static Future<void> saveProgress({required String bvid, required int cid, required int positionSeconds}) async {
    await init();
    await _box?.put('$bvid:$cid', positionSeconds);
  }

  static int? getProgress({required String bvid, required int cid}) {
    return _box?.get('$bvid:$cid');
  }

  static Future<void> clearProgress({required String bvid, required int cid}) async {
    await init();
    await _box?.delete('$bvid:$cid');
  }

  static Future<void> clearAll() async {
    await init();
    await _box?.clear();
  }
}
