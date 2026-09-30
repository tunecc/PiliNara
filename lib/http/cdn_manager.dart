import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:dio/dio.dart';
import 'package:hive_ce/hive.dart';

/// Manages CDN node selection, failover, and performance tracking.
abstract final class CdnManager {
  static const _boxName = 'cdn_config';
  static const _keyNodes = 'nodes';
  static const _keyAutoSelect = 'auto_select';
  static const _keyPreferredNode = 'preferred_node';
  static const _keyFailCount = 'fail_counts';

  static Box<dynamic>? _box;
  static Dio? _dio;

  static const List<CdnNode> defaultNodes = [
    CdnNode(id: 'cn-hz', name: '杭州电信', host: 'upos-sz-mirrorcos.bilivideo.com', region: 'domestic', priority: 10),
    CdnNode(id: 'cn-sh', name: '上海联通', host: 'upos-sz-mirrorcoso1.bilivideo.com', region: 'domestic', priority: 11),
    CdnNode(id: 'cn-bj', name: '北京移动', host: 'upos-sz-mirrorcoso2.bilivideo.com', region: 'domestic', priority: 12),
    CdnNode(id: 'hk', name: '香港 HGC', host: 'upos-hz-mirrorakam.akamaized.net', region: 'overseas', priority: 20),
    CdnNode(id: 'tw', name: '台湾 HiNet', host: 'upos-tw-mirrorakam.akamaized.net', region: 'overseas', priority: 21),
    CdnNode(id: 'sg', name: '新加坡 AWS', host: 'upos-sg-mirrorakam.akamaized.net', region: 'overseas', priority: 22),
    CdnNode(id: 'us', name: '美国 CloudFront', host: 'upos-us-mirrorakam.akamaized.net', region: 'overseas', priority: 23),
    CdnNode(id: 'jp', name: '日本 IIJ', host: 'upos-jp-mirrorakam.akamaized.net', region: 'overseas', priority: 24),
  ];

  static Future<void> init() async {
    _box ??= await Hive.openBox(_boxName);
    _dio ??= Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  static List<CdnNode> getNodes() {
    final raw = _box?.get(_keyNodes) as String?;
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.map((e) => CdnNode.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return defaultNodes;
  }

  static Future<void> saveNodes(List<CdnNode> nodes) async {
    await init();
    await _box?.put(_keyNodes, jsonEncode(nodes.map((n) => n.toMap()).toList()));
  }

  static Future<CdnNode> getBestNode({String? region}) async {
    await init();
    final autoSelect = _box?.get(_keyAutoSelect, defaultValue: true) ?? true;
    final preferredId = _box?.get(_keyPreferredNode) as String?;
    final nodes = getNodes();
    final filtered = region != null
        ? nodes.where((n) => n.region == region || n.region == 'all').toList()
        : nodes;
    if (!autoSelect && preferredId != null) {
      final preferred = filtered.where((n) => n.id == preferredId).firstOrNull;
      if (preferred != null) return preferred;
    }
    final failCounts = _getFailCounts();
    filtered.sort((a, b) {
      final fa = failCounts[a.id] ?? 0;
      final fb = failCounts[b.id] ?? 0;
      if (fa != fb) return fa.compareTo(fb);
      return a.priority.compareTo(b.priority);
    });
    return filtered.isNotEmpty ? filtered.first : defaultNodes.first;
  }

  static String applyCdn(String originalUrl, CdnNode node) {
    try {
      final uri = Uri.parse(originalUrl);
      return uri.replace(host: node.host).toString();
    } catch (_) {
      return originalUrl;
    }
  }

  static Future<void> recordFailure(String nodeId) async {
    await init();
    final counts = _getFailCounts();
    counts[nodeId] = (counts[nodeId] ?? 0) + 1;
    await _box?.put(_keyFailCount, jsonEncode(counts));
  }

  static Future<void> recordSuccess(String nodeId) async {
    await init();
    final counts = _getFailCounts();
    counts[nodeId] = 0;
    await _box?.put(_keyFailCount, jsonEncode(counts));
  }

  static Future<CdnSpeedResult> testNode(CdnNode node, {int bytes = 2 * 1024 * 1024}) async {
    final url = 'https://${node.host}/test-speed-$bytes.bin';
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio!.get(url,
        options: Options(responseType: ResponseType.bytes, followRedirects: true));
      stopwatch.stop();
      final durationMs = stopwatch.elapsedMilliseconds;
      final sizeBytes = (response.data as List<int>?)?.length ?? 0;
      final throughputMbps = durationMs > 0 ? (sizeBytes * 8 / durationMs / 1000) : 0.0;
      return CdnSpeedResult(nodeId: node.id, nodeName: node.name, success: true,
        latencyMs: durationMs, throughputMbps: throughputMbps, sizeBytes: sizeBytes);
    } catch (e) {
      stopwatch.stop();
      return CdnSpeedResult(nodeId: node.id, nodeName: node.name, success: false,
        latencyMs: stopwatch.elapsedMilliseconds, errorMessage: e.toString());
    }
  }

  static Future<List<CdnSpeedResult>> testAllNodes({bool parallel = false}) async {
    final nodes = getNodes();
    if (parallel) {
      final results = await Future.wait(nodes.map((n) => testNode(n)));
      results.sort((a, b) => b.throughputMbps.compareTo(a.throughputMbps));
      return results;
    } else {
      final results = <CdnSpeedResult>[];
      for (final node in nodes) results.add(await testNode(node));
      results.sort((a, b) => b.throughputMbps.compareTo(a.throughputMbps));
      return results;
    }
  }

  static Future<void> setAutoSelect(bool value) async { await init(); await _box?.put(_keyAutoSelect, value); }
  static Future<void> setPreferredNode(String nodeId) async { await init(); await _box?.put(_keyPreferredNode, nodeId); }

  static Map<String, int> _getFailCounts() {
    final raw = _box?.get(_keyFailCount) as String?;
    if (raw != null) { try { return Map<String, int>.from(jsonDecode(raw) as Map); } catch (_) {} }
    return {};
  }
}

class CdnNode {
  final String id, name, host, region;
  final int priority;
  const CdnNode({required this.id, required this.name, required this.host, required this.region, this.priority = 50});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'host': host, 'region': region, 'priority': priority};
  factory CdnNode.fromMap(Map<String, dynamic> m) => CdnNode(
    id: m['id'] as String, name: m['name'] as String, host: m['host'] as String,
    region: m['region'] as String? ?? 'domestic', priority: m['priority'] as int? ?? 50);
}

class CdnSpeedResult {
  final String nodeId, nodeName;
  final bool success;
  final int latencyMs, sizeBytes;
  final double throughputMbps;
  final String? errorMessage;
  const CdnSpeedResult({required this.nodeId, required this.nodeName, required this.success,
    required this.latencyMs, this.throughputMbps = 0, this.sizeBytes = 0, this.errorMessage});
}
