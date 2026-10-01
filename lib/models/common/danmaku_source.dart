/// Third-party danmaku sources that can be mixed into the player.
abstract final class DanmakuSource {
  static const bilibili = 'bilibili';
  static const gamer = 'gamer';
  static const dandanplay = 'dandanplay';

  static const Map<String, String> labels = {
    bilibili: 'Bilibili（官方）',
    gamer: 'Gamer',
    dandanplay: '弹弹play',
  };

  static const Map<String, String> descriptions = {
    bilibili: 'B 站官方弹幕',
    gamer: '来自 gamer 的弹幕，需番剧标题匹配',
    dandanplay: '弹弹play 弹幕库，需番剧标题匹配',
  };

  static String label(String source) => labels[source] ?? source;
}
