import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for Dhikr (Tasbeeh) counter
class DhikrSession {
  final String id;
  final String userId;
  final String dhikrText;
  final int count;
  final int target;
  final DateTime createdAt;
  final DateTime? completedAt;

  DhikrSession({
    required this.id,
    required this.userId,
    required this.dhikrText,
    required this.count,
    required this.target,
    required this.createdAt,
    this.completedAt,
  });

  factory DhikrSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DhikrSession(
      id: doc.id,
      userId: data['userId'] as String,
      dhikrText: data['dhikrText'] as String,
      count: data['count'] as int,
      target: data['target'] as int,
      createdAt: DateTime.parse(data['createdAt'] as String),
      completedAt: data['completedAt'] != null
          ? DateTime.parse(data['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'dhikrText': dhikrText,
      'count': count,
      'target': target,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  bool get isCompleted => count >= target;
  double get progress => target > 0 ? count / target : 0;

  DhikrSession copyWith({
    String? id,
    String? userId,
    String? dhikrText,
    int? count,
    int? target,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return DhikrSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      dhikrText: dhikrText ?? this.dhikrText,
      count: count ?? this.count,
      target: target ?? this.target,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Pre-defined Dhikr presets
class DhikrPreset {
  final String id; // empty for built-in, unique string for custom
  final String name;
  final String arabicText;
  final String transliteration;
  final String translation;
  final int defaultTarget;

  const DhikrPreset({
    this.id = '',
    required this.name,
    required this.arabicText,
    required this.transliteration,
    required this.translation,
    this.defaultTarget = 33,
  });

  bool get isCustom => id.isNotEmpty;

  /// Display text: arabic if available, otherwise name
  String get displayName => arabicText.isNotEmpty ? arabicText : name;

  factory DhikrPreset.fromJson(Map<String, dynamic> json) {
    return DhikrPreset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      arabicText: json['arabicText'] as String? ?? '',
      transliteration: json['transliteration'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      defaultTarget: json['defaultTarget'] as int? ?? 33,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'arabicText': arabicText,
      'transliteration': transliteration,
      'translation': translation,
      'defaultTarget': defaultTarget,
    };
  }
}

/// Common Dhikr presets
class DhikrPresets {
  static const List<DhikrPreset> builtIn = [
    DhikrPreset(
      name: 'SubhanAllah',
      arabicText: 'سُبْحَانَ اللَّهِ',
      transliteration: 'SubhanAllah',
      translation: 'Glory be to Allah',
      defaultTarget: 33,
    ),
    DhikrPreset(
      name: 'Alhamdulillah',
      arabicText: 'الْحَمْدُ لِلَّهِ',
      transliteration: 'Alhamdulillah',
      translation: 'All praise is due to Allah',
      defaultTarget: 33,
    ),
    DhikrPreset(
      name: 'Allahu Akbar',
      arabicText: 'اللَّهُ أَكْبَرُ',
      transliteration: 'Allahu Akbar',
      translation: 'Allah is the Greatest',
      defaultTarget: 33,
    ),
    DhikrPreset(
      name: 'La ilaha illallah',
      arabicText: 'لَا إِلَهَ إِلَّا اللَّهُ',
      transliteration: 'La ilaha illallah',
      translation: 'There is no god but Allah',
      defaultTarget: 100,
    ),
    DhikrPreset(
      name: 'Astaghfirullah',
      arabicText: 'أَسْتَغْفِرُ اللَّهِ',
      transliteration: 'Astaghfirullah',
      translation: 'I seek forgiveness from Allah',
      defaultTarget: 100,
    ),
  ];

  /// Backward-compatible: returns built-in presets
  static const List<DhikrPreset> presets = builtIn;
}

/// Dhikr statistics
class DhikrStatistics {
  final int totalSessions;
  final int totalDhikrCount;
  final int todayCount;
  final int streakDays;

  const DhikrStatistics({
    required this.totalSessions,
    required this.totalDhikrCount,
    required this.todayCount,
    required this.streakDays,
  });

  factory DhikrStatistics.empty() {
    return const DhikrStatistics(
      totalSessions: 0,
      totalDhikrCount: 0,
      todayCount: 0,
      streakDays: 0,
    );
  }
}
