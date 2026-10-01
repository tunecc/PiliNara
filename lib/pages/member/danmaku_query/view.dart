import 'package:PiliPlus/http/member_query.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class MemberDanmakuQueryPage extends StatefulWidget {
  const MemberDanmakuQueryPage({super.key, required this.mid});
  final int mid;

  @override
  State<MemberDanmakuQueryPage> createState() => _MemberDanmakuQueryPageState();
}

class _MemberDanmakuQueryPageState extends State<MemberDanmakuQueryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  late final RxnString _error = RxnString();
  late final RxBool _loading = false.obs;
  final RxList<Map<String, dynamic>> _comments = <Map<String, dynamic>>[].obs;
  int _commentPage = 0;
  bool _commentHasMore = false;
  final RxList<dynamic> _danmakus = <dynamic>[].obs;
  int _danmakuPage = 0;
  bool _danmakuHasMore = false;

  @override
  void initState() {
    super.initState();
    _tab.addListener(_onTabChanged);
    _loadComments();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tab.indexIsChanging) return;
    if (_tab.index == 1 && _danmakus.isEmpty) _loadDanmaku();
  }

  Future<void> _loadComments({bool reset = false}) async {
    if (reset) _commentPage = 0;
    if (!reset && !_commentHasMore) return;
    setState(() => _loading.value = true);
    _error.value = null;
    final res = await MemberQueryHttp.memberComments(
      mid: widget.mid,
      page: _commentPage + 1,
    );
    if (!mounted) return;
    if (res case Success(:final data)) {
      final list = (data['list'] as List?) ?? [];
      final hasMore = (data['has_more'] as num?)?.toInt() ?? false;
      if (reset) _comments.assignAll(list.map((e) => e as Map<String, dynamic>));
      else _comments.addAll(list.map((e) => e as Map<String, dynamic>));
      _commentHasMore = hasMore;
    } else if (res case Error(:final msg?)) {
      _error.value = msg;
    }
    setState(() => _loading.value = false);
  }

  Future<void> _loadDanmaku({bool reset = false}) async {
    if (reset) _danmakuPage = 0;
    if (!reset && !_danmakuHasMore) return;
    setState(() => _loading.value = true);
    _error.value = null;
    final res = await MemberQueryHttp.memberDanmaku(
      uid: widget.mid,
      page: _danmakuPage + 1,
    );
    if (!mounted) return;
    if (res case Success(:final data)) {
      final list = data as List;
      _danmakus.assignAll(list);
      _danmakuHasMore = list.length >= 20;
    } else if (res case Error(:final msg?)) {
      _error.value = msg;
    }
    setState(() => _loading.value = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('评论与弹幕查询 · UID:${widget.mid}'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: '评论'), Tab(text: '弹幕')],
          indicatorColor: Theme.of(context).colorScheme.primary,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_buildCommentTab(), _buildDanmakuTab()],
            ),
          ),
          if (_loading.value)
            LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildCommentTab() {
    final error = _error.value;
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error),
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: _loadComments, child: const Text('重试')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadComments(reset: true),
      child: Obx(
        () => ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: _comments.length + (_loading.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _comments.length) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            final c = _comments[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(c['content']?['message'] ?? c['content'] ?? '无内容'),
                subtitle: Text(c['ctime'] != null ? '时间: ${c['ctime']}' : ''),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDanmakuTab() {
    final error = _error.value;
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error),
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: _loadDanmaku, child: const Text('重试')),
          ],
        ),
      );
    }
    return Obx(
      () => ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _danmakus.length,
        itemBuilder: (context, index) {
          final d = _danmakus[index];
          if (d is Map) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(d['content'] ?? '无内容'),
                subtitle: Text(d['date']?.toString() ?? ''),
              ),
            );
          }
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(title: Text('$d')),
          );
        },
      ),
    );
  }
}
