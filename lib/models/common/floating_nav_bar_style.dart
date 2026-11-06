import 'package:PiliPlus/models/common/enum_with_label.dart';

/// 悬浮底栏（FloatingNavigationBar）的显示样式。
enum FloatingNavBarStyle implements EnumWithLabel {
  iconAndLabel('图标+文字'),
  iconOnly('仅图标'),
  labelOnly('仅文字');

  @override
  final String label;

  const FloatingNavBarStyle(this.label);
}
