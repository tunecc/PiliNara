import 'package:PiliPlus/models/common/super_resolution_type.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_output_type.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PictureEnhanceSettingPage extends StatefulWidget {
  const PictureEnhanceSettingPage({super.key});

  @override
  State<PictureEnhanceSettingPage> createState() =>
      _PictureEnhanceSettingPageState();
}

class _PictureEnhanceSettingPageState
    extends State<PictureEnhanceSettingPage> {
  late SuperResolutionType _superResolution;
  late VideoOutputType _videoOutput;
  late bool _sdr2Hdr;

  @override
  void initState() {
    super.initState();
    _superResolution = Pref.superResolutionType;
    _videoOutput = Pref.videoOutput;
    _sdr2Hdr = Pref.enableSdr2Hdr;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('画质增强')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _section('渲染器'),
          for (final type in VideoOutputType.values)
            RadioListTile<VideoOutputType>(
              value: type,
              groupValue: _videoOutput,
              title: Text(type.label),
              subtitle: Text(type.description),
              onChanged: (v) => _setVideoOutput(v!),
            ),
          const Divider(height: 1),
          _section('超分辨率'),
          for (final type in SuperResolutionType.values)
            RadioListTile<SuperResolutionType>(
              value: type,
              groupValue: _superResolution,
              title: Text(type.label),
              onChanged: (v) => _setSuperResolution(v!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '超分辨率默认只对番剧生效，且需要开启硬件解码。'
              '使用 mediacodec-embed 渲染器时不支持超分辨率。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          const Divider(height: 1),
          _section('色彩'),
          SwitchListTile(
            title: const Text('SDR 转 HDR'),
            subtitle: const Text('将 SDR 画面做逆色调映射到 HDR，需设备支持 HDR'),
            value: _sdr2Hdr,
            onChanged: (v) => _setSdr2Hdr(v),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '渲染器与超分辨率在下一次打开视频时生效。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      );

  Future<void> _setSuperResolution(SuperResolutionType type) async {
    setState(() => _superResolution = type);
    await GStorage.setting.put(SettingBoxKey.superResolutionType, type.index);
  }

  Future<void> _setVideoOutput(VideoOutputType type) async {
    setState(() => _videoOutput = type);
    await GStorage.setting.put(SettingBoxKey.videoOutput, type.value);
  }

  Future<void> _setSdr2Hdr(bool value) async {
    setState(() => _sdr2Hdr = value);
    await GStorage.setting.put(SettingBoxKey.enableSdr2Hdr, value);
  }
}
