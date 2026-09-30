import 'package:PiliPlus/models/quality_mode.dart';

class QualityRecommendation {
  final QualityMode mode;
  final int qualityCode;
  final bool isAuto;
  final String qualityLabel;
  final String? reason;
  const QualityRecommendation({
    required this.mode,
    required this.qualityCode,
    this.isAuto = false,
    this.qualityLabel = '',
    this.reason,
  });
}

abstract final class QualityRecommendationService {
  static final QualityRecommendationService instance = QualityRecommendationService._();
  QualityRecommendationService._();
  static QualityRecommendationService getInstance() => instance;

  Future<QualityRecommendation?> recommendQuality({
    required QualityMode mode,
    required List<int> availableQualities,
    Uri? probeUri,
  }) async => null;
}
