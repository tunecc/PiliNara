class BangumiCalendarItem {
  const BangumiCalendarItem({
    required this.id,
    required this.name,
    this.nameCn = '',
    this.image = '',
    this.airDate = '',
    this.rating,
    this.collectionCount,
    this.weekdayId,
    this.url = '',
  });

  final int id;
  final String name;
  final String nameCn;
  final String image;
  final String airDate;
  final double? rating;
  final int? collectionCount;
  final int? weekdayId;
  final String url;

  String get displayName => nameCn.isNotEmpty ? nameCn : name;

  factory BangumiCalendarItem.fromJson(
    Map<String, dynamic> json, {
    int? weekdayId,
  }) {
    final images = json['images'];
    final rating = json['rating'];
    final collection = json['collection'];
    return BangumiCalendarItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      nameCn: json['name_cn'] as String? ?? '',
      image: images is Map ? images['large'] as String? ?? '' : '',
      airDate: json['air_date'] as String? ?? '',
      rating: rating is Map ? (rating['score'] as num?)?.toDouble() : null,
      collectionCount: collection is Map
          ? (collection['doing'] as num?)?.toInt()
          : null,
      weekdayId: weekdayId,
      url: json['url'] as String? ?? '',
    );
  }
}
