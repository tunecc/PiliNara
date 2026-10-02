import 'package:PiliPlus/models/common/enum_with_label.dart';

/// 界面风格，对标 Kototoro InterfaceStyle
/// 控制全局圆角、动画、视觉效果
enum InterfaceStyle with EnumWithLabel {
  material3Expressive('Material 3 表现'),
  ios('iOS 风格'),
  minimal('简约风格'),
  ;

  @override
  final String label;
  const InterfaceStyle(this.label);

  /// 分组圆角（卡片、对话框等）
  double get groupCornerRadius => switch (this) {
        InterfaceStyle.material3Expressive => 20.0,
        InterfaceStyle.ios => 28.0,
        InterfaceStyle.minimal => 8.0,
      };

  /// 控件圆角（按钮、输入框等）
  double get controlCornerRadius => switch (this) {
        InterfaceStyle.material3Expressive => 14.0,
        InterfaceStyle.ios => 22.0,
        InterfaceStyle.minimal => 6.0,
      };

  /// 是否使用 iOS 风格
  bool get isIosStyle => this == InterfaceStyle.ios;

  /// 是否使用 Material 3 Expressive
  bool get isMaterial3Expressive => this == InterfaceStyle.material3Expressive;

  /// 是否使用简约风格
  bool get isMinimal => this == InterfaceStyle.minimal;

  /// 动画时长系数
  double get animationSpeedFactor => switch (this) {
        InterfaceStyle.material3Expressive => 1.2,
        InterfaceStyle.ios => 1.0,
        InterfaceStyle.minimal => 0.8,
      };

  /// 模糊强度（用于玻璃态效果）
  double get blurSigma => switch (this) {
        InterfaceStyle.material3Expressive => 20.0,
        InterfaceStyle.ios => 30.0,
        InterfaceStyle.minimal => 0.0,
      };
}
