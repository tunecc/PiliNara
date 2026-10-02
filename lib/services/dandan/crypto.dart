import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// DanDan API app credentials injected at build time via --dart-define.
///
/// Both keys are required for the signature algorithm. Without them the
/// client will silently return empty results (no crash).
abstract final class DandanCredentials {
  static String get appId =>
      const String.fromEnvironment('DANDANAPI_APPID', defaultValue: '');

  static String get apikey =>
      const String.fromEnvironment('DANDANAPI_KEY', defaultValue: '');

  /// Returns true only when both credentials are present at compile time.
  static bool get isEnabled => appId.isNotEmpty && apikey.isNotEmpty;
}

/// Generate the X-Signature header value for a DanDan API request.
///
/// Algorithm (from DanDanPlay open platform docs):
/// ```
/// signature = base64(sha256(appId + timestamp + path + apikey))
/// ```
///
/// [path] is the URI path *without* query parameters (e.g. `/api/v2/comment/12345`).
String generateDandanSignature(String path, int timestamp) {
  final data = '${DandanCredentials.appId}$timestamp$path${DandanCredentials.apikey}';
  final bytes = utf8.encode(data);
  final digest = sha256.convert(bytes);
  return base64Encode(digest.bytes);
}
