import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';
class AccountUsageSettingPage extends StatefulWidget {
  const AccountUsageSettingPage({super.key});
  @override State<AccountUsageSettingPage> createState() => _S();
}
class _S extends State<AccountUsageSettingPage> {
  late int _pb, _cm; late bool _trial;
  @override void initState() { super.initState(); _pb = Pref.playbackAccountMid; _cm = Pref.commentAccountMid; _trial = Pref.enableHighQualityTrial; }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('账号使用设置')), body: ListView(children: [
    SwitchListTile(title: const Text('1080P+试看'), value: _trial, onChanged: (v) async { setState(() => _trial = v); await GStorage.setting.put(SettingBoxKey.enableHighQualityTrial, v); }),
    ListTile(title: const Text('播放账号'), subtitle: Text(_pb == -1 ? '游客' : _pb == 0 ? '主账号' : 'UID:$_pb'), trailing: const Icon(Icons.chevron_right),
      onTap: () async { final m = await _pick(context); if (m != null) { setState(() => _pb = m); await GStorage.setting.put(SettingBoxKey.playbackAccountMid, m); } }),
    ListTile(title: const Text('评论账号'), subtitle: Text(_cm == 0 ? '主账号' : 'UID:$_cm'), trailing: const Icon(Icons.chevron_right),
      onTap: () async { final m = await _pick(context, guest: false); if (m != null) { setState(() => _cm = m); await GStorage.setting.put(SettingBoxKey.commentAccountMid, m); } }),
  ]));
  Future<int?> _pick(BuildContext context, {bool guest = true}) async {
    final accs = Accounts.account;
    return showDialog<int>(context: context, builder: (c) => SimpleDialog(title: const Text('选择账号'), children: [
      SimpleDialogOption(onPressed: () => Navigator.pop(c, 0), child: const Text('主账号')),
      if (guest) SimpleDialogOption(onPressed: () => Navigator.pop(c, -1), child: const Text('游客')),
      ...accs.values.toList().map((a) => SimpleDialogOption(onPressed: () => Navigator.pop(c, a.mid), child: Text('UID:${a.mid}'))),
    ]));
  }
}
