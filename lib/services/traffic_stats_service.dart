import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:PiliPlus/models/common/network_profile.dart';
import 'package:PiliPlus/utils/connectivity_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_ce/hive.dart';

typedef WindowsTrafficLive = ({
  int appReceived,
  int appSent,
  int interfaceReceived,
  int interfaceSent,
  double appReceiveRate,
  double appSendRate,
  double interfaceReceiveRate,
  double interfaceSendRate,
});

/// Tracks per-hour network traffic split by coarse network category.
///
/// Self-contained: keeps its own Hive box and does not depend on any
/// platform helper that this app does not ship.
final class TrafficStatsService with WidgetsBindingObserver {
  TrafficStatsService._();

  static final instance = TrafficStatsService._();

  static const _windowsChannel = MethodChannel(
    'org.brotech.pilibro/network_traffic',
  );

  Timer? _timer;
  Future<void>? _initializeFuture;
  StreamSubscription<NetworkProfile>? _networkSubscription;
  ({int received, int sent})? _last;
  ({int received, int sent})? _lastWindowsApp;
  ({int received, int sent})? _lastWindowsInterface;
  int? _lastWindowsInterfaceId;
  int _windowsInterfaceSessionReceived = 0;
  int _windowsInterfaceSessionSent = 0;
  DateTime? _lastAt;
  String? _lastCategory;
  final Map<String, dynamic> _data = {};
  final Set<String> _dirtyHours = {};
  Box<dynamic>? _box;
  bool _dirty = false;
  bool _restoring = false;
  int _dartReceived = 0;
  int _dartSent = 0;
  Future<void>? _windowsSample;

  final ValueNotifier<WindowsTrafficLive?> windowsLive = ValueNotifier(null);

  static bool get _supported => Platform.isAndroid || Platform.isWindows;

  Future<void> initialize() {
    if (_timer != null) return Future.value();
    if (!_supported) return Future.value();
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    _box = await _openBox();
    final boxData = _box!.toMap();
    if (boxData.isNotEmpty) {
      _data.addAll(
        boxData.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows) {
      await _windowsChannel.invokeMethod<bool>('installMediaHook');
    }
    await _sample();
    _networkSubscription = ConnectivityUtils.changes.listen((_) => _sample());
    _timer = Timer.periodic(
      Platform.isWindows
          ? const Duration(milliseconds: 250)
          : const Duration(seconds: 90),
      (_) => _sample(),
    );
  }

  void recordApplicationBytes({int received = 0, int sent = 0}) {
    if (!Platform.isWindows) return;
    if (received > 0) _dartReceived += received;
    if (sent > 0) _dartSent += sent;
  }

  String _category(NetworkProfile? profile) => switch (profile) {
    NetworkProfile.wifi => 'wifiBroadband',
    NetworkProfile.cellular => 'mobile',
    _ => 'other',
  };

  String _hourKey(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}T'
      '${time.hour.toString().padLeft(2, '0')}';

  Map<String, dynamic> _mutableMap(dynamic value) => value is Map<String, dynamic>
      ? value
      : value is Map
      ? value.map((key, item) => MapEntry(key.toString(), item))
      : <String, dynamic>{};

  Future<void> _sample() async {
    if (_restoring) return;
    if (Platform.isWindows) {
      await _sampleWindows();
      return;
    }
    final now = DateTime.now();
    final previousAt = _lastAt;
    final current = await _readMobileCounters();
    if (current != null && previousAt != null && _lastCategory != null &&
        _last != null) {
      final received = current.received >= _last!.received
          ? current.received - _last!.received
          : 0;
      final sent =
          current.sent >= _last!.sent ? current.sent - _last!.sent : 0;
      if (received != 0 || sent != 0) {
        _recordDelta(
          _lastCategory!,
          (received: received, sent: sent),
          previousAt,
        );
      }
    }
    if (current != null) _last = current;
    _lastAt = now;
    _lastCategory = _category(ConnectivityUtils.current);
    if (_dirty && previousAt != null && _hourKey(previousAt) != _hourKey(now)) {
      await flush();
    }
  }

  /// Reads process traffic counters from the platform side.
  ///
  /// Returns null while no native helper answers the channel, so a missing
  /// helper simply pauses accumulation instead of recording bogus deltas.
  Future<({int received, int sent})?> _readMobileCounters() async {
    try {
      final counters = await _windowsChannel
          .invokeMapMethod<Object?, Object?>('trafficCounters');
      final media = counters?['media'] as Map?;
      if (media == null) return null;
      return (
        received: (media['received'] as num?)?.toInt() ?? 0,
        sent: (media['sent'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _sampleWindows() => _windowsSample ??=
      _sampleWindowsNow().whenComplete(() => _windowsSample = null);

  Future<void> _sampleWindowsNow() async {
    try {
      final counters = await _windowsChannel
          .invokeMapMethod<Object?, Object?>('trafficCounters');
      final media = counters?['media'] as Map?;
      final network = counters?['interface'] as Map?;
      final now = DateTime.now();
      final previousAt = _lastAt;
      final app = (
        received: ((media?['received'] as num?)?.toInt() ?? 0) + _dartReceived,
        sent: ((media?['sent'] as num?)?.toInt() ?? 0) + _dartSent,
      );
      final interface = (
        received: (network?['received'] as num?)?.toInt() ?? 0,
        sent: (network?['sent'] as num?)?.toInt() ?? 0,
      );
      final elapsedUs =
          previousAt == null ? 0 : now.difference(previousAt).inMicroseconds;
      final appDelta = _delta(app, _lastWindowsApp);
      final interfaceAvailable = network?['available'] == true;
      final interfaceId = (network?['sourceId'] as num?)?.toInt();
      final sameInterface =
          interfaceAvailable && interfaceId != null && interfaceId == _lastWindowsInterfaceId;
      final interfaceDelta = interfaceAvailable
          ? _delta(interface, sameInterface ? _lastWindowsInterface : null)
          : (received: 0, sent: 0);
      _windowsInterfaceSessionReceived += interfaceDelta.received;
      _windowsInterfaceSessionSent += interfaceDelta.sent;
      if (previousAt != null && _lastCategory != null) {
        _recordDelta('appObserved.${_lastCategory!}', appDelta, previousAt);
        _recordDelta('activeInterface.${_lastCategory!}', interfaceDelta, previousAt);
      }
      if (elapsedUs > 0) {
        final invElapsedUs = 1000000 / elapsedUs;
        windowsLive.value = (
          appReceived: app.received,
          appSent: app.sent,
          interfaceReceived: _windowsInterfaceSessionReceived,
          interfaceSent: _windowsInterfaceSessionSent,
          appReceiveRate: appDelta.received * invElapsedUs,
          appSendRate: appDelta.sent * invElapsedUs,
          interfaceReceiveRate: interfaceDelta.received * invElapsedUs,
          interfaceSendRate: interfaceDelta.sent * invElapsedUs,
        );
      }
      _lastWindowsApp = app;
      if (interfaceAvailable) {
        _lastWindowsInterface = interface;
        _lastWindowsInterfaceId = interfaceId;
      }
      _lastAt = now;
      _lastCategory = _category(ConnectivityUtils.current);
      if (_dirty && previousAt != null && _hourKey(previousAt) != _hourKey(now)) {
        await flush();
      }
    } catch (_) {
      return;
    }
  }

  ({int received, int sent}) _delta(
    ({int received, int sent}) current,
    ({int received, int sent})? previous,
  ) =>
      previous == null
          ? (received: 0, sent: 0)
          : (
              received: current.received >= previous.received
                  ? current.received - previous.received
                  : 0,
              sent: current.sent >= previous.sent ? current.sent - previous.sent : 0,
            );

  void _recordDelta(
    String source,
    ({int received, int sent}) delta,
    DateTime at,
  ) {
    if (delta.received == 0 && delta.sent == 0) return;
    final hour = _hourKey(at);
    final hourly = _mutableMap(_data[hour]);
    final category = _mutableMap(hourly[source]);
    category
      ..['received'] = (category['received'] as num? ?? 0).toInt() + delta.received
      ..['sent'] = (category['sent'] as num? ?? 0).toInt() + delta.sent;
    hourly[source] = category;
    _data[hour] = hourly;
    _dirtyHours.add(hour);
    _dirty = true;
  }

  Future<void> flush() async {
    if (!_dirty) return;
    final hours = Set<String>.of(_dirtyHours);
    final values = <String, dynamic>{
      for (final hour in hours) hour: _data[hour],
    };
    _dirty = false;
    _dirtyHours.removeAll(hours);
    try {
      await _box?.putAll(values);
    } catch (_) {
      _dirty = true;
      _dirtyHours.addAll(hours);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> snapshot({DateTime? start, DateTime? end}) async {
    if (_supported) await _sample();
    final first = start == null ? null : _hourKey(start);
    final after = end == null
        ? null
        : _hourKey(DateTime(end.year, end.month, end.day + 1));
    return {
      for (final entry in _data.entries)
        if ((first == null || entry.key.compareTo(first) >= 0) &&
            (after == null || entry.key.compareTo(after) < 0))
          entry.key: Map<String, dynamic>.from(entry.value as Map),
    };
  }

  Future<void> restoreHive(File source) async {
    if (!_supported) return;
    final currentBox = _box;
    final targetPath = currentBox?.path;
    if (currentBox == null || targetPath == null) {
      throw StateError('流量统计库尚未初始化');
    }
    final target = File(targetPath);
    final previous = File('$targetPath.webdav-previous');
    await _sample();
    _restoring = true;
    try {
      await flush();
      await currentBox.close();
      _box = null;
      if (await previous.exists()) await previous.delete();
      if (await target.exists()) await target.rename(previous.path);
      await source.copy(target.path);
      _box = await _openBox();
      _reloadBoxData();
      if (await previous.exists()) await previous.delete();
    } catch (_) {
      await _box?.close();
      _box = null;
      if (await target.exists()) await target.delete();
      if (await previous.exists()) await previous.rename(target.path);
      _box = await _openBox();
      _reloadBoxData();
      rethrow;
    } finally {
      _resetSession();
      _restoring = false;
    }
    await _sample();
  }

  Future<Box<dynamic>> _openBox() => Hive.openBox(
        'trafficStats',
        compactionStrategy: (entries, deletedEntries) =>
            deletedEntries > 100 && deletedEntries > entries,
      );

  void _reloadBoxData() {
    _data
      ..clear()
      ..addAll(
        _box!.toMap().map((key, value) => MapEntry(key.toString(), value)),
      );
    _dirty = false;
    _dirtyHours.clear();
  }

  Future<void> reset() async {
    await initialize();
    await _sample();
    _restoring = true;
    try {
      _data.clear();
      _dirtyHours.clear();
      _dirty = false;
      await _box?.clear();
      _resetSession();
    } finally {
      _restoring = false;
    }
    await _sample();
  }

  Future<File?> copyHiveSnapshot(File destination) async {
    await initialize();
    final source = hiveFile;
    if (source == null || !await source.exists()) return null;
    await _sample();
    _restoring = true;
    try {
      await flush();
      await _box?.flush();
      await destination.parent.create(recursive: true);
      return await source.copy(destination.path);
    } finally {
      _restoring = false;
    }
  }

  Future<({int day, int week, int month})> currentPeriodUsage() async {
    if (!_supported) return (day: 0, week: 0, month: 0);
    await _sample();
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final weekStart = dayStart.subtract(Duration(days: dayStart.weekday - 1));
    final monthStart = DateTime(now.year, now.month);
    final dayKey = _hourKey(dayStart);
    final weekKey = _hourKey(weekStart);
    final monthKey = _hourKey(monthStart);
    final appObservedOnly = Platform.isWindows;
    var day = 0;
    var week = 0;
    var month = 0;
    for (final entry in _data.entries) {
      if (entry.key.compareTo(monthKey) < 0) continue;
      var total = 0;
      final hourly = entry.value as Map;
      for (final item in hourly.entries) {
        if (appObservedOnly && !item.key.toString().startsWith('appObserved.')) {
          continue;
        }
        final category = item.value;
        if (category is! Map) continue;
        total += (category['received'] as num? ?? 0).toInt();
        total += (category['sent'] as num? ?? 0).toInt();
      }
      month += total;
      if (entry.key.compareTo(weekKey) >= 0) week += total;
      if (entry.key.compareTo(dayKey) >= 0) day += total;
    }
    return (day: day, week: week, month: month);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _sample().then((_) => flush());
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _networkSubscription?.cancel();
    _networkSubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    await _sample();
    await flush();
    await _box?.close();
    _box = null;
    _initializeFuture = null;
  }

  void _resetSession() {
    _last = null;
    _lastWindowsApp = null;
    _lastWindowsInterface = null;
    _lastWindowsInterfaceId = null;
    _lastAt = null;
    _lastCategory = null;
    windowsLive.value = null;
  }

  File? get hiveFile {
    final boxPath = _box?.path;
    return boxPath == null ? null : File(boxPath);
  }
}
