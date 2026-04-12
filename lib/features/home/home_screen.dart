import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/providers/prayer_times_provider.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/greeting_widget.dart';
import '../../core/widgets/permission_dialog.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/services/prayer_tracking_service.dart';
import '../../core/models/prayer_record.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PrayerTrackingService _trackingService = PrayerTrackingService.instance;
  Map<String, PrayerStatus?> _completedPrayers = {};
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  int _refreshCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadCompletedPrayers();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final prayer = ref.read(prayerTimesProvider).nextPrayer;
      if (prayer == null) return;
      final diff = prayer.time.difference(DateTime.now());
      setState(() {
        _remaining = diff.isNegative ? Duration.zero : diff;
        _refreshCounter++;
      });
      if (_refreshCounter % 60 == 0) {
        _loadCompletedPrayers();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCompletedPrayers() async {
    try {
      final userId = getCurrentUserId();
      await _trackingService.initialize();
      final records = await _trackingService.getPrayersForDate(
        userId: userId,
        date: DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _completedPrayers = {
            for (final record in records) record.prayerName: record.status,
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading completed prayers: $e');
    }
  }

  String _formatCountdown(bool isArabic) {
    if (_remaining == Duration.zero) return '--:--';
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    String text;
    if (h > 0) {
      text = isArabic
          ? '$h س ${m.toString().padLeft(2, '0')} د'
          : '${h}h ${m.toString().padLeft(2, '0')}m';
    } else if (m > 0) {
      text = isArabic
          ? '$m د ${s.toString().padLeft(2, '0')} ث'
          : '${m}m ${s.toString().padLeft(2, '0')}s';
    } else {
      text = isArabic ? '$s ث' : '${s}s';
    }
    if (isArabic) text = NumberFormatter.withArabicNumeralsByLanguage(text, 'ar');
    return text;
  }

  String _getPrayerEmoji(String name) {
    switch (name.toLowerCase()) {
      case 'fajr': return '🌙';
      case 'sunrise': return '🌅';
      case 'dhuhr': return '☀️';
      case 'asr': return '🌤️';
      case 'maghrib': return '🌇';
      case 'isha': return '🌃';
      default: return '🕌';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final prayerState = ref.watch(prayerTimesProvider);

    final user = ref.watch(currentUserProvider);
    final userName = user?.displayName ?? 'User';
    final isGuest = ref.watch(guestModeProvider.select((async) => async.value ?? false));

    // Calculate prayer progress
    final trackablePrayers = kPrayerNames;
    final completedCount = trackablePrayers.where((p) {
      final status = _completedPrayers[p];
      return status == PrayerStatus.onTime || status == PrayerStatus.late;
    }).length;
    final totalPrayers = trackablePrayers.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aura | هالة'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          ConnectivityWrapper(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Greeting Section
                    GreetingWidget(
                      userName: isGuest ? null : userName,
                      onTap: () => Navigator.of(context).pushNamed('/prayer'),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

                    const SizedBox(height: AppConstants.paddingLarge),

                    // Next Prayer Mini Card
                    _buildNextPrayerCard(context, prayerState, isDark, isArabic, completedCount, totalPrayers)
                        .animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1),

                    const SizedBox(height: AppConstants.paddingMedium),

                    // Prayer Progress Bar
                    _buildPrayerProgress(context, isDark, isArabic, completedCount, totalPrayers)
                        .animate().fadeIn(delay: 200.ms, duration: 400.ms),

                    const SizedBox(height: AppConstants.paddingLarge),

                    // Footer
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
                        child: Text(
                          'version'.tr() + ' 1.0.2',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                    ),

                    // Bottom padding for nav bar
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
          // Permission dialog handler (shows dialogs after home loads)
          const PermissionDialogHandler(),
        ],
      ),
    );
  }

  Widget _buildNextPrayerCard(
    BuildContext context,
    PrayerTimesState? prayerState,
    bool isDark,
    bool isArabic,
    int completedCount,
    int totalPrayers,
  ) {
    final nextPrayer = prayerState?.nextPrayer;
    final hasData = nextPrayer != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/prayer'),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: isDark
                ? AppConstants.primaryColor.withOpacity(0.12)
                : AppConstants.primaryColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              color: AppConstants.primaryColor.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Prayer emoji
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Center(
                      child: Text(
                        hasData ? _getPrayerEmoji(nextPrayer.name) : '🕌',
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingMedium),

                  // Prayer info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'الصلاة القادمة' : 'Next Prayer',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasData
                              ? (isArabic ? nextPrayer.nameAr : nextPrayer.name)
                              : (isArabic ? 'جاري التحميل...' : 'Loading...'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Countdown
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCountdown(isArabic),
                        style: TextStyle(
                          color: AppConstants.primaryColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic ? 'حتى الأذان' : 'Until Adhan',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.paddingMedium),

              // Prayer time
              if (hasData) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, color: AppConstants.primaryColor.withOpacity(0.7), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            isArabic
                                ? NumberFormatter.withArabicNumeralsByLanguage(
                                    nextPrayer.time12h.replaceAll('AM', 'ص').replaceAll('PM', 'م'), 'ar')
                                : nextPrayer.time12h,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: AppConstants.primaryColor.withOpacity(0.7), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            isArabic
                                ? '$completedCount من $totalPrayers'
                                : '$completedCount/$totalPrayers',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerProgress(
    BuildContext context,
    bool isDark,
    bool isArabic,
    int completedCount,
    int totalPrayers,
  ) {
    final progress = totalPrayers > 0 ? completedCount / totalPrayers : 0.0;

    final prayerIcons = ['🌙', '☀️', '🌤️', '🌇', '🌃'];
    final trackablePrayers = kPrayerNames;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'تقدم الصلوات اليوم' : "Today's Prayer Progress",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                isArabic
                    ? NumberFormatter.withArabicNumeralsByLanguage('$completedCount/${kPrayerNames.length}', 'ar')
                    : '$completedCount/${kPrayerNames.length}',
                style: TextStyle(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingSmall),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.green : AppConstants.primaryColor,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingSmall),

          // Prayer status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(trackablePrayers.length, (i) {
              final status = _completedPrayers[trackablePrayers[i]];
              final isTracked = status != null;

              // Match prayer_status_dialog.dart icon/color style
              Color color;
              IconData icon;
              if (status == PrayerStatus.onTime) {
                color = Colors.green;
                icon = Icons.check_circle;
              } else if (status == PrayerStatus.late) {
                color = Colors.orange;
                icon = Icons.schedule;
              } else if (status == PrayerStatus.excused) {
                // "Missed" in dialog stores as excused with red cancel icon
                color = Colors.red;
                icon = Icons.cancel;
              } else {
                color = isDark ? AppConstants.darkBorder : AppConstants.lightBorder;
                icon = Icons.circle_outlined;
              }

              return Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isTracked
                          ? color.withValues(alpha: 0.15)
                          : (isDark ? AppConstants.darkSurface : Colors.grey[100]),
                      border: Border.all(
                        color: isTracked ? color : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isTracked
                          ? Icon(icon, color: color, size: 20)
                          : Text(prayerIcons[i], style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabic
                        ? ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'][i]
                        : kPrayerNames[i],
                    style: TextStyle(
                      fontSize: 9,
                      color: isTracked
                          ? color
                          : (isDark ? Colors.white54 : Colors.black54),
                      fontWeight: isTracked ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyProgressRing(BuildContext context, bool isDark, bool isArabic, int completed, int total) {
    final progress = total > 0 ? completed / total : 0.0;
    final percentage = (progress * 100).round();
    final displayPercentage = isArabic
        ? NumberFormatter.withArabicNumerals('$percentage')
        : '$percentage';

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'تقدم اليوم' : "Today's Progress",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Row(
            children: [
              // Progress ring
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? Colors.green : AppConstants.primaryColor,
                      ),
                    ),
                    Center(
                      child: Text(
                        '$displayPercentage%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              // Prayer dots
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: kPrayerNames.map((name) {
                    final prayerEmojis = {
                      'Fajr': '🌙', 'Zuhr': '☀️', 'Asr': '🌤️', 'Maghrib': '🌇', 'Isha': '🌃',
                    };
                    final prayerNamesAr = {
                      'Fajr': 'الفجر', 'Zuhr': 'الظهر', 'Asr': 'العصر', 'Maghrib': 'المغرب', 'Isha': 'العشاء',
                    };
                    final displayName = isArabic ? (prayerNamesAr[name] ?? name) : name;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(prayerEmojis[name] ?? '🕌', style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(displayName, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, bool isDark, bool isArabic) {
    return FutureBuilder<List<PrayerRecord>>(
      future: _getRecentRecords(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final records = snapshot.data!.take(3).toList();
        final prayerEmojis = {
          'Fajr': '🌙', 'Zuhr': '☀️', 'Asr': '🌤️', 'Maghrib': '🌇', 'Isha': '🌃',
        };

        return Container(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: isDark ? AppConstants.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'النشاط الأخير' : 'Recent Activity',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              ...records.map((record) {
                final statusIcon = record.status == PrayerStatus.onTime
                    ? Icons.check_circle
                    : record.status == PrayerStatus.late
                        ? Icons.schedule
                        : Icons.cancel;
                final statusColor = record.status == PrayerStatus.onTime
                    ? Colors.green
                    : record.status == PrayerStatus.late
                        ? Colors.orange
                        : Colors.red;
                final statusText = record.status == PrayerStatus.onTime
                    ? (isArabic ? 'في الوقت' : 'On Time')
                    : record.status == PrayerStatus.late
                        ? (isArabic ? 'متأخر' : 'Late')
                        : (isArabic ? 'معذور' : 'Excused');
                final timeStr = '${record.prayedAt.hour}:${record.prayedAt.minute.toString().padLeft(2, '0')}';
                final displayTime = isArabic ? NumberFormatter.withArabicNumerals(timeStr) : timeStr;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(prayerEmojis[record.prayerName] ?? '🕌', style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isArabic ? record.prayerName : record.prayerName,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          statusText,
                          style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        displayTime,
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<List<PrayerRecord>> _getRecentRecords() async {
    try {
      final userId = getCurrentUserId();
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      return await PrayerTrackingService.instance.getPrayersForDateRange(
        userId: userId,
        startDate: startOfDay,
        endDate: now,
      );
    } catch (_) {
      return [];
    }
  }
}
