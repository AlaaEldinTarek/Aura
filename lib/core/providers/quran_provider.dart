import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quran_models.dart';
import '../services/quran_data_service.dart';
import '../services/quran_reading_service.dart';
import 'task_provider.dart';

// ─── Data Providers ──────────────────────────────────────────────────

/// Surah metadata list (lightweight, fast load)
final quranSurahsMetaProvider = FutureProvider<List<QuranSurahMeta>>((ref) {
  return QuranDataService.instance.loadSurahsMeta();
});

/// Single surah content with all ayahs
final quranSurahProvider = FutureProvider.family<QuranSurah?, int>((ref, number) {
  return QuranDataService.instance.loadSurah(number);
});

/// Page content (ayahs on a specific page)
final quranPageProvider = FutureProvider.family<List<QuranAyah>, int>((ref, page) {
  return QuranDataService.instance.loadPage(page);
});

/// Page index (all 604 pages mapping)
final quranPageIndexProvider = FutureProvider<List<QuranPageIndex>>((ref) {
  return QuranDataService.instance.loadPageIndex();
});

// ─── Reading Progress ────────────────────────────────────────────────

/// Current reading progress
final quranReadingProgressProvider = StateNotifierProvider<QuranReadingNotifier, AsyncValue<QuranReadingProgress>>((ref) {
  return QuranReadingNotifier(ref);
});

class QuranReadingNotifier extends StateNotifier<AsyncValue<QuranReadingProgress>> {
  final Ref _ref;

  QuranReadingNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final userId = _ref.read(currentUserIdProvider);
      final progress = await QuranReadingService.instance.getProgress(userId);
      state = AsyncValue.data(progress);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markPageRead(int page) async {
    try {
      final userId = _ref.read(currentUserIdProvider);
      await QuranReadingService.instance.markPageRead(page, userId);
      await _loadProgress();
    } catch (e) {
      // Silently fail — reading tracking shouldn't block UI
    }
  }

  Future<void> markPagesRead(int fromPage, int toPage) async {
    try {
      final userId = _ref.read(currentUserIdProvider);
      await QuranReadingService.instance.markPagesRead(fromPage, toPage, userId);
      await _loadProgress();
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> refresh() async {
    await _loadProgress();
  }
}

// ─── Bookmarks ───────────────────────────────────────────────────────

/// User bookmarks stream
final quranBookmarksProvider = StreamProvider<List<QuranBookmark>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return QuranReadingService.instance.getBookmarksStream(userId);
});

// ─── Daily Logs ──────────────────────────────────────────────────────

/// Daily reading log for a specific date
final quranDailyLogProvider = FutureProvider.family<QuranDailyLog?, String>((ref, date) {
  final userId = ref.read(currentUserIdProvider);
  return QuranReadingService.instance.getDailyLog(userId, date);
});

/// Reading history for the past N days
final quranReadingHistoryProvider = FutureProvider<List<QuranDailyLog>>((ref) {
  final userId = ref.read(currentUserIdProvider);
  return QuranReadingService.instance.getReadingHistory(userId, days: 30);
});

// ─── Audio ───────────────────────────────────────────────────────────

/// Audio playback state
final quranAudioProvider = StateNotifierProvider<QuranAudioNotifier, QuranAudioInfo>((ref) {
  return QuranAudioNotifier();
});

class QuranAudioNotifier extends StateNotifier<QuranAudioInfo> {
  QuranAudioNotifier() : super(const QuranAudioInfo());

  void setReciter(String reciterId) {
    state = state.copyWith(reciterId: reciterId);
  }

  void setPlaying({required int surahNumber, required int totalAyahs, required int currentAyah}) {
    state = state.copyWith(
      state: QuranAudioState.playing,
      surahNumber: surahNumber,
      totalAyahs: totalAyahs,
      currentAyah: currentAyah,
    );
  }

  void setPaused() {
    state = state.copyWith(state: QuranAudioState.paused);
  }

  void setLoading() {
    state = state.copyWith(state: QuranAudioState.loading);
  }

  void setStopped() {
    state = state.copyWith(
      state: QuranAudioState.stopped,
      currentAyah: 0,
    );
  }

  void updateAyah(int currentAyah) {
    state = state.copyWith(currentAyah: currentAyah);
  }
}
