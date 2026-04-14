import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';

/// A beautiful greeting widget that shows personalized greeting
/// based on time of day
class GreetingWidget extends ConsumerWidget {
  final String? userName;
  final VoidCallback? onTap;

  const GreetingWidget({
    super.key,
    this.userName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    final size = MediaQuery.of(context).size;

    final hour = DateTime.now().hour;
    final (greeting, greetingAr, icon, bgColor) = _getTimeBasedGreeting(hour);

    final displayName = userName?.isNotEmpty == true ? userName : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar: user photo or app logo
            Container(
              width: size.width > 600 ? 60 : 50,
              height: size.width > 600 ? 60 : 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                child: _buildAvatar(ref),
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),

            // Greeting Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? greetingAr : greeting,
                    style: TextStyle(
                      fontSize: size.width > 600 ? 22 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (displayName != null)
                    Text(
                      isArabic ? 'مرحباً، $displayName' : 'Welcome back, $displayName',
                      style: TextStyle(
                        fontSize: size.width > 600 ? 16 : 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final photoURL = user?.photoURL;

    if (photoURL != null && photoURL.isNotEmpty) {
      return Image.network(
        photoURL,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
        ),
      );
    }
    return Image.asset('assets/images/logo.png', fit: BoxFit.cover);
  }

  (String, String, String, Color) _getTimeBasedGreeting(int hour) {
    // Early Morning (4-6 AM)
    if (hour >= 4 && hour < 6) {
      return (
        'Early Morning',
        'فجر جديد',
        '🌅',
        AppConstants.primaryColor
      );
    }
    // Morning (6-12 PM)
    if (hour >= 6 && hour < 12) {
      return (
        'Good Morning',
        'صباح الخير',
        '☀️',
        AppConstants.primaryColor
      );
    }
    // Afternoon (12-5 PM)
    if (hour >= 12 && hour < 17) {
      return (
        'Good Afternoon',
        'مساء الخير',
        '🌤️',
        AppConstants.primaryColor
      );
    }
    // Evening (5-8 PM)
    if (hour >= 17 && hour < 20) {
      return (
        'Good Evening',
        'مساء الخير',
        '🌇',
        AppConstants.primaryColor
      );
    }
    // Night (8 PM - 4 AM)
    return (
      'Good Night',
      'طابت ليلتك',
      '🌙',
      AppConstants.primaryColor
    );
  }
}

/// Simple greeting text widget for use in headers
class SimpleGreeting extends StatelessWidget {
  final String? userName;
  final TextStyle? style;

  const SimpleGreeting({
    super.key,
    this.userName,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';

    final hour = DateTime.now().hour;
    final (greeting, greetingAr, _, _) = _getTimeBasedGreeting(hour);

    final text = userName?.isNotEmpty == true
        ? (isArabic ? 'مرحباً $userName' : 'Hello, $userName')
        : (isArabic ? greetingAr : greeting);

    return Text(
      text,
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  (String, String, String, Color) _getTimeBasedGreeting(int hour) {
    if (hour >= 4 && hour < 12) {
      return ('Good Morning', 'صباح الخير', '☀️', AppConstants.primaryColor);
    } else if (hour >= 12 && hour < 17) {
      return ('Good Afternoon', 'مساء الخير', '🌤️', AppConstants.primaryColor);
    } else if (hour >= 17 && hour < 20) {
      return ('Good Evening', 'مساء الخير', '🌇', AppConstants.primaryColor);
    } else {
      return ('Good Night', 'طابت ليلتك', '🌙', AppConstants.primaryColor);
    }
  }
}
