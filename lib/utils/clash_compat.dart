abstract final class ClashCompat {
  static bool get isClashVpnRouting => false;
  static bool get clashVpnRunning => false;
  static bool get partnerStatusAvailable => false;
  static Future<void> clearFallback() async {}
  static Future<void> forceFallback() async {}
  static Future<bool> isAvailable() async => false;
  static Future<void> enable() async {}
  static Future<void> disable() async {}
  static bool get enabled => false;
}
