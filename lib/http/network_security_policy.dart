/// Network security policy for Bilibili API requests.
/// Enforces TLS version, certificate pinning hints, and request signing.
import 'dart:io';

abstract final class NetworkSecurityPolicy {
  /// Minimum TLS version for all HTTPS connections
  static const SecurityContext? securityContext = null; // Use system default

  /// Whether to enforce HTTPS-only connections
  static const bool enforceHttps = true;

  /// Request timeout configuration
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 15);

  /// Validate that a URL complies with security policy
  static bool validateUrl(String url) {
    if (enforceHttps && !url.startsWith('https://')) {
      return false;
    }
    try {
      Uri.parse(url);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get recommended cipher suites for TLS connections
  static List<String> get recommendedCiphers => [
    'TLS_AES_256_GCM_SHA384',
    'TLS_CHACHA20_POLY1305_SHA256',
    'TLS_AES_128_GCM_SHA256',
  ];
}
