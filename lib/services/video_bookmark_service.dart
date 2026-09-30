import 'package:PiliPlus/models/video_bookmark.dart';

abstract final class VideoBookmarkService {
  static List<VideoBookmark> getBookmarksForVideo(String bvid) => [];
  static List<VideoBookmark> getBookmarksSorted({
    SortType sortType = SortType.mostRecent,
    String? bvidFilter,
    int? authorMidFilter,
    String searchQuery = '',
  }) => [];
  static Future<VideoBookmark?> addBookmark({
    required String bvid,
    required String videoTitle,
    int? authorMid,
    required int timestampSeconds,
    String? name,
    String? note,
  }) async => null;
  static Future<void> updateBookmark(VideoBookmark bookmark) async {}
  static Future<void> deleteBookmark(String id) async {}
  static bool canAddBookmark(String bvid) => true;
  static int getBookmarkCountForVideo(String bvid) => 0;
  static List<int> getAuthorMids() => [];
  static String exportAllBookmarks() => '[]';
  static Future<int> importBookmarks(String jsonString) async => 0;
  static Future<void> clearAllBookmarks() async {}
}
