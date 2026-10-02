import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 全景背景设置页面 - 对标 Kototoro PanoramaSettingsRoute
class PanoramaSettingsPage extends StatefulWidget {
  const PanoramaSettingsPage({super.key});

  @override
  State<PanoramaSettingsPage> createState() => _PanoramaSettingsPageState();
}

class _PanoramaSettingsPageState extends State<PanoramaSettingsPage> {
  late bool _enabled;
  late int _blurAmount;
  late int _topOpacity;
  late int _transitionRange;
  late bool _enableAnimation;
  late bool _enableParallax;

  @override
  void initState() {
    super.initState();
    _enabled = true; // TODO: 从 Pref 读取
    _blurAmount = 35;
    _topOpacity = 90;
    _transitionRange = 100;
    _enableAnimation = true;
    _enableParallax = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('全景背景设置'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 启用开关
          SwitchListTile(
            title: const Text('启用全景背景'),
            subtitle: const Text('详情页背景随滚动视差模糊，提升视觉体验'),
            value: _enabled,
            onChanged: (v) {
              setState(() => _enabled = v);
              // TODO: 保存到 Pref
            },
          ),
          const Divider(height: 1),
          
          if (_enabled) ...[
            // 模糊强度
            _SliderSetting(
              icon: Icons.blur_on,
              title: '模糊强度',
              subtitle: '当前：$_blurAmount%',
              value: _blurAmount.toDouble(),
              max: 100.0,
              onChanged: (v) {
                setState(() => _blurAmount = v.toInt());
                // TODO: 保存到 Pref
              },
            ),
            const Divider(height: 1),
            
            // 顶部不透明度
            _SliderSetting(
              icon: Icons.opacity,
              title: '顶部不透明度',
              subtitle: '当前：$_topOpacity%',
              value: _topOpacity.toDouble(),
              max: 100.0,
              onChanged: (v) {
                setState(() => _topOpacity = v.toInt());
                // TODO: 保存到 Pref
              },
            ),
            const Divider(height: 1),
            
            // 过渡范围
            _SliderSetting(
              icon: Icons.expand,
              title: '过渡范围',
              subtitle: '当前：$_transitionRange%',
              value: _transitionRange.toDouble(),
              max: 100.0,
              onChanged: (v) {
                setState(() => _transitionRange = v.toInt());
                // TODO: 保存到 Pref
              },
            ),
            const Divider(height: 32),
            
            // 动画选项
            SwitchListTile(
              title: const Text('启用视差动画'),
              subtitle: const Text('背景随滚动产生平滑过渡效果'),
              value: _enableAnimation,
              onChanged: (v) {
                setState(() => _enableAnimation = v);
                // TODO: 保存到 Pref
              },
            ),
            const Divider(height: 1),
            
            SwitchListTile(
              title: const Text('滚动联动'),
              subtitle: const Text('背景与内容滚动同步，增强沉浸感'),
              value: _enableParallax,
              onChanged: (v) {
                setState(() => _enableParallax = v);
                // TODO: 保存到 Pref
              },
            ),
          ],
          
          const SizedBox(height: 16),
          
          // 预览区域
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '预览效果',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '模糊：$_blurAmount | 透明度：$_topOpacity%\n视差：${_enableParallax ? "开启" : "关闭"}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double max;
  final Function(double) onChanged;

  const _SliderSetting({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: Slider(
              value: value,
              max: max,
              divisions: 100,
              label: '${value.round()}%',
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
