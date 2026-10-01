import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:dio/dio.dart';

/// DNS over HTTPS resolver.
///
/// Resolves hostnames through a DoH endpoint using the JSON API
/// (RFC 8427 application/dns-json), so DNS lookups are encrypted and not
/// visible to the local network.
abstract final class DoHResolver {
  static const Duration _timeout = Duration(seconds: 5);
  static final Map<String, List<InternetAddress>> _cache = {};
  static final HttpClient _client = HttpClient()
    ..idleTimeout = const Duration(seconds: 10);

  static const Map<String, String> builtInProviders = {
    'cloudflare': 'https://cloudflare-dns.com/dns-query',
    'google': 'https://dns.google/resolve',
    'quad9': 'https://dns.quad9.net:5053/dns-query',
    'alidns': 'https://dns.alidns.com/resolve',
    'tencent': 'https://doh.pub/resolve',
    'dnspod': 'https://doh.dnspod.com/resolve',
  };

  static bool get enabled => Pref.enableDoh;

  /// Endpoint actually used, empty when DoH is off or unconfigured.
  static String get endpoint {
    if (!enabled) return '';
    final provider = Pref.dohProvider;
    if (provider == 'custom') {
      return Pref.customDohUrl.trim();
    }
    return builtInProviders[provider] ?? builtInProviders['cloudflare']!;
  }

  static Future<List<InternetAddress>> lookup(String host) {
    final cached = _cache[host];
    if (cached != null && cached.isNotEmpty) {
      return Future<List<InternetAddress>>.value(cached);
    }
    return _resolve(host);
  }

  static Future<List<InternetAddress>> _resolve(String host) async {
    final url = endpoint;
    if (url.isEmpty) {
      // Fall back to the platform resolver when DoH is off/unconfigured.
      try {
        return await InternetAddress.lookup(host);
      } catch (_) {
        return const <InternetAddress>[];
      }
    }

    // An IP literal needs no DNS at all.
    final literal = InternetAddress.tryParse(host);
    if (literal != null) {
      _cache[host] = [literal];
      return [literal];
    }

    try {
      final uri = Uri.parse(url).replace(
        queryParameters: <String, String>{'name': host, 'type': 'A'},
      );
      final request = await _client.getUrl(uri).timeout(_timeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/dns-json')
        ..set(HttpHeaders.userAgentHeader, 'PiliNara-DoH');
      final response = await request.close().timeout(_timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map) return const <InternetAddress>[];
      final answers = decoded['Answer'];
      if (answers is! List) return const <InternetAddress>[];
      final addresses = <InternetAddress>[];
      for (final answer in answers) {
        if (answer is! Map) continue;
        final type = answer['type'];
        final data = answer['data'];
        if (data is! String) continue;
        // 1 = A record, 28 = AAAA record.
        if (type == 1 || type == 28) {
          final address = InternetAddress.tryParse(data.trim());
          if (address != null) addresses.add(address);
        }
      }
      if (addresses.isEmpty) {
        return await InternetAddress.lookup(host);
      }
      _cache[host] = addresses;
      return addresses;
    } catch (_) {
      // Never break connectivity because the DoH endpoint failed.
      try {
        return await InternetAddress.lookup(host);
      } catch (_) {
        return const <InternetAddress>[];
      }
    }
  }

  /// Drops cached answers, e.g. after the provider changes.
  static void clearCache() => _cache.clear();
}

/// Applies the current DoH setting to a [HttpClient].
void applyDoH(HttpClient client) {
  if (!DoHResolver.enabled) {
    client.connectionFactory = null;
    return;
  }
  client.connectionFactory = (Uri url, String? proxyHost, int? proxyPort) {
    final host = url.host;
    final port = url.port;
    final isSecure = url.scheme == 'https';
    return () async {
      final addresses = await DoHResolver.lookup(host);
      final candidates = addresses.isNotEmpty
          ? addresses
          : await InternetAddress.lookup(host);
      if (candidates.isEmpty) {
        throw SocketException('Failed host lookup: $host');
      }
      if (!isSecure && proxyHost != null && proxyPort != null) {
        return Socket.startConnect(proxyHost, proxyPort);
      }
      for (final address in candidates) {
        try {
          return await Socket.startConnect(address, port);
        } catch (_) {
          continue;
        }
      }
      throw SocketException('Failed host lookup: $host');
    };
  };
}
