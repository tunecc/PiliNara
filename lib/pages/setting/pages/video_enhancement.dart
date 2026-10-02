import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models/common/video_enhancement_algorithm.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VideoEnhancementPage extends StatelessWidget {
  const VideoEnhancementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctr = Get.put(_VideoEnhancementController());
    return Scaffold(
      appBar: AppBar(title: const Text('画质增强')),
      body: Obx(() {
        final algo = ctr.algorithm.value;
        final sharpness = ctr.fsrSharpness.value;
        final preset = ctr.preset.value;
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _SectionTitle('增强算法'),
            RadioListTile<VideoEnhancementAlgorithm>(
              title: const Text('Anime4K'),
              subtitle: const Text('基于 CNN 的实时动画增强，兼容性好'),
              value: VideoEnhancementAlgorithm.anime4k,
              groupValue: algo,
              onChanged: (v) => ctr.setAlgorithm(v!),
            ),
            RadioListTile<VideoEnhancementAlgorithm>(
              title: const Text('FSR 1.0'),
              subtitle: const Text('AMD FidelityFX 上采样，画质更佳但消耗更高'),
              value: VideoEnhancementAlgorithm.fsr10,
              groupValue: algo,
              onChanged: (v) => ctr.setAlgorithm(v!),
            ),
            const Divider(height: 24),
            if (algo == VideoEnhancementAlgorithm.anime4k) ...[
              _SectionTitle('Anime4K 预设'),
              RadioListTile<Anime4KPreset>(
                title: const Text('快速'),
                subtitle: const Text('较少 Pass，性能优先'),
                value: Anime4KPreset.fast,
                groupValue: preset,
                onChanged: (v) => ctr.setPreset(v!),
              ),
              RadioListTile<Anime4KPreset>(
                title: const Text('高质量'),
                subtitle: const Text('更多 Pass，细节更丰富'),
                value: Anime4KPreset.quality,
                groupValue: preset,
                onChanged: (v) => ctr.setPreset(v!),
              ),
              const Divider(height: 24),
            ],
            if (algo == VideoEnhancementAlgorithm.fsr10) ...[
              _SectionTitle('FSR 锐度'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text('低', style: TextStyle(color: Colors.grey)),
                    Expanded(
                      child: Slider(
                        value: sharpness,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        label: '${(sharpness * 100).round()}%',
                        onChanged: (v) => ctr.setSharpness(v),
                      ),
                    ),
                    const Text('高', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              Center(
                child: Text(
                  '锐度：${(sharpness * 100).round()}%',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const Divider(height: 24),
            ],
            SwitchListTile(
              title: const Text('跨视频记住设置'),
              subtitle: const Text('开启后，当前视频的增强设置会在下次播放时自动恢复'),
              value: ctr.remember.value,
              onChanged: (v) => ctr.setRemember(v),
            ),
          ],
        );
      }),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
}

class _VideoEnhancementController extends GetxController {
  final Rx<VideoEnhancementAlgorithm> algorithm =
      Rx<VideoEnhancementAlgorithm>(Pref.videoEnhancementAlgorithm);
  final RxDouble fsrSharpness = RxDouble(Pref.videoFsrSharpness);
  final Rx<Anime4KPreset> preset = Rx<Anime4KPreset>(Pref.videoAnime4KPreset);
  final RxBool remember = RxBool(Pref.videoEnhancementRemember);

  void setAlgorithm(VideoEnhancementAlgorithm v) async {
    algorithm.value = v;
    Pref.setVideoEnhancementAlgorithm(v);
    final ctr = PlPlayerController.getInstance();
    await ctr.setEnhancementAlgorithm(v);
  }

  void setPreset(Anime4KPreset v) async {
    preset.value = v;
    Pref.setVideoAnime4KPreset(v);
    final ctr = PlPlayerController.getInstance();
    await ctr.setAnime4KPreset(v);
  }

  void setSharpness(double v) async {
    fsrSharpness.value = v;
    Pref.setVideoFsrSharpness(v);
    final ctr = PlPlayerController.getInstance();
    await ctr.setFsrSharpness(v);
  }

  void setRemember(bool v) {
    remember.value = v;
    Pref.setVideoEnhancementRemember(v);
  }
}
