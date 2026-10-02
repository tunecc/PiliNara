/// 视频播放器页面
/// 使用 PiliNara 内置播放器播放 HTTP 流
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/data_source.dart';
import 'package:PiliPlus/plugin/pl_player/view/view.dart';
import 'package:flutter/material.dart';

class AnimekoVideoPlayerPage extends StatefulWidget {
  final String url;
  final String title;
  final String? userAgent;

  const AnimekoVideoPlayerPage({
    super.key,
    required this.url,
    required this.title,
    this.userAgent,
  });

  @override
  State<AnimekoVideoPlayerPage> createState() => _AnimekoVideoPlayerPageState();
}

class _AnimekoVideoPlayerPageState extends State<AnimekoVideoPlayerPage> {
  late final PlPlayerController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = PlPlayerController.getInstance();
    _loadVideo();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadVideo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dataSource = NetworkSource(
        videoSource: widget.url,
        audioSource: null,
      );

      await _controller.setDataSource(
        dataSource,
        isVertical: false,
      );

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadVideo, child: const Text('重试')),
                    ],
                  ),
                )
              : PlPlayerView(controller: _controller),
    );
  }
}
