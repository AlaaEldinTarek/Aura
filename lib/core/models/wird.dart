class WirdSettings {
  final int dailyPageGoal;
  final List<String> reminderTimes; // "HH:mm" format, max 10
  final bool remindersEnabled;

  const WirdSettings({
    this.dailyPageGoal = 5,
    this.reminderTimes = const [],
    this.remindersEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'dailyPageGoal': dailyPageGoal,
        'reminderTimes': reminderTimes,
        'remindersEnabled': remindersEnabled,
      };

  factory WirdSettings.fromJson(Map<String, dynamic> json) => WirdSettings(
        dailyPageGoal: json['dailyPageGoal'] as int? ?? 5,
        reminderTimes: (json['reminderTimes'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        remindersEnabled: json['remindersEnabled'] as bool? ?? true,
      );

  WirdSettings copyWith({
    int? dailyPageGoal,
    List<String>? reminderTimes,
    bool? remindersEnabled,
  }) =>
      WirdSettings(
        dailyPageGoal: dailyPageGoal ?? this.dailyPageGoal,
        reminderTimes: reminderTimes ?? this.reminderTimes,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      );
}

class WirdProgress {
  final DateTime date;
  final int pagesRead;
  final int startPage;
  final int currentPage;
  final bool isCompleted;

  const WirdProgress({
    required this.date,
    this.pagesRead = 0,
    this.startPage = 1,
    this.currentPage = 1,
    this.isCompleted = false,
  });

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'date': dateKey,
        'pagesRead': pagesRead,
        'startPage': startPage,
        'currentPage': currentPage,
        'isCompleted': isCompleted,
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
    );
  }

  WirdProgress copyWith({
    DateTime? date,
    int? pagesRead,
    int? startPage,
    int? currentPage,
    bool? isCompleted,
  }) =>
      WirdProgress(
        date: date ?? this.date,
        pagesRead: pagesRead ?? this.pagesRead,
        startPage: startPage ?? this.startPage,
        currentPage: currentPage ?? this.currentPage,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}

class WirdState {
  final WirdSettings settings;
  final WirdProgress? todayProgress;
  final int streakCount;
  final String? streakDate;
  final int totalPagesRead;
  final int totalDaysCompleted;

  const WirdState({
    this.settings = const WirdSettings(),
    this.todayProgress,
    this.streakCount = 0,
    this.streakDate,
    this.totalPagesRead = 0,
    this.totalDaysCompleted = 0,
  });

  WirdState copyWith({
    WirdSettings? settings,
    WirdProgress? todayProgress,
    int? streakCount,
    String? streakDate,
    int? totalPagesRead,
    int? totalDaysCompleted,
  }) =>
      WirdState(
        settings: settings ?? this.settings,
        todayProgress: todayProgress ?? this.todayProgress,
        streakCount: streakCount ?? this.streakCount,
        streakDate: streakDate ?? this.streakDate,
        totalPagesRead: totalPagesRead ?? this.totalPagesRead,
        totalDaysCompleted: totalDaysCompleted ?? this.totalDaysCompleted,
      );
}
