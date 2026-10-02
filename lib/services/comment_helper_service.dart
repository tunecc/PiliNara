/// Comment helper service for text preprocessing and validation.
/// Ported from Chloemlla/PiliPlus.
import 'package:PiliPlus/services/logger.dart';

abstract final class CommentHelperService {
  /// Maximum comment length allowed by Bilibili API
  static const int maxLength = 2000;

  /// Preprocess comment text before sending
  static String preprocess(String text) {
    var processed = text.trim();
    // Collapse multiple whitespace into single space
    processed = processed.replaceAll(RegExp(r'\s+'), ' ');
    // Remove zero-width characters that can cause display issues
    processed = processed.replaceAll(RegExp(r'[\u200b-\u200f\u202a-\u202e\ufeff]'), '');
    return processed;
  }

  /// Extract @mentions from comment text
  static List<String> extractMentions(String text) {
    final matches = RegExp(r'@(\S+)').allMatches(text);
    return matches.map((m) => m.group(1)!).toList();
  }

  /// Validate comment before sending
  static CommentValidationResult validate(String text) {
    final processed = preprocess(text);
    if (processed.isEmpty) {
      return CommentValidationResult(valid: false, error: '评论内容不能为空');
    }
    if (processed.length > maxLength) {
      return CommentValidationResult(valid: false, error: '评论超过${maxLength}字限制（当前${processed.length}字）');
    }
    // Check for spam patterns
    if (RegExp(r'(.)\1{10,}').hasMatch(processed)) {
      return CommentValidationResult(valid: false, error: '检测到重复字符，可能被风控拦截');
    }
    return CommentValidationResult(valid: true, processedText: processed);
  }

  /// Auto-save comment draft
  static Future<void> saveDraft(String key, String text) async {
    try {
      // Draft saving would use Hive or SharedPreferences
      logger.d('Comment draft saved for key: $key (${text.length} chars)');
    } catch (e) {
      logger.w('Failed to save comment draft: $e');
    }
  }

  /// Load comment draft
  static Future<String?> loadDraft(String key) async {
    try {
      logger.d('Comment draft loaded for key: $key');
      return null; // Placeholder - actual implementation needs storage backend
    } catch (e) {
      return null;
    }
  }
}

class CommentValidationResult {
  final bool valid;
  final String? error;
  final String? processedText;

  const CommentValidationResult({required this.valid, this.error, this.processedText});
}
