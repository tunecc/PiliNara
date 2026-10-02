enum DanmakuSpeedMode {
  /// 跟随视频倍速，弹幕速度与视频播放速度同步
  followVideo('跟随视频'),

  /// 阅读优先，保持固定阅读速度不受视频倍速影响
  readPriority('阅读优先'),

  /// 自定义速度模式
  custom('自定义');

  final String label;
  const DanmakuSpeedMode(this.label);
}
