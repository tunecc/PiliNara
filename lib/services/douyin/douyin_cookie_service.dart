/// Douyin cookie-based authentication service.
import 'dart:convert';
import 'package:PiliPlus/services/logger.dart';
import 'package:hive_ce/hive.dart';

abstract final class DouyinCookieService {
  static const _boxName = 'douyin_session';
  static const _keyEnabled = 'enabled';
  static const _keyCookie = 'cookie';
  static const _keyUserInfo = 'user_info';
  static Box<dynamic>? _box;

  static Future<void> init() async { _box ??= await Hive.openBox(_boxName); }

  static bool get isEnabled => _box?.get(_keyEnabled, defaultValue: false) ?? false;

  static Future<void> setEnabled(bool value) async {
    await init();
    await _box?.put(_keyEnabled, value);
    if (!value) { await _box?.delete(_keyCookie); await _box?.delete(_keyUserInfo); }
  }

  static Future<void> saveCookie(String cookie) async { await init(); await _box?.put(_keyCookie, cookie); }
  static String? get cookie => isEnabled ? (_box?.get(_keyCookie) as String?) : null;
  static bool get isLoggedIn => isEnabled && (cookie?.isNotEmpty ?? false);

  static Future<void> saveUserInfo(Map<String, dynamic> info) async {
    await init(); await _box?.put(_keyUserInfo, jsonEncode(info));
  }

  static Map<String, dynamic>? get userInfo {
    final raw = _box?.get(_keyUserInfo) as String?;
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }

  static Future<void> logout() async { await init(); await _box?.delete(_keyCookie); await _box?.delete(_keyUserInfo); }
}
