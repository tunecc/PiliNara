import 'dart:async';
import 'dart:typed_data';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to Android Media3 ExoPlayer via MethodChannel.
/// Provides audio normalization, super-resolution, and frame capture.
class Media3Bridge {
  static const _methodChannel = MethodChannel('PiliNara/media3');
  static const _eventChannel = EventChannel('PiliNara/media3/events');

  StreamSubscription? _eventSub;
  final _stateController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get playerEvents => _stateController.stream;

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    _eventSub = _eventChannel.receiveBroadcastStream().listen(
      (data) {
        if (data is Map) {
          _stateController.add(Map<String, dynamic>.from(data));
        }
      },
      onError: (e) => debugPrint('Media3 event error: $e'),
    );
  }

  Future<bool> createPlayer() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('createPlayer') ?? false;
    } catch (e) {
      debugPrint('Media3 createPlayer failed: $e');
      return false;
    }
  }

  Future<bool> setDataSource(String url, {Map<String, String>? headers}) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('setDataSource', {
        'url': url,
        if (headers != null) 'headers': headers,
      }) ?? false;
    } catch (e) {
      debugPrint('Media3 setDataSource failed: $e');
      return false;
    }
  }

  Future<bool> play() => _invokeBool('play');
  Future<bool> pause() => _invokeBool('pause');

  Future<bool> seekTo(int positionMs) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('seekTo', {
        'positionMs': positionMs,
      }) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<int> getPosition() => _invokeInt('getPosition');
  Future<int> getDuration() => _invokeInt('getDuration');
  Future<int> getBufferedPosition() => _invokeInt('getBufferedPosition');

  Future<bool> setSpeed(double speed) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('setSpeed', {
        'speed': speed,
      }) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setVolume(double volume) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('setVolume', {
        'volume': volume,
      }) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isPlaying() => _invokeBool('isPlaying');

  // --- Audio Processing ---

  Future<bool> setAudioGain(double db) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('setAudioGain', {
        'db': db,
      }) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setAudioDynamic(bool enabled, {double targetRmsDb = -16.0}) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('setAudioDynamic', {
        'enabled': enabled,
        'targetRmsDb': targetRmsDb,
      }) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setAudioEq(
    bool enabled, {
    double freqHz = 1000.0,
    double gainDb = 0.0,
    double q = 1.0,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('setAudioEq', {
        'enabled': enabled,
        'freqHz': freqHz,
        'gainDb': gainDb,
        'q': q,
      }) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setSuperResolution(String mode) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('setSuperResolution', {
        'mode': mode,
      }) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<Uint8List?> captureFrame() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _methodChannel.invokeMethod<Uint8List>('captureFrame');
    } catch (e) {
      debugPrint('Media3 captureFrame failed: $e');
      return null;
    }
  }

  Future<bool> release() => _invokeBool('release');

  void dispose() {
    _eventSub?.cancel();
    _stateController.close();
  }

  Future<bool> _invokeBool(String method) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>(method) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<int> _invokeInt(String method) async {
    if (!Platform.isAndroid) return 0;
    try {
      return await _methodChannel.invokeMethod<int>(method) ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
