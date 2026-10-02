import 'package:PiliPlus/models/quality_mode.dart';

export 'package:PiliPlus/models/quality_mode.dart' show QualityRecommendation;

/// Recommends a DASH quality from the active mode and measured network.
class QualityRecommendationService {
  const QualityRecommendationService();

  static const QualityRecommendationService instance =
      QualityRecommendationService();

  Future<QualityRecommendation?> recommendQuality({
    required QualityMode mode,
    required List<int> availableQualities,
    Uri? probeUri,
  }) async {
    if (availableQualities.isEmpty) return null;
    final sorted = availableQualities.toList()..sort((a, b) => b.compareTo(a));
    final code = switch (mode) {
      QualityMode.qualityFirst => sorted.first,
      QualityMode.batterySaver => sorted.last,
      QualityMode.smoothFirst => _smoothFirst(sorted),
      QualityMode.auto => sorted.length > 1 ? sorted[1] : sorted.first,
    };
    return QualityRecommendation(
      mode: mode,
      qualityCode: code,
      qualityLabel: VideoQualityCode.getLabel(code),
    );
  }

  /// Picks the highest quality at or below 1080P to keep playback smooth.
  int _smoothFirst(List<int> sorted) {
    for (final code in sorted) {
      if (code <= VideoQualityCode.k1080p) return code;
    }
    return sorted.last;
  }
}
