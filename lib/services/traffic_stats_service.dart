import 'dart:async';
import 'dart:io' show Platform;
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/widgets.dart';

final class TrafficStatsService with WidgetsBindingObserver {
  TrafficStatsService._();
  static final instance = TrafficStatsService._();
  Timer? _timer;
  Future<void>? _initFuture;
  Map<String, dynamic> _data = {};
  bool _dirty = false;

  Future<void> initialize() {
    if (_timer != null) return Future.value();
    if (!Platform.isAndroid && !Platform.isWindows) return Future.value();
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    final raw = GStorage.setting.toMap();
    final stored = raw[SettingBoxKey.trafficStats] as Map<String, dynamic>?;
    if (stored != null) _data = Map<String, dynamic>.from(stored);
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 90), (_) => _sample());
  }

  Future<void> _sample() async {
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}';
    _data[key] = {'received': (_data[key] as Map?)?['received'] ?? 0, 'sent': (_data[key] as Map?)?['sent'] ?? 0};
    _dirty = true;
  }

  Map<String, dynamic> snapshot() => Map<String, dynamic>.from(_data);
  Future<void> flush() async {
    if (!_dirty) return;
    await GStorage.setting.put(SettingBoxKey.trafficStats, _data);
    _dirty = false;
  }
  Future<void> reset() async {
    await GStorage.setting.delete(SettingBoxKey.trafficStats);
    _data = {}; _dirty = false;
  }
}
