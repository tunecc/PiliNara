import 'dart:math';

import 'package:PiliPlus/pages/member_video/video_filter.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/utils/extension/context_ext.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:flutter/material.dart';

// 用户空间视频列表过滤设置弹窗，风格对齐搜索页筛选弹窗
abstract final class MemberVideoFilterDialog {
  static Future<void> show(BuildContext context, MemberVideoFilter filter) {
    return showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: min(640, context.mediaQueryShortestSide),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          Widget playFilterSection({
            required bool enable,
            required ValueChanged<bool> onEnableChanged,
            required int value,
            required ValueChanged<int> onValueChanged,
            required bool isMin,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '当前阈值：${NumUtils.numFormat(value)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: enable,
                  onChanged: onEnableChanged,
                ),
                if (enable)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in MemberVideoFilter.playPresets)
                        SearchText(
                          text: NumUtils.numFormat(e),
                          onTap: (_) => onValueChanged(e),
                          bgColor: value == e
                              ? theme.colorScheme.secondaryContainer
                              : null,
                          textColor: value == e
                              ? theme.colorScheme.onSecondaryContainer
                              : null,
                        ),
                      SearchText(
                        text: '自定义',
                        onTap: (_) => _showCustomPlayInput(
                          context,
                          value,
                          onValueChanged,
                        ),
                        bgColor: !MemberVideoFilter.playPresets.contains(value)
                            ? theme.colorScheme.secondaryContainer
                            : null,
                        textColor: !MemberVideoFilter.playPresets.contains(
                              value,
                            )
                            ? theme.colorScheme.onSecondaryContainer
                            : null,
                      ),
                    ],
                  ),
                if (isMin) ...[
                  const SizedBox(height: 20),
                  const Text('最大播放量（高于此值隐藏）', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 6),
                ],
              ],
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const .fromLTRB(16, 20, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('最小播放量（低于此值隐藏）', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 6),
                  playFilterSection(
                    enable: filter.enableMinPlay,
                    onEnableChanged: (v) => setState(() {
                      filter.enableMinPlay = v;
                    }),
                    value: filter.minPlay,
                    onValueChanged: (v) => setState(() {
                      filter.minPlay = v;
                    }),
                    isMin: true,
                  ),
                  playFilterSection(
                    enable: filter.enableMaxPlay,
                    onEnableChanged: (v) => setState(() {
                      filter.enableMaxPlay = v;
                    }),
                    value: filter.maxPlay,
                    onValueChanged: (v) => setState(() {
                      filter.maxPlay = v;
                    }),
                    isMin: false,
                  ),
                  const SizedBox(height: 20),
                  const Text('已观看', style: TextStyle(fontSize: 16)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('隐藏已看完', style: TextStyle(fontSize: 14)),
                    value: filter.hideCompleted,
                    onChanged: (v) => setState(() {
                      filter.hideCompleted = v;
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '隐藏看过未看完',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: filter.hideInProgress,
                    onChanged: (v) => setState(() {
                      filter.hideInProgress = v;
                    }),
                  ),
                  if (filter.hasActiveFilter)
                    TextButton(
                      onPressed: () => setState(() => filter.reset()),
                      child: const Text('清除所有过滤条件'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<void> _showCustomPlayInput(
    BuildContext context,
    int current,
    ValueChanged<int> onChanged,
  ) async {
    final controller = TextEditingController(text: current.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义播放量'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '输入数字，支持 10.5万 / 2亿 格式',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final value = NumUtils.parseNum(controller.text.trim());
              if (value > 0) {
                Navigator.of(context).pop(value);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result > 0) {
      onChanged(result);
    }
  }
}
