import 'package:PiliPlus/pages/media_source/controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MediaSourcePage extends StatefulWidget {
  const MediaSourcePage({super.key});
  @override
  State<MediaSourcePage> createState() => _MediaSourcePageState();
}

class _MediaSourcePageState extends State<MediaSourcePage> {
  late final MediaSourceController _ctrl = Get.put(MediaSourceController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('订阅源管理')),
      body: Obx(() => ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SwitchListTile(
            title: const Text('启用订阅源'),
            subtitle: const Text('关闭后番剧详情页不显示外部源搜索结果'),
            value: _ctrl.isEnabled.value,
            onChanged: _ctrl.toggleEnabled,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('内置数据源', style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            )),
          ),
          ..._ctrl.sources.map((src) => ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(src.metadata.name.substring(0, 1), style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              )),
            ),
            title: Text(src.metadata.name),
            subtitle: Text('Tier ${src.tier} · ${src.enabled ? "已启用" : "已禁用"}'),
            trailing: Switch(
              value: src.enabled,
              onChanged: (v) => _ctrl.toggleSource(src.id, v),
            ),
          )),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '提示：订阅源用于在番剧详情页聚合搜索外部播放资源（BT/在线）。'
              '数据来自第三方站点，PiliNara 不提供任何视频资源。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      )),
    );
  }
}
