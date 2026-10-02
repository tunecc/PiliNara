import 'dart:async';

import 'package:PiliPlus/models/common/network_profile.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
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

  static final _controller = StreamController<NetworkProfile>.broadcast();
  static NetworkProfile _current = NetworkProfile.wifi;

  /// Emits whenever the coarse network profile changes.
  static Stream<NetworkProfile> get changes => _controller.stream;

  static NetworkProfile get current => _current;

  static Future<NetworkProfile> detect() async =>
      await isWiFi ? NetworkProfile.wifi : NetworkProfile.cellular;

  static void _emit(NetworkProfile profile) {
    if (profile != _current) {
      _current = profile;
      _controller.add(profile);
    }
  }

  static Future<void> init() async {
    _current = await detect();
    Connectivity().onConnectivityChanged.listen((_) async {
      _emit(await detect());
    });
  }
}
