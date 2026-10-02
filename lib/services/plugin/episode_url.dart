/// 集数源站 URL 归一化：相对路径 → 绝对 URL，协议统一，去除尾部斜杠。
String normalizeEpisodeUrl(String baseUrl, String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final rawUri = Uri.tryParse(trimmed);
  final baseUri = Uri.tryParse(baseUrl.trim());
  final hasValidBase =
      baseUri != null && baseUri.hasScheme && baseUri.host.isNotEmpty;

  Uri? resolved;
  if (rawUri != null && rawUri.hasScheme && rawUri.host.isNotEmpty) {
    resolved = rawUri;
  } else if (hasValidBase) {
    try {
      resolved = baseUri.resolve(trimmed);
    } catch (_) {
      resolved = null;
    }
  }
  if (resolved == null || resolved.host.isEmpty) return trimmed;

  if (hasValidBase &&
      (baseUri.scheme == 'http' || baseUri.scheme == 'https') &&
      (resolved.scheme == 'http' || resolved.scheme == 'https') &&
      resolved.scheme != baseUri.scheme &&
      resolved.host == baseUri.host &&
      resolved.hasPort == baseUri.hasPort &&
      (!resolved.hasPort || resolved.port == baseUri.port)) {
    resolved = resolved.replace(scheme: baseUri.scheme);
  }

  String path = resolved.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final hasQuery = resolved.hasQuery && resolved.query.isNotEmpty;
  final hasFragment = resolved.hasFragment && resolved.fragment.isNotEmpty;
  return Uri(
    scheme: resolved.scheme,
    host: resolved.host,
    port: resolved.hasPort ? resolved.port : null,
    path: path,
    query: hasQuery ? resolved.query : null,
    fragment: hasFragment ? resolved.fragment : null,
  ).toString();
}
