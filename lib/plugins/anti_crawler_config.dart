/// 反反爬虫配置
class AntiCrawlerConfig {
  bool enabled;
  int captchaType;
  String captchaImage;
  String captchaInput;
  String captchaButton;
  int captchaDetectType;
  String captchaDetectValue;
  String captchaScript;

  AntiCrawlerConfig({
    this.enabled = false,
    this.captchaType = 1,
    this.captchaImage = '',
    this.captchaInput = '',
    this.captchaButton = '',
    this.captchaDetectType = 1,
    this.captchaDetectValue = '',
    this.captchaScript = '',
  });

  factory AntiCrawlerConfig.fromJson(Map<String, dynamic> json) {
    return AntiCrawlerConfig(
      enabled: json['enabled'] as bool? ?? false,
      captchaType: json['captchaType'] as int? ?? 1,
      captchaImage: json['captchaImage'] as String? ?? '',
      captchaInput: json['captchaInput'] as String? ?? '',
      captchaButton: json['captchaButton'] as String? ?? '',
      captchaDetectType: json['captchaDetectType'] as int? ?? 1,
      captchaDetectValue: json['captchaDetectValue'] as String? ?? '',
      captchaScript: json['captchaScript'] as String? ?? '',
    );
  }

  factory AntiCrawlerConfig.empty() => AntiCrawlerConfig();

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'captchaType': captchaType,
        'captchaImage': captchaImage,
        'captchaInput': captchaInput,
        'captchaButton': captchaButton,
        'captchaDetectType': captchaDetectType,
        'captchaDetectValue': captchaDetectValue,
        'captchaScript': captchaScript,
      };
}
