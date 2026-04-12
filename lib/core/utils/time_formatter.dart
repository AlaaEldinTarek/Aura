/// Utility class for time formatting
class TimeFormatter {
  TimeFormatter._();

  /// Format duration to readable string
  static String formatDuration(Duration duration, String languageCode) {
    if (duration.inDays > 0) {
      final days = duration.inDays;
      return languageCode == 'ar' ? '$days يوم' : '${days}d';
    } else if (duration.inHours > 0) {
      final hours = duration.inHours;
      return languageCode == 'ar' ? '$hours ساعة' : '${hours}h';
    } else if (duration.inMinutes > 0) {
      final minutes = duration.inMinutes;
      return languageCode == 'ar' ? '$minutes دقيقة' : '${minutes}m';
    } else {
      final seconds = duration.inSeconds;
      return languageCode == 'ar' ? '$seconds ثانية' : '${seconds}s';
    }
  }

  /// Format remaining time to readable string
  static String formatRemaining(Duration duration, String languageCode) {
    if (duration.isNegative) {
      return languageCode == 'ar' ? 'انتهى الوقت' : 'Time passed';
    }

    if (duration.inDays > 0) {
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      if (hours > 0) {
        return languageCode == 'ar'
            ? '$days يوم $hours ساعة'
            : '${days}d ${hours}h';
      }
      return languageCode == 'ar' ? '$days يوم' : '${days}d';
    } else if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (minutes > 0) {
        return languageCode == 'ar'
            ? '$hours ساعة $minutes دقيقة'
            : '${hours}h ${minutes}m';
      }
      return languageCode == 'ar' ? '$hours ساعة' : '${hours}h';
    } else if (duration.inMinutes > 0) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      if (seconds > 0) {
        return languageCode == 'ar'
            ? '$minutes دقيقة $seconds ثانية'
            : '${minutes}m ${seconds}s';
      }
      return languageCode == 'ar' ? '$minutes دقيقة' : '${minutes}m';
    } else {
      final seconds = duration.inSeconds;
      return languageCode == 'ar' ? '$seconds ثانية' : '${seconds}s';
    }
  }

  /// Format time to 12-hour format
  static String formatTime12h(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Format time to 24-hour format
  static String formatTime24h(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Parse time string to DateTime
  static DateTime? parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1].split(' ')[0]);
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
    } catch (e) {
      // Return null if parsing fails
    }
    return null;
  }
}
