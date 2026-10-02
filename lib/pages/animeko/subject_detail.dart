/// 番剧详情页 - 显示详情 + 剧集列表 + 评论 + 播放
import 'package:PiliPlus/http/bangumi.dart';
import 'package:PiliPlus/http/pgc.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/result.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AnimekoSubjectDetailPage extends StatefulWidget {
  final int seasonId;
  final String? bangumiSubjectId;

  const AnimekoSubjectDetailPage({
    super.key,
    required this.seasonId,
    this.bangumiSubjectId,
  });

  @override
  State<AnimekoSubjectDetailPage> createState() => _AnimekoSubjectDetailPageState();
}

class _AnimekoSubjectDetailPageState extends State<AnimekoSubjectDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PgcInfoModel? _pgcDetail;
  BangumiSubject? _bangumiDetail;
  List<BangumiComment> _comments = [];
  bool _isLoading = true;
  String? _error;
  final BangumiHttp _bangumi = BangumiHttp();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = null; });
    
    try {
      // 并行获取 B 站 PGC 数据和 Bangumi 数据
      final pgcFuture = _fetchPgcDetail();
      final bangumiFuture = widget.bangumiSubjectId != null 
          ? _bangumi.getSubject(int.parse(widget.bangumiSubjectId!))
          : Future.value(null);
      final commentsFuture = widget.bangumiSubjectId != null
          ? _bangumi.getComments(int.parse(widget.bangumiSubjectId!))
          : Future.value(<BangumiComment>[]);
      
      await Future.wait([pgcFuture, bangumiFuture, commentsFuture]);
      
      setState(() {
        _pgcDetail = pgcFuture.result;
        _bangumiDetail = bangumiFuture.result;
        _comments = commentsFuture.result ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<PgcInfoModel?> _fetchPgcDetail() async {
    try {
      // TODO: 调用正确的 PGC 详情 API
      // 目前使用占位数据
      return null;
    } catch (e) {
      return null;
    }
  }

  void _playEpisode(int epId) {
    if (widget.seasonId > 0 && epId > 0) {
      PageUtils.viewPgc(seasonId: widget.seasonId, epId: epId);
    }
  }

  Future<void> _postComment(String content) async {
    if (widget.bangumiSubjectId == null) return;
    
    final success = await _bangumi.postComment(
      subjectId: int.parse(widget.bangumiSubjectId!),
      content: content,
    );
    
    if (success && mounted) {
      Get.back();
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('番剧详情'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '详情'),
            Tab(text: '剧集'),
            Tab(text: '评论'),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _error != null ? _buildErrorView() : _buildTabContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchData, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDetailTab(),
        _buildEpisodeTab(),
        _buildCommentTab(),
      ],
    );
  }

  Widget _buildDetailTab() {
    final detail = _bangumiDetail ?? _pgcDetail;
    if (detail == null) {
      return const Center(child: Text('暂无详情'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(detail),
        const SizedBox(height: 16),
        if ((detail.evaluate?.isNotEmpty ?? false) || (detail.rating?.score != null)) ...[
          _buildSection('评分', detail.rating?.score != null ? '${detail.rating!.score}' : '暂无'),
          const SizedBox(height: 16),
          _buildSection('简介', detail.evaluate ?? '暂无简介'),
        ],
      ],
    );
  }

  Widget _buildHeader(dynamic detail) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            detail.cover ?? '',
            width: 120,
            height: 160,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 120,
              height: 160,
              color: Colors.grey[300],
              child: const Icon(Icons.movie),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.title ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (detail.seasonTitle?.isNotEmpty ?? false)
                Text(detail.seasonTitle!, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              if (detail.rating?.score != null)
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text('${detail.rating!.score}'),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(content),
      ],
    );
  }

  Widget _buildEpisodeTab() {
    final episodes = _bangumiDetail?.episodes ?? _pgcDetail?.episodes;
    if ((episodes?.isEmpty ?? true)) {
      return const Center(child: Text('暂无剧集'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: episodes!.length,
      itemBuilder: (context, index) {
        final ep = episodes[index];
        final epId = ep is EpisodeItem ? (ep.epId ?? ep.id ?? 0) : (ep as dynamic).epId ?? 0;
        return ListTile(
          title: Text(ep is EpisodeItem ? (ep.title ?? '第${ep.id}集') : '第${ep.num}集'),
          subtitle: Text(ep is EpisodeItem ? (ep.longTitle ?? '') : (ep.nameCN ?? ep.name)),
          trailing: ElevatedButton(
            onPressed: () => _playEpisode(epId),
            child: const Text('播放'),
          ),
        );
      },
    );
  }

  Widget _buildCommentTab() {
    if (_comments.isEmpty) {
      return const Center(child: Text('暂无评论'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(comment.username),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.content),
                const SizedBox(height: 4),
                Text(
                  '${comment.createdAt.toLocaleDateString()} · ${comment.likes} 点赞',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
