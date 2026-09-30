import 'dart:async';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/services/media_source/media_source.dart';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart' as xml;
class RssMediaSource extends MediaSource {
  @override final String id; @override final MediaSourceMetadata metadata; @override final int tier; @override bool enabled;
  final String feedUrlTemplate; final RegExp? episodePattern;
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15), headers: {'User-Agent': 'Mozilla/5.0 PiliNara/2.1.5'}));
  RssMediaSource({required this.id, required String name, required this.feedUrlTemplate, this.tier = 1, this.enabled = true, this.episodePattern, String? iconUrl}) : metadata = MediaSourceMetadata(name: name, iconUrl: iconUrl);
  @override Stream<List<MediaMatch>> fetch(MediaFetchRequest query) async* {
    final kw = query.subjectNames.join(' '); final url = feedUrlTemplate.replaceAll('{query}', Uri.encodeComponent(kw));
    try { final r = await _dio.get<String>(url); if (r.data == null) { yield []; return; }
      final doc = xml.XmlDocument.parse(r.data!); final matches = <MediaMatch>[];
      for (final item in doc.findAllElements('item')) { try {
        final t = item.findElements('title').firstOrNull?.innerText ?? ''; final l = item.findElements('link').firstOrNull?.innerText ?? '';
        final enc = item.findElements('enclosure').firstOrNull; final du = enc?.getAttribute('url') ?? l; final g = item.findElements('guid').firstOrNull?.innerText ?? l;
        if (du.isEmpty) continue; final en = _ep(t); final er = en != null ? EpisodeRange.single(en) : EpisodeRange.unknown();
        final k = _mk(t, query); final sz = enc?.getAttribute('length'); final fs = sz != null ? int.tryParse(sz) : null;
        matches.add(MediaMatch(media: Media(mediaId: g.isNotEmpty ? g : du, originalUrl: l, downloadUrl: du, properties: MediaProperties(subtitleGroup: _sg(t), resolution: _res(t), fileSizeBytes: fs), locationType: du.startsWith('magnet:') || du.endsWith('.torrent') ? MediaLocationType.torrent : MediaLocationType.web), kind: k, episodeRange: er));
      } catch (e) { logger.w('RSS[$id]: $e'); } } yield matches;
    } catch (e) { logger.e('RSS[$id]: $e'); yield []; } }
  int? _ep(String t) { if (episodePattern != null) { final m = episodePattern!.firstMatch(t); if (m != null && m.groupCount >= 1) return int.tryParse(m.group(1) ?? ''); } for (final p in [RegExp(r'\b(\d{1,4})\b(?=\s*[\[\(（]|$)'), RegExp(r'[Ee](\d{1,4})'), RegExp(r'第(\d{1,4})[话集話]')]) { final m = p.firstMatch(t); if (m != null && m.groupCount >= 1) { final n = int.tryParse(m.group(1) ?? ''); if (n != null && n > 0 && n < 9999) return n; } } return null; }
  MatchKind _mk(String t, MediaFetchRequest q) { for (final n in q.subjectNames) { if (n.isNotEmpty && t.toLowerCase().contains(n.toLowerCase())) { if (q.currentEpisode?.number != null && _ep(t) == q.currentEpisode!.number) return MatchKind.exact; return MatchKind.fuzzy; } } return MatchKind.fuzzy; }
  String? _res(String t) { for (final p in [RegExp(r'(\d{3,4}[pP])'), RegExp(r'(4[Kk]|UHD|2160)')]) { final m = p.firstMatch(t); if (m != null) return m.group(0); } return null; }
  String? _sg(String t) { final m = RegExp(r'^\[([^\]]+)\]').firstMatch(t.trim()); return m?.group(1); }
  void dispose() { _dio.close(); }
}
class BuiltInSources { static List<RssMediaSource> defaults() => [ RssMediaSource(id: 'dmhy', name: '动漫花园', feedUrlTemplate: 'https://share.dmhy.org/topics/rss/rss.xml?keyword={query}', tier: 1), RssMediaSource(id: 'mikan', name: '蜜柑计划', feedUrlTemplate: 'https://mikanani.me/RSS/Search?searchstr={query}', tier: 1), RssMediaSource(id: 'nyaa', name: 'Nyaa', feedUrlTemplate: 'https://nyaa.si/?page=rss&q={query}&c=1_2&f=0', tier: 2), ]; }
