abstract final class CommentHelperService {
  static String preprocess(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');
  static List<String> extractMentions(String text) => RegExp(r'@(\S+)').allMatches(text).map((m) => m.group(1)!).toList();
  static bool validate(String text) => text.trim().isNotEmpty && text.length <= 2000;
}
