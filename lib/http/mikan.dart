/// Mikan (蜜柑计划) HTTP 客户端
import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;

class MikanHttp {
  static const baseUrl = 'https://mikanani.me';
  final Dio dio;
  MikanHttp({Dio? dio}) : dio = dio ?? Dio();

  /// 搜索番剧
  Future<List<MikanSubject>> search(String keyword) async {
    final resp = await dio.get('$baseUrl/Home/BangumiSearch', queryParameters: {'searchstr': keyword});
    if (resp.data == null) return [];
    final doc = parse(resp.data.toString());
    final results = <MikanSubject>[];
    for (final item in doc.querySelectorAll('li.light')) {
      final linkEl = item.querySelector('a[href*="/Home/Bangumi/"]');
      if (linkEl == null) continue;
      final href = linkEl.attributes['href'] ?? '';
      final name = linkEl.text.trim();
      final idMatch = RegExp(r'/Bangumi/(\d+)').firstMatch(href);
      final id = idMatch?.group(1);
      if (name.isNotEmpty && id != null) results.add(MikanSubject(name: name, id: id));
    }
    return results;
  }

  /// 获取剧集列表
  Future<List<MikanEpisode>> getEpisodes(String subjectId) async {
    final resp = await dio.get('$baseUrl/Home/Bangumi/$subjectId');
    if (resp.data == null) return [];
    final doc = parse(resp.data.toString());
    final episodes = <MikanEpisode>[];
    for (final column in doc.querySelectorAll('.bf-green')) {
      for (final row in column.querySelectorAll('tr')) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 3) continue;
        final epMatch = RegExp(r'第?(\d+)集|EP(\d+)').firstMatch(cells[1].text.trim());
        final epNum = epMatch != null ? (int.tryParse(epMatch.group(1) ?? epMatch.group(2) ?? '0') ?? 0) : 0;
        final links = <MikanDownloadLink>[];
        for (final a in cells[2].querySelectorAll('a')) {
          final href = a.attributes['href'] ?? '';
          if (href.isNotEmpty) links.add(MikanDownloadLink(url: href.startsWith('http') ? href : '$baseUrl$href', type: a.text.trim()));
        }
        if (epNum > 0) episodes.add(MikanEpisode(episode: epNum, name: cells[1].text.trim(), time: cells[0].text.trim(), links: links));
      }
    }
    episodes.sort((a, b) => a.episode.compareTo(b.episode));
    return episodes;
  }
}

class MikanSubject {
  final String name;
  final String id;
  const MikanSubject({required this.name, required this.id});
}

class MikanEpisode {
  final int episode;
  final String name;
  final String time;
  final List<MikanDownloadLink> links;
  const MikanEpisode({required this.episode, required this.name, required this.time, required this.links});
}

class MikanDownloadLink {
  final String url;
  final String type;
  const MikanDownloadLink({required this.url, required this.type});
}
