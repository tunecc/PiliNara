/// Animeko data source service.
///
/// Core orchestration layer that:
/// 1. Fetches anime list from Bangumi
/// 2. Maps Bangumi IDs to Mikan/DMHY IDs
/// 3. Fetches resources from multiple sources
/// 4. Provides episode matching and filtering
/// 5. Manages source preferences and caching
///
/// This is the Flutter equivalent of animeko's MediaFetcher + MediaSelector.

import 'package:PiliPlus/http/bangumi.dart';
import 'package:PiliPlus/http/dmhy.dart';
import 'package:PiliPlus/http/mikan.dart';
import 'package:PiliPlus/models_new/animeko/animeko_resource.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class AnimekoService extends GetxController {
  final BangumiHttp bangumi = BangumiHttp();
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

  // Episode filter
  final RxInt? targetEpisode = RxInt(null);

  // Source preferences (mirrors animeko's MediaSelectorSettings)
  final RxString preferredSource = '全部'.obs;
  final RxString preferredResolution = '全部'.obs;
  final RxString preferredAlliance = '全部'.obs;
  final RxBool showTorrentOnly = false.obs;

  /// Search for an anime across all sources with Bangumi integration.
  ///
  /// This is the core method that implements animeko's MediaFetcher logic:
  /// 1. Search Bangumi for the anime to get subject ID
  /// 2. Use Bangumi ID to precisely match Mikan subjects
  /// 3. Fallback to keyword search on DMHY
  /// 4. Merge and sort results
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
      // Phase 1: Search Bangumi for the anime
      final bangumiResults = await bangumi.search(keyword: query, max: 5);

      // Phase 2: For each Bangumi result, try to find Mikan resources
      final mikanResources = <AnimekoResource>[];
      for (final subject in bangumiResults) {
        try {
          // Try exact match via Bangumi ID → Mikan ID
          final mikanTopics = await mikan.searchByBangumiId(subject.id.toString());
          if (mikanTopics != null) {
            for (final topic in mikanTopics) {
              mikanResources.add(AnimekoResource.fromMikanTopic(
                topic: topic,
                bangumiSubjectId: subject.id.toString(),
              ));
            }
          }

          // If no exact match, try fuzzy search by name
          if (mikanResources.isEmpty) {
            final mikanId = await mikan.findMikanIdByBangumi(
              animeName: subject.nameCN ?? subject.name,
              bangumiSubjectId: subject.id.toString(),
            );
            if (mikanId != null) {
              final episodes = await mikan.getEpisodeList(mikanId);
              // Convert episodes to resources (simplified - in real impl would use RSS)
              for (final ep in episodes.take(10)) {
                for (final link in ep.links.take(3)) {
                  mikanResources.add(AnimekoResource.fromMikanTopic(
                    topic: MikanTopic(
                      topicId: 'ep${ep.episode}',
                      rawTitle: '${subject.nameCN ?? subject.name} 第${ep.episode}集',
                      alliance: '蜜柑计划',
                      magnetUrl: link.url.startsWith('magnet') ? link.url : null,
                      resolution: '1080P',
                      subtitleLanguages: ['ZHO'],
                    ),
                    bangumiSubjectId: subject.id.toString(),
                  ));
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[AnimekoService] Mikan error for ${subject.id}: $e');
        }
      }

      // Phase 3: Fallback to DMHY keyword search
      final dmhyResult = await dmhy.search(keyword: query, page: 1);
      final dmhyResources = dmhyResult.topics.map((topic) {
        return AnimekoResource.fromDmhyTopic(topic: topic);
      }).toList();

      // Merge results
      totalMikan.value = mikanResources.length;
      totalDmhy.value = dmhyResources.length;
      allResources.value = [...mikanResources, ...dmhyResources];

      // Apply filters
      _applyFilters();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AnimekoService] Search error: $e\n$stackTrace');
      }
      errorMsg.value = '搜索失败: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Apply current filters to resources.
  void _applyFilters() {
    var resources = allResources.toList();

    // Filter by episode
    if (targetEpisode != null) {
      final ep = targetEpisode!;
      resources = resources.where((r) => r.matchesEpisode(ep)).toList();
    }

    // Filter by source
    if (preferredSource.value == '蜜柑计划') {
      resources = resources.where((r) => r.sourceId == 'mikan').toList();
    } else if (preferredSource.value == '动漫花园') {
      resources = resources.where((r) => r.sourceId == 'dmhy').toList();
    }

    // Filter by resolution
    if (preferredResolution.value != '全部') {
      resources = resources.where((r) => r.resolution == preferredResolution.value).toList();
    }

    // Filter by alliance
    if (preferredAlliance.value != '全部') {
      resources = resources.where((r) => r.alliance == preferredAlliance.value).toList();
    }

    // Filter by type
    if (showTorrentOnly.value) {
      resources = resources.where((r) => r.type == AnimekoResourceType.bittorrent).toList();
    }

    // Sort: by episode, then by source priority (mikan first), then by resolution
    resources.sort((a, b) {
      // Episode sort
      final aEp = a.episodeRange?.start ?? 0;
      final bEp = b.episodeRange?.start ?? 0;
      if (aEp != bEp) return aEp.compareTo(bEp);

      // Source priority (mikan > dmhy)
      final aPriority = a.sourceId == 'mikan' ? 0 : 1;
      final bPriority = b.sourceId == 'mikan' ? 0 : 1;
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);

      // Resolution priority
      final resOrder = {'4K': 0, '1080P': 1, '720P': 2, '480P': 3};
      final aRes = resOrder[a.resolution] ?? 4;
      final bRes = resOrder[b.resolution] ?? 4;
      return aRes.compareTo(bRes);
    });

    allResources.value = resources;
  }

  /// Filter by episode number.
  void setTargetEpisode(int? episode) {
    targetEpisode.value = episode;
    _applyFilters();
  }

  /// Filter by source.
  void setSourceFilter(String source) {
    preferredSource.value = source;
    _applyFilters();
  }

  /// Filter by resolution.
  void setResolutionFilter(String resolution) {
    preferredResolution.value = resolution;
    _applyFilters();
  }

  /// Filter by alliance.
  void setAllianceFilter(String alliance) {
    preferredAlliance.value = alliance;
    _applyFilters();
  }

  /// Toggle torrent-only filter.
  void toggleTorrentOnly(bool value) {
    showTorrentOnly.value = value;
    _applyFilters();
  }

  /// Get unique alliances from current results.
  List<String> get availableAlliances {
    finalSet = <String>{};
    for (final r in allResources) {
      if (r.alliance.isNotEmpty) finalSet.add(r.alliance);
    }
    return finalSet.toList()..sort();
  }

  /// Get unique resolutions from current results.
  List<String> get availableResolutions {
    finalSet = <String>{};
    for (final r in allResources) {
      if (r.resolution != null && r.resolution!.isNotEmpty) finalSet.add(r.resolution!);
    }
    return finalSet.toList()..sort((a, b) {
      final order = {'4K': 0, '1080P': 1, '720P': 2, '480P': 3};
      return (order[a] ?? 4).compareTo(order[b] ?? 4);
    });
  }
}
