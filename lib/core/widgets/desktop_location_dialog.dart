import 'dart:async';
import 'dart:ui' as ui show TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_constants.dart';
import '../services/location_service.dart';
import '../services/geocoding_service.dart';
import '../providers/prayer_times_provider.dart';

/// Shows the desktop location picker dialog.
/// On save the prayer times provider is refreshed automatically.
Future<void> showDesktopLocationDialog(BuildContext context, WidgetRef ref) {
  final container = ProviderScope.containerOf(context, listen: false);
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: const _DesktopLocationDialog(),
    ),
  );
}

class _DesktopLocationDialog extends ConsumerStatefulWidget {
  const _DesktopLocationDialog();

  @override
  ConsumerState<_DesktopLocationDialog> createState() =>
      _DesktopLocationDialogState();
}

class _DesktopLocationDialogState
    extends ConsumerState<_DesktopLocationDialog> {
  final _searchCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();
  final _cityNameCtrl = TextEditingController();

  List<CityResult> _results = [];
  CityResult? _selected;
  bool _searching = false;
  bool _detecting = false;
  bool _showManual = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _cityNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    final loc = await LocationService.instance.getManualLocation();
    if (loc != null && mounted) {
      setState(() {
        _latCtrl.text = loc.latitude.toStringAsFixed(6);
        _lonCtrl.text = loc.longitude.toStringAsFixed(6);
        _cityNameCtrl.text = loc.cityName;
        _selected = CityResult(
          cityName: loc.cityName,
          country: '',
          latitude: loc.latitude,
          longitude: loc.longitude,
        );
      });
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchCtrl.text.trim();
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(q));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final results =
        await GeocodingService.instance.searchCity(query, isArabic ? 'ar' : 'en');
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  Future<void> _autoDetect() async {
    setState(() {
      _detecting = true;
      _error = null;
    });
    try {
      // Use the location service's IP geolocation directly by temporarily
      // calling getBestLocation without a manual location saved.
      // We snapshot the old manual location so we can restore on failure.
      final oldManual = await LocationService.instance.getManualLocation();
      await LocationService.instance.clearManualLocation();

      LocationData detected;
      try {
        detected = await LocationService.instance.getBestLocation();
      } catch (e) {
        // Restore old manual location on failure
        if (oldManual != null) {
          await LocationService.instance.setManualLocation(
              oldManual.latitude, oldManual.longitude, oldManual.cityName);
        }
        rethrow;
      }

      if (mounted) {
        setState(() {
          _selected = CityResult(
            cityName: detected.cityName,
            country: '',
            latitude: detected.latitude,
            longitude: detected.longitude,
          );
          _latCtrl.text = detected.latitude.toStringAsFixed(6);
          _lonCtrl.text = detected.longitude.toStringAsFixed(6);
          _cityNameCtrl.text = detected.cityName;
          _searchCtrl.clear();
          _results = [];
          _detecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _detecting = false;
          _error = 'location_detect_failed'.tr();
        });
      }
    }
  }

  void _selectCity(CityResult r) {
    setState(() {
      _selected = r;
      _latCtrl.text = r.latitude.toStringAsFixed(6);
      _lonCtrl.text = r.longitude.toStringAsFixed(6);
      _cityNameCtrl.text = r.cityName;
      _searchCtrl.clear();
      _results = [];
    });
  }

  Future<void> _save() async {
    double? lat;
    double? lon;
    String city;

    if (_showManual) {
      lat = double.tryParse(_latCtrl.text.trim());
      lon = double.tryParse(_lonCtrl.text.trim());
      city = _cityNameCtrl.text.trim();
      if (lat == null || lon == null || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        setState(() => _error = 'location_invalid_coords'.tr());
        return;
      }
      if (city.isEmpty) city = 'Custom Location';
    } else if (_selected != null) {
      lat = _selected!.latitude;
      lon = _selected!.longitude;
      city = _selected!.cityName;
    } else {
      setState(() => _error = 'location_no_selection'.tr());
      return;
    }

    await LocationService.instance.setManualLocation(lat, lon, city);
    // Bust the 15-min cache so prayer times refresh immediately
    ref.invalidate(prayerTimesProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.location_on, color: primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'location_dialog_title'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Auto-detect button
              OutlinedButton.icon(
                onPressed: _detecting ? null : _autoDetect,
                icon: _detecting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: primary),
                      )
                    : Icon(Icons.my_location, color: primary),
                label: Text(
                  _detecting
                      ? 'location_detecting'.tr()
                      : 'location_auto_detect'.tr(),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              const SizedBox(height: 12),

              // Divider with "or"
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('location_or'.tr(),
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                const Expanded(child: Divider()),
              ]),

              const SizedBox(height: 12),

              // Search field
              TextField(
                controller: _searchCtrl,
                textDirection:
                    isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: 'location_search_hint'.tr(),
                  prefixIcon: _searching
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: primary),
                          ),
                        )
                      : const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                onSubmitted: (v) {
                  _debounce?.cancel();
                  if (v.trim().length >= 2) _search(v.trim());
                },
              ),

              // Search results
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 8),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).dividerColor, width: 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (ctx, i) {
                        final r = _results[i];
                        final isSelected = _selected?.cityName == r.cityName &&
                            _selected?.latitude == r.latitude;
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.location_city,
                              size: 18, color: primary),
                          title: Text(r.cityName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: r.country.isNotEmpty
                              ? Text(r.country,
                                  style: Theme.of(context).textTheme.bodySmall)
                              : null,
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: primary)
                              : null,
                          tileColor: isSelected
                              ? primary.withValues(alpha: 0.08)
                              : null,
                          onTap: () => _selectCity(r),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Selected city chip
              if (_selected != null && _results.isEmpty && !_showManual) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selected!.cityName} (${_selected!.latitude.toStringAsFixed(3)}, ${_selected!.longitude.toStringAsFixed(3)})',
                          style:
                              const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Manual entry toggle
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() => _showManual = !_showManual),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        _showManual
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 18,
                        color: primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'location_manual_entry'.tr(),
                        style: TextStyle(
                            color: primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),

              if (_showManual) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*\.?\d*'))
                      ],
                      decoration: InputDecoration(
                        labelText: 'location_lat'.tr(),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lonCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*\.?\d*'))
                      ],
                      decoration: InputDecoration(
                        labelText: 'location_lon'.tr(),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _cityNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'location_city_label'.tr(),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13)),
              ],

              const SizedBox(height: 20),

              // Save button
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'location_save'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

