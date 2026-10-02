import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:PiliPlus/services/traffic_stats_service.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class TrafficStatsPage extends StatefulWidget {
  const TrafficStatsPage({super.key});
  @override
  State<TrafficStatsPage> createState() => _TrafficStatsPageState();
}

class _TrafficStatsPageState extends State<TrafficStatsPage> {
  late Map<String, dynamic> stats = TrafficStatsService.instance.snapshot();

  String _fmt(int b) {
    if (b < 1024) return '$b B';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1073741824) return '${(b / 1048576).toStringAsFixed(1)} MB';
    return '${(b / 1073741824).toStringAsFixed(2)} GB';
  }

  Widget _sec(String t) => Padding(padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 4), child: Text(t, style: Theme.of(context).textTheme.titleMedium));
  Widget _item(String t, String v, [String? sub]) => ListTile(title: Text(t), subtitle: sub == null ? null : Text(sub), trailing: Text(v, style: Theme.of(context).textTheme.titleMedium));

  Future<void> _reset() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('清空流量统计？'), content: const Text('无法撤销。'), actions: [TextButton(onPressed: Get.back, child: const Text('取消')), TextButton(onPressed: () => Get.back(result: true), child: const Text('清空'))]));
    if (ok == true) { await TrafficStatsService.instance.reset(); if (mounted) setState(() => stats = TrafficStatsService.instance.snapshot()); }
  }

  @override
  Widget build(BuildContext context) {
    int totalRecv = 0, totalSent = 0;
    final entries = stats.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    for (final e in entries) {
      final d = e.value as Map?;
      if (d == null) continue;
      totalRecv += (d['received'] as num? ?? 0).toInt();
      totalSent += (d['sent'] as num? ?? 0).toInt();
    }
    return SimpleScaffold(
      appBar: AppBar(title: const Text('流量统计'), actions: [TextButton(onPressed: _reset, child: const Text('清空')), const SizedBox(width: 8)]),
      body: ViewSafeArea(child: ListView(padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom + 48), children: [
        _sec('总计'),
        _item('下载流量', _fmt(totalRecv)),
        _item('上传流量', _fmt(totalSent)),
        _item('总流量', _fmt(totalRecv + totalSent)),
        if (entries.isEmpty) const ListTile(title: Text('暂无统计数据'))
        else ...[
          _sec('历史记录（最近10条）'),
          ...entries.reversed.take(10).map((e) {
            final d = e.value as Map? ?? {};
            return _item(e.key, '${_fmt((d['received'] as num? ?? 0).toInt())} / ${_fmt((d['sent'] as num? ?? 0).toInt())}');
          }),
        ],
      ])),
    );
  }
}
