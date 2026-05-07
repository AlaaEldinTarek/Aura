import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/islamic_event.dart';
import '../services/islamic_events_service.dart';

final islamicEventsProvider = Provider<List<IslamicEventWithDate>>((ref) {
  return IslamicEventsService.getUpcomingEvents();
});
