import 'dart:async';
import 'package:location/location.dart';

class LocationService {
  final Location _location = Location();

  /// Demande service + permission et retourne true si tout OK.
  Future<bool> requestPermissionAndService() async {
    // service GPS
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }

    // permission
    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }
    if (permission == PermissionStatus.denied ||
        permission == PermissionStatus.deniedForever) {
      return false;
    }

    // settings : précision / interval / distance filter
    try {
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 1000, // ms
        distanceFilter: 0, // meters
      );
    } catch (e) {
      // certaines versions peuvent ne pas supporter changeSettings ; on ignore l'erreur
    }

    return true;
  }

  Future<LocationData> getCurrent() => _location.getLocation();

  /// Stream de positions
  Stream<LocationData> onLocationChanged() => _location.onLocationChanged;
}
