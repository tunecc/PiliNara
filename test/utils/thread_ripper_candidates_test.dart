import 'dart:io';

import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/services/thread_ripper/classify.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 验收 A2/A3/A4：PCDN 包装地址的规范化与换签候选。
void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'pili_tr_candidates_test',
    );
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('test_setting_tr_candidates');
  });
  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('test_setting_tr_candidates');
  });

  const wrapped =
      'https://xy220x202x9x135xy.mcdn.bilivideo.cn:8082/v1/resource/upgcxcode/99/91/x/x-1-30080.m4s?e=x&os=mcdn&upsig=y';
  const mountaintoysWrapped =
      'https://29e749o.edge.mountaintoys.cn:4483/v1/resource/upgcxcode/99/91/x/x-1-30080.m4s?e=x&os=mcdn&upsig=y';
  const mirror =
      'https://upos-sz-mirrorali.bilivideo.com/upgcxcode/99/91/x/x-1-30080.m4s?e=x&upsig=y';

  group('threadRipperCandidates', () {
    test('A3: 包装形态地址产出剥离 /v1/resource 的多节点换签候选', () {
      final candidates = VideoUtils.threadRipperCandidates([wrapped], wrapped);
      final swaps = candidates
          .where((c) => c.contains('/upgcxcode/') && !c.contains('/v1/resource/'))
          .toList();
      expect(swaps.length, greaterThan(1), reason: '应铺到多个候选节点');
      for (final swap in swaps) {
        expect(swap.startsWith('https://'), isTrue);
        expect(swap.contains('/v1/resource/'), isFalse);
      }
      // 原始包装地址保留（P2P 直连变体）
      expect(candidates, contains(wrapped));
    });

    test('A2: mountaintoys 子域是可替换媒体主机', () {
      final candidates = VideoUtils.threadRipperCandidates(
        [mountaintoysWrapped],
        mountaintoysWrapped,
      );
      final swaps = candidates
          .where((c) => c.startsWith('https://upos-sz-'))
          .toList();
      expect(swaps, isNotEmpty, reason: '子域后缀匹配失效时这里会是空列表');
    });

    test('A5: upos 签名换签不指向 akamaized', () {
      final candidates = VideoUtils.threadRipperCandidates([mirror], mirror);
      final akamai = candidates
          .where((c) => Uri.parse(c).host.endsWith('.akamaized.net'))
          .toList();
      expect(akamai, isEmpty);
      // 换签候选仍要存在（否则断言失去意义）
      expect(candidates.where((c) => c != mirror).length, greaterThan(1));
    });
  });

  group('getCdnUrl fallback', () {
    test('A4: 包装形态 playUrls 不再产出官方镜像 + /v1/resource 的坏地址', () {
      Pref.enableThreadRipper = false;
      final result = VideoUtils.getCdnUrl(
        const [wrapped],
        defaultCDNService: CDNService.ali,
      );
      expect(result.contains('/v1/resource/'), isFalse,
          reason: '官方镜像没有 /v1/resource 前缀路径，保留它必 404');
      expect(result.startsWith('https://upos-sz-mirrorali.bilivideo.com/upgcxcode/'), isTrue, reason: 'actual: $result');
    });

    test('A4b: 剥离后的 fallback 对不含 /upgcxcode 的地址保持原逻辑', () {
      Pref.enableThreadRipper = false;
      const plain = 'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/00/1/a.m4s?e=x&upsig=y';
      final result = VideoUtils.getCdnUrl(
        [plain],
        defaultCDNService: CDNService.baseUrl,
      );
      expect(result, plain);
    });
  });
}
