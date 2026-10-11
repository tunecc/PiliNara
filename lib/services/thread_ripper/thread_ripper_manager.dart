import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, visibleForTesting;

import 'package:PiliPlus/services/thread_ripper/classify.dart';
import 'package:PiliPlus/services/thread_ripper/contracts.dart';
import 'package:PiliPlus/services/thread_ripper/media_proxy_server.dart';
import 'package:PiliPlus/services/thread_ripper/media_transport.dart';
import 'package:PiliPlus/services/thread_ripper/media_transport_dio.dart';
import 'package:PiliPlus/services/thread_ripper/proxy_url.dart';
import 'package:PiliPlus/services/thread_ripper/scheduler.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

/// 应用级 Thread Ripper 装配：回环代理 + 每视频调度会话 + 描述符注册。
///
/// - 开关关闭：不启动代理，[rewritePlayable] 返回 null（URL 保持直连）。
/// - 代理绑定失败：`ThreadRipperProxy.disabled` 后本次运行内一律直连。
/// - 每个视频一个 [ThreadRipperSession]（[beginVideo]），视频/音频共享并发预算。
class ThreadRipperManager {
  ThreadRipperManager._();

  static final ThreadRipperManager I = ThreadRipperManager._();

  static final ThreadRipperProxy _proxy = ThreadRipperProxy.instance;

  MediaTransport? _transport;
  ThreadRipperSession? _session;
  bool _startCalled = false;

  /// originalUrl → token，总大小回填与去重用；token → originalUrl 反查。
  final Map<String, String> _tokenByFile = {};
  final Map<String, String> _fileByToken = {};
  final Map<String, Future<int?>> _totalProbes = {};

  bool get enabled => Pref.enableThreadRipper;

  /// 预热代理（异步绑定、幂等）。绑定完成前的首次改写会退直连，
  /// 之后的调用即可拿到代理 URL。
  void warm() {
    if (!enabled) {
      return;
    }
    _ensureStarted();
  }

  bool _ensureStarted() {
    if (_proxy.disabled) {
      return false;
    }
    if (!_startCalled) {
      _startCalled = true;
      _proxy.accelerator = _TotalLearningAccelerator(this);
      unawaited(_proxy.start());
    }
    return _proxy.port != null;
  }

  MediaTransport get _transportOrNull => _transport ??= DioMediaTransport();

  /// 把一路媒体流改写为本地代理 URL；返回 null 表示调用方沿用
  /// [fallback] 直连。任何失败都不得影响播放。
  String? rewritePlayable({
    required Iterable<String> candidateUrls,
    required bool isAudio,
    required String fallback,
    int? totalSize,
    String? contentType,
    int? bandWidth,
    int? indexEnd,
  }) {
    if (!enabled || !_ensureStarted() || _proxy.port == null) {
      return null;
    }
    try {
      _session ??= ThreadRipperSession(
        transport: _transportOrNull,
        // 码率驱动 hedge/饱和停止；索引末端决定 CRITICAL 通道（上游语义）
        requiredRateOf: (d) => d.bandWidth?.toDouble() ?? 0,
        indexEndOf: (d) => d.indexEnd ?? -1,
      );
      var effectiveFallback = fallback;
      var effectiveCandidates = candidateUrls.toList();
      if (Pref.threadRipperBlockPcdn) {
        effectiveCandidates = filterPcdnCandidates(effectiveCandidates);
        if (!effectiveCandidates.contains(effectiveFallback)) {
          // 兜底地址是 P2P 直连变体被排除：取首个幸存候选（官方镜像换签）
          effectiveFallback =
              effectiveCandidates.isNotEmpty ? effectiveCandidates.first : fallback;
        }
      }
      final candidates = <MediaCandidate>[
        MediaCandidate(url: effectiveFallback, host: Uri.parse(effectiveFallback).host),
        for (final url in effectiveCandidates)
          if (url != effectiveFallback) MediaCandidate(url: url, host: Uri.parse(url).host),
      ];
      final descriptor = MediaDescriptor(
        originalUrl: effectiveFallback,
        candidates: candidates,
        isAudio: isAudio,
        totalSize: totalSize,
        contentType: contentType,
        bandWidth: bandWidth,
        indexEnd: indexEnd,
      );
      final token = _proxy.registry.register(descriptor);
      _tokenByFile[effectiveFallback] = token;
      _fileByToken[token] = effectiveFallback;
      return buildProxyUrl(_proxy.port!, descriptor, token);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[thread-ripper] rewritePlayable failed: $e');
      }
      return null;
    }
  }

  static const _pcdnProxyHost = 'proxy-tf-all-ws.bilivideo.com';

  /// 屏蔽 PCDN：upgcxcode 形态的 PCDN 地址丢弃（其签名全镜像通用，换签
  /// 候选已覆盖）；mcdn 私有传输改写 proxy-tf 代理；szbdyd 改回 xy_usource
  /// 真实主机。非 P2P 地址原样保留。
  @visibleForTesting
  static List<String> filterPcdnCandidates(List<String> urls) {
    final out = <String>[];
    final seen = <String>{};
    for (final url in urls) {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        continue;
      }
      final cls = classifyCdnUrl(uri);
      if (!isP2PCdnDomain(uri.host)) {
        if (seen.add(uri.toString())) {
          out.add(url);
        }
        continue;
      }
      switch (cls) {
        case CdnUrlClass.mcdnTf:
          final rewritten = Uri(
            scheme: 'https',
            host: _pcdnProxyHost,
            queryParameters: {'url': url},
          ).toString();
          if (seen.add(rewritten)) {
            out.add(rewritten);
          }
        case CdnUrlClass.szbdyd:
          final source = uri.queryParameters['xy_usource'];
          if (source != null) {
            final rewritten = Uri(
              scheme: 'https',
              host: source,
              path: uri.path,
              query: uri.hasQuery ? uri.query : null,
            ).toString();
            if (seen.add(rewritten)) {
              out.add(rewritten);
            }
          }
        default:
          break; // upgcxcode 形态 P2P：换签候选已覆盖，直接排除
      }
    }
    return out;
  }

  /// 新 playinfo 落地时调用：丢弃上一视频的会话与登记。
  void beginVideo() {
    _tokenByFile.clear();
    _fileByToken.clear();
    _totalProbes.clear();
    _session?.dispose();
    _session = null;
    _proxy.registry.clear();
  }

  /// 视频页销毁时调用；与 [beginVideo] 同义，保留两个名字便于阅读调用点。
  void endVideo() => beginVideo();

  /// 预加载同类型其他清晰度的 init segment 与索引（跳过当前正在播放的
  /// 两路流）。descriptor 的 totalSize 未知不影响 warmup（显式范围请求）；
  /// [PreloadStream.fileKey] 必须与画质切换时 serve 使用的改写结果一致，
  /// 预热缓存才能命中。
  void preloadOtherQualities(Iterable<PreloadStream> streams) {
    if (!enabled) {
      return;
    }
    final session = _session;
    if (session == null) {
      return;
    }
    final specs = <PreloadSpec>[];
    for (final stream in streams) {
      final fileKey = stream.fileKey;
      final baseUrl = stream.baseUrl;
      if (fileKey.isEmpty ||
          baseUrl == null ||
          baseUrl.isEmpty ||
          baseUrl == stream.currentVideoUrl ||
          baseUrl == stream.currentAudioUrl) {
        continue;
      }
      final indexEnd = indexRangeEnd(stream.segmentBase);
      if (indexEnd == null) {
        continue;
      }
      final candidates = <MediaCandidate>[
        MediaCandidate(url: fileKey, host: Uri.parse(fileKey).host),
        for (final candidate in stream.playUrls)
          if (candidate.isNotEmpty && candidate != fileKey)
            MediaCandidate(url: candidate, host: Uri.parse(candidate).host),
      ];
      specs.add(PreloadSpec(
        key: fileKey,
        descriptor: MediaDescriptor(
          originalUrl: fileKey,
          candidates: candidates,
          isAudio: stream.isAudio,
          totalSize: null,
          bandWidth: stream.bandWidth,
          indexEnd: indexEnd,
        ),
        indexEnd: indexEnd,
      ));
    }
    if (specs.isNotEmpty) {
      session.registerPreload(specs);
    }
  }

  /// DASH `segmentBase.initialization/index_range`（"0-963" 形态）取索引段
  /// 末字节偏移；无索引信息返回 null。
  static int? indexRangeEnd(Map? segmentBase) {
    if (segmentBase == null) {
      return null;
    }
    final range = (segmentBase['indexRange'] ?? segmentBase['index_range'])
        ?.toString();
    if (range == null) {
      return null;
    }
    final dashIndex = range.lastIndexOf('-');
    if (dashIndex < 0 || dashIndex == range.length - 1) {
      return null;
    }
    return int.tryParse(range.substring(dashIndex + 1));
  }

  /// 测试观察：文件当前学到的总大小（未登记或未学到为 null）。
  @visibleForTesting
  int? totalFor(String fileKey) {
    final token = _tokenByFile[fileKey];
    if (token == null) {
      return null;
    }
    return _proxy.registry.lookup(token)?.totalSize;
  }

  /// 探测得到文件总大小后回填注册表，让后续请求直接加速。
  void _learnTotal(String fileKey, int total) {
    final token = _tokenByFile[fileKey];
    if (token == null) {
      return;
    }
    final old = _proxy.registry.lookup(token);
    if (old == null || old.totalSize == total) {
      return;
    }
    _proxy.registry.update(
      token,
      MediaDescriptor(
        originalUrl: old.originalUrl,
        candidates: old.candidates,
        isAudio: old.isAudio,
        totalSize: total,
        contentType: old.contentType,
        bandWidth: old.bandWidth,
        indexEnd: old.indexEnd,
      ),
    );
  }

  /// 学习 descriptor 的总大小：DASH 条目不带 size，先用 `bytes=0-0` 的
  /// Content-Range 学出总长（每文件一次），失败返回 null（放弃加速）。
  Future<int?> _probeTotal(MediaDescriptor descriptor) {
    final fileKey = descriptor.originalUrl;
    final existing = _totalProbes[fileKey];
    if (existing != null) {
      return existing;
    }
    final future = _doProbeTotal(descriptor)
        .whenComplete(() => _totalProbes.remove(fileKey));
    _totalProbes[fileKey] = future;
    return future;
  }

  Future<int?> _doProbeTotal(MediaDescriptor descriptor) async {
    try {
      final response = await _proxy.httpClient
          .fetch(descriptor.originalUrl, first: 0, last: 0)
          .timeout(const Duration(seconds: 4));
      // 必须消费/取消响应体（MediaHttpClient 契约）：探测只需头
      unawaited(
        response.stream.listen(null).cancel().catchError((_) {}),
      );
      if (response.statusCode != 206) {
        return null;
      }
      final contentRange = parseContentRange(response.header('content-range'));
      final total = contentRange?.total;
      if (total == null || total <= 0) {
        return null;
      }
      _learnTotal(descriptor.originalUrl, total);
      return total;
    } catch (_) {
      return null;
    }
  }
}

/// 预加载候选流的最小描述，由调用方（视频控制器）从 dash 数据组装。
class PreloadStream {
  const PreloadStream({
    required this.fileKey,
    required this.baseUrl,
    required this.playUrls,
    required this.isAudio,
    required this.currentVideoUrl,
    required this.currentAudioUrl,
    this.segmentBase,
    this.bandWidth,
  });

  /// 画质切换时 serve 使用的改写后 URL（与 `getCdnUrl` 结果一致），
  /// 作为预热缓存键。
  final String fileKey;

  /// 原始 baseUrl，仅用于跳过当前正在播放的流。
  final String? baseUrl;
  final Iterable<String> playUrls;
  final bool isAudio;
  final Map? segmentBase;

  /// 该清晰度的声明码率（bits/s），供调度器学习。
  final int? bandWidth;
  final String? currentVideoUrl;
  final String? currentAudioUrl;
}

/// 会话与代理之间的桥：descriptor 缺总大小时先探测再交给调度会话。
class _TotalLearningAccelerator implements MediaAccelerator {
  _TotalLearningAccelerator(this._manager);

  final ThreadRipperManager _manager;

  @override
  AcceleratedResponse? serve(MediaDescriptor descriptor, RangeRequest range) {
    // 会话已知总大小（预热学习或此前响应）时直接服务；否则按同步签名
    // 限制，先退直连并触发 bytes=0-0 探测，学到后该文件的后续请求加速。
    final session = _manager._session;
    final known =
        descriptor.totalSize ?? session?.knownTotal(descriptor.originalUrl);
    if (known != null) {
      return session?.serve(descriptor, range);
    }
    unawaited(_manager._probeTotal(descriptor));
    return null;
  }
}
