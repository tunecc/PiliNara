/// Browser fingerprint spoofing for Douyin web API.
/// Generates realistic browser-like headers and parameters to avoid detection.
import 'dart:math';

abstract final class DouyinFingerprint {
  static final _random = Random();

  /// Rotating pool of realistic Chrome User-Agents
  static const _uaPool = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 Edg/122.0.0.0',
  ];

  static String get userAgent => _uaPool[_random.nextInt(_uaPool.length)];

  /// Build complete request headers mimicking a real browser session
  static Map<String, String> buildHeaders({String? cookie}) {
    return {
      'User-Agent': userAgent,
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Referer': 'https://www.douyin.com/',
      'Origin': 'https://www.douyin.com',
      'Sec-Ch-Ua': '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
      'Sec-Ch-Ua-Mobile': '?0',
      'Sec-Ch-Ua-Platform': '"Windows"',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-origin',
      'Dnt': '1',
      if (cookie != null) 'Cookie': cookie,
    };
  }

  /// Generate a random device_id-style parameter
  static String generateDeviceId() {
    final chars = '0123456789abcdef';
    return List.generate(32, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  /// Generate msToken-like parameter (base64-ish random string)
  static String generateMsToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
    return List.generate(107, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  /// Build common query parameters that Douyin web expects
  static Map<String, dynamic> buildCommonParams() {
    return {
      'device_platform': 'webapp',
      'aid': '6383',
      'channel': 'channel_pc_web',
      'pc_client_type': '1',
      'version_code': '170400',
      'version_name': '17.4.0',
      'cookie_enabled': 'true',
      'screen_width': '1920',
      'screen_height': '1080',
      'browser_language': 'zh-CN',
      'browser_platform': 'Win32',
      'browser_name': 'Chrome',
      'browser_version': '124.0.0.0',
      'browser_online': 'true',
      'engine_name': 'Blink',
      'engine_version': '124.0.0.0',
      'os_name': 'Windows',
      'os_version': '10',
      'cpu_core_num': '${_random.nextInt(8) + 4}',
      'device_memory': '${_random.nextInt(16) + 8}',
      'platform': 'PC',
      'downlink': '10',
      'effective_type': '4g',
      'round_trip_time': '${_random.nextInt(50) + 10}',
    };
  }
}
