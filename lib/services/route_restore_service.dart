/// Restores last visible page after Android kills app in background.
/// Ported from ekmope/PiliMax.
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/utils/storage.dart';

abstract final class RouteRestoreService {
  static const _lastRouteKey = 'last_active_route';
  static const _lastRouteParamsKey = 'last_active_route_params';
  static const _lastRouteTimestampKey = 'last_active_route_ts';

  /// Maximum age for route restoration (24 hours)
  static const _maxAge = Duration(hours: 24);

  /// Save current route for later restoration
  static Future<void> saveCurrentRoute(String routeName, {Map<String, dynamic>? params}) async {
    try {
      await GStorage.setting.put(_lastRouteKey, routeName);
      if (params != null) {
        await GStorage.setting.put(_lastRouteParamsKey, params);
      }
      await GStorage.setting.put(_lastRouteTimestampKey, DateTime.now().millisecondsSinceEpoch);
      logger.d('Route saved for restore: $routeName');
    } catch (e) {
      logger.w('Failed to save route: $e');
    }
  }

  /// Get the last saved route name
  static String? getLastRoute() {
    if (!_isFresh()) return null;
    return GStorage.setting.get(_lastRouteKey) as String?;
  }

  /// Get the last saved route parameters
  static Map<String, dynamic>? getLastRouteParams() {
    if (!_isFresh()) return null;
    return GStorage.setting.get(_lastRouteParamsKey) as Map<String, dynamic>?;
  }

  /// Clear saved route (call after successful restoration)
  static Future<void> clearSavedRoute() async {
    await GStorage.setting.delete(_lastRouteKey);
    await GStorage.setting.delete(_lastRouteParamsKey);
    await GStorage.setting.delete(_lastRouteTimestampKey);
  }

  /// Check if there is a fresh route to restore
  static bool hasRouteToRestore() => getLastRoute() != null;

  /// Check if saved route is still fresh enough to restore
  static bool _isFresh() {
    final ts = GStorage.setting.get(_lastRouteTimestampKey) as int?;
    if (ts == null) return false;
    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    return age < _maxAge;
  }
}
