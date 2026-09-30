library;
import 'dart:async';
typedef SourceId = String;
class MediaSourceMetadata { final String name; final String? iconUrl; final String? description; final bool supportsBrowsing; const MediaSourceMetadata({required this.name, this.iconUrl, this.description, this.supportsBrowsing = false}); }
class MediaFetchRequest { final List<String> subjectNames; final String? subjectId; final List<EpisodeInfo> episodes; final EpisodeInfo? currentEpisode; const MediaFetchRequest({required this.subjectNames, this.subjectId, this.episodes = const [], this.currentEpisode}); }
class EpisodeInfo { final int? number; final String? title; final String? id; const EpisodeInfo({this.number, this.title, this.id}); @override String toString() => 'Episode(#$number: $title)'; }
enum MatchKind { exact, fuzzy }
class EpisodeRange { final int? start; final int? end; final bool isSingle; final bool isAll; const EpisodeRange._({this.start, this.end, this.isSingle = false, this.isAll = false}); factory EpisodeRange.single(int ep) => EpisodeRange._(start: ep, end: ep, isSingle: true); factory EpisodeRange.range(int s, int e) => EpisodeRange._(start: s, end: e); factory EpisodeRange.all() => const EpisodeRange._(isAll: true); factory EpisodeRange.unknown() => const EpisodeRange._(); bool contains(int ep) { if (isAll) return true; if (start == null || end == null) return false; return ep >= start! && ep <= end!; } @override String toString() { if (isAll) return 'ALL'; if (isSingle) return 'EP$start'; if (start != null && end != null) return 'EP$start-$end'; return 'UNKNOWN'; } }
class MediaProperties { final String? subtitleGroup; final String? resolution; final String? language; final int? fileSizeBytes; const MediaProperties({this.subtitleGroup, this.resolution, this.language, this.fileSizeBytes}); }
enum MediaLocationType { web, torrent, local }
class Media { final String mediaId; final String originalUrl; final String downloadUrl; final MediaProperties properties; final MediaLocationType locationType; const Media({required this.mediaId, required this.originalUrl, required this.downloadUrl, this.properties = const MediaProperties(), this.locationType = MediaLocationType.web}); }
class MediaMatch { final Media media; final MatchKind kind; final EpisodeRange episodeRange; const MediaMatch({required this.media, required this.kind, required this.episodeRange}); }
abstract class MediaSource { String get id; MediaSourceMetadata get metadata; int get tier; bool get enabled; Stream<List<MediaMatch>> fetch(MediaFetchRequest query); }
