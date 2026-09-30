class CdnTestResult {
  final String cdnName;
  final bool success;
  final double? throughputMbps;
  final int? ttfbMs;
  final int? dnsMs;
  final String? errorMessage;

  const CdnTestResult({
    required this.cdnName,
    required this.success,
    this.throughputMbps,
    this.ttfbMs,
    this.dnsMs,
    this.errorMessage,
  });
}
