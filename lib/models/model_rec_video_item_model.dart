class BaseRcmdVideoItemModel {
  final String bvid;
  final String title;
  final String pic;
  final String author;
  final int play;
  final int danmaku;

  const BaseRcmdVideoItemModel({
    this.bvid = '',
    this.title = '',
    this.pic = '',
    this.author = '',
    this.play = 0,
    this.danmaku = 0,
  });

  factory BaseRcmdVideoItemModel.fromJson(Map<String, dynamic> json) {
    return BaseRcmdVideoItemModel(
      bvid: json['bvid'] ?? '',
      title: json['title'] ?? '',
      pic: json['pic'] ?? '',
      author: json['author'] ?? '',
      play: json['play'] ?? 0,
      danmaku: json['danmaku'] ?? 0,
    );
  }
}
