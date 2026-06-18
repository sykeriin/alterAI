import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final onDeviceContextProvider = Provider<OnDeviceContext>(
  (ref) => const OnDeviceContext(),
);

/// Reads consented on-device context — today's calendar (via a native
/// ContentResolver bridge) + current location (geolocator) — so the agent can
/// reason about the user's actual day ("you have a 3pm, leave now"). Each read
/// is permissioned at the point of use; nothing is read passively/in the
/// background.
class OnDeviceContext {
  const OnDeviceContext();

  static const _calendar = MethodChannel('alter.ai/calendar');

  /// Today's calendar events as readable "HH:MM Title" lines, or a status line.
  Future<String> todayCalendar() async {
    try {
      final res = await _calendar.invokeMethod<Map<dynamic, dynamic>>(
        'todayEvents',
      );
      if (res == null) return 'Calendar unavailable.';
      if (res['granted'] != true) {
        return 'Calendar access requested — allow it, then ask me again.';
      }
      final events = (res['events'] is List)
          ? (res['events'] as List).whereType<Map<dynamic, dynamic>>().toList()
          : const <Map<dynamic, dynamic>>[];
      if (events.isEmpty) return 'No events on the calendar today.';

      String hhmm(Object? millis) {
        if (millis is! int) return '';
        final d = DateTime.fromMillisecondsSinceEpoch(millis);
        return '${d.hour.toString().padLeft(2, '0')}:'
            '${d.minute.toString().padLeft(2, '0')}';
      }

      return events.take(8).map((e) {
        final time = hhmm(e['start']);
        final raw = (e['title'] ?? '').toString().trim();
        final title = raw.isEmpty ? 'Untitled' : raw;
        return time.isEmpty ? title : '$time $title';
      }).join('; ');
    } catch (e) {
      return 'Could not read the calendar: $e';
    }
  }

  /// Current approximate location as "lat, lng", or a status line.
  Future<String> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Location services are turned off.';
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return 'Location access not granted.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      return '${pos.latitude.toStringAsFixed(4)}, '
          '${pos.longitude.toStringAsFixed(4)}';
    } catch (e) {
      return 'Could not read location: $e';
    }
  }

  /// Combined snapshot used by the agent's read_my_context tool.
  Future<String> snapshot({
    bool calendar = true,
    bool location = true,
  }) async {
    final parts = <String>[];
    if (calendar) parts.add('Today: ${await todayCalendar()}');
    if (location) parts.add('Location: ${await currentLocation()}');
    return parts.join(' | ');
  }
}
