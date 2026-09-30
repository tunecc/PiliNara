import 'package:PiliPlus/controllers/quality_recommendation_controller.dart';
import 'package:PiliPlus/models/quality_mode.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class QualityRecommendSettingPage extends StatefulWidget {
  const QualityRecommendSettingPage({super.key});

  @override
  State<QualityRecommendSettingPage> createState() => _State();
}

class _State extends State<QualityRecommendSettingPage> {
  late final QualityRecommendationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(QualityRecommendationController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('画质推荐设置')),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SwitchListTile(
              title: const Text('启用智能画质推荐'),
              subtitle: const Text('根据网络状况和设备性能自动推荐最佳画质'),
              value: _ctrl.isAutoMode,
              onChanged: (v) => _ctrl.setMode(
                v ? QualityMode.auto : QualityMode.qualityFirst,
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                '推荐策略',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            for (final mode in _ctrl.allModes)
              ListTile(
                leading: Icon(_modeIcon(mode)),
                title: Text(_modeLabel(mode)),
                subtitle: Text(_modeDescription(mode)),
                trailing: _ctrl.currentMode.value == mode
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : const Icon(Icons.circle_outlined),
                onTap: () => _ctrl.setMode(mode),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '画质推荐会根据您的网络类型、带宽和历史播放记录自动调整。'
                    '您可以在播放页面随时手动切换画质。',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _modeIcon(QualityMode mode) => switch (mode) {
        QualityMode.qualityFirst => Icons.high_quality,
        QualityMode.smoothFirst => Icons.speed,
        QualityMode.batterySaver => Icons.battery_saver,
        QualityMode.auto => Icons.auto_mode,
      };

  String _modeLabel(QualityMode mode) => switch (mode) {
        QualityMode.qualityFirst => '画质优先',
        QualityMode.smoothFirst => '流畅优先',
        QualityMode.batterySaver => '省电模式',
        QualityMode.auto => '智能推荐',
      };

  String _modeDescription(QualityMode mode) => switch (mode) {
        QualityMode.qualityFirst => '始终选择最高可用画质',
        QualityMode.smoothFirst => '优先保证流畅播放，适当降低分辨率',
        QualityMode.batterySaver => '选择最低稳定画质，减少功耗',
        QualityMode.auto => '根据网络状况和设备性能自动选择',
      };
}
