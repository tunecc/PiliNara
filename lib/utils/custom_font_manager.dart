import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:PiliPlus/utils/storage.dart';

/// Manages custom font files: import, remove, list, and apply.
/// Ported from ekmope/PiliMax.
class CustomFontManager {
  static const _fontDir = 'custom_fonts';
  static const _storageKey = 'custom_font_list';

  static Future<Directory> getFontDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final fontDir = Directory('${appDir.path}/$_fontDir');
    if (!await fontDir.exists()) {
      await fontDir.create(recursive: true);
    }
    return fontDir;
  }

  static Future<bool> importFont(String filePath, String fontName) async {
    try {
      final dir = await getFontDirectory();
      final destFile = File('${dir.path}/$fontName');
      await File(filePath).copy(destFile.path);
      final fonts = await listFonts();
      if (!fonts.contains(fontName)) {
        fonts.add(fontName);
        await GStorage.setting.put(_storageKey, fonts);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeFont(String fontName) async {
    try {
      final dir = await getFontDirectory();
      final file = File('${dir.path}/$fontName');
      if (await file.exists()) await file.delete();
      final fonts = await listFonts();
      fonts.remove(fontName);
      await GStorage.setting.put(_storageKey, fonts);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<String>> listFonts() async {
    try {
      return (GStorage.setting.get(_storageKey) as List?)?.cast<String>() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> loadFont(String fontName) async {
    try {
      final dir = await getFontDirectory();
      final file = File('${dir.path}/$fontName');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final loader = FontLoader(fontName);
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
        await loader.load();
      }
    } catch (_) {}
  }
}
