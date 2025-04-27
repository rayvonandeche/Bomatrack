import 'package:intl/intl.dart';

class DateFormatUtils {
  /// Returns a relative time string like "5 minutes ago" or "2 days ago"
  static String getRelativeTimeString(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }
  
  /// Returns a formatted date string in format "Mon, 15 Jan 2025"
  static String getFormattedDate(DateTime dateTime) {
    return DateFormat('EEE, d MMM yyyy').format(dateTime);
  }
  
  /// Returns a formatted date and time string in format "15 Jan 2025, 14:30" or "Today, 14:30"
  static String getFormattedDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (targetDate == today) {
      return 'Today, ${DateFormat('HH:mm').format(dateTime)}';
    } else if (targetDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('d MMM yyyy, HH:mm').format(dateTime);
    }
  }
}