import 'package:PiliPlus/services/douyin/douyin_video_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DouyinFeedPage extends StatefulWidget {
  const DouyinFeedPage({super.key});
  @override State<DouyinFeedPage> createState() => _DouyinFeedPageState();
}

class _DouyinFeedPageState extends State<DouyinFeedPage> {
  final videos = <DouyinVideoDetail>[].obs; final isLoading = false.obs;
  final _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); loadFeed(); }

  Future<void> loadFeed() async { isLoading.value = true; videos.assignAll(await DouyinVideoService.getRecommendFeed()); isLoading.value = false; }
  Future<void> search(String kw) async { if (kw.trim().isEmpty) return; isLoading.value = true; videos.assignAll(await DouyinVideoService.searchVideos(kw)); isLoading.value = false; }

  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('抖音'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: loadFeed)]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: SearchBar(controller: _searchCtrl, hintText: '搜索抖音视频...', onSubmitted: search,
          trailing: [IconButton(icon: const Icon(Icons.search), onPressed: () => search(_searchCtrl.text))])),
        Expanded(child: Obx(() {
          if (isLoading.value) return const Center(child: CircularProgressIndicator());
          if (videos.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.videocam_off_outlined, size: 48), const SizedBox(height: 12), TextButton(onPressed: loadFeed, child: const Text('刷新'))]));
          return RefreshIndicator(onRefresh: loadFeed, child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: videos.length,
            itemBuilder: (_, i) => _VideoCard(video: videos[i])));
        })),
      ]));
  }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }
}

class _VideoCard extends StatelessWidget {
  final DouyinVideoDetail video; const _VideoCard({required this.video});
  @override Widget build(BuildContext context) {
    return Card(margin: const EdgeInsets.only(bottom: 12), clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: () => Get.toNamed('/douyinPlayer', parameters: {'id': video.id}), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(aspectRatio: 16 / 9, child: Stack(fit: StackFit.expand, children: [
          if (video.coverUrl.isNotEmpty) Image.network(video.coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[800])),
          Positioned(right: 8, bottom: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
            child: Text(_fmtDur(video.durationMs), style: const TextStyle(color: Colors.white, fontSize: 11)))),
        ])),
        Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(video.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Row(children: [if (video.authorAvatar.isNotEmpty) CircleAvatar(radius: 10, backgroundImage: NetworkImage(video.authorAvatar)),
            const SizedBox(width: 6), Expanded(child: Text(video.authorName, style: Theme.of(context).textTheme.bodySmall)),
            Text('${_fmtCnt(video.diggCount)} ❤️', style: Theme.of(context).textTheme.labelSmall)]),
        ])),
      ])));
  }
  String _fmtDur(int ms) { final s = ms ~/ 1000; return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'; }
  String _fmtCnt(int c) => c >= 10000 ? '${(c / 10000).toStringAsFixed(1)}万' : c.toString();
}
