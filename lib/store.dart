// store.dart -- локальное хранение: обычные JSON-файлы в каталоге приложения.
// Никаких серверов и аккаунтов: настройки, история и события лежат рядом
// с приложением (Android -- app data, Windows -- %APPDATA%).
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalStore {
  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    return base;
  }

  Future<File> _file(String name) async {
    final d = await _dir();
    return File('${d.path}${Platform.pathSeparator}$name');
  }

  Future<Map<String, dynamic>?> read(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      final text = await f.readAsString();
      final parsed = jsonDecode(text);
      return parsed is Map<String, dynamic> ? parsed : null;
    } catch (_) {
      // битый файл не должен ломать приложение -- начинаем с чистого
      return null;
    }
  }

  Future<void> write(String name, Map<String, dynamic> data) async {
    try {
      final f = await _file(name);
      await f.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // нет места на диске / доступ запрещён -- переживаем без сохранения
    }
  }

  Future<void> delete(String name) async {
    try {
      final f = await _file(name);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // не критично
    }
  }
}
