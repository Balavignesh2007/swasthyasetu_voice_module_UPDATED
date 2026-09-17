import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_stub.dart' if (dart.library.html) 'location_web.dart';

/// Predefined Maharashtra Health Grid Locations
class MaharashtraLocation {
  final String id;
  final String name;
  final String district;
  final double lat;
  final double lng;
  final String nearbyFacility;

  const MaharashtraLocation({
    required this.id,
    required this.name,
    required this.district,
    required this.lat,
    required this.lng,
    required this.nearbyFacility,
  });
}

/// Reactive Live GPS & Location Service for Patient Portal
class PatientLocationService extends ChangeNotifier {
  static final PatientLocationService _instance = PatientLocationService._internal();
  static PatientLocationService get instance => _instance;

  PatientLocationService._internal() {
    _loadSavedLocation();
  }

  // Active coordinates (Default: Shivajinagar, Pune, Maharashtra)
  double _latitude = 18.5314;
  double _longitude = 73.8446;
  String _locationName = 'Shivajinagar, Pune, Maharashtra';
  double _accuracyMeters = 12.0;
  bool _isLiveGps = false;
  bool _isDetecting = false;
  String? _errorMessage;

  double get latitude => _latitude;
  double get longitude => _longitude;
  String get locationName => _locationName;
  double get accuracyMeters => _accuracyMeters;
  bool get isLiveGps => _isLiveGps;
  bool get isDetecting => _isDetecting;
  String? get errorMessage => _errorMessage;

  String get coordinatesDisplay =>
      '${_latitude.toStringAsFixed(4)}° N, ${_longitude.toStringAsFixed(4)}° E';

  // Curated Maharashtra Health Grid Locations (Available to all dashboards)
  static const List<MaharashtraLocation> maharashtraPresets = [
    MaharashtraLocation(
      id: 'pune_shivajinagar',
      name: 'Shivajinagar, Pune',
      district: 'Pune',
      lat: 18.5314,
      lng: 73.8446,
      nearbyFacility: 'Shivaji Nagar PHC (प्राथमिक आरोग्य केंद्र)',
    ),
    MaharashtraLocation(
      id: 'pune_hadapsar',
      name: 'Hadapsar, Haveli',
      district: 'Pune Rural',
      lat: 18.5089,
      lng: 73.9260,
      nearbyFacility: 'Hadapsar CHC & Haveli Rural Hospital',
    ),
    MaharashtraLocation(
      id: 'pune_kothrud',
      name: 'Kothrud, Pune',
      district: 'Pune',
      lat: 18.5074,
      lng: 73.8077,
      nearbyFacility: 'Kothrud Sub-District Dispensary',
    ),
    MaharashtraLocation(
      id: 'pune_wagholi',
      name: 'Wagholi, Pune Rural',
      district: 'Pune Rural',
      lat: 18.5808,
      lng: 73.9803,
      nearbyFacility: 'Wagholi PHC & Sub-Center',
    ),
    MaharashtraLocation(
      id: 'pune_baramati',
      name: 'Baramati, Pune Rural',
      district: 'Pune Rural',
      lat: 18.1517,
      lng: 74.5770,
      nearbyFacility: 'Baramati Sub-District Hospital',
    ),
    MaharashtraLocation(
      id: 'mumbai_central',
      name: 'Dadar / Parel, Mumbai',
      district: 'Mumbai',
      lat: 19.0033,
      lng: 72.8428,
      nearbyFacility: 'KEM Hospital & Seth GS Medical College',
    ),
    MaharashtraLocation(
      id: 'nagpur_central',
      name: 'Sitabuldi, Nagpur',
      district: 'Nagpur',
      lat: 21.1458,
      lng: 79.0882,
      nearbyFacility: 'Government Medical College (GMC) Nagpur',
    ),
    MaharashtraLocation(
      id: 'nashik_panchavati',
      name: 'Panchavati, Nashik',
      district: 'Nashik',
      lat: 19.9975,
      lng: 73.7898,
      nearbyFacility: 'Nashik District Civil Hospital',
    ),
    MaharashtraLocation(
      id: 'aurangabad_city',
      name: 'Chhatrapati Sambhaji Nagar',
      district: 'Chhatrapati Sambhaji Nagar',
      lat: 19.8762,
      lng: 75.3433,
      nearbyFacility: 'Government Medical College & Hospital',
    ),
    MaharashtraLocation(
      id: 'kolhapur_city',
      name: 'C.P.R., Kolhapur',
      district: 'Kolhapur',
      lat: 16.7050,
      lng: 74.2433,
      nearbyFacility: 'Chhatrapati Pramila Raje Hospital (CPRH)',
    ),
    MaharashtraLocation(
      id: 'satara_city',
      name: 'Civil Lines, Satara',
      district: 'Satara',
      lat: 17.6805,
      lng: 73.9997,
      nearbyFacility: 'Satara District Civil Hospital',
    ),
    MaharashtraLocation(
      id: 'thane_central',
      name: 'Civil Hospital Road, Thane',
      district: 'Thane',
      lat: 19.2183,
      lng: 72.9781,
      nearbyFacility: 'Thane District Civil Hospital',
    ),
  ];

  Future<void> _loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('patient_gps_lat');
      final lng = prefs.getDouble('patient_gps_lng');
      final name = prefs.getString('patient_gps_name');
      final isGps = prefs.getBool('patient_is_live_gps') ?? false;
      if (lat != null && lng != null && name != null) {
        _latitude = lat;
        _longitude = lng;
        _locationName = name;
        _isLiveGps = isGps;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('patient_gps_lat', _latitude);
      await prefs.setDouble('patient_gps_lng', _longitude);
      await prefs.setString('patient_gps_name', _locationName);
      await prefs.setBool('patient_is_live_gps', _isLiveGps);
    } catch (_) {}
  }

  /// Trigger device/browser GPS detection
  void detectLiveGps() {
    _isDetecting = true;
    _errorMessage = null;
    notifyListeners();

    queryBrowserGps(
      (lat, lng, acc) {
        _latitude = lat;
        _longitude = lng;
        _accuracyMeters = acc;
        _isLiveGps = true;
        _isDetecting = false;
        _errorMessage = null;

        // Check nearest Maharashtra location or label as Live GPS
        _locationName = _resolveNearestMaharashtraName(lat, lng);
        _saveLocation();
        notifyListeners();
      },
      (err) {
        _isDetecting = false;
        _errorMessage = err;
        // Keep active Maharashtra fallback
        if (_locationName.isEmpty) {
          _locationName = 'Shivajinagar, Pune, Maharashtra';
        }
        notifyListeners();
      },
    );
  }

  /// Manually select a Maharashtra preset district
  void selectPreset(MaharashtraLocation loc) {
    _latitude = loc.lat;
    _longitude = loc.lng;
    _locationName = '${loc.name}, Maharashtra';
    _isLiveGps = false;
    _errorMessage = null;
    _saveLocation();
    notifyListeners();
  }

  /// Sets custom coordinates with location label
  void setCustomLocation({
    required double lat,
    required double lng,
    required String name,
    bool isLive = false,
  }) {
    _latitude = lat;
    _longitude = lng;
    _locationName = name;
    _isLiveGps = isLive;
    _errorMessage = null;
    _saveLocation();
    notifyListeners();
  }

  /// Resolve readable name for acquired coordinates
  String _resolveNearestMaharashtraName(double lat, double lng) {
    double minDistance = double.infinity;
    MaharashtraLocation? closest;

    for (final loc in maharashtraPresets) {
      final dLat = (loc.lat - lat);
      final dLng = (loc.lng - lng);
      final dist = math.sqrt(dLat * dLat + dLng * dLng);
      if (dist < minDistance) {
        minDistance = dist;
        closest = loc;
      }
    }

    // If within ~30 km of a known preset
    if (closest != null && minDistance < 0.3) {
      return '${closest.name}, Maharashtra (Live GPS)';
    }

    // Default formatting with Maharashtra tag
    return 'Live GPS Location (${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E), Maharashtra';
  }
}
