import 'package:PiliPlus/http/cdn_manager.dart';
import 'package:flutter/material.dart';
class CdnSettingPage extends StatefulWidget {
  const CdnSettingPage({super.key});
  @override State<CdnSettingPage> createState() => _S();
}
class _S extends State<CdnSettingPage> {
  List<CdnNode> _nodes = []; List<CdnSpeedResult> _results = []; bool _testing = false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { await CdnManager.init(); setState(() => _nodes = CdnManager.getNodes()); }
  Future<void> _test() async { setState(() => _testing = true); final r = await CdnManager.testAllNodes(parallel: true); setState(() { _results = r; _testing = false; }); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('CDN节点管理'), actions: [
    _testing ? const Padding(padding: EdgeInsets.only(right:16), child: SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2))) : IconButton(icon: const Icon(Icons.speed), onPressed: _test)]),
    body: ListView(children: [
      ..._nodes.map((n) => ListTile(leading: CircleAvatar(child: Text(n.region == 'overseas' ? '海' : '国')), title: Text(n.name), subtitle: Text(n.host))),
      if (_results.isNotEmpty) ...[const Divider(), ..._results.map((r) => ListTile(title: Text(r.nodeName), subtitle: Text(r.success ? '${r.throughputMbps.toStringAsFixed(1)} Mbps' : 'Failed')))],
    ]));
}
