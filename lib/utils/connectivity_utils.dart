import 'package:PiliPlus/utils/platform_utils.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

abstract final class ConnectivityUtils {
  static Future<bool> get isWiFi async {
    try {
      return PlatformUtils.isMobile &&
          (await Connectivity().checkConnectivity()).contains(
            ConnectivityResult.wifi,
          );
    } catch (_) {
      return true;
    }
  }

  static final _controller = StreamController<bool>.broadcast();
  static bool _isWiFi = true;

  static Stream<bool> get changes => _controller.stream;

  static bool get current => _isWiFi;

  static void _onConnectivityChanged(bool isWiFi) {
    if (isWiFi != _isWiFi) {
      _isWiFi = isWiFi;
      _controller.add(isWiFi);
    }
  }

  static Future<void> init() async {
    _isWiFi = await isWiFi;
    Connectivity().onConnectivityChanged.listen((_) async {
      _onConnectivityChanged(await isWiFi);
    });
  }
}
