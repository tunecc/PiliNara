import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:PiliPlus/utils/platform_utils.dart';

/// Video output driver handed to media_kit (`--vo`).
///
/// Mirrors the renderer choices offered by Kazumi.
enum VideoOutputType implements EnumWithLabel {
  auto('auto', '自动', '由播放器按平台选择'),
  gpu('gpu', 'GPU', '默认 OpenGL 渲染，兼容性最好'),
  gpuNext('gpu-next', 'GPU-next', 'Vulkan 渲染，新设备上画质与性能更佳'),
  mediacodecEmbed(
    'mediacodec-embed',
    'mediacodec-embed',
    'Android 硬解内嵌渲染，最省电；开启后超分辨率不生效',
  ),
  libmpv('libmpv', 'libmpv', '软件渲染，作为兜底'),
  ;

  const VideoOutputType(this.value, this.label, this.description);

  final String value;
  final String description;

  @override
  final String label;

  static VideoOutputType fromValue(String? value) {
    if (value != null) {
      for (final type in values) {
        if (type.value == value) return type;
      }
    }
    return defaultValue;
  }

  static VideoOutputType get defaultValue =>
      PlatformUtils.isMobile ? gpu : libmpv;
}
