import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quran_models.dart';
import '../services/quran_data_service.dart';

class QuranAudioService {
  QuranAudioService._();
  static final QuranAudioService instance = QuranAudioService._();

  final AudioPlayer _player = AudioPlayer();
  final Dio _dio = Dio();

  String _currentReciter = 'ar.mahermuaiqly';
  int _currentSurah = 0;
  int _currentAyahIndex = 0;
  List<int> _ayahNumbers = [];
  bool _isPlaying = false;
  bool _isStreaming = true;

  String get currentReciter => _currentReciter;
  bool get isPlaying => _isPlaying;
  int get currentAyahIndex => _currentAyahIndex;

  static const String _cdnBase = 'https://cdn.islamic.network/quran/audio/128';

  Future<void> initialize() async {
    _player.onPlayerComplete.listen((_) {
      _onAyahComplete();
    });

    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
    });

    debugPrint('✅ [QURAN_AUDIO] Initialized');
  }

  /// Play a full surah
  Future<void> playSurah(String reciterId, int surahNumber) async {
    _currentReciter = reciterId;
    _currentSurah = surahNumber;
    _currentAyahIndex = 0;

    final surah = await QuranDataService.instance.loadSurah(surahNumber);
    if (surah == null) return;

    _ayahNumbers = surah.ayahs.map((a) => a.number).toList();

    // Check if surah is downloaded
    _isStreaming = !await isSurahDownloaded(reciterId, surahNumber);

    await _playCurrentAyah();
  }

  /// Play a specific ayah
  Future<void> _playCurrentAyah() async {
    if (_currentAyahIndex >= _ayahNumbers.length) {
      _isPlaying = false;
      return;
    }

    final ayahNumber = _ayahNumbers[_currentAyahIndex];
    String audioPath;

    if (_isStreaming) {
      audioPath = '$_cdnBase/$_currentReciter/$ayahNumber.mp3';
    } else {
      final dir = await _getSurahDir(_currentReciter, _currentSurah);
      audioPath = '${dir.path}/$ayahNumber.mp3';
      final file = File(audioPath);
      if (!await file.exists()) {
        // Fallback to streaming if file missing
        audioPath = '$_cdnBase/$_currentReciter/$ayahNumber.mp3';
      }
    }

    try {
      await _player.play(UrlSource(audioPath));
      _isPlaying = true;
    } catch (e) {
      debugPrint('❌ [QURAN_AUDIO] Failed to play ayah $ayahNumber: $e');
    }
  }

  void _onAyahComplete() {
    _currentAyahIndex++;
    if (_currentAyahIndex < _ayahNumbers.length) {
      _playCurrentAyah();
    } else {
      _isPlaying = false;
      _currentAyahIndex = 0;
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
  }

  Future<void> resume() async {
    await _player.resume();
    _isPlaying = true;
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    _currentAyahIndex = 0;
  }

  Future<void> skipNext() async {
    if (_currentAyahIndex < _ayahNumbers.length - 1) {
      await _player.stop();
      _currentAyahIndex++;
      await _playCurrentAyah();
    }
  }

  Future<void> skipPrevious() async {
    if (_currentAyahIndex > 0) {
      await _player.stop();
      _currentAyahIndex--;
      await _playCurrentAyah();
    }
  }

  // ─── Download Management ────────────────────────────────────────────

  Future<Directory> _getSurahDir(String reciterId, int surahNumber) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/quran_audio/$reciterId/surah_$surahNumber');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<bool> isSurahDownloaded(String reciterId, int surahNumber) async {
    final dir = await _getSurahDir(reciterId, surahNumber);
    final surah = await QuranDataService.instance.loadSurah(surahNumber);
    if (surah == null) return false;

    for (final ayah in surah.ayahs) {
      final file = File('${dir.path}/${ayah.number}.mp3');
      if (!await file.exists()) return false;
    }
    return true;
  }

  Future<void> downloadSurah(String reciterId, int surahNumber, {Function(double)? onProgress}) async {
    final surah = await QuranDataService.instance.loadSurah(surahNumber);
    if (surah == null) return;

    final dir = await _getSurahDir(reciterId, surahNumber);
    final totalAyahs = surah.ayahs.length;

    for (var i = 0; i < totalAyahs; i++) {
      final ayah = surah.ayahs[i];
      final url = '$_cdnBase/$reciterId/${ayah.number}.mp3';
      final savePath = '${dir.path}/${ayah.number}.mp3';

      final file = File(savePath);
      if (await file.exists()) {
        onProgress?.call((i + 1) / totalAyahs);
        continue;
      }

      await _dio.download(url, savePath);
      onProgress?.call((i + 1) / totalAyahs);
    }
  }

  Future<void> deleteSurah(String reciterId, int surahNumber) async {
    final dir = await _getSurahDir(reciterId, surahNumber);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<List<Map<String, dynamic>>> getDownloadedSurahs() async {
    final appDir = await getApplicationDocumentsDirectory();
    final quranDir = Directory('${appDir.path}/quran_audio');
    if (!await quranDir.exists()) return [];

    final List<Map<String, dynamic>> downloaded = [];
    await for (final reciterDir in quranDir.list()) {
      if (reciterDir is Directory) {
        final reciterId = reciterDir.path.split('/').last;
        await for (final surahDir in reciterDir.list()) {
          if (surahDir is Directory) {
            final surahStr = surahDir.path.split('surah_').last;
            final surahNum = int.tryParse(surahStr);
            if (surahNum != null) {
              downloaded.add({
                'reciterId': reciterId,
                'surahNumber': surahNum,
              });
            }
          }
        }
      }
    }
    return downloaded;
  }

  Future<void> setReciter(String reciterId) async {
    _currentReciter = reciterId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quran_reciter', reciterId);
  }

  Future<String> getSavedReciter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('quran_reciter') ?? 'ar.mahermuaiqly';
  }

  void debugPrint(String message) {
    print(message);
  }
}
