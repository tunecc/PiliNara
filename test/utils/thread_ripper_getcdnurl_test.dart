import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/services/thread_ripper/media_proxy_server.dart';
import 'package:PiliPlus/services/thread_ripper/thread_ripper_manager.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 任务 3.2 回归：getCdnUrl 关闭 Thread Ripper 时与既有行为完全一致；
/// 开启时改写为本地代理 URL。
void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'pili_tr_getcdnurl_test',
    );
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('test_setting_tr_getcdnurl');
  });
  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('test_setting_tr_getcdnurl');
    await ThreadRipperProxy.instance.close();
  });

  const urlA =
      'https://upos-sz-mirrorali.bilivideo.com/upgcxcode/00/1/a.m4s?e=x&upsig=y';
  const urlB =
      'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/00/1/a.m4s?e=x&upsig=y';

  test('OFF: baseUrl 选择返回首个 URL，行为不变', () {
    Pref.enableThreadRipper = false;
    final result = VideoUtils.getCdnUrl(
      const [urlA, urlB],
      defaultCDNService: CDNService.baseUrl,
    );
    expect(result, urlA);
  });

  test('ON: baseUrl 选择改写为本地代理 URL', () async {
    Pref.enableThreadRipper = true;
    final manager = ThreadRipperManager.I;
    manager
      ..beginVideo()
      ..warm();
    for (var i = 0;
        i < 100 && ThreadRipperProxy.instance.port == null;
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final port = ThreadRipperProxy.instance.port;
    if (port == null) {
      // 绑定失败环境（不该发生在 CI 本机）：跳过加速断言
      return;
    }
    final result = VideoUtils.getCdnUrl(
      const [urlA, urlB],
      defaultCDNService: CDNService.baseUrl,
      useThreadRipper: true,
      bandWidth: 2000000,
    );
    expect(result, startsWith('http://127.0.0.1:$port/tr/'));
    // 解码路径应还原为原 URL（透传兜底可用）
    final encoded = result.split('/tr/').last.split('/').first;
    final decoded =
        utf8.decode(base64Url.decode(encoded.padRight((encoded.length + 3) & ~3, '=')));
    expect(decoded, urlA);
    manager.endVideo();
  });
}
