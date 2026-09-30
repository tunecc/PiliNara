import 'package:PiliPlus/pages/offline_decode_lab/controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OfflineDecodeLabPage extends StatefulWidget {
  const OfflineDecodeLabPage({super.key});
  @override
  State<OfflineDecodeLabPage> createState() => _OfflineDecodeLabPageState();
}

class _OfflineDecodeLabPageState extends State<OfflineDecodeLabPage> {
  late final OfflineDecodeLabController _ctrl = Get.put(OfflineDecodeLabController());
  double _selectedSpeed = 2.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('离线解码实验室')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Card(
            child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('解码器性能测试', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('以固定倍速播放相同视频片段，测量播放器实际推进时间与物理时间的比值，得出解码器在您设备上的实际性能。', style: Theme.of(context).textTheme.bodyMedium),
            ])),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Text('测试倍速: '),
            DropdownButton<double>(
              value: _selectedSpeed,
              items: [1.0, 1.5, 2.0, 3.0, 4.0, 8.0].map((s) => DropdownMenuItem(value: s, child: Text('${s}x'))).toList(),
              onChanged: _ctrl.isTesting.value ? null : (v) => setState(() => _selectedSpeed = v!),
            ),
            const Spacer(),
            Obx(() => _ctrl.isTesting.value
                ? ElevatedButton(onPressed: _ctrl.stopTest, child: const Text('停止'))
                : ElevatedButton(onPressed: () => _ctrl.startTest(speed: _selectedSpeed), child: const Text('开始测试'))),
          ]),
          const SizedBox(height: 24),
          Obx(() => Card(
            child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              Text(_ctrl.status.value, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _StatItem(label: '物理时间', value: '${(_ctrl.elapsedMs.value / 1000).toStringAsFixed(1)}s')),
                Expanded(child: _StatItem(label: '播放器时间', value: '${(_ctrl.playerPositionMs.value / 1000).toStringAsFixed(1)}s')),
                Expanded(child: _StatItem(label: '实际倍速', value: '${_ctrl.actualSpeed.value.toStringAsFixed(2)}x')),
                Expanded(child: _StatItem(label: '名义倍速', value: '${_ctrl.nominalSpeed.value}x')),
              ]),
              if (_ctrl.elapsedMs.value > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_ctrl.actualSpeed.value / _ctrl.nominalSpeed.value).clamp(0.0, 1.0),
                  minHeight: 8,
                ),
                const SizedBox(height: 4),
                Text('效率: ${((_ctrl.actualSpeed.value / _ctrl.nominalSpeed.value) * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
              ],
            ])),
          )),
        ]),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
    ]);
  }
}
