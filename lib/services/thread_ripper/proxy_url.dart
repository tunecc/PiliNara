/// Thread Ripper 代理 URL 编解码。
///
/// 代理请求路径固定为 `/tr/<base64urlNoPad(originalUrl)>/<token>`：
/// 原始媒体 URL 编进路径，保证任何时刻（含 registry miss）都能退化为对它的
/// 纯透传；token 再经 [SessionRegistry] 反查完整描述符。base64url 无填充
/// 字符集（A-Za-z0-9-_）不含 `/`，可安全置于单个路径段内，对 mpv 的
/// `edl://` 拼接同样安全。
library;

import 'dart:convert';

import 'package:PiliPlus/services/thread_ripper/contracts.dart';

/// 为 [descriptor] 生成指向本地代理的 URL。
///
/// [token] 须来自 `SessionRegistry.register(descriptor)`；MediaDescriptor
/// 契约本身不携带 token，故需显式传入（注册后再构建是调用方的固定流程）。
String buildProxyUrl(int port, MediaDescriptor descriptor, String token) {
  final encoded = base64Url
      .encode(utf8.encode(descriptor.originalUrl))
      .replaceAll('=', '');
  return 'http://127.0.0.1:$port/tr/$encoded/$token';
}

/// 反解 `/tr/<base64urlNoPad(originalUrl)>/<token>` 路径。
///
/// 任何不合法形态（前缀、段数、base64 字符、解码结果非 http(s) URL）
/// 一律返回 null，由调用方按未知路径处理。
({String url, String token})? parseProxyPath(String path) {
  final segments = path.split('/');
  // ['', 'tr', <encoded>, <token>]
  if (segments.length != 4 || segments[0].isNotEmpty || segments[1] != 'tr') {
    return null;
  }
  final encoded = segments[2];
  final token = segments[3];
  if (encoded.isEmpty || token.isEmpty) return null;
  final String decoded;
  try {
    decoded = utf8.decode(base64Url.decode(base64Url.normalize(encoded)));
  } on FormatException {
    return null;
  }
  final uri = Uri.tryParse(decoded);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  return (url: decoded, token: token);
}
