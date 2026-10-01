import 'package:PiliPlus/services/douyin/douyin_video_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class DouyinPlayerPage extends StatefulWidget {
  final String videoId; const DouyinPlayerPage({super.key, required this.videoId});
  @override State<DouyinPlayerPage> createState() => _DouyinPlayerPageState();
}

class _DouyinPlayerPageState extends State<DouyinPlayerPage> {
  late final Player _player; late final VideoController _vc;
  DouyinVideoDetail? _detail; bool _loading = true;

  @override void initState() { super.initState(); _player = Player(); _vc = VideoController(_player); _load(); }

  Future<void> _load() async {
    final d = await DouyinVideoService.getVideoDetail(widget.videoId);
    if (d != null && d.playUrl.isNotEmpty) { setState(() { _detail = d; _loading = false; }); await _player.open(Media(d.playUrl)); await _player.play(); }
    else setState(() { _loading = false; });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(_detail?.authorName ?? '抖音播放')),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _detail == null ? const Center(child: Text('无法加载视频'))
        : Column(children: [
            AspectRatio(aspectRatio: 16 / 9, child: Video(controller: _vc)),
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_detail!.desc, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 12),
              Row(children: [if (_detail!.authorAvatar.isNotEmpty) CircleAvatar(radius: 16, backgroundImage: NetworkImage(_detail!.authorAvatar)),
                const SizedBox(width: 8), Expanded(child: Text(_detail!.authorName, style: Theme.of(context).textTheme.titleSmall)),
                IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}), Text('${_detail!.diggCount}'),
                const SizedBox(width: 12), IconButton(icon: const Icon(Icons.comment_outlined), onPressed: () {}), Text('${_detail!.commentCount}')]),
            ]))),
          ]));
  }
  @override void dispose() { _player.dispose(); super.dispose(); }
}
