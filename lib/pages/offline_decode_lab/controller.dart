import 'dart:async';
import 'package:PiliPlus/services/logger.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';

class OfflineDecodeLabController extends GetxController {
  final RxBool isTesting = false.obs;
  final RxDouble actualSpeed = 0.0.obs;
  final RxDouble nominalSpeed = 1.0.obs;
  final RxInt elapsedMs = 0.obs;
  final RxInt playerPositionMs = 0.obs;
  final RxString status = '就绪'.obs;
  Timer? _timer;
  Player? _player;

  Future<void> startTest({double speed = 2.0}) async {
    if (isTesting.value) return;
    isTesting.value = true;
    nominalSpeed.value = speed;
    actualSpeed.value = 0;
    elapsedMs.value = 0;
    playerPositionMs.value = 0;
    status.value = '初始化播放器...';

    try {
      _player = await Player.create(configuration: PlayerConfiguration(logLevel: .error));
      // Use a short public domain video for testing
      await _player!.open(Media('https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', start: Duration.zero));
      await _player!.setRate(speed);
      status.value = '测试中 (${speed}x)...';

      final stopwatch = Stopwatch()..start();
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (!isTesting.value) return;
        elapsedMs.value = stopwatch.elapsedMilliseconds;
        playerPositionMs.value = _player?.state.position.inMilliseconds ?? 0;
        if (elapsedMs.value > 0) {
          actualSpeed.value = playerPositionMs.value / elapsedMs.value;
        }
      });

      // Auto-stop after 10 seconds
      await Future.delayed(const Duration(seconds: 10));
      stopTest();
    } catch (e) {
      logger.e('Decode lab test failed: $e');
      status.value = '错误: $e';
      isTesting.value = false;
    }
  }

  void stopTest() {
    _timer?.cancel();
    _timer = null;
    _player?.dispose();
    _player = null;
    isTesting.value = false;
    if (elapsedMs.value > 0) {
      status.value = '完成: 实际 ${actualSpeed.value.toStringAsFixed(2)}x (名义 ${nominalSpeed.value}x)';
    } else {
      status.value = '已停止';
    }
  }

  @override
  void onClose() {
    stopTest();
    super.onClose();
  }
}
