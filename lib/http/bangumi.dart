import 'package:PiliPlus/models/bangumi/calendar_item.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:dio/dio.dart';

/// Minimal client for the bangumi.tv (bgm.tv) public API.
abstract final class BangumiHttp {
  static const _base = 'https://api.bgm.tv';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'PiliNara/1.0 (Flutter)',
        'Accept': 'application/json',
      },
    ),
  );

  /// Currently airing anime for the given weekday.
  ///
  /// [weekday] follows the JS convention: 1 = Monday ... 7 = Sunday.
  static Future<List<BangumiCalendarItem>> calendar() async {
    try {
      final res = await _dio.get<List<dynamic>>('/calendar');
      final data = res.data;
      if (data == null) return const [];
      final items = <BangumiCalendarItem>[];
      for (final day in data) {
        if (day is! Map) continue;
        final weekday = day['weekday'];
        final weekdayId = weekday is Map ? weekday['id'] as int? : null;
        final subjects = day['items'];
        if (subjects is! List) continue;
        for (final item in subjects) {
          if (item is! Map) continue;
          items.add(
            BangumiCalendarItem.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
              weekdayId: weekdayId,
            ),
          );
        }
      }
      return items;
    } catch (e) {
      logger.e('bangumi calendar failed: $e');
      return const [];
    }
  }
}
