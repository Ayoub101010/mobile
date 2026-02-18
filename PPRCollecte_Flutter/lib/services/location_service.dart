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
    if (permission == PermissionStatus.denied || permission == PermissionStatus.deniedForever) {
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
      // certaines versions peuvent ne pas supporter changeSettings
    }

    // ===== FOREGROUND SERVICE =====
    // Garde le GPS actif quand l'app est en arrière-plan
    // (essentiel pour la collecte de pistes/polygones)
    try {
      await _location.enableBackgroundMode(enable: true);
      print('✅ Background mode (foreground service) activé');
    } catch (e) {
      print('⚠️ Impossible d\'activer le background mode: $e');
    }

    return true;
  }

  Future<LocationData> getCurrent() => _location.getLocation();

  /// Stream de positions.
  /// Accepte automatiquement les Mock Locations
  /// (envoyées par GNSS Master, Lefebure NTRIP, etc.)
  /// car le plugin `location` ne filtre pas les mocks par défaut.
  Stream<LocationData> onLocationChanged() => _location.onLocationChanged;
}
