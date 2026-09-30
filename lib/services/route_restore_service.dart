import 'package:PiliPlus/utils/storage.dart';
abstract final class RouteRestoreService {
  static const _k = 'last_active_route';
  static Future<void> saveCurrentRoute(String r) async { await GStorage.setting.put(_k, r); }
  static String? getLastRoute() => GStorage.setting.get(_k) as String?;
  static Future<void> clearSavedRoute() async { await GStorage.setting.delete(_k); }
  static bool hasRouteToRestore() => getLastRoute() != null;
}
