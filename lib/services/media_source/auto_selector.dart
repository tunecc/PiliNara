import 'dart:async'; import 'dart:collection'; import 'package:PiliPlus/services/logger.dart'; import 'package:PiliPlus/services/media_source/media_source.dart';
class SelectedMedia { final MediaMatch match; final String sourceId; final bool wasFastSelected; const SelectedMedia({required this.match, required this.sourceId, this.wasFastSelected = false}); }
class MediaAutoSelector {
  final List<MediaSource> sources; final LinkedHashMap<String, List<_C>> _cache = LinkedHashMap(); static const _max = 100; final Duration fastSelectTimeout;
  MediaAutoSelector({required this.sources, this.fastSelectTimeout = const Duration(seconds: 3)});
  Stream<SelectedMedia> select(MediaFetchRequest q) async* {
    final ck = '${q.subjectId ?? q.subjectNames.firstOrNull ?? "u"}:${q.currentEpisode?.number ?? 0}';
    final cached = _cache[ck]; if (cached != null && cached.isNotEmpty) { final b = _pick(cached.map((c) => c.toE()).toList()); if (b != null) { yield SelectedMedia(match: b.m, sourceId: b.s, wasFastSelected: true); return; } }
    final es = sources.where((s) => s.enabled).toList(); if (es.isEmpty) return;
    final all = <_E>[]; final comp = Completer<void>(); var done = 0; SelectedMedia? fast; final subs = <StreamSubscription>[];
    for (final src in es) { subs.add(src.fetch(q).listen((ms) { for (final m in ms) { all.add(_E(m: m, s: src.id, t: src.tier)); if (src.tier == 0 && m.kind == MatchKind.exact && fast == null) fast = SelectedMedia(match: m, sourceId: src.id, wasFastSelected: true); } }, onError: (e) => logger.w('Sel:${src.id}:$e'), onDone: () { done++; if (done >= es.length) comp.complete(); })); }
    try { await Future.any([comp.future, if (fast != null) Future.delayed(fastSelectTimeout)]); } finally { for (final s in subs) s.cancel(); }
    if (fast != null) yield fast;
    final best = _pick(all); if (best != null && best.m != fast?.match) yield SelectedMedia(match: best.m, sourceId: best.s, wasFastSelected: false);
    _cache[ck] = all.map((e) => _C(m: e.m, s: e.s, t: e.t)).toList(); while (_cache.length > _max) _cache.remove(_cache.keys.first);
  }
  _E? _pick(List<_E> e) { if (e.isEmpty) return null; e.sort((a, b) { if (a.t != b.t) return a.t.compareTo(b.t); if (a.m.kind != b.m.kind) return a.m.kind == MatchKind.exact ? -1 : 1; final ra = _pr(a.m.media.properties.resolution); final rb = _pr(b.m.media.properties.resolution); if (ra != rb) return rb.compareTo(ra); return (b.m.media.properties.fileSizeBytes ?? 0).compareTo(a.m.media.properties.fileSizeBytes ?? 0); }); return e.first; }
  int _pr(String? r) { if (r == null) return 0; final l = r.toLowerCase(); if (l.contains('2160') || l.contains('4k')) return 2160; if (l.contains('1080')) return 1080; if (l.contains('720')) return 720; return 0; }
  void clearCache() => _cache.clear();
}
class _E { final MediaMatch m; final String s; final int t; const _E({required this.m, required this.s, required this.t}); }
class _C { final MediaMatch m; final String s; final int t; const _C({required this.m, required this.s, required this.t}); _E toE() => _E(m: m, s: s, t: t); }
