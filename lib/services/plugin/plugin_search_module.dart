/// Per-plugin search progress, written solely by PluginSearchService.
enum PluginSearchStatus { pending, success, error, noResult, captcha }

class SearchItem {
  String name;
  String src;

  SearchItem({required this.name, required this.src});

  factory SearchItem.fromJson(Map<String, dynamic> json) {
    return SearchItem(name: json['name'] as String?, src: json['src'] as String? ?? '');
  }
}

class PluginSearchResponse {
  String pluginName;
  List<SearchItem> data;

  PluginSearchResponse({required this.pluginName, required this.data});

  factory PluginSearchResponse.fromJson(Map<String, dynamic> json) {
    return PluginSearchResponse(
      pluginName: json['pluginName'] as String? ?? '',
      data: (json['data'] as List?)
              ?.map((e) => SearchItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
