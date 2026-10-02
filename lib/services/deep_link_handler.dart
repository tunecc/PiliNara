import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:PiliPlus/pages/plugin_manager/view.dart';
import 'package:PiliPlus/services/plugin/plugin_import_parser.dart';
import 'package:PiliPlus/services/plugin/plugin_storage.dart';
import 'package:PiliPlus/utils/rule_encoding.dart';

/// Handles deep links like `pilinara://import?url=...` or `animeko://import?url=...`
/// to import KazumiRules without leaving the app.
class DeepLinkHandler {
  DeepLinkHandler() {
    _init();
  }

  void _init() {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen(_handleUri).onError((_) {});
  }

  Future<void> _handleUri(Uri uri) async {
    debugPrint('[DeepLink] received: ${uri.toString()}');
    final scheme = uri.scheme.toLowerCase();
    // Support both pilinara:// and animeko:// (compatible with Animeko URL scheme)
    if (scheme != 'pilinara' && scheme != 'animeko') return;
    final url = uri.queryParameters['url'];
    if (url == null || url.isEmpty) return;
    try {
      final resp = await Dio().get(url);
      final data = resp.data;
      if (data is String) {
        final result = PluginImportParser.parse(data);
        for (final p in result.plugins) {
          final list = PluginStorage.load();
          final key = p.name.toLowerCase();
          final idx = list.indexWhere((e) => e.name.toLowerCase() == key);
          if (idx >= 0) {
            list[idx] = p;
          } else {
            list.add(p);
          }
        }
        PluginStorage.save(list);
        if (Get.currentRoute != '/pluginManager') {
          Get.toNamed('/pluginManager');
        }
        if (Get.context != null) {
          ScaffoldMessenger.of(Get.context!).showSnackBar(
            SnackBar(content: Text('已导入 ${result.plugins.length} 条规则')),
          );
        }
      }
    } catch (e) {
      debugPrint('[DeepLink] import failed: $e');
    }
  }
}
