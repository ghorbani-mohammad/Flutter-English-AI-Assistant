import '../utils/timezone_utils.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isVoice;
  final String? userTimezone;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isVoice = false,
    this.userTimezone,
  });

  /// Returns the formatted timestamp in the user's timezone
  String get timezoneAwareFormattedTime {
    return TimezoneUtils.getTimezoneAwareFormattedTime(timestamp, userTimezone, showDate: true);
  }
} 