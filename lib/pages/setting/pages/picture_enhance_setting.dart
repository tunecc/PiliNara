import 'package:PiliPlus/models/common/super_resolution_type.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
class PictureEnhanceSettingPage extends StatefulWidget {
  const PictureEnhanceSettingPage({super.key});
  @override State<PictureEnhanceSettingPage> createState() => _S();
}
class _S extends State<PictureEnhanceSettingPage> {
  late SuperResolutionType _sr;
  @override void initState() { super.initState(); _sr = Pref.superResolutionType; }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('画质增强')), body: ListView(children: [
    ListTile(title: const Text('增强模式'), subtitle: Text(_sr.name), trailing: const Icon(Icons.chevron_right), onTap: () async {
      final s = await showDialog<SuperResolutionType>(context: context, builder: (c) => SimpleDialog(title: const Text('选择'),
        children: SuperResolutionType.values.map((t) => SimpleDialogOption(onPressed: () => Navigator.pop(c, t), child: Text(t.name))).toList()));
      if (s != null) { await GStorage.setting.put(SettingBoxKey.superResolutionType, s.index); setState(() => _sr = s); }
    }),
  ]));
}
