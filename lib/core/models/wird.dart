enum WirdUnit { page, juz }

class WirdSettings {
  final int dailyPageGoal;
  final int dailyJuzGoal;
  final WirdUnit wirdUnit;
  final List<String> reminderTimes; // "HH:mm" format, max 10
  final bool remindersEnabled;
  final String? linkedBookmarkColor; // 'red', 'orange', 'green' or null
  final List<int> countedBookmarkPages; // pages already synced from bookmarks

  const WirdSettings({
    this.dailyPageGoal = 5,
    this.dailyJuzGoal = 1,
    this.wirdUnit = WirdUnit.page,
    this.reminderTimes = const [],
    this.remindersEnabled = true,
    this.linkedBookmarkColor,
    this.countedBookmarkPages = const [],
  });

  Map<String, dynamic> toJson() => {
        'dailyPageGoal': dailyPageGoal,
        'dailyJuzGoal': dailyJuzGoal,
        'wirdUnit': wirdUnit.name,
        'reminderTimes': reminderTimes,
        'remindersEnabled': remindersEnabled,
        'linkedBookmarkColor': linkedBookmarkColor,
        'countedBookmarkPages': countedBookmarkPages,
      };

  factory WirdSettings.fromJson(Map<String, dynamic> json) => WirdSettings(
        dailyPageGoal: json['dailyPageGoal'] as int? ?? 5,
        dailyJuzGoal: json['dailyJuzGoal'] as int? ?? 1,
        wirdUnit: WirdUnit.values.firstWhere(
          (u) => u.name == (json['wirdUnit'] as String? ?? 'page'),
          orElse: () => WirdUnit.page,
        ),
        reminderTimes: (json['reminderTimes'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        remindersEnabled: json['remindersEnabled'] as bool? ?? true,
        linkedBookmarkColor: json['linkedBookmarkColor'] as String?,
        countedBookmarkPages: (json['countedBookmarkPages'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            [],
      );

  WirdSettings copyWith({
    int? dailyPageGoal,
    int? dailyJuzGoal,
    WirdUnit? wirdUnit,
    List<String>? reminderTimes,
    bool? remindersEnabled,
    String? linkedBookmarkColor,
    bool clearLinkedColor = false,
    List<int>? countedBookmarkPages,
  }) =>
      WirdSettings(
        dailyPageGoal: dailyPageGoal ?? this.dailyPageGoal,
        dailyJuzGoal: dailyJuzGoal ?? this.dailyJuzGoal,
        wirdUnit: wirdUnit ?? this.wirdUnit,
        reminderTimes: reminderTimes ?? this.reminderTimes,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        linkedBookmarkColor: clearLinkedColor ? null : (linkedBookmarkColor ?? this.linkedBookmarkColor),
        countedBookmarkPages: countedBookmarkPages ?? this.countedBookmarkPages,
      );
}

class WirdProgress {
  final DateTime date;
  final int pagesRead;
  final int startPage;
  final int currentPage;
  final bool isCompleted;
  final List<int> juzCompletedToday; // juz numbers (1-30) completed today

  const WirdProgress({
    required this.date,
    this.pagesRead = 0,
    this.startPage = 1,
    this.currentPage = 1,
    this.isCompleted = false,
    this.juzCompletedToday = const [],
  });

  int get juzRead => juzCompletedToday.length;

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'date': dateKey,
        'pagesRead': pagesRead,
        'startPage': startPage,
        'currentPage': currentPage,
        'isCompleted': isCompleted,
        'juzCompletedToday': juzCompletedToday,
      };

  factory WirdProgress.fromJson(Map<String, dynamic> json) {
    final dateStr = json['date'] as String;
    final parts = dateStr.split('-');
    return WirdProgress(
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      pagesRead: json['pagesRead'] as int? ?? 0,
      startPage: json['startPage'] as int? ?? 1,
      currentPage: json['currentPage'] as int? ?? 1,
      isCompleted: json['isCompleted'] as bool? ?? false,
      juzCompletedToday: (json['juzCompletedToday'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }

  WirdProgress copyWith({
    DateTime? date,
    int? pagesRead,
    int? startPage,
    int? currentPage,
    bool? isCompleted,
    List<int>? juzCompletedToday,
  }) =>
      WirdProgress(
        date: date ?? this.date,
        pagesRead: pagesRead ?? this.pagesRead,
        startPage: startPage ?? this.startPage,
        currentPage: currentPage ?? this.currentPage,
        isCompleted: isCompleted ?? this.isCompleted,
        juzCompletedToday: juzCompletedToday ?? this.juzCompletedToday,
      );
}

class WirdState {
  final WirdSettings settings;
  final WirdProgress? todayProgress;
  final int streakCount;
  final String? streakDate;
  final int totalPagesRead;
  final int totalDaysCompleted;
  final List<int> allCompletedJuz; // all juz (1-30) ever completed

  const WirdState({
    this.settings = const WirdSettings(),
    this.todayProgress,
    this.streakCount = 0,
    this.streakDate,
    this.totalPagesRead = 0,
    this.totalDaysCompleted = 0,
    this.allCompletedJuz = const [],
  });

  WirdState copyWith({
    WirdSettings? settings,
    WirdProgress? todayProgress,
    int? streakCount,
    String? streakDate,
    int? totalPagesRead,
    int? totalDaysCompleted,
    List<int>? allCompletedJuz,
  }) =>
      WirdState(
        settings: settings ?? this.settings,
        todayProgress: todayProgress ?? this.todayProgress,
        streakCount: streakCount ?? this.streakCount,
        streakDate: streakDate ?? this.streakDate,
        totalPagesRead: totalPagesRead ?? this.totalPagesRead,
        totalDaysCompleted: totalDaysCompleted ?? this.totalDaysCompleted,
        allCompletedJuz: allCompletedJuz ?? this.allCompletedJuz,
      );
}
