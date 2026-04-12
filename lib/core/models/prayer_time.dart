import 'package:equatable/equatable.dart';

/// Prayer time entity for the Aura app
class PrayerTime extends Equatable {
  /// Prayer name (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha)
  final String name;

  /// Prayer name in Arabic
  final String nameAr;

  /// The time of the prayer (adhan)
  final DateTime time;

  /// The iqama time (when prayer actually starts)
  final DateTime? iqamaTime;

  /// Is this the next upcoming prayer?
  final bool isNext;

  /// Is this the current time window (between this prayer and next)?
  final bool isCurrent;

  const PrayerTime({
    required this.name,
    required this.nameAr,
    required this.time,
    this.iqamaTime,
    this.isNext = false,
    this.isCurrent = false,
  });

  /// Get prayer emoji icon
  String get emoji {
    switch (name) {
      case 'Fajr':
        return '🌙';
      case 'Sunrise':
        return '🌅';
      case 'Zuhr':
        return '☀️';
      case 'Asr':
        return '🌤️';
      case 'Maghrib':
        return '🌆';
      case 'Isha':
        return '🌙';
      default:
        return '🕌';
    }
  }

  @override
  List<Object?> get props => [name, nameAr, time, iqamaTime, isNext, isCurrent];

  /// Get prayer time as DateTime (same as time, for compatibility)
  DateTime? getDateTime() => time;

  /// Get 12-hour format time string (e.g., "5:30 AM")
  String get time12h {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Copy with method
  PrayerTime copyWith({
    String? name,
    String? nameAr,
    DateTime? time,
    DateTime? iqamaTime,
    bool? isNext,
    bool? isCurrent,
  }) {
    return PrayerTime(
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      time: time ?? this.time,
      iqamaTime: iqamaTime ?? this.iqamaTime,
      isNext: isNext ?? this.isNext,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}
