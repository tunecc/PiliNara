import 'package:PiliPlus/models/common/enum_with_label.dart';

enum VideoEnhancementAlgorithm with EnumWithLabel {
  anime4k('Anime4K'),
  fsr10('FSR 1.0'),
  ;

  @override
  final String label;
  const VideoEnhancementAlgorithm(this.label);
}

enum Anime4KPreset with EnumWithLabel {
  fast('快速'),
  quality('高质量'),
  ;

  @override
  final String label;
  const Anime4KPreset(this.label);
}
