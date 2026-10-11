import 'dart:io';

import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 验收 A1-A3：线程撕裂者与 CDN 节点偏好的互斥语义。
void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'pili_tr_exclusivity_test',
    );
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('test_setting_tr_exclusivity');
  });
  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('test_setting_tr_exclusivity');
  });

  const mirror =
      'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/99/91/x/x-1-30080.m4s?e=x&upsig=y';
  const mirrorOther =
      'https://upos-sz-mirrorali.bilivideo.com/upgcxcode/99/91/x/x-1-30080.m4s?e=x&upsig=y';
  const wrapped =
      'https://xy220x202x9x135xy.mcdn.bilivideo.cn:8082/v1/resource/upgcxcode/99/91/x/x-1-30080.m4s?e=x&os=mcdn&upsig=y';
  const mcdnTf =
      'https://113.194.35.225:4483/v1/resource/99/91/x/x-1-30080.m4s?e=x';
  const szbdyd =
      'https://pcdn.szbdyd.com/path/upgcxcode/99/91/x/x-1-30080.m4s?e=x&xy_usource=upos-sz-mirrorali.bilivideo.com';
  const szbdydNoSource =
      'https://pcdn.szbdyd.com/path/upgcxcode/99/91/x/x-1-30080.m4s?e=x';

  group('A1: 竞速开启时旁路节点偏好', () {
    test('官方镜像返回 playinfo 原始地址，而非节点改写', () {
      final result = VideoUtils.pickCdnUrl(
        [mirror],
        defaultCDNService: CDNService.ali,
        bypassCdnPreference: true,
      );
      expect(result, mirror);
    });

    test('多地址时返回 playinfo 首个镜像地址', () {
      final result = VideoUtils.pickCdnUrl(
        [mirror, mirrorOther],
        defaultCDNService: CDNService.ali,
        customHost: 'custom-cdn.example.com',
        bypassCdnPreference: true,
      );
      expect(result, mirror);
    });

    test('包装/PCDN 地址返回剥离后的原始地址（P2P 直连变体）', () {
      final result = VideoUtils.pickCdnUrl(
        [wrapped],
        defaultCDNService: CDNService.ali,
        bypassCdnPreference: true,
      );
      expect(result, contains('/upgcxcode/'));
      expect(result.contains('/v1/resource/'), isFalse);
      expect(result.startsWith('https://xy220x202x9x135xy.mcdn.bilivideo.cn'), isTrue);
    });
  });

  group('A2: 正确性改写两种模式都保留', () {
    test('mcdn 私有传输（无 upgcxcode）走 proxy-tf 代理', () {
      final result = VideoUtils.pickCdnUrl(
        [mcdnTf],
        defaultCDNService: CDNService.ali,
        bypassCdnPreference: true,
      );
      expect(result.startsWith('https://proxy-tf-all-ws.bilivideo.com?url='), isTrue);
    });

    test('szbdyd 按 xy_usource 改写', () {
      final result = VideoUtils.pickCdnUrl(
        [szbdyd],
        defaultCDNService: CDNService.ali,
        bypassCdnPreference: true,
      );
      expect(result, contains('upos-sz-mirrorali.bilivideo.com'));
    });

    test('szbdyd 无 xy_usource 且旁路时原样保留（不崩溃）', () {
      final result = VideoUtils.pickCdnUrl(
        [szbdydNoSource],
        defaultCDNService: CDNService.ali,
        bypassCdnPreference: true,
      );
      expect(result, szbdydNoSource);
    });
  });

  group('A3: 竞速关闭时节点偏好照常', () {
    test('官方镜像按默认节点改写', () {
      final result = VideoUtils.pickCdnUrl(
        [mirror],
        defaultCDNService: CDNService.ali,
      );
      expect(result, startsWith('https://upos-sz-mirrorali.bilivideo.com/upgcxcode/'));
    });

    test('自定义节点优先于默认节点', () {
      final result = VideoUtils.pickCdnUrl(
        [mirror],
        defaultCDNService: CDNService.ali,
        customHost: 'custom-cdn.example.com',
      );
      expect(result, contains('custom-cdn.example.com'));
    });

    test('包装形态重建为官方镜像剥离路径（上一 change 行为回归）', () {
      final result = VideoUtils.pickCdnUrl(
        [wrapped],
        defaultCDNService: CDNService.ali,
      );
      expect(result, startsWith('https://upos-sz-mirrorali.bilivideo.com/upgcxcode/'));
      expect(result.contains('/v1/resource/'), isFalse);
      expect(result.contains(':8082'), isFalse);
    });
  });
}
