import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class TimezoneUtils {
  /// Initialize timezone data if not already done
  static void initializeTimeZones() {
    tz_data.initializeTimeZones();
  }

  /// Convert UTC DateTime to user's timezone
  static DateTime? convertToUserTimezone(DateTime utcTime, String? userTimezone) {
    if (userTimezone == null || userTimezone.isEmpty) {
      return utcTime;
    }

    try {
      initializeTimeZones();
      final userTz = tz.getLocation(userTimezone);
      return tz.TZDateTime.from(utcTime, userTz);
    } catch (e) {
      // If timezone conversion fails, return the original time
      return utcTime;
    }
  }

  /// Format time in a user-friendly way based on the date
  static String formatTime(DateTime time, {bool showDate = true}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (messageDate == today) {
      // Today: show time only
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday: show "Yesterday" and time
      return 'Yesterday ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (showDate) {
      // Other days: show date and time
      return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      // Just time
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Get timezone-aware formatted time for a message
  static String getTimezoneAwareFormattedTime(DateTime utcTime, String? userTimezone, {bool showDate = true}) {
    final localTime = convertToUserTimezone(utcTime, userTimezone);
    if (localTime == null) {
      return formatTime(utcTime, showDate: showDate);
    }
    return formatTime(localTime, showDate: showDate);
  }
} 