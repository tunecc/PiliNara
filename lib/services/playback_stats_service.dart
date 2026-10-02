import 'dart:async';
import 'dart:math' show max;
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/widgets.dart';

abstract final class PlaybackStatsService {
  static const schemaVersion = 1;
  static final _clock = Stopwatch()..start();
  static Map<String, dynamic>? _stats;
  static Timer? _flushTimer;
  static Future<void> _writeChain = Future.value();
  static bool _dirty = false;
  static bool _appForeground = false;
  static int _appLastWallUs = 0;
  static int _pageLastWallUs = 0;
  static String _pageCategory = 'other';
  static bool _active = false;
  static bool _playing = false;
  static bool _buffering = false;
  static int _lastWallUs = 0;
  static double _rate = 1;
  static double _defaultRate = 1;
  static int _sourceDurationUs = 0;
  static int _trailingPauseUs = 0;

  static void initializeAppLifecycle() {
    _ensureInitialized();
    _appLastWallUs = _clock.elapsedMicroseconds;
    _pageLastWallUs = _appLastWallUs;
    _appForeground = WidgetsBinding.instance.lifecycleState == .resumed;
    WidgetsBinding.instance.addObserver(_Observer());
  }

  static void _ensureInitialized() {
    if (_stats != null) return;
    _stats = _loadStatsFromStorage();
    _stats!['schemaVersion'] = schemaVersion;
    _flushTimer ??= Timer.periodic(const Duration(minutes: 2), (_) => unawaited(flush()));
  }

  static Map<String, dynamic> _loadStatsFromStorage() {
    final raw = GStorage.setting.toMap();
    if (raw.isEmpty || !raw.containsKey(SettingBoxKey.playbackStats)) {
      return <String, dynamic>{'schemaVersion': schemaVersion, 'createdAtMs': DateTime.now().millisecondsSinceEpoch};
    }
    return raw[SettingBoxKey.playbackStats] as Map<String, dynamic>? ?? {};
  }

  static void _add(String key, num value) {
    if (value == 0) return;
    final current = _stats![key] as num? ?? 0;
    _stats![key] = value is double || current is double ? current.toDouble() + value : current.toInt() + value.toInt();
    _dirty = true;
  }

  static void _settleAppForeground(int now) {
    if (_appForeground) _add('appForegroundUs', max(0, now - _appLastWallUs));
    _appLastWallUs = now;
  }

  static void _settlePageDwell(int now) {
    if (_appForeground) _add('pageForegroundUs', max(0, now - _pageLastWallUs));
    _pageLastWallUs = now;
  }

  static void onAppForeground(bool foreground) {
    _ensureInitialized();
    final now = _clock.elapsedMicroseconds;
    _settleAppForeground(now);
    _settlePageDwell(now);
    _appForeground = foreground;
    if (!foreground) unawaited(flush());
  }

  static void onPlaybackStart(double defaultRate) {
    _ensureInitialized();
    _active = true;
    _defaultRate = defaultRate;
    _rate = defaultRate;
    _sourceDurationUs = 0;
    _add('videoStarts', 1);
  }

  static void onPlaybackEnd() { _active = false; _flushPending(); }
  static void onPlay() { _playing = true; _buffering = false; _trailingPauseUs = 0; }
  static void onPause() {
    _playing = false;
    _trailingPauseUs = max(0, _clock.elapsedMicroseconds - _lastWallUs);
  }
  static void onBuffering() => _buffering = true;
  static void onBufferEnd() { _buffering = false; _flushPending(); }

  static void onPosition(int positionUs, int sourceDurationUs) {
    _sourceDurationUs = sourceDurationUs;
    if (sourceDurationUs > 0 && positionUs >= sourceDurationUs * 0.95 && _playing) {
      _add('sessionCompletedCount', 1);
    }
  }

  static void onSpeedChange(double rate) {
    _rate = rate;
    _addBucket('speedSelections', rate.toStringAsFixed(2), 1);
  }

  static void onSeek(int fromUs, int toUs) {
    _flushPending();
    final distance = toUs - fromUs;
    if (distance < 0) { _add('rewindCount', 1); _add('rewindUs', -distance); }
    else if (distance > 1000000) { _add('forwardSkipCount', 1); _add('forwardSkipUs', distance); }
  }

  static void _flushPending() {
    final now = _clock.elapsedMicroseconds;
    final activeDelta = max(0, now - _lastWallUs);
    if (_playing && !_buffering) {
      final mediaAdvance = (activeDelta * _rate).round();
      _add('activePlaybackUs', activeDelta);
      _add('mediaAdvanceUs', mediaAdvance);
      _add('nominalMediaUs', activeDelta * _defaultRate);
    } else if (_buffering) {
      _add('bufferingUs', activeDelta);
    } else if (!_playing && _trailingPauseUs > 0) {
      _add('pausedUs', _trailingPauseUs);
    }
    _lastWallUs = now;
    _trailingPauseUs = 0;
  }

  static void _addBucket(String key, String bucket, num value) {
    final map = _map(key);
    map[bucket] = ((map[bucket] as num?) ?? 0) + value;
    _dirty = true;
  }

  static Map<String, dynamic> _map(String key) {
    final current = _stats![key];
    if (current is Map<String, dynamic>) return current;
    final next = <String, dynamic>{};
    _stats![key] = next;
    return next;
  }

  static Map<String, dynamic> snapshot() {
    _ensureInitialized();
    final now = _clock.elapsedMicroseconds;
    _settleAppForeground(now);
    _settlePageDwell(now);
    _flushPending();
    final raw = Map<String, dynamic>.from(_stats!);
    final active = _num(raw['activePlaybackUs']);
    final media = _num(raw['mediaAdvanceUs']);
    final paused = _num(raw['pausedUs']);
    final buffering = _num(raw['bufferingUs']);
    final observed = active + paused + buffering;
    final nominal = _num(raw['nominalMediaUs']);
    final scale = active == 0 ? 0 : 1 / active;
    raw['derived'] = {
      'actualAverageSpeed': media * scale,
      'nominalAverageSpeed': nominal * scale,
      'savedTimeUs': media - active,
      'playerObservedUs': observed,
    };
    return raw;
  }

  static num _num(dynamic v) => v is num ? v : 0;

  static String _duration(int us) {
    final neg = us < 0;
    var s = (us.abs() * 0.000001).round();
    final days = s ~/ 86400; s -= days * 86400;
    final hours = s ~/ 3600; s -= hours * 3600;
    final mins = s ~/ 60; s -= mins * 60;
    final parts = <String>[];
    if (days > 0) parts.add('$days天');
    if (hours > 0) parts.add('$hours小时');
    if (mins > 0) parts.add('$mins分钟');
    if (s > 0 || parts.isEmpty) parts.add('$s秒');
    return '${neg ? '-' : ''}${parts.join()}';
  }

  static Future<void> flush({bool force = false}) async {
    if (!force && !_dirty) return;
    _ensureInitialized();
    _flushPending();
    _stats!['updatedAtMs'] = DateTime.now().millisecondsSinceEpoch;
    final writes = Map<String, dynamic>.from(_stats!);
    _dirty = false;
    _writeChain = _writeChain.then((_) async {
      await GStorage.setting.put(SettingBoxKey.playbackStats, writes);
    });
    try { await _writeChain; } catch (_) { _dirty = true; rethrow; }
  }

  static Future<void> reset() async {
    _ensureInitialized();
    await GStorage.setting.delete(SettingBoxKey.playbackStats);
    _stats = {'schemaVersion': schemaVersion, 'createdAtMs': DateTime.now().millisecondsSinceEpoch};
    _dirty = true;
    await flush(force: true);
  }
}

class _Observer extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    PlaybackStatsService.onAppForeground(state == AppLifecycleState.resumed);
  }
}
