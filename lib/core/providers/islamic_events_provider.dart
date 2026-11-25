import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/islamic_event.dart';
import '../services/islamic_events_service.dart';

class IslamicEventsNotifier extends Notifier<List<IslamicEventWithDate>> {
  Timer? _midnightTimer;

  @override
  List<IslamicEventWithDate> build() {
    ref.onDispose(() => _midnightTimer?.cancel());
    _scheduleMidnight();
    return IslamicEventsService.getUpcomingEvents();
  }

  void _scheduleMidnight() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer?.cancel();
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      state = IslamicEventsService.getUpcomingEvents();
      _scheduleMidnight();
    });
  }
}

final islamicEventsProvider =
    NotifierProvider<IslamicEventsNotifier, List<IslamicEventWithDate>>(
  IslamicEventsNotifier.new,
);
