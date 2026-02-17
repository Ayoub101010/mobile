// lib/collection_manager.dart - VERSION CORRIGÉE
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import '../models/collection_models.dart';
import 'collection_service.dart';

class CollectionManager extends ChangeNotifier {
  final CollectionService _collectionService = CollectionService();
  static int _nextPisteId = 1;
  static int _nextChausseeId = 1;

  LigneCollection? _ligneCollection;
  ChausseeCollection? _chausseeCollection;
  SpecialCollection? _specialCollection;
  int _countdown = 20;

  // Getters
  LigneCollection? get ligneCollection => _ligneCollection;
  ChausseeCollection? get chausseeCollection => _chausseeCollection;
  SpecialCollection? get specialCollection => _specialCollection;
  int get countdown => _countdown;

  bool get hasActiveCollection => (_ligneCollection?.isActive ?? false) || (_chausseeCollection?.isActive ?? false) || (_specialCollection?.isActive ?? false);
  bool get hasPausedCollection => (_ligneCollection?.isPaused ?? false) || (_chausseeCollection?.isPaused ?? false) || (_specialCollection?.isPaused ?? false);

  String? get activeCollectionType {
    if (_ligneCollection?.isActive ?? false) return 'ligne';
    if (_chausseeCollection?.isActive ?? false) return 'chaussée';
    if (_specialCollection?.isActive ?? false) return 'spéciale';
    return null;
  }

  void startSpecialCollection({
    required String specialType,
    required LatLng initialPosition,
    required Stream<LocationData> locationStream,
  }) {
    if (hasActiveCollection) {
      throw Exception('Une collecte est déjà en cours.');
    }

    _specialCollection = SpecialCollection(
      id: _nextPisteId++,
      specialType: specialType,
      status: CollectionStatus.active,
      points: [
        initialPosition
      ],
      startTime: DateTime.now(),
      lastPointTime: DateTime.now(),
    );

    _startCollectionService(_specialCollection!, locationStream);
    notifyListeners();
  }

  CollectionResult? finishSpecialCollection() {
    if (_specialCollection == null) return null;

    if (!_collectionService.canFinishCollection(_specialCollection!)) {
      return null;
    }

    final result = CollectionResult(
      id: _specialCollection!.id,
      codePiste: null,
      type: CollectionType.special,
      points: List<LatLng>.from(_specialCollection!.points),
      totalDistance: _specialCollection!.totalDistance,
      startTime: _specialCollection!.startTime,
      endTime: DateTime.now(),
    );

    _specialCollection = null;
    _collectionService.stopCollection();
    notifyListeners();

    return result;
  }

  /// Démarre une collecte de ligne
  void startLigneCollection({
    required String codePiste, // ✅ Code piste saisi par l'utilisateur
    required LatLng initialPosition,
    required Stream<LocationData> locationStream,
  }) {
    if (hasActiveCollection) {
      throw Exception('Une collecte est déjà en cours. Veuillez la mettre en pause d\'abord.');
    }

    _ligneCollection = LigneCollection(
      id: _nextPisteId++, // ✅ Générer ID automatiquement
      codePiste: codePiste, // ✅ Utiliser le code piste fourni
      status: CollectionStatus.active,
      points: [
        initialPosition
      ],
      startTime: DateTime.now(),
      lastPointTime: DateTime.now(),
    );

    _startCollectionService(_ligneCollection!, locationStream);
    notifyListeners();
  }

  /// Démarre une collecte de chaussée
  void startChausseeCollection({
    required LatLng initialPosition,
    required Stream<LocationData> locationStream,
  }) {
    if (hasActiveCollection) {
      throw Exception('Une collecte est déjà en cours. Veuillez la mettre en pause d\'abord.');
    }

    _chausseeCollection = ChausseeCollection(
      id: _nextChausseeId++, // ✅ Générer ID automatiquement
      status: CollectionStatus.active,
      points: [
        initialPosition
      ],
      startTime: DateTime.now(),
      lastPointTime: DateTime.now(),
    );

    _startCollectionService(_chausseeCollection!, locationStream);
    notifyListeners();
  }

  /// Démarre le service de collecte pour une collection donnée
  void _startCollectionService(CollectionBase collection, Stream<LocationData> locationStream) {
    _collectionService.startCollection(
      collection: collection,
      locationStream: locationStream,
      onPointAdded: (point, distance) {
        _addPointToCollection(collection.type, point, distance);
      },
      onCountdownChanged: (seconds) {
        _countdown = seconds;
        notifyListeners();
      },
    );
  }

  /// Ajoute un point à la collecte appropriée
  void _addPointToCollection(CollectionType type, LatLng point, double distance) {
    if (type == CollectionType.ligne && _ligneCollection != null) {
      final updatedPoints = List<LatLng>.from(_ligneCollection!.points)..add(point);
      final newDistance = _ligneCollection!.totalDistance + distance;

      _ligneCollection = _ligneCollection!.copyWith(
        points: updatedPoints,
        totalDistance: newDistance,
        lastPointTime: DateTime.now(),
      );
    } else if (type == CollectionType.chaussee && _chausseeCollection != null) {
      final updatedPoints = List<LatLng>.from(_chausseeCollection!.points)..add(point);
      final newDistance = _chausseeCollection!.totalDistance + distance;

      _chausseeCollection = _chausseeCollection!.copyWith(
        points: updatedPoints,
        totalDistance: newDistance,
        lastPointTime: DateTime.now(),
      );
    } else if (type == CollectionType.special && _specialCollection != null) {
      final updatedPoints = List<LatLng>.from(_specialCollection!.points)..add(point);
      final newDistance = _specialCollection!.totalDistance + distance;

      _specialCollection = _specialCollection!.copyWith(
        points: updatedPoints,
        totalDistance: newDistance,
        lastPointTime: DateTime.now(),
      );
    }

    notifyListeners();
  }

  /// Met en pause une collecte de ligne
  void pauseLigneCollection() {
    if (_ligneCollection?.isActive ?? false) {
      _ligneCollection = _ligneCollection!.copyWith(
        status: CollectionStatus.paused,
      );
      _collectionService.stopCollection();
      notifyListeners();
    }
  }

  /// Met en pause une collecte de chaussée
  void pauseChausseeCollection() {
    if (_chausseeCollection?.isActive ?? false) {
      _chausseeCollection = _chausseeCollection!.copyWith(
        status: CollectionStatus.paused,
      );
      _collectionService.stopCollection();
      notifyListeners();
    }
  }

  /// Reprend une collecte de ligne
  void resumeLigneCollection(Stream<LocationData> locationStream) {
    if (_ligneCollection?.isPaused ?? false) {
      if (hasActiveCollection) {
        throw Exception('Une autre collecte est en cours. Veuillez la mettre en pause d\'abord.');
      }

      _ligneCollection = _ligneCollection!.copyWith(
        status: CollectionStatus.active,
      );
      _startCollectionService(_ligneCollection!, locationStream);
      notifyListeners();
    }
  }

  /// Reprend une collecte de chaussée
  void resumeChausseeCollection(Stream<LocationData> locationStream) {
    if (_chausseeCollection?.isPaused ?? false) {
      if (hasActiveCollection) {
        throw Exception('Une autre collecte est en cours. Veuillez la mettre en pause d\'abord.');
      }

      _chausseeCollection = _chausseeCollection!.copyWith(
        status: CollectionStatus.active,
      );
      _startCollectionService(_chausseeCollection!, locationStream);
      notifyListeners();
    }
  }

  /// Met en pause une collecte spéciale (Zone de Plaine)
  void pauseSpecialCollection() {
    if (_specialCollection?.isActive ?? false) {
      _specialCollection = _specialCollection!.copyWith(
        status: CollectionStatus.paused,
      );
      _collectionService.stopCollection();
      notifyListeners();
    }
  }

  /// Reprend une collecte spéciale (Zone de Plaine)
  void resumeSpecialCollection(Stream<LocationData> locationStream) {
    if (_specialCollection?.isPaused ?? false) {
      if (hasActiveCollection) {
        throw Exception('Une autre collecte est en cours. Veuillez la mettre en pause d\'abord.');
      }

      _specialCollection = _specialCollection!.copyWith(
        status: CollectionStatus.active,
      );
      _startCollectionService(_specialCollection!, locationStream);
      notifyListeners();
    }
  }

  /// Termine une collecte de ligne
  CollectionResult? finishLigneCollection() {
    if (_ligneCollection == null) return null;

    if (!_collectionService.canFinishCollection(_ligneCollection!)) {
      return null;
    }

    final result = CollectionResult(
      id: _ligneCollection!.id,
      codePiste: _ligneCollection!.codePiste, // ✅ Inclure le code piste
      type: CollectionType.ligne,
      points: List<LatLng>.from(_ligneCollection!.points),
      totalDistance: _ligneCollection!.totalDistance,
      startTime: _ligneCollection!.startTime,
      endTime: DateTime.now(),
    );

    _ligneCollection = null;
    _collectionService.stopCollection();
    notifyListeners();

    return result;
  }

  /// Termine une collecte de chaussée
  CollectionResult? finishChausseeCollection() {
    if (_chausseeCollection == null) return null;

    if (!_collectionService.canFinishCollection(_chausseeCollection!)) {
      return null;
    }

    final result = CollectionResult(
      id: _chausseeCollection!.id,
      codePiste: null, // ✅ Pas de code piste pour chaussée
      type: CollectionType.chaussee,
      points: List<LatLng>.from(_chausseeCollection!.points),
      totalDistance: _chausseeCollection!.totalDistance,
      startTime: _chausseeCollection!.startTime,
      endTime: DateTime.now(),
    );

    _chausseeCollection = null;
    _collectionService.stopCollection();
    notifyListeners();

    return result;
  }

  /// ✅ MÉTHODE MANQUANTE AJOUTÉE - Ajoute un point manuellement pour debug/simulation
  void addManualPoint(CollectionType type, LatLng point) {
    if (type == CollectionType.ligne && (_ligneCollection?.isActive ?? false)) {
      final lastPoint = _ligneCollection!.points.isNotEmpty ? _ligneCollection!.points.last : point;
      final distance = _collectionService.calculateTotalDistance([
        lastPoint,
        point
      ]);
      _addPointToCollection(type, point, distance);
    } else if (type == CollectionType.chaussee && (_chausseeCollection?.isActive ?? false)) {
      final lastPoint = _chausseeCollection!.points.isNotEmpty ? _chausseeCollection!.points.last : point;
      final distance = _collectionService.calculateTotalDistance([
        lastPoint,
        point
      ]);
      _addPointToCollection(type, point, distance);
    } else if (type == CollectionType.special && (_specialCollection?.isActive ?? false)) {
      final lastPoint = _specialCollection!.points.isNotEmpty ? _specialCollection!.points.last : point;
      final distance = _collectionService.calculateTotalDistance([
        lastPoint,
        point
      ]);
      _addPointToCollection(type, point, distance);
    }
  }

  @override
  void dispose() {
    _collectionService.dispose();
    super.dispose();
  }
}
