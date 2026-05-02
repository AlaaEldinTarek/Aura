import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class QuranSvgService {
  static const _base =
      'https://cdn.jsdelivr.net/gh/AlaaEldinTarek/aura-adhans/mushafs/hafs/svg';

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
  ));

  // Dedup: avoid downloading the same page twice concurrently.
  static final Map<int, Future<File>> _inflight = {};

  static String _name(int page) => '${page.toString().padLeft(3, '0')}.svg';

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/quran_pages');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> getPage(int page) {
    if (_inflight.containsKey(page)) return _inflight[page]!;
    final future = _fetchPage(page);
    _inflight[page] = future;
    future.whenComplete(() => _inflight.remove(page));
    return future;
  }

  static Future<File> _fetchPage(int page) async {
    final dir = await _dir();
    final file = File('${dir.path}/${_name(page)}');
    if (await file.exists()) return file;

    try {
      await _dio.download('$_base/${_name(page)}', file.path);
      return file;
    } catch (e) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  static void preload(int page) {
    if (page >= 1 && page <= 604) getPage(page);
  }

  static bool isNetworkError(Object error) {
    if (error is! DioException) return false;
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
  }
}
