/// Video source result model ported from Kazumi.
class KazumiVideoSourceResult {
  final String sourceId;
  final String sourceName;
  final String title;
  final String url;
  final int episode;
  final String? subtitleUrl;
  final String? quality;

  const KazumiVideoSourceResult({
    required this.sourceId, required this.sourceName, required this.title,
    required this.url, required this.episode, this.subtitleUrl, this.quality,
  });

  @override
  String toString() => '[$sourceName] $title EP$episode ($quality)';
}
