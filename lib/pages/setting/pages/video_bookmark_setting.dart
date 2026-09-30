import 'package:PiliPlus/controllers/video_bookmark_controller.dart';
import 'package:PiliPlus/pages/video_detail_v/view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VideoBookmarkSettingPage extends StatefulWidget {
  const VideoBookmarkSettingPage({super.key});
  @override State<VideoBookmarkSettingPage> createState() => _State();
}

class _State extends State<VideoBookmarkSettingPage> {
  late final VideoBookmarkController _ctrl;

  @override void initState() {
    super.initState();
    _ctrl = Get.put(VideoBookmarkController());
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频书签管理')),
      body: Obx(() => Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Icon(Icons.bookmark_outline, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('已保存 ${_ctrl.bookmarks.length} 个书签', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (_ctrl.bookmarks.isNotEmpty)
            TextButton(onPressed: _ctrl.clearAllBookmarks, child: const Text('清空全部')),
        ])),
        Expanded(child: _ctrl.bookmarks.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.bookmark_border, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('暂无书签', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
              const SizedBox(height: 8),
              Text('在视频播放页面点击书签图标即可添加', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ]))
          : ListView.separated(
              itemCount: _ctrl.bookmarks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final bm = _ctrl.bookmarks[index];
                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(bm.title ?? '未知视频'),
                  subtitle: Text('BV: ${bm.bvid ?? "?"} · ${bm.createdAt?.toString().substring(0, 16) ?? "?"}'),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _ctrl.deleteBookmark(bm)),
                  onTap: () => Get.to(() => const VideoDetailPageV(bvid: bm.bvid)),
                );
              },
            ),
        ),
      ])),
    );
  }
}
