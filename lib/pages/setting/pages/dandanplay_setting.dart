import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

class DandanplaySettingPage extends StatefulWidget {
  const DandanplaySettingPage({super.key});

  @override
  State<DandanplaySettingPage> createState() => _DandanplaySettingPageState();
}

class _DandanplaySettingPageState extends State<DandanplaySettingPage> {
  late TextEditingController _appIdController;
  late TextEditingController _appSecretController;

  @override
  void initState() {
    super.initState();
    _appIdController = TextEditingController(text: Pref.dandanplayAppId);
    _appSecretController = TextEditingController(text: Pref.dandanplayAppSecret);
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _appSecretController.dispose();
    super.dispose();
  }

  void _save() {
    // 注意：这些key目前只是为了兼容，实际使用公共API不需要
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('弹弹play 设置')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '说明',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '弹弹play 已切换为公共API，无需配置凭据。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              '如需使用私有API，可在此配置：',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _appIdController,
              decoration: const InputDecoration(
                labelText: 'App ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _appSecretController,
              decoration: const InputDecoration(
                labelText: 'App Secret',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
