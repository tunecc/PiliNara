import 'dart:math' show max;

import 'package:PiliPlus/models/common/video/audio_quality.dart';
import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/models/common/video/video_decode_type.dart';
import 'package:PiliPlus/models/video/play/url.dart'
    show AudioItem, VideoItem, FormatItem;
import 'package:PiliPlus/models_new/live/live_room_play_info/codec.dart';
import 'package:PiliPlus/utils/cdn_node_store.dart';
import 'package:PiliPlus/services/thread_ripper/classify.dart'
    show isAkamaiHost, normalizeUpgcxcodeUri, signatureFamilyOf, SignatureFamily;
import 'package:PiliPlus/services/thread_ripper/thread_ripper_manager.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, visibleForTesting;

abstract final class VideoUtils {
  static CDNService cdnService = Pref.defaultCDNService;
  static String? customCDNUrl = Pref.customCDNUrl;
  static String? liveCdnUrl = Pref.liveCdnUrl;
  static bool disableAudioCDN = Pref.disableAudioCDN;

  static const _proxyTf = 'proxy-tf-all-ws.bilivideo.com';

  static final _mirrorRegex = RegExp(
    r'^https?://(?:upos-\w+-(?!302)\w+|(?:upos|proxy)-tf-[^/]+)\.(?:bilivideo|akamaized)\.(?:com|net)/upgcxcode',
  );

  static final _mCdnTfRegex = RegExp(
    r'^https?://(?:(?:(?:\d{1,3}\.){3}\d{1,3}|[^/]+\.mcdn\.bilivideo\.(?:com|cn|net))(?:\:\d{1,5})?/v\d/resource)',
  );

  static const _mediaHostSuffixes = [
    '.bilivideo.com',
    '.bilivideo.cn',
    '.acgvideo.com',
    '.akamaized.net',
  ];

  // host 首段为 API/上报类前缀的域名不参与自定义节点替换
  static final _blockedHostPrefix = RegExp(r'^(?:bvc|data|pbp|api)\w*\.');

  static bool _isReplaceableMediaHost(String host) {
    final lower = host.toLowerCase();
    if (_blockedHostPrefix.hasMatch(lower)) {
      return false;
    }
    return lower.endsWith('.edge.mountaintoys.cn') ||
        lower == 'edge.mountaintoys.cn' ||
        _mediaHostSuffixes.any(lower.endsWith);
  }

  /// 完整 URL 提取 host；纯 host 不得含路径/查询/锚点；空白视为 null
  static String? normalizeCustomCDNHost(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return null;
    }
    if (uri.hasScheme) {
      return uri.host.isEmpty ? null : uri.host;
    }
    if (trimmed.contains('/') ||
        trimmed.contains('?') ||
        trimmed.contains('#') ||
        trimmed.contains(' ')) {
      return null;
    }
    return trimmed;
  }

  /// 当前生效 CDN 的展示文本：自定义节点优先反查节点表标注地区运营商
  static String effectiveCdnDesc() {
    final host = customCDNUrl;
    if (host == null) {
      return cdnService.desc;
    }
    return CdnNodeStore.labelOf(host) ?? '自定义：$host';
  }

  /// [customHost] 显式指定自定义节点（节点测速用）；未传时按 [applyCustomCDN]
  /// 决定是否采用全局自定义节点。全局自定义生效时完全旁路枚举语义。
  ///
  /// [useThreadRipper] 仅由播放链路传入：Thread Ripper 开启时改写为本地代理
  /// URL（多 CDN 并发下载），失败或关闭时仍返回单节点结果；下载等其他
  /// 调用点不传该参数，行为不变。
  static String getCdnUrl(
    Iterable<String> urls, {
    CDNService? defaultCDNService,
    String? customHost,
    bool applyCustomCDN = true,
    bool isAudio = false,
    bool useThreadRipper = false,
    int? totalSize,
    String? mimeType,
    int? bandWidth,
    int? indexEnd,
  }) {
    final result = pickCdnUrl(
      urls,
      defaultCDNService: defaultCDNService,
      customHost: customHost,
      applyCustomCDN: applyCustomCDN,
      isAudio: isAudio,
      bypassCdnPreference: useThreadRipper,
    );
    if (!useThreadRipper) {
      return result;
    }
    return ThreadRipperManager.I.rewritePlayable(
          candidateUrls: threadRipperCandidates(urls, result),
          isAudio: isAudio,
          fallback: result,
          totalSize: totalSize,
          contentType: mimeType,
          bandWidth: bandWidth,
          indexEnd: indexEnd,
        ) ??
        result;
  }

  /// Thread Ripper 候选 URL：播放信息给出的全部原始地址（PCDN 包装/直连
  /// 形态原样保留）+ [fallback] + 对每个含 `/upgcxcode/` 路径地址的节点池
  /// 换签。签名只绑定查询参数（`os=mcdn` 签名在官方镜像同样 206），换签前
  /// 剥离 `/v1/resource` 传输包装并清掉源端口（PCDN 边缘的 4483/8082 不适用
  /// 于官方镜像）；Akamai 主机不接受 upos 签名，两侧都不参与换签。
  static List<String> threadRipperCandidates(
    Iterable<String> urls,
    String fallback,
  ) {
    final list = <String>[fallback, ...urls];
    for (final url in list.toList()) {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !uri.path.contains('/upgcxcode/') ||
          isAkamaiHost(uri.host) ||
          signatureFamilyOf(uri) != SignatureFamily.upos ||
          !_isReplaceableMediaHost(uri.host) ||
          _blockedHostPrefix.hasMatch(uri.host)) {
        continue;
      }
      final stripped = normalizeUpgcxcodeUri(uri);
      for (final svc in CDNService.values) {
        final host = svc.host;
        if (host == null ||
            host.isEmpty ||
            isAkamaiHost(host) ||
            host == uri.host ||
            _blockedHostPrefix.hasMatch(host)) {
          continue;
        }
        final candidate = Uri(
          scheme: 'https',
          host: host,
          path: stripped.path,
          query: stripped.hasQuery ? stripped.query : null,
        ).toString();
        if (!list.contains(candidate)) {
          list.add(candidate);
        }
      }
    }
    return list;
  }

  @visibleForTesting
  static String pickCdnUrl(
    Iterable<String> urls, {
    CDNService? defaultCDNService,
    String? customHost,
    bool applyCustomCDN = true,
    bool isAudio = false,
    bool bypassCdnPreference = false,
  }) {
    defaultCDNService ??= cdnService;
    if (!bypassCdnPreference) {
      customHost ??= applyCustomCDN ? customCDNUrl : null;
    }
    if (isAudio && disableAudioCDN) {
      customHost = null;
    }

    // PCDN 边缘地址的 /v1/resource 传输包装先剥离：官方镜像没有该前缀路径，
    // 带着 它换 host 会得到必 404 的地址
    final preparedUrls = urls
        .map((u) {
          final uri = Uri.tryParse(u);
          return uri == null ? u : normalizeUpgcxcodeUri(uri).toString();
        })
        .toList();

    if (!bypassCdnPreference &&
        customHost == null &&
        defaultCDNService == CDNService.baseUrl) {
      return preparedUrls.first;
    }

    String? mcdnTf;
    String? mcdnUpgcxcode;

    String last = '';
    for (final url in preparedUrls) {
      last = url;
      if (_mirrorRegex.hasMatch(url)) {
        if (bypassCdnPreference) {
          // 线程撕裂者竞速接管：节点偏好旁路，返回 playinfo 原始镜像地址
          return url;
        }
        final uri = Uri.parse(url);
        if (uri.queryParameters['os'] == 'mcdn') {
          // upos-sz-mirrorcoso1.bilivideo.com os=mcdn
          mcdnUpgcxcode = url;
        } else {
          if (customHost != null) {
            return uri.replace(host: customHost).toString();
          }
          if (defaultCDNService == CDNService.backupUrl ||
              (isAudio && disableAudioCDN)) {
            return url;
          }
          return uri.replace(host: defaultCDNService.host).toString();
        }
      }

      if (_mCdnTfRegex.hasMatch(url)) {
        mcdnTf = url;
        continue;
      }

      // upos-\w*-302.* & bcache & mcdn host but upgcxcode path
      if (url.contains('/upgcxcode/')) {
        mcdnUpgcxcode = url;
        continue;
      }

      // may be deprecated
      if (url.contains('szbdyd.com')) {
        final uri = Uri.parse(url);
        final hostname = uri.queryParameters['xy_usource'] ??
            (bypassCdnPreference ? null : (customHost ?? defaultCDNService.host));
        if (hostname == null) {
          continue;
        }
        return uri
            .replace(scheme: 'https', host: hostname, port: 443)
            .toString();
      }

      if (kDebugMode) {
        debugPrint('unknown cdn type: $url');
      }
    }

    if (mcdnUpgcxcode != null) {
      if (bypassCdnPreference) {
        // 线程撕裂者竞速接管：返回剥离包装后的原始地址（P2P 直连变体）
        return mcdnUpgcxcode;
      }
      final uri = Uri.parse(mcdnUpgcxcode);
      // 换到官方镜像时必须清掉 PCDN 源端口（4483/8082）：镜像只有 443。
      // Uri.replace 无法删除已有端口，需用构造器重建。
      String rebuild(Uri source, String host) => Uri(
            scheme: 'https',
            host: host,
            path: source.path,
            query: source.hasQuery ? source.query : null,
          ).toString();
      if (customHost != null && _isReplaceableMediaHost(uri.host)) {
        return rebuild(uri, customHost);
      }
      return rebuild(uri, (defaultCDNService.host ?? CDNService.ali.host)!);
    }
    return mcdnTf == null
        ? last
        : Uri(
            scheme: 'https',
            host: _proxyTf,
            queryParameters: {'url': mcdnTf},
          ).toString();
  }

  static String getLiveCdnUrl(CodecItem e, {int index = 0}) {
    final urlInfo = e.urlInfo.getOrFirst(index);
    return (liveCdnUrl ?? urlInfo.host) + e.baseUrl + urlInfo.extra;
  }

  static VideoDecodeFormatType selectCodec(
    Iterable<String> codecs,
    List<VideoDecodeFormatType> preferCodecs,
  ) {
    if (preferCodecs.isNotEmpty) {
      int bestIndex = preferCodecs.length;
      for (final e in codecs) {
        for (int i = 0; i < bestIndex; i++) {
          if (preferCodecs[i].codes.any(e.startsWith)) {
            bestIndex = i;
            if (bestIndex == 0) {
              return preferCodecs[0];
            }
            break;
          }
        }
      }
      if (bestIndex < preferCodecs.length) {
        return preferCodecs[bestIndex];
      }
    }
    return VideoDecodeFormatType.fromString(codecs.first);
  }

  static int _selectFromCandidates(
    List<int> candidates,
    int preferredQuality,
    Set<int> blockedQualities,
  ) {
    if (blockedQualities.isNotEmpty) {
      final allowed =
          candidates.where((e) => !blockedQualities.contains(e)).toList();
      if (allowed.isNotEmpty) {
        return allowed.findClosestTarget((e) => e <= preferredQuality, max);
      }
    }
    return candidates.findClosestTarget((e) => e <= preferredQuality, max);
  }

  static int _findAvailableVideoQuality(
    List<VideoItem> videoList,
    List<int>? acceptQuality,
    int preferQuality, {
    Set<int> blockedQualities = const {},
  }) {
    final highestVideoQa = videoList.first.id;

    // 无屏蔽时沿用上游语义
    if (blockedQualities.isEmpty) {
      if (preferQuality >= highestVideoQa) {
        return highestVideoQa;
      }
      if (acceptQuality != null && acceptQuality.isNotEmpty) {
        return acceptQuality.findTargetMedia((e) => e, preferQuality);
      }
      return videoList.findTargetMedia((e) => e.id, preferQuality).quality.code;
    }

    final qualitys = acceptQuality;
    if (qualitys == null || qualitys.isEmpty) {
      return highestVideoQa;
    }
    if (preferQuality <= highestVideoQa) {
      return _selectFromCandidates(qualitys, preferQuality, blockedQualities);
    }
    if (blockedQualities.contains(highestVideoQa)) {
      final allowed = qualitys
          .where((e) => !blockedQualities.contains(e) && e <= highestVideoQa)
          .toList();
      if (allowed.isNotEmpty) return allowed.reduce(max);
    }
    return highestVideoQa;
  }

  static (
    int targetQuality,
    FormatItem targetFormat,
    VideoDecodeFormatType targetDecode,
    VideoItem targetVideo,
  )
  findTargetVideo(
    List<VideoItem> videoList,
    int preferQuality,
    List<int>? acceptQuality,
    List<FormatItem> supportFormats,
    List<VideoDecodeFormatType> preferCodecs, {
    Set<int> blockedQualities = const {},
  }) {
    assert(videoList.isNotEmpty);

    final targetQuality = _findAvailableVideoQuality(
      videoList,
      acceptQuality,
      preferQuality,
      blockedQualities: blockedQualities,
    );

    final targetFormat = supportFormats.firstWhere(
      (e) => e.quality == targetQuality,
      orElse: () => supportFormats.first,
    );

    final targetDecode = VideoUtils.selectCodec(
      targetFormat.codecs!,
      preferCodecs,
    );

    final targetQaVideoList = videoList
        .where((e) => e.id == targetQuality)
        .toList();

    final targetVideo = targetQaVideoList.firstWhere(
      (e) => targetDecode.codes.any(e.codecs!.startsWith),
      orElse: () => targetQaVideoList.first,
    );

    return (targetQuality, targetFormat, targetDecode, targetVideo);
  }

  static AudioItem findTargetAudio(
    List<AudioItem> audioList,
    int preferQuality,
  ) {
    assert(audioList.isNotEmpty);

    final preferredRank = AudioQuality.fromCode(preferQuality).rank;
    return audioList.findTargetMedia(
      (audio) => AudioQuality.fromCode(audio.id).rank,
      preferredRank,
    );
  }
}
