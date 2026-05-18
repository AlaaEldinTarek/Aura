import 'dart:ui' as ui show TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:aura_app/core/constants/app_constants.dart';
import 'package:aura_app/core/providers/wird_provider.dart';
import 'package:aura_app/core/utils/number_formatter.dart';

const _duaArabic =
    'اللَّهُمَّ ارْحَمْنَا بِالْقُرْآنِ الْعَظِيمِ، وَاجْعَلْهُ لَنَا إِمَامًا وَنُورًا وَهُدًى وَرَحْمَةً.\n\n'
    'اللَّهُمَّ ذَكِّرْنَا مِنْهُ مَا نُسِّينَا، وَعَلِّمْنَا مِنْهُ مَا جَهِلْنَا، وَارْزُقْنَا تِلَاوَتَهُ آنَاءَ اللَّيْلِ وَأَطْرَافَ النَّهَارِ.\n\n'
    'اللَّهُمَّ اجْعَلِ الْقُرْآنَ لَنَا رَبِيعَ الْقُلُوبِ، وَنُورَ الصُّدُورِ، وَجَلَاءَ الْأَحْزَانِ.\n\n'
    'اللَّهُمَّ اجْعَلِ الْقُرْآنَ حُجَّةً لَنَا لَا عَلَيْنَا، وَاجْعَلْهُ شَافِعًا لَنَا يَوْمَ الْقِيَامَةِ.\n\n'
    'اللَّهُمَّ تَقَبَّلْ مِنَّا هَذِهِ التِّلَاوَةَ، وَتُبْ عَلَيْنَا وَعَافِنَا، إِنَّكَ أَنْتَ التَّوَّابُ الرَّحِيمُ.';

const _duaEnglish =
    'O Allah, bestow mercy upon us through the Noble Quran, and make it for us a guide, a light, guidance and mercy.\n\n'
    'O Allah, remind us of what we have forgotten of it, teach us of it what we do not know, and grant us its recitation at the hours of the night and the ends of the day.\n\n'
    'O Allah, make the Quran the spring of our hearts, the light of our chests, and the remover of our sorrows.\n\n'
    'O Allah, make the Quran a proof for us and not against us, and make it an intercessor for us on the Day of Resurrection.\n\n'
    'O Allah, accept this recitation from us, forgive us and grant us well-being — verily You are the All-Accepting, the Most Merciful.';

class KhatmaDuaScreen extends ConsumerWidget {
  const KhatmaDuaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final secondary = isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary;

    final wirdState = ref.watch(wirdStateProvider).valueOrNull;
    final khatmCount = wirdState?.khatmCount ?? 0;
    final khatmDates = wirdState?.khatmDates ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('khatma_dua_title'.tr()),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Du'a card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Arabic du'a
                  Text(
                    _duaArabic,
                    textAlign: TextAlign.right,
                    textDirection: ui.TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      height: 2.2,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 20),
                  Divider(color: primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),

                  // English translation label
                  Text(
                    'khatma_dua_translation_label'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // English translation
                  Text(
                    _duaEnglish,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.8,
                      color: secondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Khatm history section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'khatma_history_title'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),

          if (khatmCount == 0)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'khatma_history_empty'.tr(),
                    style: TextStyle(color: secondary),
                  ),
                ),
              ),
            )
          else
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: List.generate(khatmCount, (i) {
                  final num = khatmCount - i;
                  final numStr = NumberFormatter.withArabicNumeralsByLanguage(num.toString(), lang);
                  final dateIndex = num - 1;
                  String dateStr = '';
                  if (dateIndex < khatmDates.length) {
                    try {
                      final parts = khatmDates[dateIndex].split('-');
                      final dt = DateTime(
                        int.parse(parts[0]),
                        int.parse(parts[1]),
                        int.parse(parts[2]),
                      );
                      dateStr = DateFormat('d MMM yyyy', lang == 'ar' ? 'ar' : 'en').format(dt);
                    } catch (_) {
                      dateStr = khatmDates[dateIndex];
                    }
                  }
                  return Column(
                    children: [
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              numStr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          'khatma_count_label'.tr().replaceAll('%d', numStr),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: dateStr.isNotEmpty
                            ? Text(dateStr, style: TextStyle(fontSize: 12, color: secondary))
                            : null,
                      ),
                    ],
                  );
                }),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
