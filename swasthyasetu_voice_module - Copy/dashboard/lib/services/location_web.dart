// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

typedef GpsCallback = void Function(double lat, double lng, double accuracy);
typedef ErrorCallback = void Function(String error);

void queryBrowserGps(GpsCallback onSuccess, ErrorCallback onError) {
  try {
    final geo = html.window.navigator.geolocation;

    geo.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 12),
      maximumAge: const Duration(minutes: 2),
    ).then((pos) {
      final coords = pos.coords;
      if (coords != null && coords.latitude != null && coords.longitude != null) {
        final lat = coords.latitude!.toDouble();
        final lng = coords.longitude!.toDouble();
        final acc = (coords.accuracy ?? 15.0).toDouble();
        onSuccess(lat, lng, acc);
      } else {
        onError('GPS position coordinates were null.');
      }
    }).catchError((dynamic err) {
      onError('GPS sensor permission or timeout error: $err');
    });
  } catch (e) {
    onError('Failed to invoke browser geolocation: $e');
  }
}
