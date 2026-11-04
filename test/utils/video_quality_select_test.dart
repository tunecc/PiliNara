import 'package:PiliPlus/models/common/video/base_quality.dart';
import 'package:PiliPlus/models/common/video/video_decode_type.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:flutter_test/flutter_test.dart';

PlayUrlModel _playUrl(List<VideoQuality> videoIds) => PlayUrlModel.fromJson({
  'dash': {
    'duration': 0,
    'video': [
      for (final id in videoIds)
        {
          'id': id.code,
          'codecs': VideoDecodeFormatType.AV1.codes.first,
        },
    ],
  },
  'accept_quality': [
    for (final id in videoIds) id.code,
  ],
  'support_formats': [
    for (final id in videoIds)
      {
        'quality': id.code,
        'codecs': VideoDecodeFormatType.AV1.codes,
      },
  ],
});

void main() {
  test('find target quality', () {
    final playUrl = _playUrl(VideoQuality.values);
    final dash = playUrl.dash!;
    final preferQa = VideoQuality.high1080.code;
    final (
      int targetQuality,
      FormatItem targetFormat,
      VideoDecodeFormatType targetDecode,
      VideoItem targetVideo,
    ) = VideoUtils.findTargetVideo(
      dash.video!,
      preferQa,
      playUrl.acceptQuality,
      playUrl.supportFormats!,
      [.AV1],
    );
    expect(targetQuality, preferQa);
  });

  test('find closest quality', () {
    final playUrl = _playUrl(
      VideoQuality.values.toList()..remove(VideoQuality.high1080plus),
    );
    final dash = playUrl.dash!;
    final preferQa = VideoQuality.high1080plus.code;
    final (
      int targetQuality,
      FormatItem targetFormat,
      VideoDecodeFormatType targetDecode,
      VideoItem targetVideo,
    ) = VideoUtils.findTargetVideo(
      dash.video!,
      preferQa,
      playUrl.acceptQuality,
      playUrl.supportFormats!,
      [.AV1],
    );
    expect(targetQuality, VideoQuality.superResolution.code);
  });

  test('find closest quality', () {
    final playUrl = _playUrl([
      VideoQuality.dolbyVision,
      VideoQuality.high1080,
      VideoQuality.clear480,
    ]);
    final dash = playUrl.dash!;
    final preferQa = VideoQuality.speed240.code;
    final (
      int targetQuality,
      FormatItem targetFormat,
      VideoDecodeFormatType targetDecode,
      VideoItem targetVideo,
    ) = VideoUtils.findTargetVideo(
      dash.video!,
      preferQa,
      playUrl.acceptQuality,
      playUrl.supportFormats!,
      [.AV1],
    );
    expect(targetQuality, VideoQuality.clear480.code);
  });

  /// 接口 accept_quality 含实际 dash.video 里没有的档位（真实接口会出现这种不一致）
  PlayUrlModel _playUrlWithAccepts({
    required List<VideoQuality> streamed,
    required List<VideoQuality> accepted,
  }) => PlayUrlModel.fromJson({
    'dash': {
      'duration': 0,
      'video': [
        for (final q in streamed)
          {'id': q.code, 'codecs': VideoDecodeFormatType.AV1.codes.first},
      ],
    },
    'accept_quality': [
      for (final q in accepted) q.code,
    ],
    'support_formats': [
      for (final q in accepted)
        {'quality': q.code, 'codecs': VideoDecodeFormatType.AV1.codes},
    ],
  });

  const _streamed = [
    VideoQuality.high1080plus,
    VideoQuality.high720,
    VideoQuality.clear480,
  ];
  const _accepted = [
    VideoQuality.super4K,
    VideoQuality.high1080plus,
    VideoQuality.high1080,
    VideoQuality.high720,
    VideoQuality.clear480,
  ];

  test('选定档位没有对应流时退回实际存在的最高档，不抛异常', () {
    final playUrl = _playUrlWithAccepts(
      streamed: _streamed,
      accepted: _accepted,
    );
    final (
      int targetQuality,
      FormatItem targetFormat,
      VideoDecodeFormatType targetDecode,
      VideoItem targetVideo,
    ) = VideoUtils.findTargetVideo(
      playUrl.dash!.video!,
      VideoQuality.high1080.code,
      playUrl.acceptQuality,
      playUrl.supportFormats!,
      [.AV1],
    );
    expect(targetQuality, VideoQuality.high1080plus.code);
    expect(targetVideo.id, targetQuality);
  });

  test('退回档位被屏蔽时继续退到未屏蔽档', () {
    final playUrl = _playUrlWithAccepts(
      streamed: _streamed,
      accepted: _accepted,
    );
    final (
      int targetQuality,
      FormatItem targetFormat,
      VideoDecodeFormatType targetDecode,
      VideoItem targetVideo,
    ) = VideoUtils.findTargetVideo(
      playUrl.dash!.video!,
      VideoQuality.high1080.code,
      playUrl.acceptQuality,
      playUrl.supportFormats!,
      [.AV1],
      blockedQualities: {VideoQuality.high1080plus.code},
    );
    expect(targetQuality, VideoQuality.high720.code);
    expect(targetVideo.id, targetQuality);
  });
}
