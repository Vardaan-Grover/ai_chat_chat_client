import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

/// Provides extra functionality for formatting the time.
extension DateTimeExtension on DateTime {
  bool operator <(DateTime other) {
    return millisecondsSinceEpoch < other.millisecondsSinceEpoch;
  }

  bool operator >(DateTime other) {
    return millisecondsSinceEpoch > other.millisecondsSinceEpoch;
  }

  bool operator >=(DateTime other) {
    return millisecondsSinceEpoch >= other.millisecondsSinceEpoch;
  }

  bool operator <=(DateTime other) {
    return millisecondsSinceEpoch <= other.millisecondsSinceEpoch;
  }

  /// Checks if two DateTimes are close enough to belong to the same
  /// environment.
  bool sameEnvironment(DateTime prevTime) =>
      difference(prevTime) < const Duration(hours: 1);

  /// Returns a simple time String.
  String localizedTimeOfDayWithMode(BuildContext context) =>
      DateFormat('h:mm a', 'en').format(this);

  /// Returns [localizedTimeOfDay()] if the ChatTime is today, the name of the week
  /// day if the ChatTime is this week and a date string else.
  String localizedTimeShort(BuildContext context) {
    final now = DateTime.now();

    final sameYear = now.year == year;

    final sameDay = sameYear && now.month == month && now.day == day;

    final sameWeek =
        sameYear &&
        !sameDay &&
        now.millisecondsSinceEpoch - millisecondsSinceEpoch <
            1000 * 60 * 60 * 24 * 7;

    if (sameDay) {
      return localizedTimeOfDayWithMode(context);
    } else if (sameWeek) {
      return DateFormat.E(
        Localizations.localeOf(context).languageCode,
      ).format(this);
    } else if (sameYear) {
      return DateFormat.MMMd(
        Localizations.localeOf(context).languageCode,
      ).format(this);
    }
    return DateFormat.yMMMd(
      Localizations.localeOf(context).languageCode,
    ).format(this);
  }

  /// If the DateTime is today, this returns [localizedTimeOfDay()], if not it also
  /// shows the date.
  /// TODO: Add localization
  String localizedTime(BuildContext context) {
    final now = DateTime.now();

    final sameYear = now.year == year;

    final sameDay = sameYear && now.month == month && now.day == day;

    if (sameDay) return localizedTimeOfDayWithMode(context);
    return '${localizedTimeShort(context)}, ${localizedTimeOfDayWithMode(context)}';
  }
}
