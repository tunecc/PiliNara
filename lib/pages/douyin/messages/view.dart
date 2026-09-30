import 'package:PiliPlus/services/douyin/douyin_message_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DouyinMessagesPage extends StatefulWidget {
  const DouyinMessagesPage({super.key});
  @override State<DouyinMessagesPage> createState() => _DouyinMessagesPageState();
}

class _DouyinMessagesPageState extends State<DouyinMessagesPage> {
  final convs = <DouyinConversation>[].obs; final isLoading = false.obs;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { isLoading.value = true; convs.assignAll(await DouyinMessageService.getConversations()); isLoading.value = false; }

  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('抖音消息'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      body: Obx(() {
        if (isLoading.value) return const Center(child: CircularProgressIndicator());
        if (convs.isEmpty) return const Center(child: Text('暂无会话'));
        return RefreshIndicator(onRefresh: _load, child: ListView.separated(itemCount: convs.length, separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) { final c = convs[i]; return ListTile(
            leading: CircleAvatar(backgroundImage: c.peerAvatar.isNotEmpty ? NetworkImage(c.peerAvatar) : null, child: c.peerAvatar.isEmpty ? const Icon(Icons.person) : null),
            title: Text(c.peerName), subtitle: Text(c.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: c.unreadCount > 0 ? Badge(label: Text('${c.unreadCount}')) : null,
            onTap: () => Get.toNamed('/douyinChat', parameters: {'conversationId': c.id, 'peerName': c.peerName})); }));
      }));
  }
}
