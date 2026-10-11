/// Thread Ripper 的 HTTP Range 语义工具。
///
/// 覆盖代理两侧的解析与产出：把播放器的 `Range` 请求头解析为
/// [RangeRequest]（解析失败一律 null，调用方退化为整段透传，由上游 CDN
/// 自行处理）；把 [RangeRequest.resolve] 不可满足的请求按 RFC 9110 回
/// 416 与 `Content-Range: bytes */total`；并按上游 `classify.ts` 的语义
/// 解析上游响应的 `Content-Range` 供校验。形态参考
/// Make-Bilibili-Great-Than-Ever-Before `src/core/player/range.ts`。
library;

import 'package:PiliPlus/services/thread_ripper/contracts.dart';

final RegExp _rangeHeaderRegex = RegExp(r'^bytes=(.*)$', caseSensitive: false);
final RegExp _rangeSpecRegex = RegExp(r'^(\d*)-(\d*)$');
final RegExp _contentRangeRegex = RegExp(
  r'^bytes (\d+)-(\d+)/(\d+|\*)$',
  caseSensitive: false,
);

/// 解析播放器的 `Range` 请求头。
///
/// 支持 `bytes=a-b`、`bytes=a-`、`bytes=-n` 单段形式；多段 range、
/// 非 bytes 单位、语法非法（含 end < start、超出整数范围）均返回 null
/// ——调用方应忽略该头直接透传，而不是拒绝请求。
/// `bytes=-0` 保留为不可满足形态（total 已知时回 416）。
RangeRequest? parseRangeHeader(String? value) {
  if (value == null) return null;
  final header = value.trim().toLowerCase();
  if (header.isEmpty) return null;
  final headerMatch = _rangeHeaderRegex.firstMatch(header);
  if (headerMatch == null) return null;
  // 多段 range（如 `bytes=0-1,5-6`）不加速，交由上游原样处理
  final specs = headerMatch.group(1)!.split(',');
  if (specs.length != 1) return null;
  final match = _rangeSpecRegex.firstMatch(specs.first.trim());
  if (match == null) return null;
  final firstStr = match.group(1)!;
  final lastStr = match.group(2)!;
  if (firstStr.isEmpty && lastStr.isEmpty) return null;
  if (firstStr.isNotEmpty && lastStr.isNotEmpty) {
    final first = int.tryParse(firstStr);
    final last = int.tryParse(lastStr);
    if (first == null || last == null || last < first) return null;
    return RangeRequest(first: first, last: last);
  }
  if (firstStr.isNotEmpty) {
    final first = int.tryParse(firstStr);
    if (first == null) return null;
    return RangeRequest(first: first);
  }
  final suffixLength = int.tryParse(lastStr);
  if (suffixLength == null) return null;
  return RangeRequest(suffixLength: suffixLength);
}

/// 206 响应的 `Content-Range` 头值。
String contentRangeHeader(int first, int last, int total) =>
    'bytes $first-$last/$total';

/// 416 响应的 `Content-Range` 头值。
String unsatisfiableContentRange(int total) => 'bytes */$total';

/// 解析上游响应的 `Content-Range` 头；total 为 `*` 时 [ContentRange.total]
/// 为 null。形态非法、end < start 或 total <= end（同上游 classify 语义）
/// 返回 null。
ContentRange? parseContentRange(String? value) {
  if (value == null) return null;
  final match = _contentRangeRegex.firstMatch(value.trim());
  if (match == null) return null;
  final start = int.tryParse(match.group(1)!);
  final end = int.tryParse(match.group(2)!);
  if (start == null || end == null || end < start) return null;
  final totalStr = match.group(3)!;
  if (totalStr == '*') {
    return ContentRange(start: start, end: end);
  }
  final total = int.tryParse(totalStr);
  if (total == null || total <= end) return null;
  return ContentRange(start: start, end: end, total: total);
}
