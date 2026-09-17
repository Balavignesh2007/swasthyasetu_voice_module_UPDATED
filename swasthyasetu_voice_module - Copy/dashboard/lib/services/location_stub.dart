import 'package:geolocator/geolocator.dart';

typedef GpsCallback = void Function(double lat, double lng, double accuracy);
typedef ErrorCallback = void Function(String error);

void queryBrowserGps(GpsCallback onSuccess, ErrorCallback onError) async {
  try {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onError('Location services are disabled. Please enable GPS.');
      return;
    }

    // Check/request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        onError('Location permission denied by user.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      onError('Location permission permanently denied. Enable in device Settings > SwasthyaSetu > Location.');
      return;
    }

    // Get current position
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );

    onSuccess(pos.latitude, pos.longitude, pos.accuracy);
  } catch (e) {
    onError('Failed to get GPS location: $e');
  }
}
