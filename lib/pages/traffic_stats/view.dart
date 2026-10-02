import 'package:PiliPlus/pages/traffic_stats/controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

class TrafficStatsPage extends StatefulWidget {
  const TrafficStatsPage({super.key});
  @override
  State<TrafficStatsPage> createState() => _TrafficStatsPageState();
}

class _TrafficStatsPageState extends State<TrafficStatsPage> {
  late final TrafficStatsController _ctrl = Get.put(TrafficStatsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('流量统计')),
      body: Obx(() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('流量统计服务已激活', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('按小时记录 Wi-Fi / 蜂窝 / 等效移网的上下行流量。', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text('数据存储在本地 Hive 中，不会上传。', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
              ]),
            ),
          ),
        ],
      )),
    );
  }
}
