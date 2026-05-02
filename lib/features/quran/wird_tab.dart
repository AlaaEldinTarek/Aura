import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:aura_app/core/constants/app_constants.dart';
import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/providers/wird_provider.dart';
import 'package:aura_app/core/utils/number_formatter.dart';
import 'quran_reader_screen.dart';

class WirdTab extends ConsumerWidget {
  final String lang;

  const WirdTab({super.key, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wirdAsync = ref.watch(wirdStateProvider);

    return wirdAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (wirdState) {
        return _WirdContentView(state: wirdState, lang: lang);
      },
    );
  }
}

class _WirdContentView extends ConsumerWidget {
  final WirdState state;
  final String lang;

  const _WirdContentView({required this.state, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final progress = state.todayProgress;
    final goal = state.settings.dailyPageGoal;
    final pagesRead = progress?.pagesRead ?? 0;
    final isCompleted = progress?.isCompleted ?? false;
    final progressRatio = goal > 0 ? pagesRead / goal : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStreakCard(primary, isDark),
        const SizedBox(height: 16),
        _buildProgressCard(context, primary, isDark, pagesRead, goal, isCompleted, progressRatio),
        const SizedBox(height: 16),

        if (isCompleted)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'wird_completed_today'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _buildActionButtons(context, ref, primary, progress),
          const SizedBox(height: 16),
        ],

        _buildStatsRow(primary, isDark),
        const SizedBox(height: 16),
        _buildSettingsSection(context, ref, primary, isDark),
      ],
    );
  }

  Widget _buildStreakCard(Color primary, bool isDark) {
    final streak = state.streakCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.2),
            primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(streak > 0 ? '🔥' : '📚', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'wird_streak'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      NumberFormatter.withArabicNumeralsByLanguage(streak.toString(), lang),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'wird_streak_days'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context, Color primary, bool isDark,
    int pagesRead, int goal, bool isCompleted, double progressRatio,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('wird_today_progress'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: isCompleted ? 1.0 : progressRatio.clamp(0.0, 1.0),
                    strokeWidth: 10,
                    backgroundColor: (isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary).withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : primary),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${NumberFormatter.withArabicNumeralsByLanguage(pagesRead.toString(), lang)}'
                          ' ${'wird_of'.tr()} '
                          '${NumberFormatter.withArabicNumeralsByLanguage(goal.toString(), lang)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'page'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isCompleted && pagesRead < goal) ...[
              const SizedBox(height: 8),
              Text(
                '${NumberFormatter.withArabicNumeralsByLanguage((goal - pagesRead).toString(), lang)} ${'wird_pages_remaining'.tr()}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Color primary, WirdProgress? progress) {
    final goal = state.settings.dailyPageGoal;
    final startPage = progress?.startPage ?? 1;
    final currentPage = progress?.currentPage ?? startPage;
    final endPage = (startPage + goal - 1).clamp(1, 604);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'wird_page_range'.tr()
                    .replaceAll('%s', NumberFormatter.withArabicNumeralsByLanguage(startPage.toString(), lang))
                    .replaceAll('%e', NumberFormatter.withArabicNumeralsByLanguage(endPage.toString(), lang)),
                style: TextStyle(fontSize: 14, color: primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuranReaderScreen(suraNo: 1, initialPage: currentPage),
                    ),
                  );
                },
                icon: Icon(progress == null ? Icons.play_arrow : Icons.arrow_forward),
                label: Text(progress == null ? 'wird_start_reading'.tr() : 'wird_continue_reading'.tr()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showRecordPagesDialog(context, ref, currentPage),
                icon: const Icon(Icons.edit_note),
                label: Text('wird_record_pages'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ref.read(wirdStateProvider.notifier).markComplete(),
                icon: const Icon(Icons.check),
                label: Text('wird_mark_complete'.tr()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showRecordPagesDialog(BuildContext context, WidgetRef ref, int currentPage) {
    final controller = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('wird_how_many_pages'.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'wird_pages_read'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              final pages = int.tryParse(controller.text) ?? 0;
              if (pages > 0) {
                ref.read(wirdStateProvider.notifier).recordPagesRead(pages, currentPage + pages);
                Navigator.pop(ctx);
              }
            },
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Color primary, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    NumberFormatter.withArabicNumeralsByLanguage(state.totalPagesRead.toString(), lang),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primary),
                  ),
                  Text(
                    'wird_total_pages'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    NumberFormatter.withArabicNumeralsByLanguage(state.totalDaysCompleted.toString(), lang),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primary),
                  ),
                  Text(
                    'wird_total_days'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context, WidgetRef ref, Color primary, bool isDark) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.menu_book, color: primary),
            title: Text('wird_daily_goal'.tr()),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    final current = state.settings.dailyPageGoal;
                    if (current > 1) ref.read(wirdStateProvider.notifier).setDailyPageGoal(current - 1);
                  },
                  icon: const Icon(Icons.remove, size: 20),
                ),
                Text(
                  NumberFormatter.withArabicNumeralsByLanguage(state.settings.dailyPageGoal.toString(), lang),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () {
                    final current = state.settings.dailyPageGoal;
                    if (current < 604) ref.read(wirdStateProvider.notifier).setDailyPageGoal(current + 1);
                  },
                  icon: const Icon(Icons.add, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: Icon(Icons.notifications_active, color: primary),
            title: Text('wird_reminder_enabled'.tr()),
            subtitle: Text('wird_reminder_subtitle'.tr()),
            value: state.settings.remindersEnabled,
            onChanged: (v) => ref.read(wirdStateProvider.notifier).setRemindersEnabled(v),
          ),
          if (state.settings.remindersEnabled) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('wird_reminders'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            ...state.settings.reminderTimes.asMap().entries.map((entry) {
              final idx = entry.key;
              final time = entry.value;
              final parts = time.split(':');
              final timeOfDay = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

              return ListTile(
                dense: true,
                leading: const Icon(Icons.access_time, size: 20),
                title: Text(timeOfDay.format(context), style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => ref.read(wirdStateProvider.notifier).removeReminder(idx),
                ),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: timeOfDay);
                  if (picked != null) {
                    final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    final times = [...state.settings.reminderTimes];
                    times[idx] = newTime;
                    ref.read(wirdStateProvider.notifier).setReminderTimes(times);
                  }
                },
              );
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: state.settings.reminderTimes.length >= 10
                    ? null
                    : () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 6, minute: 0),
                        );
                        if (picked != null) {
                          final time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          ref.read(wirdStateProvider.notifier).addReminder(time);
                        }
                      },
                icon: const Icon(Icons.add),
                label: Text('wird_add_reminder'.tr()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
