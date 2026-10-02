/// Controller for the Animeko aggregation page.
///
/// Searches Mikan and DMHY simultaneously, aggregates results, and provides
/// filtering by episode number, resolution, and source.

import 'package:PiliNara/http/dmhy.dart';
import 'package:PiliNara/http/mikan.dart';
import 'package:PiliNara/models_new/animeko/animeko_resource.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class AnimekoController extends GetxController {
  final MikanHttp mikan = MikanHttp();
  final DmhyHttp dmhy = DmhyHttp();

  // Search state
  final RxString searchQuery = ''.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMsg = ''.obs;

  // Results
  final RxList<AnimekoResource> allResources = RxList<AnimekoResource>([]);
  final RxInt totalMikan = 0.obs;
  final RxInt totalDmhy = 0.obs;

  // Filters
  final RxString resolutionFilter = '全部'.obs;
  final RxString sourceFilter = '全部'.obs;
  final RxBool showTorrentOnly = false.obs;

  /// Filtered results based on current filters
  List<AnimekoResource> get filteredResources {
    var resources = allResources.toList();

    if (resolutionFilter.value != '全部') {
      resources = resources.where((r) => r.resolution == resolutionFilter.value).toList();
    }

    if (sourceFilter.value == '蜜柑计划') {
      resources = resources.where((r) => r.sourceId == 'mikan').toList();
    } else if (sourceFilter.value == '动漫花园') {
      resources = resources.where((r) => r.sourceId == 'dmhy').toList();
    }

    if (showTorrentOnly.value) {
      resources = resources.where((r) => r.isTorrent).toList();
    }

    // Sort by episode number, then by source
    resources.sort((a, b) {
      if (a.episode != null && b.episode != null) {
        final cmp = a.episode!.compareTo(b.episode!);
        if (cmp != 0) return cmp;
      }
      return a.sourceId.compareTo(b.sourceId);
    });

    return resources;
  }

  /// Search for an anime across all sources.
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      allResources.clear();
      totalMikan.value = 0;
      totalDmhy.value = 0;
      errorMsg.value = '';
      return;
    }

    isLoading.value = true;
    errorMsg.value = '';

    try {
      final mikanResults = await _searchMikan(query);
      final dmhyResults = await _searchDmhy(query);

      totalMikan.value = mikanResults.length;
      totalDmhy.value = dmhyResults.length;

      allResources.value = [...mikanResults, ...dmhyResults];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AnimekoController] Search error: $e\n$stackTrace');
      }
      errorMsg.value = '搜索失败: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<AnimekoResource>> _searchMikan(String query) async {
    try {
      final subjects = await mikan.search(query);
      if (subjects.isEmpty) return [];

      // Get episodes for the first subject (best match)
      final episodes = await mikan.getEpisodes(subjects.first.id);
      if (episodes.isEmpty) return [];

      final resources = <AnimekoResource>[];
      for (final ep in episodes.take(20)) {
        for (final link in ep.links.take(3)) {
          resources.add(AnimekoResource.fromMikan(
            subjectName: subjects.first.name,
            subjectId: subjects.first.id,
            episode: ep.episode,
            episodeName: ep.name,
            linkUrl: link.url,
          ));
        }
      }
      return resources;
    } catch (e) {
      if (kDebugMode) debugPrint('[Mikan] Search error: $e');
      return [];
    }
  }

  Future<List<AnimekoResource>> _searchDmhy(String query) async {
    try {
      final result = await dmhy.search(keyword: query, page: 1);
      if (result.topics.isEmpty) return [];

      return result.topics.map((topic) {
        // Try to extract episode number from title
        int? episode;
        final epMatch = RegExp(r'第(\d+)集|EP(\d+)|(\d+)话').firstMatch(topic.title);
        if (epMatch != null) {
          episode = int.tryParse(
            epMatch.group(1) ?? epMatch.group(2) ?? epMatch.group(3) ?? '0',
          );
        }

        // Try to extract resolution from title
        String resolution = '';
        if (topic.title.contains('1080') || topic.title.contains('1080p')) {
          resolution = '1080P';
        } else if (topic.title.contains('720') || topic.title.contains('720p')) {
          resolution = '720P';
        } else if (topic.title.contains('480')) {
          resolution = '480P';
        } else if (topic.title.contains('2160') || topic.title.contains('4K')) {
          resolution = '4K';
        }

        return AnimekoResource.fromDmhy(
          title: topic.title,
          topicId: topic.id,
          author: topic.author,
          size: topic.size,
          magnetUrl: topic.magnetUrl,
          detailUrl: topic.detailUrl,
          episode: episode,
          resolution: resolution,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[DMHY] Search error: $e');
      return [];
    }
  }

  void setResolutionFilter(String resolution) {
    resolutionFilter.value = resolution;
  }

  void setSourceFilter(String source) {
    sourceFilter.value = source;
  }

  void toggleTorrentOnly(bool value) {
    showTorrentOnly.value = value;
  }
}
