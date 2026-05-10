import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/azkar.dart';
import '../../core/providers/azkar_provider.dart';
import '../../core/utils/haptic_feedback.dart' as app_haptic;
import '../../core/utils/number_formatter.dart';

class AzkarScreen extends ConsumerStatefulWidget {
  const AzkarScreen({super.key});

  @override
  ConsumerState<AzkarScreen> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends ConsumerState<AzkarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final primary = AppConstants.getPrimary(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الأذكار' : 'Azkar'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Text('🌅', style: TextStyle(fontSize: 18)),
              text: isArabic ? 'أذكار الصباح' : 'Morning',
            ),
            Tab(
              icon: const Text('🌙', style: TextStyle(fontSize: 18)),
              text: isArabic ? 'أذكار المساء' : 'Evening',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AzkarTabView(
            category: AzkarCategory.morning,
            isDark: isDark,
            isArabic: isArabic,
            primary: primary,
          ),
          _AzkarTabView(
            category: AzkarCategory.evening,
            isDark: isDark,
            isArabic: isArabic,
            primary: primary,
          ),
        ],
      ),
    );
  }
}

class _AzkarTabView extends ConsumerWidget {
  final AzkarCategory category;
  final bool isDark;
  final bool isArabic;
  final Color primary;

  const _AzkarTabView({
    required this.category,
    required this.isDark,
    required this.isArabic,
    required this.primary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(azkarProvider);
    final items = AzkarData.forCategory(category);
    final doneCount = state.doneCount(category);
    final total = items.length;
    final isComplete = category == AzkarCategory.morning
        ? state.isMorningComplete
        : state.isEveningComplete;
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    Widget buildCard(ZikrItem item) {
      final isDone = state.isItemDone(item.id, category);
      return _ZikrCard(
        item: item,
        isDone: isDone,
        isDark: isDark,
        isArabic: isArabic,
        primary: primary,
        isGridItem: isDesktop,
        onTap: () {
          app_haptic.HapticFeedback.light();
          ref.read(azkarProvider.notifier).toggleItem(item.id, category);
        },
      );
    }

    return CustomScrollView(
      slivers: [
        // Progress header
        SliverToBoxAdapter(
          child: _ProgressHeader(
            done: doneCount,
            total: total,
            isComplete: isComplete,
            isDark: isDark,
            isArabic: isArabic,
            primary: primary,
            streakCount: state.streakCount,
          ),
        ),

        // Zikr list — 2-column grid on desktop, single column on mobile
        if (isDesktop)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(builder: (_, constraints) {
                const spacing = 12.0;
                final itemWidth = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: 10,
                  children: items.map((item) => SizedBox(
                    width: itemWidth,
                    child: buildCard(item),
                  )).toList(),
                );
              }),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => buildCard(items[index]),
              childCount: items.length,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int done;
  final int total;
  final bool isComplete;
  final bool isDark;
  final bool isArabic;
  final Color primary;
  final int streakCount;

  const _ProgressHeader({
    required this.done,
    required this.total,
    required this.isComplete,
    required this.isDark,
    required this.isArabic,
    required this.primary,
    required this.streakCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? done / total : 0.0;

    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isComplete
              ? [const Color(0xFFFFB300), const Color(0xFFFF8F00)]
              : [
                  primary.withOpacity(0.15),
                  primary.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: isComplete
              ? const Color(0xFFFFB300).withOpacity(0.5)
              : primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Circular progress
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: isComplete
                        ? Colors.white.withOpacity(0.3)
                        : primary.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete ? Colors.white : primary,
                    ),
                  ),
                ),
                Text(
                  isComplete
                      ? '✓'
                      : '${NumberFormatter.withArabicNumeralsByLanguage('$done', isArabic ? 'ar' : 'en')}/${NumberFormatter.withArabicNumeralsByLanguage('$total', isArabic ? 'ar' : 'en')}',
                  style: TextStyle(
                    fontSize: isComplete ? 24 : 13,
                    fontWeight: FontWeight.bold,
                    color: isComplete
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplete
                      ? (isArabic ? 'ما شاء الله! 🎉' : 'Well done! 🎉')
                      : (isArabic ? 'تقدمك اليوم' : "Today's Progress"),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isComplete
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isComplete
                      ? (isArabic ? 'أكملت جميع الأذكار' : 'All azkar completed')
                      : (isArabic
                          ? '${NumberFormatter.withArabicNumerals('$done')} من ${NumberFormatter.withArabicNumerals('$total')} مكتمل'
                          : '$done of $total completed'),
                  style: TextStyle(
                    fontSize: 13,
                    color: isComplete
                        ? Colors.white.withOpacity(0.9)
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
                if (streakCount > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        isArabic
                            ? '${NumberFormatter.withArabicNumerals('$streakCount')} يوم متتالي'
                            : '$streakCount day streak',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isComplete
                              ? Colors.white.withOpacity(0.9)
                              : primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZikrCard extends StatelessWidget {
  final ZikrItem item;
  final bool isDone;
  final bool isDark;
  final bool isArabic;
  final Color primary;
  final VoidCallback onTap;
  final bool isGridItem;

  const _ZikrCard({
    required this.item,
    required this.isDone,
    required this.isDark,
    required this.isArabic,
    required this.primary,
    required this.onTap,
    this.isGridItem = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: EdgeInsets.symmetric(
        horizontal: isGridItem ? 0 : AppConstants.paddingMedium,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isDone
            ? primary.withOpacity(0.1)
            : (isDark ? AppConstants.darkCard : AppConstants.lightCard),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: isDone
              ? primary.withOpacity(0.4)
              : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
          width: isDone ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? primary : Colors.transparent,
                  border: Border.all(
                    color: isDone ? primary : (isDark ? Colors.white30 : Colors.black26),
                    width: 2,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Arabic text
                    Text(
                      item.textAr,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.8,
                        fontFamily: 'Cairo',
                        color: isDone
                            ? primary
                            : (isDark ? Colors.white : Colors.black87),
                        decoration: TextDecoration.none,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 6),
                    // English translation
                    Text(
                      item.textEn,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: isDone
                            ? primary.withOpacity(0.7)
                            : (isDark ? Colors.white54 : Colors.black45),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Repeat count badge
                    if (item.repeatCount > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDone
                              ? primary.withOpacity(0.15)
                              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isArabic
                              ? '× ${NumberFormatter.withArabicNumerals('${item.repeatCount}')}'
                              : '× ${item.repeatCount}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDone
                                ? primary
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
