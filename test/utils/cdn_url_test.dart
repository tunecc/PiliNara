import 'dart:io';

import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  // VideoUtils 的 cdnService / customCDNUrl 等静态字段在类加载时读 Pref，
  // fork 的测试基设必须先开出 GStorage.setting（与其余 fork 测试一致）
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('pili_cdn_url_test');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('test_setting_cdn_url');
  });
  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('test_setting_cdn_url');
  });
  const cosov =
      'https://upos-sz-mirrorcosov.bilivideo.com/upgcxcode/01/video.m4s'
      '?os=cosovbv&upsig=cosov-signature';
  const akamai =
      'https://upos-hz-mirrorakam.akamaized.net/upgcxcode/01/video.m4s'
      '?os=akam&upsig=akamai-signature&hdnts=exp%3D123~hmac%3Dabc&x=one%2btwo';
  const mcdn = 'https://example.mcdn.bilivideo.cn:4483/v1/resource/video.m4s';

  setUp(() {
    VideoUtils.cdnService = CDNService.akamai;
    VideoUtils.disableAudioCDN = false;
  });

  test('Akamai selects its signed backup without changing any bytes', () {
    expect(VideoUtils.getCdnUrl([cosov, akamai]), akamai);
  });

  test('Akamai keeps a signed primary URL', () {
    expect(VideoUtils.getCdnUrl([akamai, cosov]), akamai);
  });

  test('Akamai finds its backup after a relay URL', () {
    expect(VideoUtils.getCdnUrl([mcdn, cosov, akamai]), akamai);
  });

  test('missing Akamai backup preserves the original primary URL', () {
    expect(VideoUtils.getCdnUrl([cosov]), cosov);
    expect(VideoUtils.getCdnUrl([mcdn, cosov]), mcdn);
  });

  test('Akamai selects the signed audio backup too', () {
    expect(VideoUtils.getCdnUrl([cosov, akamai], isAudio: true), akamai);
  });

  test('disabled audio CDN still keeps the original audio mirror', () {
    VideoUtils.disableAudioCDN = true;
    expect(VideoUtils.getCdnUrl([cosov, akamai], isAudio: true), cosov);
    expect(VideoUtils.getCdnUrl([cosov, akamai]), akamai);
  });

  test('base and backup selection retain their existing behavior', () {
    expect(
      VideoUtils.getCdnUrl([
        mcdn,
        cosov,
        akamai,
      ], defaultCDNService: CDNService.baseUrl),
      mcdn,
    );
    expect(
      VideoUtils.getCdnUrl([
        mcdn,
        cosov,
        akamai,
      ], defaultCDNService: CDNService.backupUrl),
      cosov,
    );
  });

  test('other configured mirrors retain their existing behavior', () {
    expect(
      VideoUtils.getCdnUrl([cosov, akamai], defaultCDNService: CDNService.ali),
      Uri.parse(cosov).replace(host: CDNService.ali.host).toString(),
    );
  });

  test('Akamai hostname must match exactly', () {
    const lookalike =
        'https://upos-hz-mirrorakam.akamaized.net.example.com/video.m4s';
    expect(VideoUtils.getCdnUrl([cosov, lookalike, akamai]), akamai);
    expect(VideoUtils.getCdnUrl([cosov, lookalike]), cosov);
  });
}
