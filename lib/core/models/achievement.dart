/// Achievement category
enum AchievementCategory {
  streaks,
  consistency,
  dhikr,
  tasks,
  special,
}

/// Achievement model representing a badge the user can earn
class Achievement {
  final String id;
  final String nameEn;
  final String nameAr;
  final String descriptionEn;
  final String descriptionAr;
  final String iconEmoji;
  final AchievementCategory category;
  final int threshold;
  final DateTime? earnedAt;

  const Achievement({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.iconEmoji,
    required this.category,
    required this.threshold,
    this.earnedAt,
  });

  bool get isEarned => earnedAt != null;

  String name(bool isArabic) => isArabic ? nameAr : nameEn;
  String description(bool isArabic) => isArabic ? descriptionAr : descriptionEn;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'earnedAt': earnedAt?.toIso8601String(),
    };
  }

  factory Achievement.earnedFromFirestore(String id, DateTime earnedAt) {
    final def = AchievementDefinitions.all.firstWhere(
      (a) => a.id == id,
      orElse: () => Achievement(
        id: id,
        nameEn: 'Unknown',
        nameAr: 'غير معروف',
        descriptionEn: '',
        descriptionAr: '',
        iconEmoji: '🏅',
        category: AchievementCategory.special,
        threshold: 0,
        earnedAt: earnedAt,
      ),
    );
    return Achievement(
      id: id,
      nameEn: def.nameEn,
      nameAr: def.nameAr,
      descriptionEn: def.descriptionEn,
      descriptionAr: def.descriptionAr,
      iconEmoji: def.iconEmoji,
      category: def.category,
      threshold: def.threshold,
      earnedAt: earnedAt,
    );
  }
}

/// All achievement definitions
class AchievementDefinitions {
  static const List<Achievement> all = [
    // Streaks
    Achievement(
      id: 'first_prayer',
      nameEn: 'First Step',
      nameAr: 'الخطوة الأولى',
      descriptionEn: 'Record your first prayer',
      descriptionAr: 'سجّل أول صلاة',
      iconEmoji: '🌱',
      category: AchievementCategory.streaks,
      threshold: 1,
    ),
    Achievement(
      id: 'streak_7',
      nameEn: 'Week Warrior',
      nameAr: 'محارب الأسبوع',
      descriptionEn: '7-day prayer streak',
      descriptionAr: 'تتابع 7 أيام',
      iconEmoji: '🔥',
      category: AchievementCategory.streaks,
      threshold: 7,
    ),
    Achievement(
      id: 'streak_30',
      nameEn: 'Monthly Devotion',
      nameAr: 'إخلاص شهري',
      descriptionEn: '30-day prayer streak',
      descriptionAr: 'تتابع 30 يوم',
      iconEmoji: '⭐',
      category: AchievementCategory.streaks,
      threshold: 30,
    ),
    Achievement(
      id: 'streak_100',
      nameEn: 'Centurion',
      nameAr: 'المئوي',
      descriptionEn: '100-day prayer streak',
      descriptionAr: 'تتابع 100 يوم',
      iconEmoji: '💎',
      category: AchievementCategory.streaks,
      threshold: 100,
    ),

    // Consistency
    Achievement(
      id: 'perfect_day',
      nameEn: 'Perfect Day',
      nameAr: 'يوم مثالي',
      descriptionEn: 'Complete all 5 prayers in one day',
      descriptionAr: 'أكمل جميع الصلوات الخمس في يوم واحد',
      iconEmoji: '✨',
      category: AchievementCategory.consistency,
      threshold: 1,
    ),
    Achievement(
      id: 'on_time_50',
      nameEn: 'On Time Champion',
      nameAr: 'بطل الالتزام',
      descriptionEn: '50 consecutive on-time prayers',
      descriptionAr: '50 صلاة متتالية في الوقت',
      iconEmoji: '⏰',
      category: AchievementCategory.consistency,
      threshold: 50,
    ),
    Achievement(
      id: 'consistency_80',
      nameEn: 'Consistent Worshipper',
      nameAr: 'مصلّي منتظم',
      descriptionEn: '80%+ completion rate for 30 days',
      descriptionAr: 'معدل إتمام 80%+ لمدة 30 يوم',
      iconEmoji: '🏆',
      category: AchievementCategory.consistency,
      threshold: 80,
    ),
    Achievement(
      id: 'prayers_100',
      nameEn: 'Century Mark',
      nameAr: 'المئة صلاة',
      descriptionEn: 'Complete 100 prayers total',
      descriptionAr: 'أكمل 100 صلاة إجمالاً',
      iconEmoji: '💯',
      category: AchievementCategory.consistency,
      threshold: 100,
    ),

    // Dhikr
    Achievement(
      id: 'dhikr_first',
      nameEn: 'First Zikr',
      nameAr: 'أول ذكر',
      descriptionEn: 'Complete your first zikr session',
      descriptionAr: 'أكمل أول جلسة أذكار',
      iconEmoji: '📿',
      category: AchievementCategory.dhikr,
      threshold: 1,
    ),
    Achievement(
      id: 'dhikr_50',
      nameEn: 'Zikr Regular',
      nameAr: 'ذاكر منتظم',
      descriptionEn: 'Complete 50 zikr sessions',
      descriptionAr: 'أكمل 50 جلسة أذكار',
      iconEmoji: '🤲',
      category: AchievementCategory.dhikr,
      threshold: 50,
    ),
    Achievement(
      id: 'dhikr_100',
      nameEn: 'Zikr Master',
      nameAr: 'أستاذ الأذكار',
      descriptionEn: 'Complete 100 zikr sessions',
      descriptionAr: 'أكمل 100 جلسة أذكار',
      iconEmoji: '🌟',
      category: AchievementCategory.dhikr,
      threshold: 100,
    ),

    // Tasks
    Achievement(
      id: 'first_task',
      nameEn: 'First Mission',
      nameAr: 'أول مهمة',
      descriptionEn: 'Complete your first task',
      descriptionAr: 'أكمل أول مهمة',
      iconEmoji: '✅',
      category: AchievementCategory.tasks,
      threshold: 1,
    ),
    Achievement(
      id: 'tasks_10',
      nameEn: 'Getting Things Done',
      nameAr: 'منجز المهام',
      descriptionEn: 'Complete 10 tasks',
      descriptionAr: 'أكمل 10 مهام',
      iconEmoji: '📋',
      category: AchievementCategory.tasks,
      threshold: 10,
    ),
    Achievement(
      id: 'tasks_50',
      nameEn: 'Task Master',
      nameAr: 'سيّد المهام',
      descriptionEn: 'Complete 50 tasks',
      descriptionAr: 'أكمل 50 مهمة',
      iconEmoji: '🚀',
      category: AchievementCategory.tasks,
      threshold: 50,
    ),
    Achievement(
      id: 'task_streak_7',
      nameEn: 'Consistent Achiever',
      nameAr: 'المثابر',
      descriptionEn: 'Complete tasks 7 days in a row',
      descriptionAr: 'أكمل مهام 7 أيام متتالية',
      iconEmoji: '📅',
      category: AchievementCategory.tasks,
      threshold: 7,
    ),

    // Special
    Achievement(
      id: 'night_prayer',
      nameEn: 'Night Owl',
      nameAr: 'صلاة الليل',
      descriptionEn: 'Pray Isha on time 7 days in a row',
      descriptionAr: 'صلّ العشاء في الوقت 7 أيام متتالية',
      iconEmoji: '🌙',
      category: AchievementCategory.special,
      threshold: 7,
    ),
    Achievement(
      id: 'early_bird',
      nameEn: 'Early Bird',
      nameAr: 'صلاة الفجر',
      descriptionEn: 'Pray Fajr on time 7 days in a row',
      descriptionAr: 'صلّ الفجر في الوقت 7 أيام متتالية',
      iconEmoji: '🐦',
      category: AchievementCategory.special,
      threshold: 7,
    ),
  ];
}
