import 'package:PiliPlus/controllers/quality_recommendation_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class QualityRecommendSettingPage extends StatefulWidget {
  const QualityRecommendSettingPage({super.key});
  @override State<QualityRecommendSettingPage> createState() => _State();
}

class _State extends State<QualityRecommendSettingPage> {
  late final QualityRecommendationController _ctrl;

  @override void initState() {
    super.initState();
    _ctrl = Get.put(QualityRecommendationController());
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('画质推荐设置')),
      body: Obx(() => ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
        SwitchListTile(
          title: const Text('启用智能画质推荐'),
          subtitle: const Text('根据网络状况和设备性能自动推荐最佳画质'),
          value: _ctrl.isEnabled.value,
          onChanged: _ctrl.toggleEnabled,
        ),
        const Divider(indent: 16, endIndent: 16),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('推荐策略', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary))),
        ListTile(
          leading: const Icon(Icons.wifi_outlined),
          title: const Text('Wi-Fi 推荐画质'),
          subtitle: Text(_ctrl.wifiQuality.value),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showQualityPicker(context, 'Wi-Fi', _ctrl.wifiQuality),
        ),
        ListTile(
          leading: const Icon(Icons.signal_cellular_alt_outlined),
          title: const Text('蜂窝网络推荐画质'),
          subtitle: Text(_ctrl.cellularQuality.value),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showQualityPicker(context, '蜂窝网络', _ctrl.cellularQuality),
        ),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(elevation: 0, color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(padding: const EdgeInsets.all(12),
              child: Text('画质推荐会根据您的网络类型、带宽和历史播放记录自动调整。\n您可以在播放页面随时手动切换画质。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5))))),
      ])),
    );
  }

  Future<void> _showQualityPicker(BuildContext context, String label, RxString current) async {
    const options = ['自动', '4K', '1080P60', '1080P+', '1080P', '720P60', '720P', '480P', '360P'];
    final selected = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
      title: Text('$label推荐画质'),
      children: options.map((o) => SimpleDialogOption(
        onPressed: () => Navigator.pop(ctx, o),
        child: Row(children: [Expanded(child: Text(o)), if (current.value == o) const Icon(Icons.check, size: 20)]),
      )).toList()));
    if (selected != null) current.value = selected;
  }
}
