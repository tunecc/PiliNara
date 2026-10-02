/// TVBox/CloudStream3 源解析器
/// 支持 JSON 格式的数据源配置
import 'package:dio/dio.dart';

class TVBoxSource {
  final String name;
  final String url;
  final String? api;
  final List<TVBoxChannel>? channels;
  final Map<String, dynamic>? settings;

  const TVBoxSource({
    required this.name,
    required this.url,
    this.api,
    this.channels,
    this.settings,
  });

  factory TVBoxSource.fromJson(Map<String, dynamic> json) {
    return TVBoxSource(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      api: json['api'],
      channels: (json['channels'] as List?)?.map((e) => TVBoxChannel.fromJson(e)).toList(),
      settings: json['settings']?.cast<String, String>(),
    );
  }
}

class TVBoxChannel {
  final String name;
  final String url;
  final String? type;
  final int? playUrl;

  const TVBoxChannel({
    required this.name,
    required this.url,
    this.type,
    this.playUrl,
  });

  factory TVBoxChannel.fromJson(Map<String, dynamic> json) {
    return TVBoxChannel(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      type: json['type']?.toString(),
      playUrl: json['playUrl'],
    );
  }
}

class TVBoxHttp {
  final Dio dio;
  TVBoxHttp({Dio? dio}) : dio = dio ?? Dio();

  /// 加载 TVBox 源列表
  Future<List<TVBoxSource>> loadSources(String repoUrl) async {
    try {
      final resp = await dio.get(repoUrl);
      if (resp.data case List sources) {
        return sources.map((e) => TVBoxSource.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      print('[TVBox] Load sources error: $e');
    }
    return [];
  }

  /// 解析单个源的配置
  Future<TVBoxSource?> parseSource(String sourceUrl) async {
    try {
      final resp = await dio.get(sourceUrl);
      if (resp.data is Map) {
        return TVBoxSource.fromJson(resp.data as Map<String, dynamic>);
      }
    } catch (e) {
      print('[TVBox] Parse source error: $e');
    }
    return null;
  }
}
