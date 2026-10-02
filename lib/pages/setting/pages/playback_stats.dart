import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:PiliPlus/services/playback_stats_service.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class PlaybackStatsPage extends StatefulWidget {
  const PlaybackStatsPage({super.key});
  @override
  State<PlaybackStatsPage> createState() => _PlaybackStatsPageState();
}

class _PlaybackStatsPageState extends State<PlaybackStatsPage> {
  static final _tz = RegExp(r'0+$');
  static final _td = RegExp(r'\.$');
  late Map<String, dynamic> stats = PlaybackStatsService.snapshot();

  num _v(String k) => stats[k] as num? ?? 0;
  Map<String, dynamic> get _d => stats['derived'] as Map<String, dynamic>? ?? {};

  String _dur(num us) {
    final neg = us < 0;
    var s = (us.abs() * 0.000001).round();
    final days = s ~/ 86400; s -= days * 86400;
    final hours = s ~/ 3600; s -= hours * 3600;
    final mins = s ~/ 60; s -= mins * 60;
    final p = <String>[];
    if (days > 0) p.add('$days天');
    if (hours > 0) p.add('$hours小时');
    if (mins > 0) p.add('$mins分钟');
    if (s > 0 || p.isEmpty) p.add('$s秒');
    return '${neg ? '-' : ''}${p.join()}';
  }

  String _spd(num? v) {
    if (v == null || !v.isFinite || v == 0) return '暂无数据';
    final t = v.toStringAsFixed(2).replaceFirst(_tz, '').replaceFirst(_td, '');
    return '$t 倍';
  }

  Widget _sec(String t) => Padding(padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 4), child: Text(t, style: Theme.of(context).textTheme.titleMedium));
  Widget _item(String t, String v, [String? sub]) => ListTile(title: Text(t), subtitle: sub == null ? null : Text(sub), trailing: Text(v, style: Theme.of(context).textTheme.titleMedium));

  Future<void> _reset() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('清空播放统计？'), content: const Text('无法撤销。'), actions: [TextButton(onPressed: Get.back, child: const Text('取消')), TextButton(onPressed: () => Get.back(result: true), child: const Text('清空'))]));
    if (ok == true) { await PlaybackStatsService.reset(); if (mounted) setState(() => stats = PlaybackStatsService.snapshot()); }
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(title: const Text('播放统计'), actions: [TextButton(onPressed: _reset, child: const Text('清空')), const SizedBox(width: 8)]),
      body: ViewSafeArea(child: ListView(padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom + 48), children: [
        _sec('倍速与时间'),
        _item('实际平均倍速', _spd(_d['actualAverageSpeed'] as num?)),
        _item('名义平均倍速', _spd(_d['nominalAverageSpeed'] as num?)),
        _item('实际播放视频时长', _dur(_v('activePlaybackUs').toInt())),
        _item('倍速为您节约', _dur((_d['savedTimeUs'] as num? ?? 0).toInt())),
        _item('暂停累计时间', _dur(_v('pausedUs').toInt())),
        _item('缓冲等待时间', _dur(_v('bufferingUs').toInt())),
        _sec('观看概况'),
        _item('累计播放视频次数', '${_v('videoStarts').toInt()} 次'),
        _item('已完成视频', '${_v('sessionCompletedCount').toInt()} 次'),
        _item('累计倒带时长', _dur(_v('rewindUs').toInt())),
      ])),
    );
  }
}
