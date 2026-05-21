import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/azkar.dart';
import '../../core/providers/azkar_provider.dart';
import '../../core/utils/haptic_feedback.dart' as app_haptic;
import '../../core/utils/number_formatter.dart';
import '../../core/theme/app_typography.dart';

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
    final ts = MediaQuery.textScalerOf(context);
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
              icon: Text('🌅', style: TextStyle(fontSize: ts.scale(18.0))),
              text: isArabic ? 'أذكار الصباح' : 'Morning',
            ),
            Tab(
              icon: Text('🌙', style: TextStyle(fontSize: ts.scale(18.0))),
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
    final ts = MediaQuery.textScalerOf(context);
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
            padding: EdgeInsets.symmetric(horizontal: ts.scale(AppConstants.paddingMedium)),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(builder: (_, constraints) {
                final spacing = ts.scale(12.0);
                final itemWidth = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: ts.scale(10.0),
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

        SliverToBoxAdapter(child: SizedBox(height: ts.scale(32.0))),
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
    final ts = MediaQuery.textScalerOf(context);
    final progress = total > 0 ? done / total : 0.0;
    final circleSz = ts.scale(72.0);

    return Container(
      margin: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
      padding: EdgeInsets.all(ts.scale(AppConstants.paddingLarge)),
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
            width: circleSz,
            height: circleSz,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: circleSz,
                  height: circleSz,
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isComplete
                        ? '✓'
                        : '${NumberFormatter.withArabicNumeralsByLanguage('$done', isArabic ? 'ar' : 'en')}/${NumberFormatter.withArabicNumeralsByLanguage('$total', isArabic ? 'ar' : 'en')}',
                    style: AppTypography.bodyS.copyWith(
                      fontSize: isComplete ? ts.scale(24.0) : ts.scale(13.0),
                      fontWeight: FontWeight.bold,
                      color: isComplete
                          ? Colors.white
                          : (AppConstants.textPrimary(isDark)),
                    ),
                    textScaler: TextScaler.noScaling,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ts.scale(16.0)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplete
                      ? (isArabic ? 'ما شاء الله! 🎉' : 'Well done! 🎉')
                      : (isArabic ? 'تقدمك اليوم' : "Today's Progress"),
                  style: AppTypography.bodyL.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isComplete
                        ? Colors.white
                        : (AppConstants.textPrimary(isDark)),
                  ),
                ),
                SizedBox(height: ts.scale(4.0)),
                Text(
                  isComplete
                      ? (isArabic ? 'أكملت جميع الأذكار' : 'All azkar completed')
                      : (isArabic
                          ? '${NumberFormatter.withArabicNumerals('$done')} من ${NumberFormatter.withArabicNumerals('$total')} مكتمل'
                          : '$done of $total completed'),
                  style: AppTypography.bodyS.copyWith(
                    color: isComplete
                        ? Colors.white.withOpacity(0.9)
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
                if (streakCount > 0) ...[
                  SizedBox(height: ts.scale(6.0)),
                  Row(
                    children: [
                      Text('🔥', style: TextStyle(fontSize: ts.scale(12.0))),
                      SizedBox(width: ts.scale(4.0)),
                      Text(
                        isArabic
                            ? '${NumberFormatter.withArabicNumerals('$streakCount')} يوم متتالي'
                            : '$streakCount day streak',
                        style: AppTypography.caption.copyWith(
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
    final ts = MediaQuery.textScalerOf(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: EdgeInsets.symmetric(
        horizontal: isGridItem ? 0 : ts.scale(AppConstants.paddingMedium),
        vertical: ts.scale(5.0),
      ),
      decoration: BoxDecoration(
        color: isDone
            ? primary.withOpacity(0.1)
            : (AppConstants.card(isDark)),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: isDone
              ? primary.withOpacity(0.4)
              : (AppConstants.border(isDark)),
          width: isDone ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Padding(
          padding: EdgeInsets.all(ts.scale(14.0)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: ts.scale(28.0),
                height: ts.scale(28.0),
                margin: EdgeInsets.only(top: ts.scale(2.0)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? primary : Colors.transparent,
                  border: Border.all(
                    color: isDone ? primary : (isDark ? Colors.white30 : Colors.black26),
                    width: 2,
                  ),
                ),
                child: isDone
                    ? Icon(Icons.check, color: Colors.white, size: ts.scale(16.0))
                    : null,
              ),
              SizedBox(width: ts.scale(12.0)),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Arabic text
                    Text(
                      item.textAr,
                      style: AppTypography.ar(AppTypography.headingS).copyWith(
                        height: 1.8,
                        color: isDone
                            ? primary
                            : (AppConstants.textPrimary(isDark)),
                        decoration: TextDecoration.none,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: ts.scale(6.0)),
                    // English translation
                    Text(
                      item.textEn,
                      style: AppTypography.labelS.copyWith(
                        height: 1.4,
                        color: isDone
                            ? primary.withOpacity(0.7)
                            : (isDark ? Colors.white54 : Colors.black45),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(height: ts.scale(8.0)),
                    // Repeat count badge
                    if (item.repeatCount > 1)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: ts.scale(8.0), vertical: ts.scale(3.0)),
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
                          style: AppTypography.labelS.copyWith(
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
