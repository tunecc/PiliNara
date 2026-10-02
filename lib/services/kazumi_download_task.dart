/// Download task model ported from Kazumi.
enum KazumiDownloadStatus { pending, downloading, completed, failed, paused }

class KazumiDownloadTask {
  final String id;
  final String url;
  final String title;
  final String episode;
  final String savePath;
  final KazumiDownloadStatus status;
  final double progress;
  final String? errorMessage;
  final DateTime createdAt;

  const KazumiDownloadTask({
    required this.id, required this.url, required this.title,
    required this.episode, required this.savePath,
    this.status = KazumiDownloadStatus.pending, this.progress = 0.0,
    this.errorMessage, DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  KazumiDownloadTask copyWith({KazumiDownloadStatus? status, double? progress, String? errorMessage}) {
    return KazumiDownloadTask(id: id, url: url, title: title, episode: episode, savePath: savePath,
      status: status ?? this.status, progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage, createdAt: createdAt);
  }
}
