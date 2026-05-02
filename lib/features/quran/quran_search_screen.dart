import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:aura_app/core/constants/app_constants.dart';
import 'package:aura_app/core/models/quran_models.dart';
import 'package:aura_app/core/providers/quran_provider.dart';
import 'package:aura_app/core/utils/number_formatter.dart';
import 'quran_reader_screen.dart';

class QuranSearchScreen extends ConsumerStatefulWidget {
  const QuranSearchScreen({super.key});

  @override
  ConsumerState<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends ConsumerState<QuranSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (value.trim().length >= 2) {
        setState(() => _query = value.trim());
      } else {
        setState(() => _query = '');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'search_quran'.tr(),
            border: InputBorder.none,
            hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black38),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _query.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('search_quran_hint'.tr(), style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            )
          : _SearchResults(query: _query, isDark: isDark),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;
  final bool isDark;

  const _SearchResults({required this.query, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(quranSearchProvider(query));
    final lang = context.locale.languageCode;

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (results) {
        if (results.isEmpty) {
          return Center(child: Text('no_results'.tr(), style: TextStyle(color: Colors.grey[500])));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final ayah = results[index];
            return ListTile(
              title: Text(
                ayah.ayaTextEmlaey,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 16,
                  height: 1.8,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  lang == 'ar'
                      ? '${ayah.suraNameAr} - ${NumberFormatter.withArabicNumeralsByLanguage(ayah.ayaNo.toString(), lang)}'
                      : '${ayah.suraNameEn} - ${ayah.ayaNo}',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuranReaderScreen(suraNo: ayah.suraNo, scrollToAyaNo: ayah.ayaNo, initialPage: ayah.page),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
