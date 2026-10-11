import 'dart:math';

import 'package:PiliPlus/services/thread_ripper/contracts.dart';

/// 每视频会话的 descriptor 注册表：token → [MediaDescriptor]。
///
/// 由视频会话持有，`player.open` 前注册、换视频/页面销毁时 [clear]，
/// 不做任何跨视频或持久化缓存。token 仅在本进程内用于代理路径反查。
class SessionRegistry {
  final Map<String, MediaDescriptor> _byToken = {};

  final Random _random = Random.secure();

  /// 登记一个 descriptor，返回本次会话内不重复的随机十六进制 token。
  String register(MediaDescriptor descriptor) {
    var token = _newToken();
    while (_byToken.containsKey(token)) {
      token = _newToken();
    }
    _byToken[token] = descriptor;
    return token;
  }

  /// 反查 token 对应的 descriptor；未登记返回 null（代理据此退化透传）。
  MediaDescriptor? lookup(String token) => _byToken[token];

  /// 用 [descriptor] 替换 [token] 的登记项（总大小探测学习后回填）。
  void update(String token, MediaDescriptor descriptor) {
    if (_byToken.containsKey(token)) {
      _byToken[token] = descriptor;
    }
  }

  /// 清空全部登记（换视频/页面销毁时调用）。
  void clear() => _byToken.clear();

  /// 16 字节随机数的十六进制表示（32 字符），自实现避免新增依赖。
  String _newToken() => List.generate(
        16,
        (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
}
