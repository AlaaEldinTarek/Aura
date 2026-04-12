import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Model for tracking prayer completion records
class PrayerRecord {
  final String id;
  final String userId;
  final String prayerName; // Fajr, Dhuhr, Asr, Maghrib, Isha
  final DateTime date;
  final DateTime prayedAt;
  final PrayerStatus status;
  final PrayerMethod method;
  final String? notes;

  PrayerRecord({
    required this.id,
    required this.userId,
    required this.prayerName,
    required this.date,
    required this.prayedAt,
    this.status = PrayerStatus.onTime,
    this.method = PrayerMethod.congregation,
    this.notes,
  });

  factory PrayerRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PrayerRecord(
      id: doc.id,
      userId: data['userId'] as String,
      prayerName: data['prayerName'] as String,
      date: DateTime.parse(data['date'] as String),
      prayedAt: DateTime.parse(data['prayedAt'] as String),
      status: PrayerStatus.fromString(data['status'] as String? ?? 'on_time'),
      method: PrayerMethod.fromString(data['method'] as String? ?? 'congregation'),
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'prayerName': prayerName,
      'date': date.toIso8601String(),
      'prayedAt': prayedAt.toIso8601String(),
      'status': status.value,
      'method': method.value,
      'notes': notes,
    };
  }

  PrayerRecord copyWith({
    String? id,
    String? userId,
    String? prayerName,
    DateTime? date,
    DateTime? prayedAt,
    PrayerStatus? status,
    PrayerMethod? method,
    String? notes,
  }) {
    return PrayerRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      prayerName: prayerName ?? this.prayerName,
      date: date ?? this.date,
      prayedAt: prayedAt ?? this.prayedAt,
      status: status ?? this.status,
      method: method ?? this.method,
      notes: notes ?? this.notes,
    );
  }
}

/// Prayer status (on time, late, etc.)
enum PrayerStatus {
  onTime('on_time'),
  late('late'),
  missed('missed'),
  excused('excused');

  final String value;

  const PrayerStatus(this.value);

  static PrayerStatus fromString(String value) {
    return PrayerStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PrayerStatus.onTime,
    );
  }
}

/// Prayer method (congregation, alone, etc.)
enum PrayerMethod {
  congregation('congregation'),
  alone('alone'),
  atHome('at_home');

  final String value;

  const PrayerMethod(this.value);

  static PrayerMethod fromString(String value) {
    return PrayerMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PrayerMethod.congregation,
    );
  }
}

/// Daily prayer summary
class DailyPrayerSummary {
  final DateTime date;
  final Map<String, PrayerStatus> prayers; // Fajr -> status, Dhuhr -> status, etc.

  DailyPrayerSummary({
    required this.date,
    required this.prayers,
  });

  int get completedCount => prayers.values.where((s) => s != PrayerStatus.missed).length;
  int get totalCount => prayers.length;
  double get completionRate => totalCount > 0 ? completedCount / totalCount : 0;

  bool get isComplete => completionRate == 1.0;
}

/// Prayer statistics for a period
class PrayerStatistics {
  final int totalPrayers;
  final int completedOnTime;
  final int completedLate;
  final int missed;
  final int currentStreak;
  final int bestStreak;
  final double completionRate;

  const PrayerStatistics({
    required this.totalPrayers,
    required this.completedOnTime,
    required this.completedLate,
    required this.missed,
    required this.currentStreak,
    required this.bestStreak,
    required this.completionRate,
  });

  factory PrayerStatistics.empty() {
    return const PrayerStatistics(
      totalPrayers: 0,
      completedOnTime: 0,
      completedLate: 0,
      missed: 0,
      currentStreak: 0,
      bestStreak: 0,
      completionRate: 0,
    );
  }

  int get completedTotal => completedOnTime + completedLate;
}

/// Standard list of trackable prayer names (excludes Sunrise)
const kPrayerNames = ['Fajr', 'Zuhr', 'Asr', 'Maghrib', 'Isha'];

/// Get the current user ID for prayer tracking
String getCurrentUserId() {
  return FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';
}
