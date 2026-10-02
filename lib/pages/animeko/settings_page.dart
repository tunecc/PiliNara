/// Settings page for Animeko integration.
/// Allows users to configure Bangumi and Dandanplay credentials.

import 'package:PiliNara/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AnimekoSettingsPage extends StatefulWidget {
  const AnimekoSettingsPage({super.key});

  @override
  State<AnimekoSettingsPage> createState() => _AnimekoSettingsPageState();
}

class _AnimekoSettingsPageState extends State<AnimekoSettingsPage> {
  late TextEditingController _bangumiController;
  late TextEditingController _dandanplayAppIdController;
  late TextEditingController _dandanplayAppSecretController;

  @override
  void initState() {
    super.initState();
    _bangumiController = TextEditingController(text: Pref.bangumiUsername ?? '');
    _dandanplayAppIdController = TextEditingController(text: Pref.dandanplayAppId ?? '');
    _dandanplayAppSecretController = TextEditingController(text: Pref.dandanplayAppSecret ?? '');
  }

  @override
  void dispose() {
    _bangumiController.dispose();
    _dandanplayAppIdController.dispose();
    _dandanplayAppSecretController.dispose();
    super.dispose();
  }

  void _saveBangumi() {
    Pref.bangumiUsername = _bangumiController.text.trim().isEmpty
        ? null
        : _bangumiController.text.trim();
    Get.snackbar('保存成功', 'Bangumi 用户名已更新');
  }

  void _saveDandanplay() {
    final appId = _dandanplayAppIdController.text.trim();
    final appSecret = _dandanplayAppSecretController.text.trim();
    
    if (appId.isNotEmpty) Pref.dandanplayAppId = appId;
    if (appSecret.isNotEmpty) Pref.dandanplayAppSecret = appSecret;
    
    Get.snackbar('保存成功', '弹弹 play 配置已更新');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('番剧聚合设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bangumi section
          const SectionTitle('Bangumi 云同步'),
          const DescriptionText(
            '登录 Bangumi 后可同步追番进度，实现多设备同步。',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bangumiController,
            decoration: const InputDecoration(
              labelText: 'Bangumi 用户名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _saveBangumi,
              child: const Text('保存'),
            ),
          ),
          const SizedBox(height: 24),

          // Dandanplay section
          const SectionTitle('弹弹 play 弹幕'),
          const DescriptionText(
            '配置弹弹 play API 密钥以获取多源弹幕。',
            '申请地址: https://www.dandanplay.com/api-doc/',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dandanplayAppIdController,
            decoration: const InputDecoration(
              labelText: 'AppID',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dandanplayAppSecretController,
            decoration: const InputDecoration(
              labelText: 'AppSecret',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.security),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _saveDandanplay,
              child: const Text('保存'),
            ),
          ),
          const SizedBox(height: 24),

          // Info
          const InfoCard(
            title: '说明',
            content: '''
番剧聚合功能会从以下源搜索资源：
• 蜜柑计划 (mikanani.me) - 国产字幕组 BT 索引
• 动漫花园 (dmhy.org) - 综合 BT 索引

磁力链接点击后跳转到浏览器，可使用系统下载器或 BT 客户端打开。
''',
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class DescriptionText extends StatelessWidget {
  final String text;
  final String? secondary;
  const DescriptionText(this.text, [this.secondary, {super.key}]);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(color: Colors.grey)),
        if (secondary != null)
          Text(secondary!, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String content;
  const InfoCard({required this.title, required this.content, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
