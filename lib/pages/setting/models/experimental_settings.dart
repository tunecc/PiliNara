import 'package:PiliPlus/http/doh.dart';
import 'package:PiliPlus/http/network_security_policy.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// Experimental features: UI effects (Kototoro/bilipai/PiliMax) + Network (DoH)
List<SettingsModel> get experimentalSettings => [
  // === Visual Effects ===
  const _SectionHeader('视觉效果'),

  const SwitchModel(
    title: '液态玻璃效果',
    subtitle: '参考 Kototoro AndroidLiquidGlass，为卡片和导航栏添加毛玻璃背景模糊（重启应用后生效）',
    leading: Icon(Icons.blur_on_outlined),
    setKey: SettingBoxKey.experimentalLiquidGlass,
    defaultVal: false,
  ),

  const SwitchModel(
    title: '背景模糊蒙层',
    subtitle: '参考 bilipai 磨砂玻璃风格，弹窗/底栏/Tab栏启用高斯模糊背景（重启应用后生效）',
    leading: Icon(Icons.layers_outlined),
    setKey: SettingBoxKey.experimentalBlurBackdrop,
    defaultVal: false,
  ),

  const SwitchModel(
    title: 'AMOLED 纯黑主题',
    subtitle: '暗色主题下使用纯黑 (#000000) 背景，节省 OLED 屏幕功耗（重启应用后生效）',
    leading: Icon(Icons.dark_mode_outlined),
    setKey: SettingBoxKey.experimentalAmoledBlack,
    defaultVal: false,
  ),

  // === Animation ===
  const _SectionHeader('交互动画'),

  const SwitchModel(
    title: '卡片展开动画',
    subtitle: '参考 PiliMax，统一卡片展开与骨架入场过渡效果',
    leading: Icon(Icons.animation_outlined),
    setKey: SettingBoxKey.experimentalCardAnimation,
    defaultVal: false,
  ),

  const SwitchModel(
    title: 'Material You 动态取色',
    subtitle: '从壁纸或系统主题自动提取主色调应用到整个应用',
    leading: Icon(Icons.palette_outlined),
    setKey: SettingBoxKey.experimentalDynamicColor,
    defaultVal: false,
  ),

  // === Layout ===
  const _SectionHeader('布局'),

  const SwitchModel(
    title: '紧凑模式',
    subtitle: '减小卡片间距、字体和内边距，单屏展示更多内容',
    leading: Icon(Icons.view_compact_outlined),
    setKey: SettingBoxKey.experimentalCompactMode,
    defaultVal: false,
  ),

  // === Network ===
  const _SectionHeader('网络'),

  const SwitchModel(
    title: 'DNS over HTTPS (DoH)',
    subtitle: '通过加密 HTTPS 解析 DNS，防止劫持和污染',
    leading: Icon(Icons.dns_outlined),
    setKey: SettingBoxKey.enableDoh,
    defaultVal: false,
  ),

  NormalModel(
    onTap: _showDohProviderDialog,
    leading: const Icon(Icons.cloud_outlined),
    title: 'DoH 服务商',
    getSubtitle: () {
      final names = {
        'cloudflare': 'Cloudflare',
        'google': 'Google',
        'quad9': 'Quad9',
        'alidns': '阿里 DNS',
        'tencent': '腾讯 DNSPod',
        'dnspod': '腾讯 DNSPod',
      };
      final label = names[Pref.dohProvider] ?? '自定义';
      final endpoint = DoHResolver.endpoint;
      return endpoint.isEmpty ? '$label（未启用）' : '$label · $endpoint';
    },
  ),

  // === Info ===
  const _SectionHeader('说明'),

  const _InfoText(
    '以上功能均为实验性质，可能存在性能开销或视觉异常。\n'
    '来源：Kototoro (液态玻璃/AMOLED)、bilipai (模糊/紧凑/动态取色)、PiliMax (卡片动画)。\n'
    '重启应用后生效。',
  ),
];

// --- DoH Provider Dialog ---
Future<void> _showDohProviderDialog(BuildContext context, VoidCallback setState) async {
  const providers = [
    ('cloudflare', 'Cloudflare (推荐)'),
    ('google', 'Google'),
    ('quad9', 'Quad9'),
    ('alidns', '阿里 DNS'),
    ('tencent', '腾讯 DNSPod'),
    ('custom', '自定义 URL'),
  ];

  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('选择 DoH 服务商'),
      children: providers.map((e) => SimpleDialogOption(
        onPressed: () => Navigator.pop(ctx, e.$1),
        child: Text(e.$2, style: TextStyle(
          fontWeight: Pref.dohProvider == e.$1 ? FontWeight.bold : FontWeight.normal,
        )),
      )).toList(),
    ),
  );

  if (selected != null) {
    if (selected == 'custom') {
      final controller = TextEditingController(text: Pref.customDohUrl);
      final url = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('自定义 DoH URL'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'https://your-doh-server.com/dns-query',
              helperText: '需返回 application/dns-json',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (url == null) return;
      if (url.isEmpty || !NetworkSecurityPolicy.validateUrl(url)) {
        SmartDialog.showToast('请输入以 https:// 开头的有效地址');
        return;
      }
      await GStorage.setting.put(SettingBoxKey.customDohUrl, url);
    }
    await GStorage.setting.put(SettingBoxKey.dohProvider, selected);
    DoHResolver.clearCache();
    setState();
  }
}

// --- Helper Widgets ---
class _SectionHeader extends WidgetModel {
  final String title;
  const _SectionHeader(this.title) : super(child: const SizedBox.shrink(), searchTitle: '');
}

class _InfoText extends WidgetModel {
  final String text;
  const _InfoText(this.text) : super(child: const SizedBox.shrink(), searchTitle: '');
}
