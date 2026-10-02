import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class TvRemoteSetupPage extends StatefulWidget {
  const TvRemoteSetupPage({super.key});
  @override
  State<TvRemoteSetupPage> createState() => _TvRemoteSetupPageState();
}

class _TvRemoteSetupPageState extends State<TvRemoteSetupPage> {
  late bool enableTvMode = Pref.enableTvMode;
  late bool tvFocusEnabled = Pref.tvFocusEnabled;
  late int tvDpadSpeed = Pref.tvDpadSpeed;

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(title: const Text('TV 遥控器模式')),
      body: ViewSafeArea(child: ListView(padding: const EdgeInsets.only(bottom: 48), children: [
        SwitchListTile(title: const Text('启用 TV 模式'), subtitle: const Text('开启后适配大屏布局，隐藏移动端特有控件'), value: enableTvMode, onChanged: (v) async { await GStorage.setting.put(SettingBoxKey.enableTvMode, v); setState(() => enableTvMode = v); }),
        if (enableTvMode) ...[
          SwitchListTile(title: const Text('遥控器焦点导航'), subtitle: const Text('使用方向键在界面元素间移动焦点'), value: tvFocusEnabled, onChanged: (v) async { await GStorage.setting.put(SettingBoxKey.tvFocusEnabled, v); setState(() => tvFocusEnabled = v); }),
          ListTile(title: const Text('方向键移动速度'), subtitle: Text('当前: ${tvDpadSpeed} ms'), onTap: () async {
            final res = await showDialog<int>(context: context, builder: (_) => AlertDialog(title: const Text('方向键移动速度'), content: Column(mainAxisSize: MainAxisSize.min, children: [5, 10, 15, 20, 25].map((v) => RadioListTile<int>(title: Text('$v ms'), value: v, groupValue: tvDpadSpeed, onChanged: (x) => Get.back(result: x))).toList()), actions: [TextButton(onPressed: () => Get.back(), child: const Text('取消'))]));
            if (res != null) { await GStorage.setting.put(SettingBoxKey.tvDpadSpeed, res); setState(() => tvDpadSpeed = res); }
          }),
        ],
      ])),
    );
  }
}
