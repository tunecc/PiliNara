import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

class AccountUsageSettingPage extends StatefulWidget {
  const AccountUsageSettingPage({super.key});

  @override
  State<AccountUsageSettingPage> createState() => _AccountUsageSettingPageState();
}

class _AccountUsageSettingPageState extends State<AccountUsageSettingPage> {
  late int _playbackMid;
  late int _commentMid;
  late bool _trial;

  @override
  void initState() {
    super.initState();
    _playbackMid = Pref.playbackAccountMid;
    _commentMid = Pref.commentAccountMid;
    _trial = Pref.enableHighQualityTrial;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('账号使用设置')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('1080P+ 试看'),
            subtitle: const Text('未登录时请求 1080P 高码率试看流'),
            value: _trial,
            onChanged: (v) async {
              setState(() => _trial = v);
              await GStorage.setting.put(
                SettingBoxKey.enableHighQualityTrial,
                v,
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('播放账号'),
            subtitle: Text(_describe(_playbackMid)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final m = await _pick(context, allowGuest: true);
              if (m == null) return;
              setState(() => _playbackMid = m);
              await GStorage.setting.put(
                SettingBoxKey.playbackAccountMid,
                m,
              );
              await Accounts.applyPreferredVideoAccount();
              if (mounted) {
                SmartDialog.showToast('播放账号已切换为 ${_describe(m)}');
              }
            },
          ),
          ListTile(
            title: const Text('评论账号'),
            subtitle: Text(_describe(_commentMid)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final m = await _pick(context, allowGuest: true);
              if (m == null) return;
              setState(() => _commentMid = m);
              await GStorage.setting.put(SettingBoxKey.commentAccountMid, m);
              if (mounted) {
                SmartDialog.showToast('评论账号已切换为 ${_describe(m)}');
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              '播放账号决定视频取流使用哪个登录态：选择「游客」即未登录取流，'
              '配合「1080P+ 试看」可试看高码率；选择「主账号」则使用已登录的账号。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _describe(int mid) {
    if (mid == -1) return '游客（未登录）';
    if (mid == 0) return '主账号';
    return 'UID:$mid';
  }

  Future<int?> _pick(BuildContext context, {bool allowGuest = true}) async {
    final accounts = Accounts.account.values.toList();
    return showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('选择账号'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 0),
            child: const Text('主账号'),
          ),
          if (allowGuest)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, -1),
              child: const Text('游客（未登录）'),
            ),
          for (final a in accounts)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, a.mid),
              child: Text('UID:${a.mid}'),
            ),
        ],
      ),
    );
  }
}
