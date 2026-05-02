import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/adhan_player_service.dart';
import '../../core/services/prayer_alarm_service.dart';

/// Adhan Reciter Model
class AdhanReciter {
  final String id;
  final String name;
  final String nameAr;
  final String description;
  final String descriptionAr;
  final String url;
  final String fileName;
  final String imageUrl;
  final double fileSize; // in MB

  AdhanReciter({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.description,
    required this.descriptionAr,
    required this.url,
    required this.fileName,
    required this.imageUrl,
    required this.fileSize,
  });
}

/// Available Adhan Reciters
/// Using GitHub CDN (jsDelivr) for fast downloads
/// Files hosted at: https://github.com/AlaaEldinTarek/aura-adhans
/// Note: Default adhan is built into the app - use Reset button to restore it
final List<AdhanReciter> availableAdhans = [
  AdhanReciter(
    id: 'alafasy',
    name: 'Mishary Alafasy',
    nameAr: 'مشاري العفاسي',
    description: 'Beautiful and clear recitation',
    descriptionAr: 'تلاوة جميلة وواضحة',
    url: 'https://cdn.jsdelivr.net/gh/AlaaEldinTarek/aura-adhans@main/adhan_alafasy.mp3',
    fileName: 'adhan_alafasy.mp3',
    imageUrl: 'https://img.icons8.com/color/96/mosque.png',
    fileSize: 0.7,
  ),
  AdhanReciter(
    id: 'sudais',
    name: 'Abdul Rahman Al-Sudais',
    nameAr: 'عبدالرحمن السديس',
    description: 'Imam of Grand Mosque, Mecca',
    descriptionAr: 'إمام الحرم المكي',
    url: 'https://cdn.jsdelivr.net/gh/AlaaEldinTarek/aura-adhans@main/adhan_sudais.mp3',
    fileName: 'adhan_sudais.mp3',
    imageUrl: 'https://img.icons8.com/color/96/mosque.png',
    fileSize: 0.8,
  ),
  AdhanReciter(
    id: 'abdulbasit1',
    name: 'Abdul Basit - Version 1',
    nameAr: 'عبدالباسط عبدالصمد - الإصدار 1',
    description: 'Classic Egyptian style',
    descriptionAr: 'الطراز المصري الكلاسيكي',
    url: 'https://cdn.jsdelivr.net/gh/AlaaEldinTarek/aura-adhans@main/adhan_abdulbasit1.mp3',
    fileName: 'adhan_abdulbasit1.mp3',
    imageUrl: 'https://img.icons8.com/color/96/mosque.png',
    fileSize: 1.0,
  ),
  AdhanReciter(
    id: 'abdulbasit2',
    name: 'Abdul Basit - Version 2',
    nameAr: 'عبدالباسط عبدالصمد - الإصدار 2',
    description: 'Alternative recitation style',
    descriptionAr: 'أسلوب تلاوة بديل',
    url: 'https://cdn.jsdelivr.net/gh/AlaaEldinTarek/aura-adhans@main/adhan_abdulbasit2.mp3',
    fileName: 'adhan_abdulbasit2.mp3',
    imageUrl: 'https://img.icons8.com/color/96/mosque.png',
    fileSize: 1.1,
  ),
  AdhanReciter(
    id: 'abdulbasit3',
    name: 'Abdul Basit - Version 3',
    nameAr: 'عبدالباسط عبدالصمد - الإصدار 3',
    description: 'Another beautiful variation',
    descriptionAr: 'تلاوة جميلة أخرى',
    url: 'https://cdn.jsdelivr.net/gh/AlaaEldinTarek/aura-adhans@main/adhan_abdulbasit3.mp3',
    fileName: 'adhan_abdulbasit3.mp3',
    imageUrl: 'https://img.icons8.com/color/96/mosque.png',
    fileSize: 1.2,
  ),
];

/// Provider for download state
final downloadProvider = StateNotifierProvider<DownloadNotifier, Map<String, DownloadInfo>>((ref) {
  return DownloadNotifier();
});

/// Provider for selected adhan
final selectedAdhanProvider = StateProvider<String?>((ref) {
  return null;
});

/// Provider for currently playing adhan (for stop button)
final playingAdhanProvider = StateProvider<String?>((ref) {
  return null;
});

enum DownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  error,
}

class DownloadInfo {
  final DownloadStatus status;
  final double progress;
  final String? error;

  DownloadInfo({
    required this.status,
    this.progress = 0.0,
    this.error,
  });
}

class DownloadNotifier extends StateNotifier<Map<String, DownloadInfo>> {
  DownloadNotifier() : super({});

  Future<void> downloadAdhan(AdhanReciter reciter, Function(double) onProgress) async {
    debugPrint('🔥 [ADHAN DOWNLOAD] Starting download for ${reciter.name}');
    debugPrint('🔥 [ADHAN DOWNLOAD] URL: ${reciter.url}');
    debugPrint('🔥 [ADHAN DOWNLOAD] Filename: ${reciter.fileName}');

    final current = Map<String, DownloadInfo>.from(state);
    current[reciter.id] = DownloadInfo(status: DownloadStatus.downloading, progress: 0.0);
    state = current;

    try {
      // Get app documents directory and create adhan subdirectory
      debugPrint('🔥 [ADHAN DOWNLOAD] Getting app directory...');
      final appDir = await getApplicationDocumentsDirectory();
      final adhanDir = Directory('${appDir.path}/adhans');

      // Create directory if it doesn't exist
      if (!await adhanDir.exists()) {
        debugPrint('🔥 [ADHAN DOWNLOAD] Creating adhan directory...');
        await adhanDir.create(recursive: true);
      }

      debugPrint('🔥 [ADHAN DOWNLOAD] Adhan directory: ${adhanDir.path}');
      final filePath = '${adhanDir.path}/${reciter.fileName}';
      debugPrint('🔥 [ADHAN DOWNLOAD] Full file path: $filePath');

      // Check if file already exists
      final file = File(filePath);
      if (await file.exists()) {
        debugPrint('🔥 [ADHAN DOWNLOAD] File already exists, deleting old file...');
        await file.delete();
      }

      // Download file with timeout and better error handling
      debugPrint('🔥 [ADHAN DOWNLOAD] Starting dio download...');
      final dio = Dio();
      int lastPercent = 0;

      // Set timeout options
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 120);
      dio.options.sendTimeout = const Duration(seconds: 30);

      await dio.download(
        reciter.url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            final percent = (progress * 100).toInt();

            // Log every 10% progress
            if (percent >= lastPercent + 10 || percent == 100) {
              debugPrint('🔥 [ADHAN DOWNLOAD] Progress: $percent% ($received/$total bytes)');
              lastPercent = percent;
            }

            final updated = Map<String, DownloadInfo>.from(state);
            updated[reciter.id] = DownloadInfo(
              status: DownloadStatus.downloading,
              progress: progress,
            );
            state = updated;
            onProgress(progress);
          } else {
            debugPrint('🔥 [ADHAN DOWNLOAD] Received $received bytes (total unknown)');
          }
        },
      );

      debugPrint('🔥 [ADHAN DOWNLOAD] Download complete, verifying file...');
      final downloadedFile = File(filePath);
      final exists = await downloadedFile.exists();
      final size = exists ? await downloadedFile.length() : 0;
      debugPrint('🔥 [ADHAN DOWNLOAD] File exists: $exists, Size: $size bytes');

      if (!exists || size == 0) {
        throw Exception('Download failed - file is empty or does not exist');
      }

      final updated = Map<String, DownloadInfo>.from(state);
      updated[reciter.id] = DownloadInfo(
        status: DownloadStatus.downloaded,
        progress: 1.0,
      );
      state = updated;
      debugPrint('🔥 [ADHAN DOWNLOAD] ✅ Download successful!');

    } catch (e) {
      debugPrint('🔥 [ADHAN DOWNLOAD] ❌ ERROR: ${e.toString()}');
      debugPrint('🔥 [ADHAN DOWNLOAD] Error type: ${e.runtimeType}');

      // Get more detailed error info
      String userFriendlyError = 'Download failed';
      if (e.toString().contains('404')) {
        userFriendlyError = 'File not found (404) - URL may be incorrect';
      } else if (e.toString().contains('timeout')) {
        userFriendlyError = 'Download timeout - check your internet connection';
      } else if (e.toString().contains('FileSystemException')) {
        userFriendlyError = 'Storage error - cannot save file';
      } else if (e.toString().contains('DioException')) {
        userFriendlyError = 'Network error - check your internet connection';
      }

      debugPrint('🔥 [ADHAN DOWNLOAD] User error: $userFriendlyError');

      final updated = Map<String, DownloadInfo>.from(state);
      updated[reciter.id] = DownloadInfo(
        status: DownloadStatus.error,
        error: userFriendlyError,
      );
      state = updated;
    }
  }

  Future<void> deleteAdhan(AdhanReciter reciter) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final adhanDir = Directory('${appDir.path}/adhans');
      final file = File('${adhanDir.path}/${reciter.fileName}');
      if (await file.exists()) {
        await file.delete();
      }
      final updated = Map<String, DownloadInfo>.from(state);
      updated.remove(reciter.id);
      state = updated;
    } catch (e) {
      debugPrint('Error deleting adhan: $e');
    }
  }

  Future<bool> isDownloaded(String reciterId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final adhanDir = Directory('${appDir.path}/adhans');
    final reciter = availableAdhans.firstWhere((r) => r.id == reciterId);
    final file = File('${adhanDir.path}/${reciter.fileName}');
    return await file.exists();
  }

  Future<String> getDownloadedPath(String reciterId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final adhanDir = Directory('${appDir.path}/adhans');
    final reciter = availableAdhans.firstWhere((r) => r.id == reciterId);
    return '${adhanDir.path}/${reciter.fileName}';
  }

  Future<void> checkDownloadedStatus() async {
    final updated = Map<String, DownloadInfo>.from(state);
    for (final reciter in availableAdhans) {
      if (await isDownloaded(reciter.id)) {
        updated[reciter.id] = DownloadInfo(
          status: DownloadStatus.downloaded,
          progress: 1.0,
        );
      }
    }
    state = updated;
  }
}

/// Adhan Downloads Screen
class AdhanDownloadsScreen extends ConsumerStatefulWidget {
  const AdhanDownloadsScreen({super.key});

  @override
  ConsumerState<AdhanDownloadsScreen> createState() => _AdhanDownloadsScreenState();
}

class _AdhanDownloadsScreenState extends ConsumerState<AdhanDownloadsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(downloadProvider.notifier).checkDownloadedStatus();
      _loadSelectedAdhan();
    });
  }

  Future<void> _loadSelectedAdhan() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedId = prefs.getString('selected_adhan_id');
    if (mounted && selectedId != null) {
      ref.read(selectedAdhanProvider.notifier).state = selectedId;
    }
  }

  Future<void> _setSelectedAdhan(String reciterId, String reciterName, bool isArabic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_adhan_id', reciterId);

    if (mounted) {
      ref.read(selectedAdhanProvider.notifier).state = reciterId;

      // Get the downloaded file path
      final path = await ref.read(downloadProvider.notifier).getDownloadedPath(reciterId);

      // Set as custom adhan
      await AdhanPlayerService.instance.setCustomAdhan(path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تم تعيين $reciterName كالأذان الافتراضي' : '$reciterName set as default azan'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';

    final downloads = ref.watch(downloadProvider);
    final selectedAdhanId = ref.watch(selectedAdhanProvider);
    ref.watch(playingAdhanProvider); // Watch to update UI when playing state changes

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'تحميل الأذان' : 'Download Azan'),
        actions: [
          // Permission check button
          IconButton(
            onPressed: () async {
              final canSchedule = await PrayerAlarmService.instance.canScheduleExactAlarms();
              if (mounted) {
                if (!canSchedule) {
                  // Show dialog to request permission
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(isArabic ? 'إذن المنبه الدقيق' : 'Exact Alarm Permission'),
                      content: Text(
                        isArabic
                            ? 'لعمل منبهات الصلاة بشكل صحيح، يرجى منح إذن المنبه الدقيق من الإعدادات.'
                            : 'For prayer alarms to work correctly, please grant exact alarm permission from settings.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            PrayerAlarmService.instance.openExactAlarmSettings();
                          },
                          child: Text(isArabic ? 'الإعدادات' : 'Settings'),
                        ),
                      ],
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isArabic ? '✅ الإذن ممنوح' : '✅ Permission granted'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.settings),
            tooltip: isArabic ? 'الإعدادات' : 'Settings',
          ),
          if (selectedAdhanId != null)
            TextButton.icon(
              onPressed: () async {
                await AdhanPlayerService.instance.setCustomAdhan(null);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('selected_adhan_id');
                if (mounted) {
                  ref.read(selectedAdhanProvider.notifier).state = null;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isArabic ? 'تم إعادة تعيين الأذان الافتراضي' : 'Default azan reset'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh),
              label: Text(isArabic ? 'إعادة تعيين' : 'Reset'),
            ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        itemCount: availableAdhans.length,
        itemBuilder: (context, index) {
          final reciter = availableAdhans[index];
          final downloadInfo = downloads[reciter.id];
          final isSelected = selectedAdhanId == reciter.id;

          return _buildAdhanCard(
            context,
            reciter,
            downloadInfo,
            isDark,
            isArabic,
            isSelected,
          ).animate().fadeIn(
            delay: Duration(milliseconds: 100 * index),
            duration: 400.ms,
          );
        },
      ),
    );
  }

  Widget _buildAdhanCard(
    BuildContext context,
    AdhanReciter reciter,
    DownloadInfo? downloadInfo,
    bool isDark,
    bool isArabic,
    bool isSelected,
  ) {
    final isDownloaded = downloadInfo?.status == DownloadStatus.downloaded;
    final isDownloading = downloadInfo?.status == DownloadStatus.downloading;
    final progress = downloadInfo?.progress ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: isSelected
              ? AppConstants.getPrimary(isDark)
              : (isDownloaded
                  ? AppConstants.getPrimary(isDark).withOpacity(0.5)
                  : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder)),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMedium,
              vertical: AppConstants.paddingSmall,
            ),
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppConstants.getPrimary(isDark)
                    : AppConstants.getPrimary(isDark).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: Icon(
                Icons.mosque,
                color: isSelected ? Colors.white : AppConstants.getPrimary(isDark),
                size: 30,
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    isArabic ? reciter.nameAr : reciter.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppConstants.getPrimary(isDark),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isArabic ? 'الافتراضي' : 'Default',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? reciter.descriptionAr : reciter.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${reciter.fileSize.toStringAsFixed(1)} MB',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppConstants.getPrimary(isDark),
                        fontSize: 11,
                      ),
                ),
              ],
            ),
            trailing: _buildTrailing(
              context,
              reciter,
              downloadInfo,
              isDownloaded,
              isDownloading,
              progress,
              isSelected,
              isArabic,
            ),
          ),
          // Progress bar
          if (isDownloading)
            Padding(
              padding: const EdgeInsets.only(
                left: AppConstants.paddingMedium,
                right: AppConstants.paddingMedium,
                bottom: AppConstants.paddingSmall,
              ),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(AppConstants.getPrimary(isDark)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrailing(
    BuildContext context,
    AdhanReciter reciter,
    DownloadInfo? downloadInfo,
    bool isDownloaded,
    bool isDownloading,
    double progress,
    bool isSelected,
    bool isArabic,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playingAdhanId = ref.watch(playingAdhanProvider);
    final isPlaying = playingAdhanId == reciter.id;

    if (isDownloading) {
      return Text(
        '${(progress * 100).toInt()}%',
        style: TextStyle(
          color: AppConstants.getPrimary(isDark),
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (isDownloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Set as Default button (only if not already selected)
          if (!isSelected)
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: const Icon(Icons.check_circle_outline, size: 18),
                color: AppConstants.getPrimary(isDark),
                padding: EdgeInsets.zero,
                onPressed: () => _setSelectedAdhan(
                  reciter.id,
                  isArabic ? reciter.nameAr : reciter.name,
                  isArabic,
                ),
                tooltip: isArabic ? 'تعيين كافتراضي' : 'Set as default',
              ),
            ),
          // Play/Stop button
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: Icon(
                isPlaying ? Icons.stop_circle : Icons.play_circle_outline,
                color: isPlaying ? Colors.red : Colors.green,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              onPressed: () async {
                if (isPlaying) {
                  // Stop the adhan
                  await AdhanPlayerService.instance.stopAdhan();
                  if (mounted) {
                    ref.read(playingAdhanProvider.notifier).state = null;
                    // Clear any existing snackbars and show stopped message
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isArabic ? 'تم الإيقاف' : 'Stopped'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } else {
                  // Stop any currently playing adhan first
                  if (playingAdhanId != null) {
                    await AdhanPlayerService.instance.stopAdhan();
                  }

                  // Play the new adhan
                  final path = await ref.read(downloadProvider.notifier).getDownloadedPath(reciter.id);
                  await AdhanPlayerService.instance.setCustomAdhan(path);
                  await AdhanPlayerService.instance.playAdhan('Fajr');

                  if (mounted) {
                    ref.read(playingAdhanProvider.notifier).state = reciter.id;
                    // Clear any existing snackbars first
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isArabic ? 'جاري التشغيل...' : 'Playing...'),
                        duration: const Duration(seconds: 5),
                        backgroundColor: Colors.green,
                        action: SnackBarAction(
                          label: isArabic ? 'إيقاف' : 'Stop',
                          textColor: Colors.white,
                          onPressed: () async {
                            await AdhanPlayerService.instance.stopAdhan();
                            ref.read(playingAdhanProvider.notifier).state = null;
                            ScaffoldMessenger.of(context).clearSnackBars();
                          },
                        ),
                      ),
                    );
                  }
                }
              },
              tooltip: isPlaying ? (isArabic ? 'إيقاف' : 'Stop') : (isArabic ? 'تشغيل' : 'Play'),
            ),
          ),
          // Delete button
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              padding: EdgeInsets.zero,
              onPressed: () => _confirmDelete(reciter, isArabic),
              tooltip: isArabic ? 'حذف' : 'Delete',
            ),
          ),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: () => _downloadAdhan(reciter, isArabic),
      icon: const Icon(Icons.download),
      label: Text(isArabic ? 'تحميل' : 'Download'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppConstants.getPrimary(isDark),
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _downloadAdhan(AdhanReciter reciter, bool isArabic) async {
    debugPrint('🔥 [ADHAN DOWNLOAD UI] User pressed download for ${reciter.name}');

    // Show download started message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'بدأ التحميل...' : 'Download started...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await ref.read(downloadProvider.notifier).downloadAdhan(
      reciter,
      (progress) {
        // Progress is updated automatically in the notifier
        debugPrint('🔥 [ADHAN DOWNLOAD UI] Progress callback: ${(progress * 100).toInt()}%');
      },
    );

    // Show completion message
    if (mounted) {
      final downloads = ref.read(downloadProvider);
      final info = downloads[reciter.id];

      debugPrint('🔥 [ADHAN DOWNLOAD UI] Final status: ${info?.status}');
      debugPrint('🔥 [ADHAN DOWNLOAD UI] Error: ${info?.error}');

      if (info?.status == DownloadStatus.downloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'تم التحميل بنجاح!' : 'Downloaded successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (info?.status == DownloadStatus.error) {
        final errorMessage = info?.error ?? 'Unknown error';
        debugPrint('🔥 [ADHAN DOWNLOAD UI] Showing error to user: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isArabic ? 'خطأ' : 'Error'}: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(AdhanReciter reciter, bool isArabic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'حذف الأذان' : 'Delete Azan'),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من حذف هذا الأذان؟'
              : 'Are you sure you want to delete this azan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              isArabic ? 'حذف' : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(downloadProvider.notifier).deleteAdhan(reciter);

      // Stop playing if this adhan is currently playing
      final playingId = ref.read(playingAdhanProvider);
      if (playingId == reciter.id) {
        await AdhanPlayerService.instance.stopAdhan();
        if (mounted) {
          ref.read(playingAdhanProvider.notifier).state = null;
        }
      }

      // Check if this was the selected adhan and clear it
      final selectedId = ref.read(selectedAdhanProvider);
      if (selectedId == reciter.id) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('selected_adhan_id');
        if (mounted) {
          ref.read(selectedAdhanProvider.notifier).state = null;
          await AdhanPlayerService.instance.setCustomAdhan(null);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'تم الحذف' : 'Deleted'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
