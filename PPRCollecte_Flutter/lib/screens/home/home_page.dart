// ============================================================
// lib/screens/home/home_page.dart
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:math';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ============================================================
// WIDGETS
// ============================================================
import '../../widgets/common/top_bar_widget.dart';
import '../../widgets/common/bottom_buttons_widget.dart';
import '../../widgets/common/bottom_status_bar_widget.dart';
import '../../widgets/common/custom_marker_icons.dart';
import '../../widgets/map/map_widget.dart';
import '../../widgets/map/map_controls_widget.dart';
import '../../widgets/map/legend_widget.dart';
import '../../widgets/status/collection_status_widgets.dart';
import '../../widgets/forms/provisional_form_dialog.dart';

// ============================================================
// CONTROLLERS
// ============================================================
import '../../controllers/home_controller.dart';

// ============================================================
// SERVICES
// ============================================================
import '../../services/sync_service.dart';

// ============================================================
// DATA
// ============================================================
import '../../data/local/database_helper.dart';
import '../../data/local/piste_chaussee_db_helper.dart';
import '../../data/remote/api_service.dart';

// ============================================================
// MODELS
// ============================================================
import '../../models/collection_models.dart';

// ============================================================
// SCREENS
// ============================================================
import '../auth/login_page.dart';
import '../data/data_categories_page.dart';
import '../forms/point_form_screen.dart';
import '../forms/special_line_form_page.dart';
import '../forms/formulaire_ligne_page.dart';
import '../forms/formulaire_chaussee_page.dart';
import '../forms/polygon_form_page.dart';
import 'package:flutter_map/flutter_map.dart' show Polygon; // si pas déjà importé

class MapFocusTarget {
  final String kind; // 'point' | 'polyline'
  final LatLng? point;
  final List<LatLng>? polyline;
  final String? label;
  final String? id;

  const MapFocusTarget.point({
    required LatLng this.point,
    this.label,
    this.id,
  })  : kind = 'point',
        polyline = null;

  const MapFocusTarget.polyline({
    required List<LatLng> this.polyline,
    this.label,
    this.id,
  })  : kind = 'polyline',
        point = null;
}

class HomePage extends StatefulWidget {
  final Function onLogout;
  final String agentName;
  final bool isOnline;
  final MapFocusTarget? initialFocus;
  const HomePage({
    super.key,
    required this.onLogout,
    required this.agentName,
    required this.isOnline,
    this.initialFocus,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LatLng? userPosition;
  bool gpsEnabled = true;
  String _regionNom = '----';
  String _prefectureNom = '----';
  String _communeNom = '----';

  DateTime? _suspendAutoCenterUntil;
  bool _autoCenterDisabledByUser = false;
  List<Marker> collectedMarkers = [];
  List<Polyline> collectedPolylines = [];
  List<Polyline> _finishedPistes = []; // ← AJOUTEZ ICI
  List<Polyline> _finishedChaussees = [];
  List<Marker> formMarkers = [];
  bool isSyncing = false;
  bool isDownloading = false;
  SyncResult? lastSyncResult;
  double _progressValue = 0.0;
  String _currentOperation = "Préparation de la sauvegarde...";
  int _totalItems = 0;
  int _processedItems = 0;
  double _syncProgressValue = 0.0;
  String _currentSyncOperation = "Préparation de la synchronisation...";
  int _syncTotalItems = 0;
  int _syncProcessedItems = 0;
  List<Marker> _displayedPointsMarkers = [];
  String? _currentNearestPisteCode;
  bool _isSpecialCollection = false;
  String? _specialCollectionType;
  bool _isPolygonCollection = false;
  List<Polygon> _displayedPolygons = [];
  Map<String, int> _pointCountsByTable = {};
  MapController? _mapController;
  LatLng? _lastCameraPosition;
  late final HomeController homeController;
  final DisplayedPointsService _pointsService = DisplayedPointsService();
  final SpecialLinesService _specialLinesService = SpecialLinesService();
  List<Polyline> _displayedSpecialLines = [];
  final DownloadedPointsService _downloadedPointsService = DownloadedPointsService();
  List<Marker> _downloadedPointsMarkers = [];
  bool _showDownloadedPoints = true;
  // Markers séparés par table pour le filtrage par sous-type
  Map<String, List<Marker>> _displayedPointsByTable = {};
  Map<String, List<Marker>> _downloadedPointsByTable = {};
  bool _isSatellite = false;
  final DownloadedSpecialLinesService _downloadedSpecialLinesService = DownloadedSpecialLinesService();
  List<Polyline> _downloadedSpecialLinesPolylines = [];
  bool _showDownloadedSpecialLines = true;

  // Téléchargés : Pistes

  final DownloadedPistesService _downloadedPistesService = DownloadedPistesService();
  List<Polyline> _downloadedPistesPolylines = [];
  bool _showDownloadedPistes = true; // comme pour les points
  DownloadedChausseesService _downloadedChausseesService = DownloadedChausseesService();
  List<Polyline> _downloadedChausseesPolylines = [];
  bool _showDownloadedChaussees = true;
  bool get _autoCenterSuspended => _autoCenterDisabledByUser || (_suspendAutoCenterUntil != null && DateTime.now().isBefore(_suspendAutoCenterUntil!));
  String? _lastSyncTimeText;
  late bool _isOnlineDynamic;
  Timer? _onlineWatchTimer;
// Dans _HomePageState
  Map<String, bool> _legendVisibility = {
    'points': true,
    'pistes': true,
    'chaussee_bitume': true,
    'chaussee_terre': true,
    'chaussee_latérite': true,
    'chaussee_bouwal': true,
    'chaussee_autre': true, // Pas de 'chaussee_sable'
    'bac': true,
    'passage_submersible': true,
    'zone_plaine': true,
  };
  String enqueteurDisplayByStatut({
    required String? enqueteurValue,
    required String statut,
  }) {
    final v = (enqueteurValue ?? '').trim();

    if (v.isNotEmpty && v.toLowerCase() != 'null' && v.toLowerCase() != 'sync') {
      return v;
    }

    final isLocal = statut.toLowerCase().contains('localement');
    if (isLocal) {
      final a = widget.agentName.trim();
      if (a.isNotEmpty) return a;
    }

    return '-----';
  }

  @override
  void initState() {
    super.initState();
    homeController = HomeController();
    //_cleanupDisplayedPoints();
    _loadDisplayedPistes();
    _loadDisplayedPoints();
    _loadDisplayedChaussees();
    _loadDisplayedSpecialLines();
    _loadDownloadedPoints();
    _loadDownloadedPistes();
    _loadDownloadedChaussees();
    _isOnlineDynamic = widget.isOnline;
    _loadLastSyncTime();
    _startOnlineWatcher();
    _loadAdminNamesOffline();
    _loadDownloadedSpecialLines();
    _loadDisplayedPolygons();

    homeController.addListener(
      () {
        setState(
          () {
            userPosition = homeController.userPosition;
            gpsEnabled = homeController.gpsEnabled;
            formMarkers = homeController.formMarkers;
          },
        );

        if (_mapController != null && _lastCameraPosition == null && userPosition != null) {
          _mapController!.move(userPosition!, 17);
          _lastCameraPosition = userPosition;
        } else {
          _moveCameraIfNeeded();
        }
      },
    );

    homeController.initialize();

    // Données de test initiales
    /* collectedMarkers.addAll([
      Marker(
        markerId: const MarkerId('poi1'),
        position: const LatLng(34.021, -6.841),
        infoWindow: const InfoWindow(title: 'Point d\'intérêt 1', snippet: 'Infrastructure - Point'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    ]);*/

    /* collectedPolylines.add(const Polyline(
      polylineId: PolylineId('piste1'),
      points: [
        LatLng(34.020, -6.840),
        LatLng(34.022, -6.842),
        LatLng(34.023, -6.843),
      ],
      color: Colors.blue,
      width: 3,
    ));*/
  }

  String _safe(dynamic v, {String empty = '----'}) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return empty;
    if (s.toLowerCase() == 'null') return empty;
    return s;
  }

  String _enqueteurDisplay(dynamic v) {
    final s = _safe(v, empty: '-----'); // tu voulais "-----" pour enqueteur
    if (s == '-----') return s;

    final lower = s.toLowerCase();

    // ✅ uniquement des valeurs "techniques" exactes (pas contains)
    const badExact = {
      'sync',
      'synced',
      'synchronise',
      'synchronisé',
      'synchronisee',
      'synchronisée',
      'download',
      'downloaded'
    };
    if (badExact.contains(lower)) return '-----';

    // ✅ si c’est juste un nombre (id), on masque
    final onlyDigits = RegExp(r'^\d+$');
    if (onlyDigits.hasMatch(s)) return '-----';

    return s;
  }

  Future<void> _loadDownloadedSpecialLines() async {
    print('🔄 [_loadDownloadedSpecialLines] start');

    try {
      final lines = await _downloadedSpecialLinesService.getDownloadedSpecialLinesPolylines(
        onTapDetails: (data) {
          final start = LatLng(
            (data['start_lat'] as num).toDouble(),
            (data['start_lng'] as num).toDouble(),
          );
          final end = LatLng(
            (data['end_lat'] as num).toDouble(),
            (data['end_lng'] as num).toDouble(),
          );

          final distanceKm = polylineDistanceKm([
            start,
            end
          ]);

          _showSpecialLineDetailsSheet(
            context: context,
            specialType: (data['special_type'] ?? '----').toString(),
            statut: 'Sauvegardée (downloaded)',
            region: _regionNom,
            prefecture: _prefectureNom,
            commune: _communeNom,
            distanceKm: distanceKm,
            startLat: start.latitude,
            startLng: start.longitude,
            endLat: end.latitude,
            endLng: end.longitude,
          );
        },
      );

      setState(() {
        _downloadedSpecialLinesPolylines = lines;
      });

      print('✅ [_loadDownloadedSpecialLines] ${lines.length} lignes téléchargées');
    } catch (e) {
      print('❌ [_loadDownloadedSpecialLines] $e');
    }

    print('✅ [_loadDownloadedSpecialLines] done');
  }

  void _showChausseeDetailsSheet({
    required BuildContext context,
    required String statut,
    required String typeChaussee,
    required String endroit,
    required String codePiste,
    String? enqueteur,
    required String region,
    required String prefecture,
    required String commune,
    required int nbPoints,
    required double distanceKm,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    String safe(dynamic s) {
      final v = (s ?? '').toString().trim();
      if (v.isEmpty) return '----';
      // évite "null"
      if (v.toLowerCase() == 'null') return '----';
      return v;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Chaussée — ${safe(typeChaussee)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _detailRow('Statut', safe(statut)),
              if (!statut.toLowerCase().contains('localement')) ...[
                _detailRow('Région', safe(region)),
                _detailRow('Préfecture', safe(prefecture)),
                _detailRow('Commune', safe(commune)),
              ],
              _detailRow('Type', safe(typeChaussee)),
              _detailRow(
                'Enquêteur',
                enqueteurDisplayByStatut(enqueteurValue: enqueteur, statut: statut),
              ),
              _detailRow('Endroit', safe(endroit)),
              _detailRow('Code piste', safe(codePiste)),
              _detailRow('Nb points', nbPoints.toString()),
              _detailRow('Début', 'X=${startLng.toStringAsFixed(6)} • Y=${startLat.toStringAsFixed(6)}'),
              _detailRow('Fin', 'X=${endLng.toStringAsFixed(6)} • Y=${endLat.toStringAsFixed(6)}'),
              _detailRow('Distance', '${distanceKm.toStringAsFixed(2)} km'),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSpecialLineDetailsSheet({
    required BuildContext context,
    required String specialType, // "Bac" / "Passage Submersible"
    required String statut,
    String? enqueteur, // "Enregistrée localement"
    required String region,
    required String prefecture,
    required String commune,
    required double distanceKm,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    String safe(dynamic s) {
      final v = (s ?? '').toString().trim();
      if (v.isEmpty || v.toLowerCase() == 'null') return '----';
      return v;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${safe(specialType)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _detailRow('Statut', safe(statut)),
              _detailRow(
                'Enquêteur',
                enqueteurDisplayByStatut(enqueteurValue: enqueteur, statut: statut),
              ),
              if (!statut.toLowerCase().contains('localement')) ...[
                _detailRow('Région', safe(region)),
                _detailRow('Préfecture', safe(prefecture)),
                _detailRow('Commune', safe(commune)),
              ],
              _detailRow('Début', 'X=${startLng.toStringAsFixed(6)} • Y=${startLat.toStringAsFixed(6)}'),
              _detailRow('Fin', 'X=${endLng.toStringAsFixed(6)} • Y=${endLat.toStringAsFixed(6)}'),
              _detailRow('Distance', '${distanceKm.toStringAsFixed(2)} km'),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPisteDetailsSheet({
    required BuildContext context,
    required String codePiste,
    String? enqueteur,
    required String region,
    required String prefecture,
    required String commune,
    required String statut, // "Enregistrée" / "Sauvegardée"
    required int nbPoints,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required double distanceKm,
    String? plateforme,
    String? relief,
    String? vegetation,
    String? debutTravaux,
    String? finTravaux,
    String? financement,
    String? projet,
    String? entreprise,
  }) {
    String safe(String? s) => (s ?? '').trim().isEmpty ? '----' : s!.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Piste — ${safe(codePiste)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _detailRow('Statut', safe(statut)),
              _detailRow(
                'Enquêteur',
                enqueteurDisplayByStatut(enqueteurValue: enqueteur, statut: statut),
              ),
              if (!statut.toLowerCase().contains('localement')) ...[
                _detailRow('Région', safe(region)),
                _detailRow('Préfecture', safe(prefecture)),
                _detailRow('Commune', safe(commune)),
              ],
              _detailRow('Nb points', nbPoints.toString()),
              _detailRow('Début', 'X=${startLng.toStringAsFixed(6)} • Y=${startLat.toStringAsFixed(6)}'),
              _detailRow('Fin', 'X=${endLng.toStringAsFixed(6)} • Y=${endLat.toStringAsFixed(6)}'),
              _detailRow('Distance', '${distanceKm.toStringAsFixed(2)} km'),
              const Divider(),
              _detailRow('Plateforme', safe(plateforme)),
              _detailRow('Relief', safe(relief)),
              _detailRow('Végétation', safe(vegetation)),
              _detailRow('Début travaux', safe(debutTravaux)),
              _detailRow('Fin travaux', safe(finTravaux)),
              _detailRow('Financement', safe(financement)),
              _detailRow('Projet', safe(projet)),
              _detailRow('Entreprise', safe(entreprise)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPointDetailsSheet({
    required BuildContext context,
    required String type,
    required String name,
    required String region,
    required String prefecture,
    required String commune,
    required String enqueteur,
    required String codePiste,
    required double lat,
    required double lng,
    required String statut,
  }) {
    String safe(String s) => s.trim().isEmpty ? '----' : s.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$type — ${safe(name)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _detailRow('Statut', safe(statut)),
              if (!statut.toLowerCase().contains('localement')) ...[
                _detailRow('Région', safe(region)),
                _detailRow('Préfecture', safe(prefecture)),
                _detailRow('Commune', safe(commune)),
              ],
              _detailRow(
                'Enquêteur',
                enqueteurDisplayByStatut(enqueteurValue: enqueteur, statut: statut),
              ),
              _detailRow('Code piste', safe(codePiste)),
              _detailRow('Coordonnées', 'X=${lng.toStringAsFixed(6)}  •  Y=${lat.toStringAsFixed(6)}'),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handlePolylineTap(Object? hitValue) {
    if (hitValue == null || hitValue is! PolylineTapData) return;

    final tapData = hitValue;
    final type = tapData.type;
    final data = tapData.data;

    print('🖱️ Polyline tappée: type=$type');

    switch (type) {
      case 'piste_local':
      case 'piste_downloaded':
        _showPisteDetailsSheet(
          context: context,
          codePiste: (data['code_piste'] ?? '----').toString(),
          statut: type == 'piste_local' ? ((data['synced'].toString() == '1') ? 'Synchronisée' : 'Enregistrée localement') : 'Sauvegardée (downloaded)',
          region: type == 'piste_downloaded'
              ? (data['region_name'] ?? '----').toString()
              : (data['region_name'] ?? '').toString().isNotEmpty
                  ? (data['region_name']).toString()
                  : _regionNom,
          prefecture: type == 'piste_downloaded'
              ? (data['prefecture_name'] ?? '----').toString()
              : (data['prefecture_name'] ?? '').toString().isNotEmpty
                  ? (data['prefecture_name']).toString()
                  : _prefectureNom,
          commune: type == 'piste_downloaded'
              ? (data['commune_name'] ?? '----').toString()
              : (data['commune_name'] ?? '').toString().isNotEmpty
                  ? (data['commune_name']).toString()
                  : _communeNom,
          enqueteur: (data['enqueteur'] ?? '').toString(),
          nbPoints: (data['nb_points'] as int?) ?? 0,
          distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0.0,
          startLat: (data['start_lat'] as num).toDouble(),
          startLng: (data['start_lng'] as num).toDouble(),
          endLat: (data['end_lat'] as num).toDouble(),
          endLng: (data['end_lng'] as num).toDouble(),
          plateforme: (data['plateforme'] ?? '----').toString(),
          relief: (data['relief'] ?? '----').toString(),
          vegetation: (data['vegetation'] ?? '----').toString(),
          debutTravaux: (data['debut_travaux'] ?? '----').toString(),
          finTravaux: (data['fin_travaux'] ?? '----').toString(),
          financement: (data['financement'] ?? '----').toString(),
          projet: (data['projet'] ?? '----').toString(),
          entreprise: (data['entreprise'] ?? '----').toString(),
        );
        break;

      case 'chaussee_local':
      case 'chaussee_downloaded':
        _showChausseeDetailsSheet(
          context: context,
          statut: type == 'chaussee_local' ? ((data['synced'].toString() == '1') ? 'Synchronisée' : 'Enregistrée localement') : 'Sauvegardée (downloaded)',
          typeChaussee: (data['type_chaussee'] ?? '----').toString(),
          endroit: (data['endroit'] ?? '----').toString(),
          codePiste: (data['code_piste'] ?? '----').toString(),
          region: type == 'chaussee_downloaded'
              ? (data['region_name'] ?? '----').toString()
              : (data['region_name'] ?? '').toString().isNotEmpty
                  ? (data['region_name']).toString()
                  : _regionNom,
          prefecture: type == 'chaussee_downloaded'
              ? (data['prefecture_name'] ?? '----').toString()
              : (data['prefecture_name'] ?? '').toString().isNotEmpty
                  ? (data['prefecture_name']).toString()
                  : _prefectureNom,
          commune: type == 'chaussee_downloaded'
              ? (data['commune_name'] ?? '----').toString()
              : (data['commune_name'] ?? '').toString().isNotEmpty
                  ? (data['commune_name']).toString()
                  : _communeNom,
          enqueteur: (data['enqueteur'] ?? '').toString(),
          nbPoints: (data['nb_points'] as int?) ?? 0,
          distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0.0,
          startLat: (data['start_lat'] as num).toDouble(),
          startLng: (data['start_lng'] as num).toDouble(),
          endLat: (data['end_lat'] as num).toDouble(),
          endLng: (data['end_lng'] as num).toDouble(),
        );
        break;

      case 'special_local':
      case 'special_downloaded':
        _showSpecialLineDetailsSheet(
          context: context,
          specialType: (data['special_type'] ?? '----').toString(),
          statut: type == 'special_local' ? ((data['synced'].toString() == '1') ? 'Synchronisée' : 'Enregistrée localement') : 'Sauvegardée (downloaded)',
          region: type == 'special_downloaded'
              ? (data['region_name'] ?? '----').toString()
              : (data['region_name'] ?? '').toString().isNotEmpty
                  ? (data['region_name']).toString()
                  : _regionNom,
          prefecture: type == 'special_downloaded'
              ? (data['prefecture_name'] ?? '----').toString()
              : (data['prefecture_name'] ?? '').toString().isNotEmpty
                  ? (data['prefecture_name']).toString()
                  : _prefectureNom,
          commune: type == 'special_downloaded'
              ? (data['commune_name'] ?? '----').toString()
              : (data['commune_name'] ?? '').toString().isNotEmpty
                  ? (data['commune_name']).toString()
                  : _communeNom,
          enqueteur: (data['enqueteur'] ?? '').toString(),
          distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0.0,
          startLat: (data['start_lat'] as num).toDouble(),
          startLng: (data['start_lng'] as num).toDouble(),
          endLat: (data['end_lat'] as num).toDouble(),
          endLng: (data['end_lng'] as num).toDouble(),
        );
        break;
    }
  }

  void _handlePolygonTap(Object? hitValue) {
    if (hitValue == null || hitValue is! PolygonTapData) return;
    final data = hitValue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Zone de Plaine — ${data.nom}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _detailRow('Statut', data.statut),
              _detailRow('Code piste', data.codePiste),
              // Région/Préfecture/Commune: visible seulement si downloaded ou synced
              if (data.downloaded || data.synced) ...[
                _detailRow('Région', data.regionName.isEmpty ? '----' : data.regionName),
                _detailRow('Préfecture', data.prefectureName.isEmpty ? '----' : data.prefectureName),
                _detailRow('Commune', data.communeName.isEmpty ? '----' : data.communeName),
              ],
              _detailRow('Superficie', '${data.superficie.toStringAsFixed(4)} ha'),
              _detailRow('Sommets', '${data.nbSommets} points'),
              _detailRow(
                  'Enquêteur',
                  enqueteurDisplayByStatut(
                    enqueteurValue: data.enqueteur,
                    statut: data.statut,
                  )),
              _detailRow('Date création', data.dateCreation.length > 10 ? data.dateCreation.substring(0, 10) : data.dateCreation),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _sanitizeEnqueteur(String? v) {
    if (v == null) return '----';

    final s = v.trim();
    if (s.isEmpty) return '----';

    final lower = s.toLowerCase();

    // valeurs techniques à masquer
    if (lower == '0' || lower == '1') return '----';
    if (lower.contains('sync')) return '----'; // sync, synced, date_sync...
    if (lower.contains('download')) return '----'; // downloaded...

    return s;
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAdminNamesOffline() async {
    try {
      // 1) SQLite (offline)
      final user = await DatabaseHelper().getCurrentUser();
      final r = (user?['region_nom'] ?? '').toString().trim();
      final p = (user?['prefecture_nom'] ?? '').toString().trim();
      final c = (user?['commune_nom'] ?? '').toString().trim();

      // 2) fallback ApiService si sqlite vide
      String rr = r.isNotEmpty ? r : (ApiService.regionNom ?? '').toString().trim();
      String pp = p.isNotEmpty ? p : (ApiService.prefectureNom ?? '').toString().trim();
      String cc = c.isNotEmpty ? c : (ApiService.communeNom ?? '').toString().trim();

      // 3) ===== NOUVEAU : Fallback RBAC pour BTGR / SPGR =====
      // BTGR → afficher les régions assignées
      if (rr.isEmpty && ApiService.assignedRegions.isNotEmpty) {
        rr = ApiService.assignedRegions.map((r) => (r['region_nom'] ?? '').toString()).where((n) => n.isNotEmpty).join(', ');
      }
      // SPGR → afficher les préfectures assignées
      if (pp.isEmpty && ApiService.assignedPrefectures.isNotEmpty) {
        pp = ApiService.assignedPrefectures.map((p) => (p['prefecture_nom'] ?? '').toString()).where((n) => n.isNotEmpty).join(', ');
      }
      // Commune → afficher le nombre de communes accessibles
      if (cc.isEmpty && ApiService.accessibleCommuneIds.isNotEmpty) {
        cc = '${ApiService.accessibleCommuneIds.length} communes';
      }

      if (!mounted) return;
      setState(() {
        _regionNom = rr.isEmpty ? '----' : rr;
        _prefectureNom = pp.isEmpty ? '----' : pp;
        _communeNom = cc.isEmpty ? '----' : cc;
      });
    } catch (_) {
      // on laisse ----
    }
  }

  void _suspendAutoCenterFor(Duration d) {
    _suspendAutoCenterUntil = DateTime.now().add(d);
    // Debug
    // print('⏸️ auto-center suspendu jusqu\'à $_suspendAutoCenterUntil');
  }

  void _startOnlineWatcher() {
    // On annule un éventuel ancien timer
    _onlineWatchTimer?.cancel();

    // Premier check immédiat
    _checkOnlineStatus();

    // Puis check toutes les 10 secondes (ajuste si tu veux)
    _onlineWatchTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkOnlineStatus(),
    );
  }
// === AJOUTEZ CES MÉTHODES ===

// Méthode utilitaire pour déterminer le type de chaussée depuis sa couleur
  String _getChausseeTypeFromColor(Color color) {
    if (color == Colors.black) return 'bitume';
    if (color.value == const Color(0xFFD2691E).value) return 'terre';
    if (color.value == Colors.red.shade700.value) return 'latérite';
    if (color.value == Colors.yellow.shade700.value) return 'bouwal';
    if (color == Colors.blueGrey) return 'autre';
    return 'inconnu';
  }

// Méthode pour filtrer les polylines selon la légende
  List<Polyline> _getFilteredPolylines() {
    final List<Polyline> filtered = List<Polyline>.from(collectedPolylines);
    if (_legendVisibility['pistes'] == true) {
      filtered.addAll(_finishedPistes);
    }

    // 2. Pistes téléchargées - selon légende
    if (_legendVisibility['pistes'] == true && _showDownloadedPistes) {
      filtered.addAll(_downloadedPistesPolylines);
    }

    // 3. Chaussées finies (selon type)
    for (final chaussee in _finishedChaussees) {
      final type = _getChausseeTypeFromColor(chaussee.color);
      if (_legendVisibility['chaussee_$type'] == true) {
        filtered.add(chaussee);
      }
    }

    // 4. Chaussées téléchargées (selon type)
    if (_showDownloadedChaussees) {
      for (final chaussee in _downloadedChausseesPolylines) {
        final type = _getChausseeTypeFromColor(chaussee.color);
        if (_legendVisibility['chaussee_$type'] == true) {
          filtered.add(chaussee);
        }
      }
    }

    for (final l in _displayedSpecialLines) {
      // flutter_map n'a pas d'ID sur Polyline, on utilise la couleur pour identifier
      final color = l.color;

      // Bac = purple, Passage submersible = cyan
      final isBac = color == Colors.purple;
      final isPassage = color == Colors.cyan;

      if (isBac && (_legendVisibility['bac'] == true)) {
        filtered.add(l);
      } else if (isPassage && (_legendVisibility['passage_submersible'] == true)) {
        filtered.add(l);
      } else if (!isBac && !isPassage) {
        // fallback si jamais
        filtered.add(l);
      }
    }

    if (_showDownloadedSpecialLines) {
      for (final l in _downloadedSpecialLinesPolylines) {
        // flutter_map n'a pas d'ID sur Polyline, on utilise la couleur pour identifier
        final color = l.color;

        // Bac = purple, Passage submersible = cyan
        final isBac = color == Colors.purple;
        final isPassage = color == Colors.cyan;

        if (isBac && (_legendVisibility['bac'] == true)) {
          filtered.add(l);
        } else if (isPassage && (_legendVisibility['passage_submersible'] == true)) {
          filtered.add(l);
        } else if (!isBac && !isPassage) {
          filtered.add(l);
        }
      }
    }

    // 6. Lignes en cours (TOUJOURS visibles)
    // Ligne en cours
    if (homeController.ligneCollection != null) {
      final lignePoints = homeController.ligneCollection!.points;
      if (lignePoints.length > 1) {
        filtered.add(
          Polyline(
            points: lignePoints,
            color: homeController.ligneCollection!.isPaused ? Colors.orange : Colors.green,
            strokeWidth: 4.0,
            pattern: homeController.ligneCollection!.isPaused
                ? StrokePattern.dashed(segments: [
                    10,
                    5
                  ])
                : const StrokePattern.solid(),
          ),
        );
      }
    }

    // Chaussée en cours
    if (homeController.chausseeCollection != null) {
      final chausseePoints = homeController.chausseeCollection!.points;
      if (chausseePoints.length > 1) {
        filtered.add(
          Polyline(
            points: chausseePoints,
            color: homeController.chausseeCollection!.isPaused ? Colors.deepOrange : const Color(0xFFFF9800),
            strokeWidth: 5.0,
            pattern: homeController.chausseeCollection!.isPaused
                ? StrokePattern.dashed(segments: [
                    15,
                    5
                  ])
                : const StrokePattern.solid(),
          ),
        );
      }
    }

    // Ligne/polygone spécial en cours
    if (homeController.specialCollection != null) {
      final specialPoints = homeController.specialCollection!.points;
      if (specialPoints.length > 1) {
        if (_isPolygonCollection) {
          // Zone de Plaine : afficher comme POLYGONE semi-transparent
          // (on ajoute le contour comme polyline + le polygone sera dans _displayedPolygons)
          filtered.add(
            Polyline(
              points: [
                ...specialPoints,
                specialPoints.first
              ], // fermer le contour
              color: const Color(0xFF2E7D32),
              strokeWidth: 3.0,
              pattern: const StrokePattern.solid(),
            ),
          );
        } else {
          // Bac / Passage : afficher comme LIGNE
          final specialColor = _specialCollectionType == "Bac" ? Colors.purple : Colors.deepPurple;
          filtered.add(
            Polyline(
              points: specialPoints,
              color: specialColor,
              strokeWidth: 5.0,
              pattern: homeController.specialCollection!.isPaused
                  ? StrokePattern.dashed(segments: [
                      10,
                      5
                    ])
                  : const StrokePattern.solid(),
            ),
          );
        }
      }
    }

    return filtered;
  }

// Méthode pour filtrer les markers selon la légende
  List<Marker> _getFilteredMarkers() {
    if (_legendVisibility['points'] != true) {
      return <Marker>[];
    }

    final List<Marker> filtered = <Marker>[];

    // === Points locaux — filtrer par sous-type ===
    for (final entry in _displayedPointsByTable.entries) {
      final subKey = 'point_${entry.key}';
      if (_legendVisibility[subKey] != false) {
        filtered.addAll(entry.value);
      }
    }
    // Ajouter les markers qui ne sont dans aucune table (sécurité)
    final byTablePositions = <String>{};
    for (final markers in _displayedPointsByTable.values) {
      for (final m in markers) {
        byTablePositions.add('${m.point.latitude}_${m.point.longitude}');
      }
    }
    for (final m in _displayedPointsMarkers) {
      if (!byTablePositions.contains('${m.point.latitude}_${m.point.longitude}')) {
        filtered.add(m);
      }
    }

    // === Points téléchargés — filtrer par sous-type ===
    if (_showDownloadedPoints) {
      for (final entry in _downloadedPointsByTable.entries) {
        final subKey = 'point_${entry.key}';
        if (_legendVisibility[subKey] != false) {
          filtered.addAll(entry.value);
        }
      }
      // Ajouter les downloaded non classés
      final dlPositions = <String>{};
      for (final markers in _downloadedPointsByTable.values) {
        for (final m in markers) {
          dlPositions.add('${m.point.latitude}_${m.point.longitude}');
        }
      }
      for (final m in _downloadedPointsMarkers) {
        if (!dlPositions.contains('${m.point.latitude}_${m.point.longitude}')) {
          filtered.add(m);
        }
      }
    }

    return filtered;
  }

  /// Détermine le nom de table à partir de la couleur du marker
  String? _getTableFromMarkerColor(Marker marker) {
    // Le child du Marker est un GestureDetector > Container avec couleur
    // On compare avec les couleurs connues de CustomMarkerIcons
    for (final entry in CustomMarkerIcons.iconConfig.entries) {
      // On ne peut pas facilement extraire la couleur du widget,
      // donc on utilise _downloadedPointsByTable si disponible
    }
    return null;
  }

// Méthode pour mettre à jour la visibilité depuis la légende
  void _updateVisibilityFromLegend(Map<String, bool> visibility) {
    setState(() {
      _legendVisibility = visibility;
      _showDownloadedPoints = visibility['points'] ?? true;
      _showDownloadedPistes = visibility['pistes'] ?? true;

      // Bac + Passage submersible
      final showBac = visibility['bac'] ?? true;
      final showPassage = visibility['passage_submersible'] ?? true;
      _showDownloadedSpecialLines = showBac || showPassage;

      // Chaussées : parent + sous-types
      final chausseesParent = visibility['chaussees'] ?? true;
      final hasVisibleChaussee = chausseesParent &&
          [
            'bitume',
            'terre',
            'latérite',
            'bouwal',
            'autre'
          ].any((type) => visibility['chaussee_$type'] ?? true);
      _showDownloadedChaussees = hasVisibleChaussee;

      // Zone de plaine
      if (visibility['zone_plaine'] == false) {
        _displayedPolygons = [];
      } else {
        _loadDisplayedPolygons();
      }
    });
  }

  // APRÈS (code corrigé)
  Future<void> _checkOnlineStatus() async {
    final reachable = await _isApiReachableForStatus();
    if (!mounted) return;

    final wasOffline = !_isOnlineDynamic;

    if (reachable != _isOnlineDynamic) {
      setState(() {
        _isOnlineDynamic = reachable;
      });

      // ⭐ NOUVEAU : Quand on passe de offline → online,
      // restaurer ApiService.userId depuis la DB locale
      if (wasOffline && reachable) {
        await _restoreApiServiceFromLocal();
      }
    }
  }

  /// Restaure les champs statiques d'ApiService depuis SQLite
  /// (nécessaire après un login offline suivi d'un retour de connectivité)
  Future<void> _restoreApiServiceFromLocal() async {
    try {
      // Ne rien écraser si déjà rempli (login online classique)
      if (ApiService.userId != null) return;

      final user = await DatabaseHelper().getCurrentUser();
      if (user == null) return;

      ApiService.userId = user['apiId'] is int ? user['apiId'] : int.tryParse(user['apiId']?.toString() ?? '');
      ApiService.communeId = user['communes_rurales'] is int ? user['communes_rurales'] : int.tryParse(user['communes_rurales']?.toString() ?? '');
      ApiService.prefectureId = user['prefecture_id'] is int ? user['prefecture_id'] : int.tryParse(user['prefecture_id']?.toString() ?? '');
      ApiService.regionId = user['region_id'] is int ? user['region_id'] : int.tryParse(user['region_id']?.toString() ?? '');
      ApiService.communeNom = user['commune_nom']?.toString();
      ApiService.prefectureNom = user['prefecture_nom']?.toString();
      ApiService.regionNom = user['region_nom']?.toString();
      ApiService.userRole = user['role']?.toString();

      print('🔄 ApiService restauré depuis SQLite: userId=${ApiService.userId}, role=${ApiService.userRole}');
    } catch (e) {
      print('❌ Erreur restauration ApiService: $e');
    }
  }

  Future<bool> _isApiReachableForStatus() async {
    try {
      final uri = Uri.parse(ApiService.baseUrl);
      final host = uri.host;
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);

      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 1),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadLastSyncTime() async {
    final dt = await DatabaseHelper().getLastSyncTime();
    if (!mounted) return;
    setState(() {
      _lastSyncTimeText = dt != null ? _formatTimeHHmm(dt) : null;
    });
  }

  String _formatTimeHHmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m'; // "HH:MM"
  }

  Future<void> _loadDownloadedPistes() async {
    print('🔄 [_loadDownloadedPistes] start');
    try {
      final polylines = await _downloadedPistesService.getDownloadedPistesPolylines(
        onTapDetails: (data) {
          _showPisteDetailsSheet(
            context: context,
            codePiste: (data['code_piste'] ?? '----').toString(),
            statut: 'Sauvegardée (downloaded)',
            region: _regionNom,
            prefecture: _prefectureNom,
            commune: _communeNom,
            nbPoints: (data['nb_points'] as int?) ?? 0,
            distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0.0,
            startLat: (data['start_lat'] as num).toDouble(),
            startLng: (data['start_lng'] as num).toDouble(),
            endLat: (data['end_lat'] as num).toDouble(),
            endLng: (data['end_lng'] as num).toDouble(),
          );
        },
      );

      setState(() {
        _downloadedPistesPolylines = polylines;
      });

      final total = collectedPolylines.length + _finishedPistes.length + _finishedChaussees.length + _downloadedPistesPolylines.length;

      print('📏 [_loadDownloadedPistes] ${polylines.length} polylines reçues du service');
      print('🗺️  [_loadDownloadedPistes] total polylines (avant rendu): $total');
    } catch (e) {
      print('❌ [_loadDownloadedPistes] $e');
    }
    print('✅ [_loadDownloadedPistes] done');
  }

  LatLngBounds _boundsFor(List<LatLng> pts) {
    // flutter_map utilise fromPoints pour créer des bounds
    return LatLngBounds.fromPoints(pts);
  }

  double _deg2rad(double deg) => deg * (Math.pi / 180.0);

  double _haversineMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);

    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);

    final sinDLat = Math.sin(dLat / 2);
    final sinDLng = Math.sin(dLng / 2);

    final h = sinDLat * sinDLat + Math.cos(lat1) * Math.cos(lat2) * sinDLng * sinDLng;
    final c = 2 * Math.asin(Math.min(1.0, Math.sqrt(h)));
    return R * c;
  }

  double polylineDistanceKm(List<LatLng> pts) {
    if (pts.length < 2) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < pts.length - 1; i++) {
      sum += _haversineMeters(pts[i], pts[i + 1]);
    }
    return sum / 1000.0;
  }

  Future<void> _loadDownloadedChaussees() async {
    print('🔄 [_loadDownloadedChaussees] start');
    try {
      final lines = await _downloadedChausseesService.getDownloadedChausseesPolylines(
        onTapDetails: (data) {
          _showChausseeDetailsSheet(
            context: context,
            statut: 'Sauvegardée (downloaded)',
            typeChaussee: (data['type_chaussee'] ?? '----').toString(),
            endroit: (data['endroit'] ?? '----').toString(),
            codePiste: (data['code_piste'] ?? '----').toString(),
            region: _regionNom,
            prefecture: _prefectureNom,
            commune: _communeNom,
            nbPoints: (data['nb_points'] as int?) ?? 0,
            distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0.0,
            startLat: (data['start_lat'] as num).toDouble(),
            startLng: (data['start_lng'] as num).toDouble(),
            endLat: (data['end_lat'] as num).toDouble(),
            endLng: (data['end_lng'] as num).toDouble(),
          );
        },
      );
      print('📏 [_loadDownloadedChaussees] ${lines.length} polylines reçues du service');
      setState(() {
        _downloadedChausseesPolylines = lines;
      });
      final total = collectedPolylines.length + _finishedPistes.length + _finishedChaussees.length + _downloadedPistesPolylines.length + _downloadedChausseesPolylines.length;
      print('🗺️  [_loadDownloadedChaussees] total polylines (avant rendu): $total');
    } catch (e) {
      print('❌ [_loadDownloadedChaussees] $e');
    }
    print('✅ [_loadDownloadedChaussees] done');
  }

  Future<void> _focusOnTarget(MapFocusTarget target) async {
    //  Désactiver l'auto-center définitivement (comme si l'utilisateur avait touché la carte)
    // L'utilisateur devra appuyer sur "Ma position" pour réactiver le suivi GPS
    _autoCenterDisabledByUser = true;

    // Créer les éléments de focus
    Polyline? focusPolyline;
    Marker? focusMarker;

    if (target.kind == 'polyline' && target.polyline != null && target.polyline!.isNotEmpty) {
      focusPolyline = Polyline(
        points: target.polyline!,
        color: Colors.purpleAccent,
        strokeWidth: 6.0,
        pattern: StrokePattern.dashed(segments: [
          12,
          6
        ]),
      );
    } else if (target.kind == 'point' && target.point != null) {
      focusMarker = Marker(
        point: target.point!,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.purpleAccent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 24),
        ),
      );
    }

    setState(() {
      if (focusPolyline != null) {
        _displayedSpecialLines.add(focusPolyline);
      }
      if (focusMarker != null) {
        _displayedPointsMarkers.add(focusMarker);
      }
    });

    if (_mapController != null) {
      if (target.kind == 'point' && target.point != null) {
        _mapController!.move(target.point!, 18);
        _lastCameraPosition = target.point; // ⭐ IMPORTANT: Mettre à jour la dernière position
      } else if (target.kind == 'polyline' && target.polyline != null && target.polyline!.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(target.polyline!);
        _mapController!.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(64)));
        _lastCameraPosition = bounds.center; // ⭐ IMPORTANT: Mettre à jour la dernière position
      }
    }

    // ⏱️ Retirer le focus après 10 secondes (par référence exacte, pas removeLast)
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() {
        if (focusPolyline != null) {
          _displayedSpecialLines.remove(focusPolyline);
        }
        if (focusMarker != null) {
          _displayedPointsMarkers.remove(focusMarker);
        }
      });
    });
  }

  void _toggleMapType() {
    setState(() {
      _isSatellite = !_isSatellite;
    });
  }

  Future<void> _refreshAllPoints() async {
    print(
      '🔄 Rafraîchissement de tous les points...',
    );
    await _loadDisplayedPoints(); // Points locaux (rouges)
    await _loadDownloadedPoints();
    await _loadDownloadedPistes();
// Points téléchargés (verts)
  }

  Future<void> _loadDownloadedPoints() async {
    try {
      final Map<String, List<Marker>> dlByTable = {};
      final markers = await _downloadedPointsService.getDownloadedPointsMarkers(
        onTapDetails: (data) {
          _showPointDetailsSheet(
            context: context,
            type: (data['type'] ?? 'Point').toString(),
            name: (data['name'] ?? 'Sans nom').toString(),
            region: (data['region_name'] ?? '').toString(),
            prefecture: (data['prefecture_name'] ?? '').toString(),
            commune: (data['commune_name'] ?? '').toString(),
            enqueteur: (data['enqueteur'] ?? '').toString(),
            codePiste: (data['code_piste'] ?? '').toString(),
            lat: (data['lat'] as num).toDouble(),
            lng: (data['lng'] as num).toDouble(),
            statut: 'Sauvegardée (downloaded)',
          );
        },
        onMarkerCreated: (String tableName, Marker marker) {
          dlByTable.putIfAbsent(tableName, () => []);
          dlByTable[tableName]!.add(marker);
        },
      );
      setState(
        () {
          _downloadedPointsMarkers = markers;
          _downloadedPointsByTable = dlByTable;
        },
      );
      print(
        '✅ ${markers.length} points téléchargés chargés (verts)',
      );
    } catch (e) {
      print(
        '❌ Erreur chargement points téléchargés: $e',
      );
    }
  }

  Future<void> _refreshAfterNavigation() async {
    print(
      '🔄 Rafraîchissement après navigation...',
    );
    await _loadDisplayedSpecialLines();
    await _refreshAllPoints(); // Seulement les lignes spéciales
  }

  Future<void> _loadDisplayedSpecialLines() async {
    try {
      final lines = await _specialLinesService.getDisplayedSpecialLines(
        onTapDetails: (data) {
          final start = LatLng(
            (data['start_lat'] as num).toDouble(),
            (data['start_lng'] as num).toDouble(),
          );
          final end = LatLng(
            (data['end_lat'] as num).toDouble(),
            (data['end_lng'] as num).toDouble(),
          );

          final distanceKm = polylineDistanceKm([
            start,
            end
          ]);

          _showSpecialLineDetailsSheet(
            context: context,
            specialType: (data['special_type'] ?? '----').toString(),
            statut: 'Sauvegardée (downloaded)',
            region: (data['region_name'] ?? '').toString().isNotEmpty ? (data['region_name']).toString() : _regionNom,
            prefecture: (data['prefecture_name'] ?? '').toString().isNotEmpty ? (data['prefecture_name']).toString() : _prefectureNom,
            commune: (data['commune_name'] ?? '').toString().isNotEmpty ? (data['commune_name']).toString() : _communeNom,
            enqueteur: (data['enqueteur'] ?? '').toString(),
            distanceKm: distanceKm,
            startLat: start.latitude,
            startLng: start.longitude,
            endLat: end.latitude,
            endLng: end.longitude,
          );
        },
      );

      setState(() {
        _displayedSpecialLines = lines;
      });

      print('✅ ${lines.length} lignes spéciales affichées');
    } catch (e) {
      print('❌ Erreur chargement lignes spéciales: $e');
    }
  }

  // Dans _HomePageState
  // Remplacer startSpecialLineCollection par :
  Future<void> startSpecialCollection(
    String type,
  ) async {
    if (!homeController.gpsEnabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Veuillez activer le GPS",
          ),
        ),
      );
      return;
    }

    if (homeController.hasActiveCollection) {
      final activeType = homeController.activeCollectionType;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez mettre en pause la collecte de $activeType en cours',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await homeController.startSpecialCollection(
        type,
      );

      setState(
        () {
          _isSpecialCollection = true;
          _specialCollectionType = type;
        },
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Collecte de $type démarrée',
          ),
          backgroundColor: Colors.purple, // Couleur différente
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Remplacer finishSpecialLigneCollection par :
  Future<void> finishSpecialCollection() async {
    // === CAS POLYGONE ===
    if (_isPolygonCollection) {
      final result = homeController.finishSpecialCollection();

      if (result == null || result.points.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Un polygone doit contenir au moins 3 points. (${result?.points.length ?? 0} collectés)",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final current = homeController.userPosition;
      final nearestPisteCode = await SimpleStorageHelper().findNearestPisteCode(
        current,
        activePisteCode: homeController.activePisteCode,
      );

      final formResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PolygonFormPage(
            polygonPoints: result.points,
            startTime: result.startTime,
            endTime: result.endTime,
            agentName: widget.agentName,
            activePisteCode: homeController.activePisteCode,
            nearestPisteCode: nearestPisteCode,
          ),
        ),
      );

      if (mounted) _refreshAfterNavigation();

      setState(() {
        _isSpecialCollection = false;
        _isPolygonCollection = false;
        _specialCollectionType = null;
      });

      if (formResult != null) {
        await _loadDisplayedPolygons();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zone de Plaine enregistrée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    // === CAS LIGNE (Bac / Passage Submersible) — code existant ===
    final result = homeController.finishSpecialCollection();

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Une ligne doit contenir au moins 2 points."),
        ),
      );
      return;
    }

    // ⭐ Vérifier que le premier et dernier point sont distincts
    if (result.points.length >= 2 && result.points.first.latitude == result.points.last.latitude && result.points.first.longitude == result.points.last.longitude) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La ligne doit avoir un point de début et de fin différents. Veuillez vous déplacer pendant la collecte."),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() {
        _isSpecialCollection = false;
        _specialCollectionType = null;
      });
      return;
    }

    print('=== DEBUG FINISH SPECIAL ===');
    print('Result codePiste: ${result.codePiste}');
    print('HomeController activePisteCode: ${homeController.activePisteCode}');
    print('Special type: $_specialCollectionType');
    final current = homeController.userPosition;
    final nearestPisteCode = await SimpleStorageHelper().findNearestPisteCode(
      current,
      activePisteCode: homeController.activePisteCode,
    );

    print('📍 Code piste pour spécial: $nearestPisteCode');

    final formResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpecialLineFormPage(
          linePoints: result.points,
          provisionalCode: result.codePiste ?? '',
          startTime: result.startTime,
          endTime: result.endTime,
          agentName: widget.agentName,
          specialType: _specialCollectionType!,
          totalDistance: result.totalDistance,
          activePisteCode: homeController.activePisteCode,
        ),
      ),
    );
    if (mounted) _refreshAfterNavigation();

    setState(() {
      _isSpecialCollection = false;
      _specialCollectionType = null;
    });

    if (formResult != null) {
      await _loadDisplayedSpecialLines();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Données enregistrées avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _loadDisplayedPolygons() async {
    try {
      final db = await DatabaseHelper().database;
      final polygons = await db.query('enquete_polygone');

      List<Polygon> mapPolygons = [];
      for (var poly in polygons) {
        final pointsJson = poly['points_json'] as String?;
        if (pointsJson != null && pointsJson.isNotEmpty) {
          try {
            final List<dynamic> coords = jsonDecode(pointsJson);
            final List<LatLng> points = coords.map<LatLng>((c) {
              if (c is List && c.length >= 2) {
                return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
              }
              return LatLng(0, 0);
            }).toList();

            if (points.length >= 3) {
              mapPolygons.add(Polygon(
                points: points,
                color: const Color(0xFF4CAF50).withOpacity(0.3),
                borderColor: const Color(0xFF2E7D32),
                borderStrokeWidth: 2.0,
                isFilled: true,
                hitValue: PolygonTapData(
                  nom: poly['nom']?.toString() ?? '----',
                  codePiste: poly['code_piste']?.toString() ?? '----',
                  superficie: (poly['superficie_en_ha'] as num?)?.toDouble() ?? 0.0,
                  nbSommets: points.length,
                  enqueteur: poly['enqueteur']?.toString() ?? '',
                  dateCreation: poly['date_creation']?.toString() ?? '----',
                  synced: poly['synced'] == 1,
                  downloaded: poly['downloaded'] == 1,
                  regionName: poly['region_name']?.toString() ?? '',
                  prefectureName: poly['prefecture_name']?.toString() ?? '',
                  communeName: poly['commune_name']?.toString() ?? '',
                ),
              ));
            }
          } catch (e) {
            print('❌ Erreur parsing polygone: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _displayedPolygons = mapPolygons;
        });
        print('✅ ${mapPolygons.length} polygones affichés');
      }
    } catch (e) {
      print('❌ Erreur chargement polygones: $e');
    }
  }

  StrokePattern? getChausseePattern(String type) {
    switch (type.toLowerCase()) {
      case 'asphalte':
      case 'bitume':
        return null; // ligne continue
      case 'terre':
        return StrokePattern.dashed(segments: [
          20,
          10
        ]);
      case 'béton':
        return StrokePattern.dotted(spacingFactor: 1.5);
      case 'pavée':
      case 'latérite':
        return StrokePattern.dashed(segments: [
          10,
          5
        ]);
      case 'bouwal':
        return StrokePattern.dotted(spacingFactor: 2.0);
      default:
        return null; // par défaut, ligne continue
    }
  }

  Future<void> _loadDisplayedChaussees() async {
    try {
      final storageHelper = SimpleStorageHelper();
      final rows = await storageHelper.loadDisplayedChausseesMaps();

      final displayedChaussees = <Polyline>[];

      for (final row in rows) {
        final typeChaussee = (row['type_chaussee'] ?? '').toString();
        final endroit = (row['endroit'] ?? '').toString();
        final codePiste = (row['code_piste'] ?? '').toString();

        final pointsData = jsonDecode(row['points_json'] as String) as List;
        final pts = <LatLng>[];
        for (final p in pointsData) {
          final lat = p['lat'] as double?;
          final lng = p['lng'] as double?;
          if (lat != null && lng != null) pts.add(LatLng(lat, lng));
        }
        if (pts.length < 2) continue;

        final distanceKm = polylineDistanceKm(pts);

        // Lookup synced/region dans la vraie table chaussees
        String chSynced = '0';
        String chRegion = '';
        String chPrefecture = '';
        String chCommune = '';
        String chEnqueteur = '';
        try {
          final chDb = await SimpleStorageHelper().database;
          final chRows = await chDb.query(
            'chaussees',
            columns: [
              'synced',
              'region_name',
              'prefecture_name',
              'commune_name',
              'user_login',
            ],
            where: 'code_piste = ? AND synced = 1',
            whereArgs: [
              codePiste
            ],
            limit: 1,
          );
          if (chRows.isNotEmpty) {
            chSynced = '1';
            chRegion = (chRows.first['region_name'] ?? '').toString();
            chPrefecture = (chRows.first['prefecture_name'] ?? '').toString();
            chCommune = (chRows.first['commune_name'] ?? '').toString();
            chEnqueteur = (chRows.first['user_login'] ?? '').toString();
          }
        } catch (_) {}

        displayedChaussees.add(
          Polyline(
            points: pts,
            color: storageHelper.getChausseeColor(typeChaussee),
            strokeWidth: (row['width'] as int).toDouble(),
            pattern: storageHelper.getChausseePattern(typeChaussee) ?? const StrokePattern.solid(),
            hitValue: PolylineTapData(
              type: 'chaussee_local',
              data: {
                'type_chaussee': typeChaussee,
                'endroit': endroit,
                'code_piste': codePiste,
                'nb_points': pts.length,
                'distance_km': distanceKm,
                'start_lat': pts.first.latitude,
                'start_lng': pts.first.longitude,
                'end_lat': pts.last.latitude,
                'end_lng': pts.last.longitude,
                'synced': chSynced,
                'region_name': chRegion,
                'prefecture_name': chPrefecture,
                'commune_name': chCommune,
                'enqueteur': chEnqueteur,
              },
            ),
          ),
        );
      }

      setState(() {
        _finishedChaussees = displayedChaussees;
      });
      print('✅ ${displayedChaussees.length} chaussées rechargées');
    } catch (e) {
      print('❌ Erreur rechargement chaussées: $e');
    }
  }

  Future<String> generateCodePiste() async {
    // horodatage YYYYMMDDhhmmssSSS
    final now = DateTime.now();
    final ts = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}'
        '${now.millisecond.toString().padLeft(3, '0')}';

    // helper: convertir n’importe quoi en int (int/string) avec 0 par défaut
    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    int communeId = 0;
    int prefectureId = 0;
    int regionId = 0;

    // 1) API si dispo et non nulle
    final apiCommuneId = _toInt(ApiService.communeId);
    final apiPrefId = _toInt(ApiService.prefectureId);
    final apiRegionId = _toInt(ApiService.regionId);

    if (apiCommuneId > 0 && apiPrefId > 0 && apiRegionId > 0) {
      communeId = apiCommuneId;
      prefectureId = apiPrefId;
      regionId = apiRegionId;
      print('📍 Localisation (IDs) récupérée depuis API');
    } else {
      // 2) DB locale via session / fallback dernier user
      final currentUser = await DatabaseHelper().getCurrentUser();
      if (currentUser != null) {
        communeId = _toInt(currentUser['communes_rurales']);
        prefectureId = _toInt(currentUser['prefecture_id']);
        regionId = _toInt(currentUser['region_id']);
        print('📍 Localisation (IDs) récupérée depuis base locale');
      } else {
        print('⚠️ Localisation IDs inconnue (pas de session, pas de user local)');
      }
    }

    final code = 'Piste_${communeId}_${prefectureId}_${regionId}_$ts';
    print('🆔 Code piste généré (IDs): $code');
    return code;
  }

  // AJOUTEZ CETTE MÉTHODE DANS _HomePageState
  /*void _setupRefreshListener() {
    // Rafraîchir périodiquement toutes les 2 secondes
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadDisplayedPoints();
        print('🔄 Rafraîchissement automatique des points');
      }
    });
  }*/

  Future<void> _loadDisplayedPoints() async {
    // AJOUTEZ CE DEBUG pour voir QUI appelle
    print(
      '🛑 _loadDisplayedPoints appelée par:',
    );
    print(
      StackTrace.current
          .toString()
          .split(
            '\n',
          )
          .take(
            3,
          )
          .join(
            '\n',
          ),
    );
    print(
      '---',
    );

    try {
      final markers = await _pointsService.getDisplayedPointsMarkers(
        onTapDetails: (data) {
          _suspendAutoCenterFor(const Duration(seconds: 10));
          _showPointDetailsSheet(
            context: context,
            type: (data['type'] ?? 'Point').toString(),
            name: (data['name'] ?? 'Sans nom').toString(),
            region: (data['region_name'] ?? '').toString().isNotEmpty ? (data['region_name']).toString() : _regionNom,
            prefecture: (data['prefecture_name'] ?? '').toString().isNotEmpty ? (data['prefecture_name']).toString() : _prefectureNom,
            commune: (data['commune_name'] ?? '').toString().isNotEmpty ? (data['commune_name']).toString() : _communeNom,
            enqueteur: (data['enqueteur'] ?? '').toString(),
            codePiste: (data['code_piste'] ?? '').toString(),
            lat: (data['lat'] as num).toDouble(),
            lng: (data['lng'] as num).toDouble(),
            statut: (data['synced'].toString() == '1') ? 'Synchronisée' : 'Enregistrée localement',
          );
        },
      );
      // ⭐⭐ FILTRER SEULEMENT LES MARQUEURS VALIDES ⭐⭐
      final dbHelper = DatabaseHelper();
      final existingPoints = await dbHelper.loadDisplayedPoints();
      final existingKeys = existingPoints.map((p) {
        final t = (p['original_table'] ?? '').toString();
        final i = p['id'];
        return '$t:$i';
      }).toSet();

      // Créer un Set des positions existantes (lat_lng comme clé unique)
      final existingPositions = existingPoints.map((p) {
        final lat = (p['latitude'] as num).toDouble();
        final lng = (p['longitude'] as num).toDouble();
        return '${lat}_${lng}';
      }).toSet();

// Filtrer les markers dont la position existe encore
      final validMarkers = markers.where((marker) {
        final posKey = '${marker.point.latitude}_${marker.point.longitude}';
        return existingPositions.contains(posKey);
      }).toList();

      // Compter les points par table pour la légende
      final Map<String, int> counts = {};
      for (var p in existingPoints) {
        final table = (p['original_table'] ?? '').toString();
        if (table.isNotEmpty) {
          counts[table] = (counts[table] ?? 0) + 1;
        }
      }

      // Regrouper les markers par table pour le filtrage légende
      final Map<String, List<Marker>> byTable = {};
      for (var point in existingPoints) {
        final table = (point['original_table'] ?? '').toString();
        if (table.isEmpty) continue;
        final lat = (point['latitude'] as num).toDouble();
        final lng = (point['longitude'] as num).toDouble();
        final posKey = '${lat}_${lng}';
        // Trouver le marker correspondant à cette position
        for (var m in validMarkers) {
          if ('${m.point.latitude}_${m.point.longitude}' == posKey) {
            byTable.putIfAbsent(table, () => []);
            byTable[table]!.add(m);
            break;
          }
        }
      }

      setState(() {
        _displayedPointsMarkers = validMarkers;
        _displayedPointsByTable = byTable;
      });

      // Compter depuis les tables réelles (inclut locaux + téléchargés)
      await _loadPointCountsByTable();

      print(
        '📍 ${validMarkers.length} points affichés valides',
      );
    } catch (e) {
      print(
        '❌ Erreur chargement points: $e',
      );
    }
  }

  Future<void> _loadPointCountsByTable() async {
    try {
      final db = await DatabaseHelper().database;
      final Map<String, int> counts = {};
      final tables = [
        'localites',
        'ecoles',
        'marches',
        'services_santes',
        'batiments_administratifs',
        'infrastructures_hydrauliques',
        'autres_infrastructures',
        'ponts',
        'buses',
        'dalots',
        'points_critiques',
        'points_coupures',
        'site_enquete',
      ];

      for (var table in tables) {
        try {
          final result = await db.rawQuery('SELECT COUNT(*) as c FROM $table');
          counts[table] = result.first['c'] as int? ?? 0;
        } catch (_) {
          counts[table] = 0;
        }
      }

      if (mounted) {
        setState(() {
          _pointCountsByTable = counts;
        });
      }
      print('📊 Compteurs points: $counts');
    } catch (e) {
      print('❌ Erreur comptage points: $e');
    }
  }

  void _onMapCreated(MapController controller) {
    _mapController = controller;

    // ⭐⭐ CORRECTION: Si un focus initial est demandé, NE PAS aller vers userPosition ⭐⭐
    if (widget.initialFocus != null) {
      // Suspendre l'auto-center AVANT le focus
      _suspendAutoCenterFor(const Duration(seconds: 10));

      // Focus sur la cible demandée (avec un petit délai pour que la carte soit prête)
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _focusOnTarget(widget.initialFocus!);
        }
      });
    } else {
      // Comportement normal: déplacer vers la position GPS de l'utilisateur
      if (userPosition != null) {
        controller.move(userPosition!, 17);
        _lastCameraPosition = userPosition;
      }
    }
  }

  void _moveCameraIfNeeded() {
    if (_mapController == null) return;

    //  AJOUT: Vérifier que userPosition n'est pas null
    if (userPosition == null) return;

    try {
      //  Utiliser userPosition! car on a vérifié qu'il n'est pas null
      final shouldMove = _lastCameraPosition == null ||
          _coordinateDistance(
                _lastCameraPosition!.latitude,
                _lastCameraPosition!.longitude,
                userPosition!.latitude, // ← Ajout du !
                userPosition!.longitude, // ← Ajout du !
              ) >
              20;

      if (_autoCenterSuspended) {
        // Debug
      } else if (shouldMove) {
        _mapController!.move(userPosition!, 17); // ← Ajout du !
        _lastCameraPosition = userPosition;
      }
    } catch (_) {}
  }

  // === GESTION DES POINTS D'INTÉRÊT ===
  Future<void> addPointOfInterest() async {
    if (_isSpecialCollection && homeController.specialCollection?.isPaused != true) {
      await finishSpecialCollection();
      return;
    }

    // Vérifier si une collecte est active
    final activeType = homeController.getActiveCollectionType();
    if (activeType != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez mettre en pause la collecte de $activeType en cours',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final current = homeController.userPosition;
    final nearestPisteCode = await SimpleStorageHelper().findNearestPisteCode(
      current,
      activePisteCode: homeController.activePisteCode,
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (
          _,
        ) =>
            PointFormScreen(
          pointData: {
            'latitude': current.latitude,
            'longitude': current.longitude,
            'accuracy': 10.0,
            'timestamp': DateTime.now().toIso8601String(),
          },
          agentName: widget.agentName,
          nearestPisteCode: nearestPisteCode,
          onSpecialTypeSelected: (
            type,
          ) {
            if (type == "Zone de Plaine") {
              startPolygonCollection();
            } else {
              startSpecialCollection(type);
            }
          },
        ),
      ),
    );
    if (mounted) {
      _refreshAfterNavigation(); // Rafraîchir après être revenu
    }
    if (result != null && result is Map<String, dynamic>) {
      setState(
        () {
          collectedMarkers.add(Marker(
            point: LatLng(result['latitude'], result['longitude']),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () {
                // Si vous aviez un onTap, mettez-le ici
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 24),
              ),
            ),
          ));
        },
      );
    }
  }

  // === GESTION DE LA COLLECTE LIGNE/PISTE ===
  // home_page.dart - Modifiez la méthode startLigneCollection

  // home_page.dart - Méthode startLigneCollection modifiée
// === COLLECTE POLYGONE (Zone de Plaine) ===
  Future<void> startPolygonCollection() async {
    if (!homeController.gpsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez activer le GPS")),
      );
      return;
    }

    if (homeController.hasActiveCollection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez terminer la collecte en cours'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Réutiliser le mécanisme de special collection
      await homeController.startSpecialCollection("Zone de Plaine");

      setState(() {
        _isSpecialCollection = true;
        _isPolygonCollection = true;
        _specialCollectionType = "Zone de Plaine";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔷 Collecte de polygone démarrée — Marchez le périmètre de la zone'),
          backgroundColor: Color(0xFF1B5E20),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> startLigneCollection() async {
    if (!homeController.gpsEnabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Veuillez activer le GPS",
          ),
        ),
      );
      return;
    }

    if (homeController.hasActiveCollection) {
      final activeType = homeController.activeCollectionType;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez mettre en pause la collecte de $activeType en cours',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ⭐⭐ GÉNÉRER le code piste automatiquement - AJOUTER AWAIT
    final codePisteAuto = await generateCodePiste(); // ← AJOUTER AWAIT

    // ⭐⭐ Afficher le dialogue AVEC code pré-rempli et IMMODIFIABLE
    final provisionalData = await ProvisionalFormDialog.show(
      context: context,
      initialCode: codePisteAuto, // ← Maintenant ça fonctionne
    );

    // ⭐⭐ Plus besoin de vérifier si null, car le code est toujours fourni
    if (provisionalData == null) return;

    try {
      await homeController.startLigneCollection(
        provisionalData['code_piste']!,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Collecte de piste démarrée',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void toggleSpecialCollection() {
    try {
      homeController.toggleSpecialCollection();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  void toggleLigneCollection() {
    try {
      homeController.toggleLigneCollection();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> finishLigneCollection() async {
    final result = homeController.finishLigneCollection();
    if (result == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Une piste doit contenir au moins 2 points.",
          ),
        ),
      );
      return;
    }

    // Ouvrir le formulaire principal avec les données provisoires
    final formResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (
          _,
        ) =>
            FormulaireLignePage(
          linePoints: result['points'],
          provisionalCode: result['codePiste'], // ✅ Nom correct du paramètre
          startTime: result['startTime'],
          endTime: result['endTime'],
          agentName: widget.agentName,
        ),
      ),
    );

    if (formResult != null) {
      final List<LatLng> pts = List<LatLng>.from(result['points'] as List<LatLng>);
      final distanceKm = pts.length >= 2 ? polylineDistanceKm(pts) : 0.0;

      setState(() {
        _finishedPistes.add(
          Polyline<PolylineTapData>(
            points: pts,
            color: Colors.brown,
            strokeWidth: 3.0,
            pattern: StrokePattern.dotted(spacingFactor: 2.0),
            hitValue: PolylineTapData(
              type: 'piste_local',
              data: {
                'code_piste': (formResult['code_piste'] ?? result['codePiste'] ?? '').toString(),
                'nb_points': pts.length,
                'distance_km': distanceKm,
                'start_lat': pts.isNotEmpty ? pts.first.latitude : 0.0,
                'start_lng': pts.isNotEmpty ? pts.first.longitude : 0.0,
                'end_lat': pts.isNotEmpty ? pts.last.latitude : 0.0,
                'end_lng': pts.isNotEmpty ? pts.last.longitude : 0.0,
                'synced': '0',
                'enqueteur': formResult['user_login'] ?? widget.agentName ?? '',
                'plateforme': formResult['plateforme'],
                'relief': formResult['relief'],
                'vegetation': formResult['vegetation'],
                'debut_travaux': formResult['debut_travaux'],
                'fin_travaux': formResult['fin_travaux'],
                'financement': formResult['financement'],
                'projet': formResult['projet'],
                'entreprise': formResult['entreprise'],
              },
            ),
          ),
        );
      });

      final storageHelper = SimpleStorageHelper();
      await storageHelper.saveDisplayedPiste(result['codePiste'], pts, Colors.brown, 3.0);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Piste enregistrée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<String> _resolveLocalPisteCodeFromPolyline(List<LatLng> polyPts) async {
    try {
      if (polyPts.length < 2) return '----';

      final storageHelper = SimpleStorageHelper();
      final db = await storageHelper.database;

      // On prend le 1er point comme "signature"
      final start = polyPts.first;
      const tol = 0.00005; // ~5m (ajuste si besoin)

      // IMPORTANT: dans tes pistes locales points_json tu as {lat,lng}
      final rows = await db.query(
        'pistes',
        columns: [
          'code_piste',
          'points_json'
        ],
        where: 'synced = ? AND downloaded = ?',
        whereArgs: [
          0,
          0
        ],
      );

      for (final r in rows) {
        final pj = r['points_json'];
        if (pj is! String || pj.trim().isEmpty) continue;

        final decoded = jsonDecode(pj);
        if (decoded is! List || decoded.isEmpty) continue;

        final first = decoded.first;
        if (first is! Map) continue;

        final lat = (first['latitude'] ?? first['lat']);
        final lng = (first['longitude'] ?? first['lng']);
        if (lat is! num || lng is! num) continue;

        final dLat = (lat.toDouble() - start.latitude).abs();
        final dLng = (lng.toDouble() - start.longitude).abs();

        if (dLat <= tol && dLng <= tol) {
          return (r['code_piste'] ?? '----').toString();
        }
      }
    } catch (e) {
      print('❌ _resolveLocalPisteCodeFromPolyline: $e');
    }
    return '----';
  }

  // Pour charger au démarrage
  // Dans la classe _HomePageState
  // Remplacer l'ancienne méthode par la nouvelle
  Future<void> _loadDisplayedPistes() async {
    try {
      final storageHelper = SimpleStorageHelper();

      // ✅ au lieu de loadDisplayedPistes() (Polyline), on récupère les maps
      final rows = await storageHelper.loadDisplayedPistesMaps();

      final displayedPistes = <Polyline>[];

      for (final row in rows) {
        final codePiste = (row['code_piste'] ?? '----').toString().trim();

        final pointsData = jsonDecode(row['points_json'] as String) as List;
        final pts = <LatLng>[];

        for (final p in pointsData) {
          final lat = (p['latitude'] ?? p['lat'] as dynamic);
          final lng = (p['longitude'] ?? p['lng'] as dynamic);

          final latD = (lat is num) ? lat.toDouble() : null;
          final lngD = (lng is num) ? lng.toDouble() : null;

          if (latD != null && lngD != null) {
            pts.add(LatLng(latD, lngD));
          }
        }

        if (pts.isEmpty) continue;

        final distanceKm = pts.length >= 2 ? polylineDistanceKm(pts) : 0.0;

        // Chercher synced/region dans la vraie table pistes
        // Chercher synced/region dans la vraie table pistes
        String piSynced = '0';
        String piRegion = '';
        String piPrefecture = '';
        String piCommune = '';
        String piEnqueteur = '';
        String piPlateforme = '';
        String piRelief = '';
        String piVegetation = '';
        String piDebutTravaux = '';
        String piFinTravaux = '';
        String piFinancement = '';
        String piProjet = '';
        String piEntreprise = '';
        try {
          final pisteDb = await SimpleStorageHelper().database;
          final pisteRows = await pisteDb.query(
            'pistes',
            columns: [
              'synced',
              'region_name',
              'prefecture_name',
              'commune_name',
              'plateforme',
              'relief',
              'vegetation',
              'debut_travaux',
              'fin_travaux',
              'financement',
              'projet',
              'entreprise',
              'user_login',
            ],
            where: 'code_piste = ?',
            whereArgs: [
              codePiste
            ],
            limit: 1,
          );
          if (pisteRows.isNotEmpty) {
            piSynced = (pisteRows.first['synced']?.toString() == '1') ? '1' : '0';
            piRegion = (pisteRows.first['region_name'] ?? '').toString();
            piPrefecture = (pisteRows.first['prefecture_name'] ?? '').toString();
            piCommune = (pisteRows.first['commune_name'] ?? '').toString();
            piEnqueteur = (pisteRows.first['user_login'] ?? '').toString();
            piPlateforme = (pisteRows.first['plateforme'] ?? '').toString();
            piRelief = (pisteRows.first['relief'] ?? '').toString();
            piVegetation = (pisteRows.first['vegetation'] ?? '').toString();
            piDebutTravaux = (pisteRows.first['debut_travaux'] ?? '').toString();
            piFinTravaux = (pisteRows.first['fin_travaux'] ?? '').toString();
            piFinancement = (pisteRows.first['financement'] ?? '').toString();
            piProjet = (pisteRows.first['projet'] ?? '').toString();
            piEntreprise = (pisteRows.first['entreprise'] ?? '').toString();
          }
        } catch (_) {}

        displayedPistes.add(
          Polyline(
            points: pts,
            color: Color(row['color'] as int),
            strokeWidth: (row['width'] as num).toDouble(),
            pattern: StrokePattern.dotted(spacingFactor: 2.0),
            hitValue: PolylineTapData(
              type: 'piste_local',
              data: {
                'code_piste': codePiste,
                'nb_points': pts.length,
                'distance_km': distanceKm,
                'start_lat': pts.first.latitude,
                'start_lng': pts.first.longitude,
                'end_lat': pts.last.latitude,
                'end_lng': pts.last.longitude,
                'plateforme': piPlateforme,
                'relief': piRelief,
                'vegetation': piVegetation,
                'debut_travaux': piDebutTravaux,
                'fin_travaux': piFinTravaux,
                'financement': piFinancement,
                'projet': piProjet,
                'entreprise': piEntreprise,
                'synced': piSynced,
                'region_name': piRegion,
                'prefecture_name': piPrefecture,
                'commune_name': piCommune,
                'enqueteur': piEnqueteur,
              },
            ),
          ),
        );
      }

      setState(() {
        _finishedPistes = displayedPistes;
      });

      print('✅ ${displayedPistes.length} pistes rechargées (HomePage build + onTap OK)');
    } catch (e) {
      print('❌ Erreur rechargement pistes: $e');
    }
  }

  // === GESTION DE LA COLLECTE CHAUSSÉE ===
  Future<void> startChausseeCollection() async {
    if (!homeController.gpsEnabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Veuillez activer le GPS",
          ),
        ),
      );
      return;
    }

    // Vérifier si une collecte est active
    if (homeController.hasActiveCollection) {
      final activeType = homeController.activeCollectionType;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez mettre en pause la collecte de $activeType en cours',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // ⭐⭐ TROUVER LE CODE PISTE LE PLUS PROCHE ⭐⭐
      _currentNearestPisteCode = homeController.activePisteCode ??
          await SimpleStorageHelper().findNearestPisteCode(
            homeController.userPosition,
          );
      await homeController.startChausseeCollection(); // ✅ Aucun paramètre requis

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Collecte de chaussée démarrée',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void toggleChausseeCollection() {
    try {
      homeController.toggleChausseeCollection();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color getChausseeColor(
    String type,
  ) {
    switch (type.toLowerCase()) {
      case 'bitume':
        return Colors.black;
      case 'terre':
        return const Color(0xFFD2691E); // Chocolate — distinct du brown des pistes
      case 'latérite': // ← minuscule
        return Colors.red.shade700;
      case 'bouwal':
        return Colors.yellow.shade700;
      default:
        return Colors.blueGrey; // inconnu / autre
    }
  }

  Future<void> finishChausseeCollection() async {
    final result = homeController.finishChausseeCollection();
    if (result == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Une chaussée doit contenir au moins 2 points.",
          ),
        ),
      );
      return;
    }

    // Ouvrir le formulaire principal avec les données provisoires
    final formResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (
          _,
        ) =>
            FormulaireChausseePage(
          chausseePoints: result['points'],
          provisionalId: result['id'],
          agentName: widget.agentName,
          nearestPisteCode: _currentNearestPisteCode, // ✅ Utiliser l'ID correct
        ),
      ),
    );

    if (formResult != null) {
      final List<LatLng> pts = List<LatLng>.from(result['points'] as List<LatLng>);
      final distanceKm = pts.length >= 2 ? polylineDistanceKm(pts) : 0.0;
      final typeChaussee = (formResult['type_chaussee'] ?? 'inconnu').toString();
      final endroit = (formResult['endroit'] ?? '').toString();
      final codePiste = (formResult['code_piste'] ?? '').toString();

      setState(
        () {
          _finishedChaussees.add(
            Polyline<PolylineTapData>(
              points: pts,
              color: getChausseeColor(typeChaussee),
              strokeWidth: 4.0,
              pattern: getChausseePattern(typeChaussee) ?? const StrokePattern.solid(),
              hitValue: PolylineTapData(
                type: 'chaussee_local',
                data: {
                  'type_chaussee': typeChaussee,
                  'endroit': endroit,
                  'code_piste': codePiste,
                  'nb_points': pts.length,
                  'distance_km': distanceKm,
                  'start_lat': pts.first.latitude,
                  'start_lng': pts.first.longitude,
                  'end_lat': pts.last.latitude,
                  'end_lng': pts.last.longitude,
                  'synced': '0',
                  'region_name': '',
                  'prefecture_name': '',
                  'commune_name': '',
                  'enqueteur': formResult['user_login'] ?? widget.agentName ?? '',
                },
              ),
            ),
          );
        },
      );
      final storageHelper = SimpleStorageHelper();
      await storageHelper.saveDisplayedChaussee(
        pts,
        typeChaussee,
        4.0,
        codePiste,
        endroit,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Chaussée enregistrée avec succès',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showSyncConfirmationDialog() {
    showDialog(
      context: context,
      builder: (
        ctx,
      ) =>
          AlertDialog(
        title: const Text(
          'Confirmation de synchronisation',
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Êtes-vous sûr de vouloir synchroniser vos données locales vers le serveur ?',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              ctx,
            ),
            child: const Text(
              'Non',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                ctx,
              );
              _performSync();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text(
              'Oui',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSyncResult(SyncResult result) {
    showDialog(
      context: context,
      builder: (ctx) {
        // On limite le nombre d'erreurs affichées
        final errorsToShow = result.errors.take(10).toList();
        final remaining = result.errors.length - errorsToShow.length;

        return AlertDialog(
          title: const Text('Synchronisation terminée'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ ${result.successCount} succès'),
                Text('❌ ${result.failedCount} échecs'),

                // 💡 Message d'astuce en cas d'échec
                if (result.failedCount > 0) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '💡 Vérifiez votre connexion internet ou réessayez plus tard.',
                  ),
                ],

                if (errorsToShow.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Détails des erreurs:'),
                  const SizedBox(height: 5),

                  // On affiche seulement les 10 premières erreurs
                  ...errorsToShow.map(
                    (e) => Text(
                      '• $e',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),

                  // S’il reste encore des erreurs, on ajoute une ligne de résumé
                  if (remaining > 0) ...[
                    const SizedBox(height: 5),
                    Text(
                      '• ... et $remaining autres erreurs.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // ⭐ Recharger les polylines locales pour refléter synced=1 + région/préfecture/commune
                _loadDisplayedPistes();
                _loadDisplayedChaussees();
                _loadDisplayedPoints();
                _loadDisplayedPolygons();
                _loadDisplayedSpecialLines();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSaveConfirmationDialog() {
    showDialog(
      context: context,
      builder: (
        ctx,
      ) =>
          AlertDialog(
        title: const Text(
          'Confirmation de sauvegarde',
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Êtes-vous sûr de vouloir télécharger toutes les données depuis le serveur ?',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              ctx,
            ),
            child: const Text(
              'Non',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                ctx,
              );
              _performDownload();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text(
              'Oui',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDownloadResult(SyncResult result) {
    showDialog(
      context: context,
      builder: (ctx) {
        final errorsToShow = result.errors.take(10).toList();
        final remaining = result.errors.length - errorsToShow.length;

        return AlertDialog(
          title: const Text('Sauvegarde terminée'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📥 ${result.successCount} données sauvegardées'),
                if (result.failedCount > 0) Text('❌ ${result.failedCount} types de données n’ont pas pu être mis à jour'),
                if (result.failedCount > 0) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '💡 : Vérifiez votre connexion internet ou réessayez plus tard.',
                  ),
                ],
                if (errorsToShow.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Détails des erreurs:'),
                  const SizedBox(height: 5),
                  ...errorsToShow.map(
                    (e) => Text(
                      '• $e',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (remaining > 0) ...[
                    const SizedBox(height: 5),
                    Text(
                      '• ... et $remaining autres problèmes.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Recharger toutes les données téléchargées
                _loadDownloadedPoints();
                _loadDownloadedPistes();
                _loadDownloadedChaussees();
                _loadDownloadedSpecialLines();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void handleSync() {
    if (isSyncing) return;

    _performSync(); // Appeler la méthode async séparément
  }

  // AJOUTEZ cette méthode
  void handleSave() {
    if (isDownloading) return;
    _performDownload(); // Appeler la méthode async séparément
  }

  // AJOUTEZ cette méthode
  Future<void> _performDownload() async {
    setState(
      () {
        isDownloading = true;
        _progressValue = 0.0;
        _processedItems = 0;
        _totalItems = 1; // Valeur initiale
      },
    );

    try {
      final result = await SyncService().downloadAllData(
        onProgress: (
          progress,
          currentOperation,
          processed,
          total,
        ) {
          setState(
            () {
              _progressValue = progress;
              _currentOperation = currentOperation;
              _processedItems = processed;
              _totalItems = total;
            },
          );
        },
      );
      setState(
        () => lastSyncResult = result,
      );
      _showDownloadResult(
        result,
      ); // Réutilisez la même méthode d'affichage

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Sauvegarde terminée: ${result.successCount} données',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur sauvegarde: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(
        () => isDownloading = false,
      );
    }
  }

  void handleMenuPress() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (
          context,
        ) =>
            DataCategoriesPage(
          isOnline: _isOnlineDynamic,
          agentName: widget.agentName,
        ),
      ),
    ).then(
      (
        _,
      ) {
        _refreshAllPoints();
        // ⭐⭐ RAFRAÎCHIR TOUJOURS À LE RETOUR ⭐⭐
        _loadDisplayedPoints();
        _loadDisplayedPistes();
        _loadDisplayedChaussees();
        _loadDisplayedSpecialLines();
        if (_legendVisibility['zone_plaine'] != false) {
          _loadDisplayedPolygons();
        }
        _loadPointCountsByTable();
      },
    );
  }

  // Ajoutez cette méthode pour afficher la confirmation de déconnexion
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (
        ctx,
      ) =>
          AlertDialog(
        title: const Text(
          'Confirmation de déconnexion',
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              ctx,
            ),
            child: const Text(
              'Non',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                ctx,
              ); // Fermer la boîte de dialogue
              _performLogout(); // Effectuer la déconnexion
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Oui',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ajoutez cette méthode pour effectuer la déconnexion
  Future<void> _performLogout() async {
    await DatabaseHelper().clearSession();
    ApiService.userId = null;

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // Méthode AVEC Future pour la logique async

  Future<void> _performSync() async {
    setState(() {
      isSyncing = true;
      _syncProgressValue = 0.0;
      _syncProcessedItems = 0;
      _syncTotalItems = 1;
    });

    try {
      final result = await SyncService().syncAllDataSequential(
        onProgress: (progress, currentOperation, processed, total) {
          double safeProgress = progress.isNaN || progress.isInfinite ? 0.0 : progress.clamp(0.0, 1.0);
          int safeProcessed = processed.isNaN || processed.isInfinite ? 0 : processed;
          int safeTotal = total.isNaN || total.isInfinite ? 1 : total;

          setState(() {
            _syncProgressValue = safeProgress;
            _currentSyncOperation = currentOperation;
            _syncProcessedItems = safeProcessed;
            _syncTotalItems = safeTotal;
          });
        },
      )
          // ⏰ TIMEOUT GLOBAL SUR TOUTE LA SYNCHRO
          .timeout(const Duration(seconds: 45));
      final now = DateTime.now();
      await DatabaseHelper().saveLastSyncTime(now);
      if (mounted) {
        setState(() {
          _lastSyncTimeText = _formatTimeHHmm(now); // ex: "14:32"
        });
      }
      setState(() => lastSyncResult = result);
      setState(() => isSyncing = false);
      _showSyncResult(result);
    } on TimeoutException catch (_) {
      // 🔴 La synchro a mis trop de temps / bloqué
      setState(() => isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⏰ La synchronisation a pris trop de temps. Vérifiez votre connexion et réessayez.',
          ),
        ),
      );
    } catch (e) {
      setState(() => isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
        ),
      );
    }
  }

  double _coordinateDistance(
    lat1,
    lon1,
    lat2,
    lon2,
  ) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        (cos(
              (lat2 - lat1) * p,
            ) /
            2) +
        cos(
              lat1 * p,
            ) *
            cos(
              lat2 * p,
            ) *
            (1 -
                cos(
                  (lon2 - lon1) * p,
                )) /
            2;
    return 12742000 *
        asin(
          sqrt(
            a,
          ),
        );
  }

  @override
  void dispose() {
    homeController.dispose();
    _onlineWatchTimer?.cancel();
    super.dispose();
  }

  Widget _buildStepIndicator() {
    String currentStep = "Pistes";
    if (_currentSyncOperation.contains(
          "chaussée",
        ) ||
        _currentSyncOperation.contains(
          "chaussee",
        )) {
      currentStep = "Chaussées";
    } else if (_currentSyncOperation.contains(
          "localité",
        ) ||
        _currentSyncOperation.contains(
          "école",
        )) {
      currentStep = "Points d'intérêt";
    }

    return Row(
      children: [
        Icon(
          Icons.check_circle,
          color: currentStep == "Pistes" ? Colors.grey : Colors.green,
          size: 16,
        ),
        SizedBox(
          width: 4,
        ),
        Text(
          'Pistes',
          style: TextStyle(
            color: currentStep == "Pistes" ? Colors.orange : Colors.green,
            fontWeight: currentStep == "Pistes" ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        SizedBox(
          width: 12,
        ),
        Icon(
          Icons.check_circle,
          color: currentStep == "Chaussées"
              ? Colors.grey
              : currentStep == "Pistes"
                  ? Colors.grey
                  : Colors.green,
          size: 16,
        ),
        SizedBox(
          width: 4,
        ),
        Text(
          'Chaussées',
          style: TextStyle(
            color: currentStep == "Chaussées"
                ? Colors.orange
                : currentStep == "Pistes"
                    ? Colors.grey
                    : Colors.green,
            fontWeight: currentStep == "Chaussées" ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        SizedBox(
          width: 12,
        ),
        Icon(
          Icons.check_circle,
          color: currentStep == "Points d'intérêt" ? Colors.grey : Colors.green,
          size: 16,
        ),
        SizedBox(
          width: 4,
        ),
        Text(
          'Points',
          style: TextStyle(
            color: currentStep == "Points d'intérêt" ? Colors.orange : Colors.grey,
            fontWeight: currentStep == "Points d'intérêt" ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // Ajoutez cette méthode
  Widget _buildSyncProgressIndicator() {
    return Container(
      padding: EdgeInsets.all(
        16,
      ),
      margin: EdgeInsets.symmetric(
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color: Colors.orange[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_upload,
                color: Colors.orange,
              ),
              SizedBox(
                width: 10,
              ),
              Text(
                'Synchronisation en cours',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 12,
          ),
          LinearProgressIndicator(
            value: _syncProgressValue,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.orange,
            ),
          ),
          SizedBox(
            height: 8,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(_syncProgressValue * 100).toStringAsFixed(0)}%',
              ),
              Text(
                '$_syncProcessedItems/$_syncTotalItems',
              ),
            ],
          ),
          SizedBox(
            height: 8,
          ),
          Text(
            _currentSyncOperation,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(
            height: 8,
          ),
          // Ajouter des indicateurs d'étapes
          _buildStepIndicator(),
        ],
      ),
    );
  }

  // Ajoutez cette méthode pour afficher la progression
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(
        16,
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[100], // Même couleur que la boîte "Sauvegarde terminée"
        borderRadius: BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color: Colors.blue[100]!,
        ), // Bordure bleue claire
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.cloud_download,
                color: Colors.blue,
              ),
              SizedBox(
                width: 10,
              ),
              Text(
                'Sauvegarde en cours',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          LinearProgressIndicator(
            value: _progressValue,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(
              Colors.blue,
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(
              4,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(_progressValue * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$_processedItems/$_totalItems',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            _currentOperation,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final List<Marker> filteredMarkers = _getFilteredMarkers();

    // 2. Filtrer les polylines selon la légende
    final List<Polyline> filteredPolylines = _getFilteredPolylines();
    List<Polygon> filteredPolygons = List.from(_displayedPolygons);
    // === LOGS POUR DEBUG ===
    print('📍 [MAP] filteredMarkers size = ${filteredMarkers.length}');
    print('🧮 [MAP] filteredPolylines size = ${filteredPolylines.length}');

    // === AJOUTER LES ÉLÉMENTS EN COURS (toujours visibles) ===

    if (homeController.specialCollection != null) {
      final specialPoints = homeController.specialCollection!.points;
      if (specialPoints.length > 1) {
        if (_isPolygonCollection) {
          filteredPolylines.add(
            Polyline(
              points: [
                ...specialPoints,
                specialPoints.first
              ],
              color: const Color(0xFF2E7D32),
              strokeWidth: 3.0,
              pattern: const StrokePattern.solid(),
            ),
          );
        } else {
          final specialColor = _specialCollectionType == "Bac" ? Colors.purple : Colors.deepPurple;
          filteredPolylines.add(
            Polyline(
              points: specialPoints,
              color: specialColor,
              strokeWidth: 5.0,
              pattern: homeController.specialCollection!.isPaused
                  ? StrokePattern.dashed(segments: [
                      10,
                      5
                    ])
                  : const StrokePattern.solid(),
            ),
          );
        }
      }
    }
// === AFFICHER LE POLYGONE EN COURS DE COLLECTE ===
    if (_isPolygonCollection && homeController.specialCollection != null) {
      final polyPoints = homeController.specialCollection!.points;
      if (polyPoints.length >= 3) {
        filteredPolygons.add(
          Polygon(
            points: polyPoints,
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            borderColor: const Color(0xFF1B5E20),
            borderStrokeWidth: 3.0,
            isFilled: true,
          ),
        );
      }
    }
    // Ajouter la piste en cours si active
    if (homeController.ligneCollection != null) {
      final lignePoints = homeController.ligneCollection!.points;
      if (lignePoints.length > 1) {
        filteredPolylines.add(
          Polyline(
            points: lignePoints,
            color: homeController.ligneCollection!.isPaused ? Colors.orange : Colors.green,
            strokeWidth: 4.0,
            pattern: homeController.ligneCollection!.isPaused
                ? StrokePattern.dashed(segments: [
                    10,
                    5
                  ])
                : const StrokePattern.solid(),
          ),
        );
      }
    }

    // Ajouter la chaussée en cours si active (nouveau système)
    if (homeController.chausseeCollection != null) {
      final chausseePoints = homeController.chausseeCollection!.points;
      if (chausseePoints.length > 1) {
        filteredPolylines.add(
          Polyline(
            points: chausseePoints,
            color: homeController.chausseeCollection!.isPaused ? Colors.deepOrange : const Color(0xFFFF9800),
            strokeWidth: 5.0,
            pattern: homeController.chausseeCollection!.isPaused
                ? StrokePattern.dashed(segments: [
                    15,
                    5
                  ])
                : const StrokePattern.solid(),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(
        0xFFF0F8FF,
      ),
      body: SafeArea(
        child: Column(
          children: [
            TopBarWidget(
              agentName: widget.agentName ?? 'Agent',
              onLogout: _showLogoutConfirmation,
            ),
            Expanded(
              child: Stack(
                children: [
                  MapWidget(
                    userPosition: userPosition ?? homeController.userPosition,
                    gpsEnabled: gpsEnabled,
                    markers: filteredMarkers,
                    polylines: filteredPolylines,
                    polygons: filteredPolygons,
                    onPolygonTap: _handlePolygonTap,
                    onMapCreated: _onMapCreated,
                    formMarkers: formMarkers,
                    isSatellite: _isSatellite,
                    onPolylineTap: _handlePolylineTap,
                    onUserInteraction: () {
                      _autoCenterDisabledByUser = true;
                    },
                    onGpsButtonPressed: () {
                      _autoCenterDisabledByUser = false;
                    },
                  ),
                  // === WIDGET DE LÉGENDE ===
                  LegendWidget(
                    initialVisibility: _legendVisibility,
                    onVisibilityChanged: _updateVisibilityFromLegend,
                    allPolylines: filteredPolylines,
                    allMarkers: filteredMarkers,
                    polygonCount: _displayedPolygons.length,
                    pointCountsByTable: _pointCountsByTable,
                  ),
                  if (isSyncing)
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 3,
                        sigmaY: 3,
                      ),
                      child: Container(
                        color: Colors.black.withOpacity(
                          0.2,
                        ),
                      ),
                    ),

                  if (isDownloading)
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 3,
                        sigmaY: 3,
                      ),
                      child: Container(
                        color: Colors.black.withOpacity(
                          0.2,
                        ),
                      ),
                    ),

                  // === AJOUTEZ ICI === //
                  Positioned(
                    bottom: 200,
                    right: 16,
                    child: Visibility(
                      visible: kDebugMode && homeController.hasActiveCollection,
                      child: FloatingActionButton(
                        onPressed: () {
                          homeController.addRealisticPisteSimulation();
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Points réalistes simulés',
                              ), // ← MESSAGE MODIFIÉ
                              backgroundColor: Colors.blue,
                              duration: Duration(
                                seconds: 2,
                              ),
                            ),
                          );
                        },
                        backgroundColor: Colors.orange,
                        child: const Icon(
                          Icons.add_location_alt,
                          color: Colors.white,
                        ),
                        mini: true,
                        heroTag: 'dev_button',
                      ),
                    ),
                  ),
                  // Ajouter dans la section des boutons de debug
                  Positioned(
                    bottom: 120,
                    right: 16,
                    child: Visibility(
                      visible: _isSpecialCollection && kDebugMode,
                      child: FloatingActionButton(
                        onPressed: () {
                          homeController.addManualPointToSpecialCollection();
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Points simulés pour $_specialCollectionType',
                              ),
                              backgroundColor: Colors.purple,
                              duration: const Duration(
                                seconds: 2,
                              ),
                            ),
                          );
                        },
                        backgroundColor: Colors.purple,
                        child: const Icon(
                          Icons.add_road,
                          color: Colors.white,
                        ),
                        mini: true,
                        heroTag: 'simulate_special_button',
                      ),
                    ),
                  ),
                  //  SIMULATION POLYGONE — À SUPPRIMER APRÈS TEST
                  // 🧪 BOUTON SIMULATION ÉMULATEUR — À SUPPRIMER POUR LA PRODUCTION
                  // 🔴🔴🔴 SIMULATION POLYGONE — À SUPPRIMER APRÈS TEST 🔴🔴🔴
                  if (_isPolygonCollection)
                    Positioned(
                      bottom: 120,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: () {
                          final pos = homeController.userPosition;
                          // 5 points formant un pentagone clair autour de la position
                          final simulatedPoints = [
                            LatLng(pos.latitude + 0.002, pos.longitude),
                            LatLng(pos.latitude + 0.0006, pos.longitude + 0.0019),
                            LatLng(pos.latitude - 0.0016, pos.longitude + 0.0012),
                            LatLng(pos.latitude - 0.0016, pos.longitude - 0.0012),
                            LatLng(pos.latitude + 0.0006, pos.longitude - 0.0019),
                          ];
                          for (var pt in simulatedPoints) {
                            homeController.collectionManager.addManualPoint(
                              CollectionType.special,
                              pt,
                            );
                          }
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '🔷 5 points de polygone simulés (${homeController.specialCollection?.points.length ?? 0} total)',
                              ),
                              backgroundColor: const Color(0xFF1B5E20),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        backgroundColor: const Color(0xFF1B5E20),
                        mini: true,
                        heroTag: 'simulate_polygon_button',
                        child: const Icon(Icons.pentagon, color: Colors.white),
                      ),
                    ),
                  //  FIN SIMULATION — À SUPPRIMER APRÈS TEST
                  //  FIN SIMULATION
                  //  FIN SIMULATION — À SUPPRIMER APRÈS TEST
                  // === FIN DE L'AJOUT === //
                  // Contrôles de carte
                  MapControlsWidget(
                    controller: homeController,
                    onAddPoint: addPointOfInterest,
                    onStartLigne: startLigneCollection,
                    onStartChaussee: startChausseeCollection,
                    onToggleLigne: toggleLigneCollection,
                    onToggleChaussee: toggleChausseeCollection,
                    onFinishLigne: finishLigneCollection,
                    onFinishChaussee: finishChausseeCollection,
                    onRefresh: _loadDisplayedPoints,
                    isSpecialCollection: _isSpecialCollection, // ← NOUVEAU
                    onStopSpecial: finishSpecialCollection,
                    isPolygonCollection: _isPolygonCollection,
                    onToggleSpecial: () {
                      homeController.toggleSpecialCollection();
                      setState(() {});
                    },
                  ),
                  MapTypeToggle(
                    isSatellite: _isSatellite,
                    onMapTypeChanged: (
                      newType,
                    ) {
                      setState(
                        () {
                          _isSatellite = newType;
                        },
                      );
                    },
                  ),
                  /* DownloadedPistesToggle(
                    isOn: _showDownloadedPistes,
                    count: _downloadedPistesPolylines.length, // optionnel
                    onChanged: (value) {
                      setState(() => _showDownloadedPistes = value);
                      print('🎚️ [_UI] _showDownloadedPistes = $_showDownloadedPistes '
                          '(count=${_downloadedPistesPolylines.length})');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value ? 'Pistes téléchargées : AFFICHÉES' : 'Pistes téléchargées : MASQUÉES'),
                          duration: const Duration(milliseconds: 900),
                        ),
                      );
                    },
                  ),
                  // === NOUVEAU : même style que le bouton Pistes ===
                  DownloadedChausseesToggle(
                    isOn: _showDownloadedChaussees,
                    count: _downloadedChausseesPolylines.length,
                    onChanged: (value) {
                      setState(() => _showDownloadedChaussees = value);
                      print('🎚️ [_UI] _showDownloadedChaussees = $_showDownloadedChaussees (count=${_downloadedChausseesPolylines.length})');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value ? 'Chaussées téléchargées : AFFICHÉES' : 'Chaussées téléchargées : MASQUÉES'),
                          duration: const Duration(milliseconds: 900),
                        ),
                      );
                    },
                  ), */

                  // === WIDGETS DE STATUT (NOUVEAU SYSTÈME UNIQUEMENT) ===

                  // Afficher le statut de ligne si active
                  if (homeController.ligneCollection != null)
                    LigneStatusWidget(
                      collection: homeController.ligneCollection!,
                      topOffset: 16,
                    ),

                  // Afficher le statut de chaussée si active
                  if (homeController.chausseeCollection != null)
                    ChausseeStatusWidget(
                      collection: homeController.chausseeCollection!,
                      topOffset: homeController.ligneCollection != null ? 70 : 16,
                    ),
                  // Afficher le statut de spécial (Bac / Passage) si active
                  if (homeController.specialCollection != null)
                    SpecialStatusWidget(
                      collection: homeController.specialCollection!,
                      topOffset: homeController.ligneCollection != null && homeController.chausseeCollection != null
                          ? 124 // décalé sous les deux autres
                          : (homeController.ligneCollection != null || homeController.chausseeCollection != null)
                              ? 70 // décalé sous l’un des deux
                              : 16, // position par défaut
                    ),

                  // === COMPTE À REBOURS GPS ===
                  GlobalCountdownWidget(
                    seconds: homeController.collectionCountdown,
                    isVisible: homeController.hasActiveCollection,
                  ),

                  // DataCountWidget(count: collectedMarkers.length + collectedPolylines.length),
                  // Remplacez le Positioned actuel par ceci :
                  if (isDownloading)
                    Positioned(
                      top: 70, // Position sous la barre d'outils
                      left: 0,
                      right: 0,
                      child: AnimatedSlide(
                        duration: const Duration(
                          milliseconds: 300,
                        ),
                        curve: Curves.easeOut,
                        offset: isDownloading
                            ? Offset.zero
                            : const Offset(
                                0,
                                -1,
                              ),
                        child: AnimatedOpacity(
                          duration: const Duration(
                            milliseconds: 300,
                          ),
                          opacity: isDownloading ? 1.0 : 0.0,
                          child: _buildProgressIndicator(),
                        ),
                      ),
                    ),
                  if (isSyncing)
                    Positioned(
                      top: 70, // Position sous la top bar
                      left: 0,
                      right: 0,
                      child: AnimatedSlide(
                        duration: Duration(
                          milliseconds: 300,
                        ),
                        curve: Curves.easeOut,
                        offset: isSyncing
                            ? Offset.zero
                            : Offset(
                                0,
                                -1,
                              ),
                        child: AnimatedOpacity(
                          duration: Duration(
                            milliseconds: 300,
                          ),
                          opacity: isSyncing ? 1.0 : 0.0,
                          child: _buildSyncProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            BottomStatusBarWidget(
              gpsEnabled: gpsEnabled,
              isOnline: _isOnlineDynamic,
              lastSyncTime: _lastSyncTimeText,
            ),
            BottomButtonsWidget(
              onSave: isDownloading ? () {} : _showSaveConfirmationDialog,
              onSync: isSyncing ? () {} : _showSyncConfirmationDialog,
              onMenu: handleMenuPress,
            ),
          ],
        ),
      ),
    );
  }
}

String getEntityTypeFromTable(String tableName) {
  const entityTypes = {
    'localites': 'Localité',
    'ecoles': 'École',
    'marches': 'Marché',
    'services_santes': 'Service de Santé',
    'batiments_administratifs': 'Bâtiment Administratif',
    'infrastructures_hydrauliques': 'Infrastructure Hydraulique',
    'autres_infrastructures': 'Autre Infrastructure',
    'ponts': 'Pont',
    'buses': 'Buse',
    'dalots': 'Dalot',
    'points_critiques': 'Point Critique',
    'points_coupures': 'Point de Coupure',
    'site_enquete': 'Site de Plaine',
    'enquete_polygone': 'Zone de Plaine',
  };
  return entityTypes[tableName] ?? tableName;
}

class DisplayedPointsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Marker>> getDisplayedPointsMarkers({
    required void Function(Map<String, dynamic>) onTapDetails,
  }) async {
    try {
      final points = await _dbHelper.loadDisplayedPoints();
      final List<Marker> markers = [];
      final user = await _dbHelper.getCurrentUser();
      final regionNom = (user?['region_nom'] ?? ApiService.regionNom ?? '----').toString();
      final prefectureNom = (user?['prefecture_nom'] ?? ApiService.prefectureNom ?? '----').toString();
      final communeNom = (user?['commune_nom'] ?? ApiService.communeNom ?? '----').toString();

      // Créer les marqueurs avec les icônes (flutter_map utilise des Widgets, pas besoin de cache)
      for (var point in points) {
        final pointType = point['point_type'] as String?;
        if (pointType == "Bac" || pointType == "Passage Submersible") {
          continue;
        }

        final table = (point['original_table'] ?? '').toString();
        final pointName = point['point_name'] as String? ?? 'Sans nom';
        final typeLabel = getEntityTypeFromTable(table);

        final name = (point['point_name'] ?? point['nom'] ?? 'Sans nom').toString();
        final codePiste = point['code_piste'] as String? ?? 'N/A';
        final double lat = (point['latitude'] as num).toDouble();
        final double lng = (point['longitude'] as num).toDouble();

        markers.add(Marker(
          point: LatLng(lat, lng),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () async {
              final db = await _dbHelper.database;
              final originalId = point['id'];
              final originalTable = (point['original_table'] ?? '').toString();
              String synced = '0';
              String regionName = '';
              String prefectureName = '';
              String communeName = '';
              String enqueteurFromDb = '';

              if (originalTable.isNotEmpty && originalId != null) {
                try {
                  final rows = await db.query(
                    originalTable,
                    columns: [
                      'synced',
                      'region_name',
                      'prefecture_name',
                      'commune_name',
                      'enqueteur'
                    ],
                    where: 'id = ?',
                    whereArgs: [
                      originalId
                    ],
                    limit: 1,
                  );
                  if (rows.isNotEmpty) {
                    synced = (rows.first['synced'] ?? 0).toString();
                    regionName = (rows.first['region_name'] ?? '').toString();
                    prefectureName = (rows.first['prefecture_name'] ?? '').toString();
                    communeName = (rows.first['commune_name'] ?? '').toString();
                    enqueteurFromDb = (rows.first['enqueteur'] ?? '').toString();
                  }
                } catch (_) {}
              }

              onTapDetails({
                'type': getEntityTypeFromTable(table),
                'name': (point['point_name'] ?? point['nom'] ?? 'Sans nom').toString(),
                'enqueteur': enqueteurFromDb.isNotEmpty ? enqueteurFromDb : (point['enqueteur'] ?? '').toString(),
                'code_piste': (codePiste ?? '').toString(),
                'lat': lat,
                'lng': lng,
                'synced': synced,
                'region_name': regionName,
                'prefecture_name': prefectureName,
                'commune_name': communeName,
              });
            },
            child: CustomMarkerIcons.getMarkerWidget(table),
          ),
        ));
      }

      print('📍 ${markers.length} points affichés chargés (cache: ${CustomMarkerIcons.getCacheSize()} icônes)');
      return markers;
    } catch (e) {
      print('❌ Erreur dans getDisplayedPointsMarkers: $e');
      return [];
    }
  }

  Future<List<Marker>> refreshDisplayedPoints({
    required void Function(Map<String, dynamic>) onTapDetails,
  }) async {
    return await getDisplayedPointsMarkers(onTapDetails: onTapDetails);
  }
}

// Dans home_page.dart, ajoutez cette classe
class SpecialLinesService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Polyline>> getDisplayedSpecialLines({
    required void Function(Map<String, dynamic>) onTapDetails,
  }) async {
    try {
      final lines = await _dbHelper.loadDisplayedSpecialLines();
      final List<Polyline> polylines = [];

      for (var line in lines) {
        final specialType = (line['special_type'] ?? '').toString();
// DEBUG
        print('🔍 Special line type from DB: "$specialType"');
        print('🔍 toLowerCase: "${specialType.toLowerCase()}"');
        Color lineColor;
        StrokePattern? linePattern;

        switch (specialType.toLowerCase()) {
          case 'bac':
            lineColor = Colors.purple;
            linePattern = StrokePattern.dashed(segments: [
              15,
              5
            ]);
            break;
          case 'passage submersible':
            lineColor = Colors.cyan;
            linePattern = StrokePattern.dashed(segments: [
              15,
              5
            ]);
            break;
          default:
            lineColor = Colors.blueGrey;
            linePattern = null;
        }

        final start = LatLng(
          (line['lat_debut'] as num).toDouble(),
          (line['lng_debut'] as num).toDouble(),
        );
        final end = LatLng(
          (line['lat_fin'] as num).toDouble(),
          (line['lng_fin'] as num).toDouble(),
        );
// ⭐ Skip les lignes où début == fin (polyline invisible)
        if (start.latitude == end.latitude && start.longitude == end.longitude) {
          print('⚠️ Ligne spéciale ignorée (début == fin): $specialType');
          continue;
        }
        // ✅ distance en km (utilise tes méthodes haversine déjà ajoutées)
        // (tu vas la calculer côté HomePage, pas ici)
        // Ici on renvoie juste les coords.
        final st = specialType.toLowerCase().trim();
        final tag = st.contains('bac')
            ? 'bac'
            : st.contains('passage')
                ? 'passage_submersible'
                : 'special';
        final distanceKm = _haversineDistance(start, end);

        // Chercher synced/region dans la vraie table (bacs ou passages_submersibles)
        String slSynced = '0';
        String slRegion = '';
        String slPrefecture = '';
        String slCommune = '';
        String slEnqueteur = '';
        try {
          final originalTable = (line['original_table'] ?? '').toString();
          if (originalTable.isNotEmpty) {
            final slDb = await _dbHelper.database;
            final slRows = await slDb.query(
              originalTable,
              columns: [
                'synced',
                'region_name',
                'prefecture_name',
                'commune_name',
                'enqueteur'
              ],
              where: 'id = ?',
              whereArgs: [
                line['original_id']
              ],
              limit: 1,
            );
            if (slRows.isNotEmpty) {
              slSynced = (slRows.first['synced']?.toString() == '1') ? '1' : '0';
              slRegion = (slRows.first['region_name'] ?? '').toString();
              slPrefecture = (slRows.first['prefecture_name'] ?? '').toString();
              slCommune = (slRows.first['commune_name'] ?? '').toString();
              slEnqueteur = (slRows.first['enqueteur'] ?? '').toString();
            }
          }
        } catch (_) {}

        polylines.add(
          Polyline(
            points: [
              start,
              end
            ],
            color: lineColor,
            strokeWidth: 4.0,
            pattern: linePattern ?? const StrokePattern.solid(),

            // ✅ IMPORTANT : PolylineTapData (comme Chaussees)
            hitValue: PolylineTapData(
              type: 'special_local',
              data: {
                'special_type': specialType,
                'start_lat': start.latitude,
                'start_lng': start.longitude,
                'end_lat': end.latitude,
                'end_lng': end.longitude,
                'distance_km': distanceKm,
                'synced': slSynced,
                'region_name': slRegion,
                'prefecture_name': slPrefecture,
                'commune_name': slCommune,
                'enqueteur': slEnqueteur,
              },
            ),
          ),
        );
      }

      print('📍 ${polylines.length} lignes spéciales chargées');
      return polylines;
    } catch (e) {
      print('❌ Erreur chargement lignes spéciales: $e');
      return [];
    }
  }

  double _haversineDistance(LatLng start, LatLng end) {
    const double R = 6371; // Rayon de la Terre en km
    final dLat = (end.latitude - start.latitude) * pi / 180;
    final dLon = (end.longitude - start.longitude) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(start.latitude * pi / 180) * cos(end.latitude * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}

class DownloadedPointsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Marker>> getDownloadedPointsMarkers({
    required void Function(Map<String, dynamic>) onTapDetails,
    void Function(String tableName, Marker marker)? onMarkerCreated,
  }) async {
    try {
      final List<String> pointTables = [
        'localites',
        'ecoles',
        'marches',
        'services_santes',
        'batiments_administratifs',
        'infrastructures_hydrauliques',
        'autres_infrastructures',
        'ponts',
        'buses',
        'dalots',
        'points_critiques',
        'points_coupures',
        'site_enquete',
        'enquete_polygone',
      ];

      final List<Marker> markers = [];
      final loginId = await DatabaseHelper().resolveLoginId();

      if (loginId == null) {
        print('❌ [DL-POINTS] Impossible de déterminer login_id (viewer)');
        return [];
      }
      final user = await _dbHelper.getCurrentUser();
      final regionNom = (user?['region_nom'] ?? ApiService.regionNom ?? '----').toString();
      final prefectureNom = (user?['prefecture_nom'] ?? ApiService.prefectureNom ?? '----').toString();
      final communeNom = (user?['commune_nom'] ?? ApiService.communeNom ?? '----').toString();

      // Pré-générer toutes les icônes nécessaires
      /* final Map<String, Future<BitmapDescriptor>> iconFutures = {};
      for (var tableName in pointTables) {
        iconFutures[tableName] = CustomMarkerIcons.getIconForTable(tableName);
      }

      // Récupérer toutes les icônes en parallèle
      final Map<String, BitmapDescriptor> icons = {};
      await Future.wait(
        iconFutures.entries.map((entry) async {
          icons[entry.key] = await entry.value;
        }),
      );*/

      // Traiter chaque table
      for (var tableName in pointTables) {
        try {
          final db = await _dbHelper.database;
          final points = await db.query(
            tableName,
            where: 'downloaded = ? AND saved_by_user_id = ?',
            whereArgs: [
              1,
              loginId
            ],
          );

          for (var point in points) {
            final coordinates = _getCoordinatesFromPoint(point, tableName);

            if (coordinates['lat'] != null && coordinates['lng'] != null) {
              final double lat = (coordinates['lat'] as num).toDouble();
              final double lng = (coordinates['lng'] as num).toDouble();
              final typeLabel = _getEntityTypeFromTable(tableName);
              final name = (point['nom'] ?? point['name'] ?? point['libelle'] ?? 'Sans nom').toString();

              final pointName = point['nom'] ?? 'Sans nom';
              final codePiste = point['code_piste'] ?? 'N/A';
              final enqueteur = point['enqueteur'] ?? 'Autre utilisateur';

              // Utiliser l'icône du cache
              // final icon = icons[tableName] ?? await CustomMarkerIcons.getIconForTable(tableName);

              markers.add(
                Marker(
                  point: LatLng(lat, lng),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () {
                      onTapDetails({
                        'type': getEntityTypeFromTable(tableName),
                        'name': (point['nom'] ?? point['name'] ?? point['libelle'] ?? 'Sans nom').toString(),
                        'enqueteur': (point['enqueteur'] ?? '').toString(),
                        'code_piste': (codePiste ?? '').toString(),
                        'lat': lat,
                        'lng': lng,
                        'region_name': (point['region_name'] ?? '').toString(),
                        'prefecture_name': (point['prefecture_name'] ?? '').toString(),
                        'commune_name': (point['commune_name'] ?? '').toString(),
                      });
                    },
                    child: CustomMarkerIcons.getMarkerWidget(tableName),
                  ),
                ),
              );
              // Notifier le callback pour le filtrage par table
              if (onMarkerCreated != null) {
                onMarkerCreated(tableName, markers.last);
              }
              print('🧮 [DL-POINTS] $tableName count=${points.length} (viewerId=$loginId)');
            }
          }
        } catch (e) {
          print('❌ Erreur table $tableName: $e');
        }
      }
      print('🧾 [DL-POINTS] viewerId used for filter = $loginId, apiUserId=${ApiService.userId}');

      print('📍 ${markers.length} points téléchargés chargés (cache: ${CustomMarkerIcons.getCacheSize()} icônes)');
      return markers;
    } catch (e) {
      print('❌ Erreur dans getDownloadedPointsMarkers: $e');
      return [];
    }
  }

  Map<String, dynamic> _getCoordinatesFromPoint(
    Map<String, dynamic> point,
    String tableName,
  ) {
    final coordinateMappings = {
      'localites': {
        'lat': 'y_localite',
        'lng': 'x_localite',
      },
      'ecoles': {
        'lat': 'y_ecole',
        'lng': 'x_ecole',
      },
      'marches': {
        'lat': 'y_marche',
        'lng': 'x_marche',
      },
      'services_santes': {
        'lat': 'y_sante',
        'lng': 'x_sante',
      },
      'batiments_administratifs': {
        'lat': 'y_batiment_administratif',
        'lng': 'x_batiment_administratif',
      },
      'infrastructures_hydrauliques': {
        'lat': 'y_infrastructure_hydraulique',
        'lng': 'x_infrastructure_hydraulique',
      },
      'autres_infrastructures': {
        'lat': 'y_autre_infrastructure',
        'lng': 'x_autre_infrastructure',
      },
      'ponts': {
        'lat': 'y_pont',
        'lng': 'x_pont',
      },
      'buses': {
        'lat': 'y_buse',
        'lng': 'x_buse',
      },
      'dalots': {
        'lat': 'y_dalot',
        'lng': 'x_dalot',
      },
      'points_critiques': {
        'lat': 'y_point_critique',
        'lng': 'x_point_critique',
      },
      'points_coupures': {
        'lat': 'y_point_coupure',
        'lng': 'x_point_coupure',
      },
      'site_enquete': {
        'lat': 'y_site',
        'lng': 'x_site',
      },
      'enquete_polygone': {
        'lat': 'y_site',
        'lng': 'x_site'
      }, // pas utilisé (polygone)
    };

    final mapping = coordinateMappings[tableName];
    if (mapping != null) {
      return {
        'lat': point[mapping['lat']],
        'lng': point[mapping['lng']],
      };
    }

    return {
      'lat': null,
      'lng': null,
    };
  }

  String _getEntityTypeFromTable(
    String tableName,
  ) {
    const entityTypes = {
      'localites': 'Localité',
      'ecoles': 'École',
      'marches': 'Marché',
      'services_santes': 'Service de Santé',
      'batiments_administratifs': 'Bâtiment Administratif',
      'infrastructures_hydrauliques': 'Infrastructure Hydraulique',
      'autres_infrastructures': 'Autre Infrastructure',
      'ponts': 'Pont',
      'buses': 'Buse',
      'dalots': 'Dalot',
      'points_critiques': 'Point Critique',
      'points_coupures': 'Point de Coupure',
      'site_enquete': 'Site de Plaine',
      'enquete_polygone': 'Zone de Plaine',
    };
    return entityTypes[tableName] ?? tableName;
  }
}

// Dans home_page.dart – Service d’affichage des pistes téléchargées (robuste + logs)
class DownloadedPistesService {
  final SimpleStorageHelper _storageHelper = SimpleStorageHelper();

  // Brun proche orange
  static const Color downloadedPisteColor = Color(0xFFB86E1D);

  // --- Helpers robustes ---

  /// Essaie d'extraire (lon, lat) depuis différents formats de point
  LatLng? _parsePoint(dynamic item) {
    try {
      // 1) Liste [lon, lat]
      if (item is List && item.length >= 2) {
        final lon = (item[0] as num?)?.toDouble();
        final lat = (item[1] as num?)?.toDouble();
        if (lon != null && lat != null) return LatLng(lat, lon);
      }

      // 2) Map {lon, lat} / {x, y} / {longitude, latitude}
      if (item is Map) {
        // clés possibles
        final candidatesLon = [
          'lon',
          'lng',
          'x',
          'longitude'
        ];
        final candidatesLat = [
          'lat',
          'y',
          'latitude'
        ];

        double? lon;
        double? lat;

        for (final k in candidatesLon) {
          if (item.containsKey(k)) {
            final v = item[k];
            if (v is num) lon = v.toDouble();
            if (v is String) lon = double.tryParse(v);
            break;
          }
        }
        for (final k in candidatesLat) {
          if (item.containsKey(k)) {
            final v = item[k];
            if (v is num) lat = v.toDouble();
            if (v is String) lat = double.tryParse(v);
            break;
          }
        }

        if (lon != null && lat != null) return LatLng(lat, lon);

        // parfois {lat, lon} inversés / noms différents
        if (item.containsKey('latitude') && item.containsKey('longitude')) {
          final lat2 = (item['latitude'] is num) ? (item['latitude'] as num).toDouble() : double.tryParse(item['latitude'].toString());
          final lon2 = (item['longitude'] is num) ? (item['longitude'] as num).toDouble() : double.tryParse(item['longitude'].toString());
          if (lat2 != null && lon2 != null) return LatLng(lat2, lon2);
        }
      }

      // 3) String "lon,lat" ou "lon lat"
      if (item is String) {
        final s = item.trim();
        final sep = s.contains(',') ? ',' : ' ';
        final parts = s.split(sep).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (parts.length >= 2) {
          final lon = double.tryParse(parts[0]);
          final lat = double.tryParse(parts[1]);
          if (lon != null && lat != null) return LatLng(lat, lon);
        }
      }
    } catch (_) {
      // ignore, on retourne null
    }
    return null;
  }

  /// Convertit une liste hétérogène (list/objects/strings) en List<LatLng>
  List<LatLng> _toLatLngList(dynamic coords) {
    final result = <LatLng>[];
    if (coords is! List) return result;

    for (final item in coords) {
      final p = _parsePoint(item);
      if (p != null) result.add(p);
    }
    return result;
  }

  /// Essaie d’extraire une liste de coordonnées d’un GeoJSON line-like
  /// - MultiLineString: prend la première ligne
  /// - LineString: prend la liste directement
  dynamic _extractLineCoordsFromGeoJson(Map gj) {
    final gType = (gj['type'] ?? '').toString();
    final coords = gj['coordinates'];
    if (gType == 'MultiLineString' && coords is List && coords.isNotEmpty) {
      return coords.first; // [[lon,lat], ...]
    }
    if (gType == 'LineString' && coords is List) {
      return coords;
    }
    return null;
  }

  double _deg2rad(double deg) => deg * (Math.pi / 180.0);

  double _haversineMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);

    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);

    final sinDLat = Math.sin(dLat / 2);
    final sinDLng = Math.sin(dLng / 2);

    final h = sinDLat * sinDLat + Math.cos(lat1) * Math.cos(lat2) * sinDLng * sinDLng;
    final c = 2 * Math.asin(Math.min(1.0, Math.sqrt(h)));
    return R * c;
  }

  double _polylineDistanceKm(List<LatLng> pts) {
    if (pts.length < 2) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < pts.length - 1; i++) {
      sum += _haversineMeters(pts[i], pts[i + 1]);
    }
    return sum / 1000.0;
  }

  Future<List<Polyline>> getDownloadedPistesPolylines({
    required void Function(Map<String, dynamic>) onTapDetails,
  }) async {
    try {
      final db = await _storageHelper.database;
      final loginId = await DatabaseHelper().resolveLoginId();
      if (loginId == null) {
        print('❌ [DL-PISTES] Impossible de déterminer login_id (viewer)');
        return [];
      }
      print('🔎 [DL-PISTES] Chargement (downloaded=1, saved_by_user_id=${ApiService.userId})');
      final pistes = await db.query(
        'pistes',
        where: 'downloaded = ? AND saved_by_user_id = ?',
        whereArgs: [
          1,
          loginId
        ],
      );
      print('📦 [DL-PISTES] ${pistes.length} ligne(s) trouvée(s) en SQLite (table pistes)');

      // Stats rapides
      int withPointsJson = 0, withGeom = 0, unusable = 0;
      for (final r in pistes) {
        final pj = r['points_json'];
        final g = r['geom'];
        if (pj is String && pj.trim().isNotEmpty)
          withPointsJson++;
        else if (g != null && g.toString().trim().startsWith('{'))
          withGeom++;
        else
          unusable++;
      }
      print('🧮 [DL-PISTES] points_json OK: $withPointsJson | geom GeoJSON OK: $withGeom | sans exploitable: $unusable');

      final polylines = <Polyline>{};
      int added = 0, skipped = 0;

      for (final row in pistes) {
        final id = row['id'];
        final code = row['code_piste'];
        final createdAt = row['created_at'];

        List<LatLng> points = [];

        // 1) points_json prioritaire
        final pointsJson = row['points_json'];
        if (pointsJson is String && pointsJson.trim().isNotEmpty) {
          // debug: petit aperçu
          final preview = pointsJson.length > 120 ? pointsJson.substring(0, 120) + '…' : pointsJson;
          print('🔤 [DL-PISTE:$id] $code -> points_json len=${pointsJson.length} preview="$preview"');

          try {
            final decoded = jsonDecode(pointsJson);
            points = _toLatLngList(decoded);
            print('✅ [DL-PISTE:$id] $code -> points_json converti: ${points.length} pts');
          } catch (e) {
            print('⚠️  [DL-PISTE:$id] $code -> points_json non décodable: $e');
          }
        }

        // 2) sinon, geom (GeoJSON 4326)
        if (points.isEmpty) {
          final geom = row['geom'];
          final gs = geom?.toString().trim() ?? '';
          if (gs.startsWith('{')) {
            try {
              final gj = jsonDecode(gs);
              final line = _extractLineCoordsFromGeoJson(gj);
              if (line != null) {
                final preview = line is List ? (line.isNotEmpty ? line.first.toString() : '[]') : line.toString();
                print('🔤 [DL-PISTE:$id] $code -> geom.gj sample="$preview"');
                points = _toLatLngList(line);
                print('✅ [DL-PISTE:$id] $code -> geom converti: ${points.length} pts');
              } else {
                print('⚠️  [DL-PISTE:$id] $code -> GeoJSON type/structure non gérée');
              }
            } catch (e) {
              print('⚠️  [DL-PISTE:$id] $code -> geom non décodable: $e');
            }
          } else if (gs.isNotEmpty) {
            print('ℹ️  [DL-PISTE:$id] $code -> geom non-GeoJSON (ex: WKT/UTM), ignoré offline');
          }
        }

        if (points.length < 2) {
          print('🚫 [DL-PISTE:$id] $code -> moins de 2 points (${points.length}), skip (created_at=$createdAt)');
          skipped++;
          continue;
        }

        final first = points.first;
        final last = points.last;
        print('➕ [DL-PISTE:$id] $code -> polyline ${points.length} pts | '
            'start=(${first.latitude},${first.longitude}) end=(${last.latitude},${last.longitude})');
        final distanceKm = _polylineDistanceKm(points);

        final pl = Polyline(
          points: points,
          color: downloadedPisteColor,
          strokeWidth: 3.0,
          pattern: StrokePattern.dotted(spacingFactor: 2.0),

          // ✅ AJOUT IMPORTANT
          hitValue: PolylineTapData(
            type: 'piste_downloaded',
            data: {
              'code_piste': (code ?? '----').toString(),
              'nb_points': points.length,
              'start_lat': points.first.latitude,
              'start_lng': points.first.longitude,
              'end_lat': points.last.latitude,
              'end_lng': points.last.longitude,
              'distance_km': distanceKm,
              'plateforme': (row['plateforme'] ?? '----').toString(),
              'relief': (row['relief'] ?? '----').toString(),
              'vegetation': (row['vegetation'] ?? '----').toString(),
              'debut_travaux': (row['debut_travaux'] ?? '----').toString(),
              'fin_travaux': (row['fin_travaux'] ?? '----').toString(),
              'financement': (row['financement'] ?? '----').toString(),
              'projet': (row['projet'] ?? '----').toString(),
              'entreprise': (row['entreprise'] ?? '----').toString(),
              'region_name': (row['region_name'] ?? '----').toString(),
              'prefecture_name': (row['prefecture_name'] ?? '----').toString(),
              'commune_name': (row['commune_name'] ?? '----').toString(),
            },
          ),
        );

        polylines.add(pl);
        added++;
      }

      print('🎯 [DL-PISTES] ajoutées: $added | ignorées: $skipped');
      return polylines.toList();
    } catch (e) {
      print('❌ [DL-PISTES] Erreur chargement: $e');
      return [];
    }
  }
}

class DownloadedChausseesService {
  final SimpleStorageHelper _storageHelper = SimpleStorageHelper();

  // Couleur par défaut pour les chaussées téléchargées (tu peux changer)
  static const Color downloadedChausseeColor = Color(0xFF1A7F5A); // vert foncé

  LatLng? _parsePoint(dynamic item) {
    try {
      // 1) [lon, lat]
      if (item is List && item.length >= 2) {
        final lon = (item[0] as num?)?.toDouble();
        final lat = (item[1] as num?)?.toDouble();
        if (lon != null && lat != null) return LatLng(lat, lon);
      }
      // 2) {longitude, latitude}
      if (item is Map) {
        final lon = (item['longitude'] ?? item['lng']) as num?;
        final lat = (item['latitude'] ?? item['lat']) as num?;
        if (lon != null && lat != null) return LatLng(lat.toDouble(), lon.toDouble());
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  List<LatLng> _parsePointsJson(dynamic raw) {
    if (raw == null) return [];
    try {
      final decoded = (raw is String) ? jsonDecode(raw) : raw;
      if (decoded is List) {
        final pts = <LatLng>[];
        for (final item in decoded) {
          final p = _parsePoint(item);
          if (p != null) pts.add(p);
        }
        return pts;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Fallback GeoJSON { "type":"MultiLineString", "coordinates":[ [ [lon,lat], ... ] ] }
  List<LatLng> _parseGeom(dynamic raw) {
    try {
      if (raw is String && raw.trim().startsWith('{')) {
        final g = jsonDecode(raw);
        if (g is Map && g['type'] == 'MultiLineString') {
          final coords = g['coordinates'];
          if (coords is List && coords.isNotEmpty && coords[0] is List) {
            final firstLine = coords[0] as List;
            final pts = <LatLng>[];
            for (final item in firstLine) {
              final p = _parsePoint(item);
              if (p != null) pts.add(p);
            }
            return pts;
          }
        }
      }
    } catch (_) {}
    return [];
  }

  double _deg2rad(double deg) => deg * (Math.pi / 180.0);

  double _haversineMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);

    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);

    final sinDLat = Math.sin(dLat / 2);
    final sinDLng = Math.sin(dLng / 2);

    final h = sinDLat * sinDLat + Math.cos(lat1) * Math.cos(lat2) * sinDLng * sinDLng;
    final c = 2 * Math.asin(Math.min(1.0, Math.sqrt(h)));
    return R * c;
  }

  double _polylineDistanceKm(List<LatLng> pts) {
    if (pts.length < 2) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < pts.length - 1; i++) {
      sum += _haversineMeters(pts[i], pts[i + 1]);
    }
    return sum / 1000.0;
  }

  Future<List<Polyline>> getDownloadedChausseesPolylines({
    required void Function(Map<String, dynamic>) onTapDetails,
  }) async {
    final polylines = <Polyline>{};
    try {
      final db = await _storageHelper.database;
      final loginId = await DatabaseHelper().resolveLoginId();
      if (loginId == null) {
        print('❌ [DL-CHAUSSEES] Impossible de déterminer login_id (viewer)');
        return [];
      }
      // même filtre que pour les pistes téléchargées
      final rows = await db.query(
        'chaussees',
        where: 'downloaded = ? AND saved_by_user_id = ?',
        whereArgs: [
          1,
          loginId
        ],
      );

      int added = 0, skipped = 0;

      for (final r in rows) {
        final id = r['id'];
        final type = (r['type_chaussee'] ?? '').toString(); // ex: 'bitume', 'terre', 'latérite', 'sable', 'bouwal'
        final endroit = (r['endroit'] ?? '').toString();
        final codePiste = (r['code_piste'] ?? '').toString();

        // points
        List<LatLng> pts = _parsePointsJson(r['points_json']);
        if (pts.isEmpty) {
          // fallback éventuel (peu probable si points_json est rempli)
          pts = _parseGeom(r['geom']);
        }
        // ignorer si vide
        if (pts.length < 2) {
          skipped++;
          continue;
        }

        // Style : utilise tes helpers existants si tu veux des patterns/couleurs par type
        final helper = SimpleStorageHelper();
        final color = helper.getChausseeColor(type); // mapping déjà présent chez toi
        final pattern = helper.getChausseePattern(type); // idem
        final width = 6;
        final distanceKm = _polylineDistanceKm(pts);

        final pl = Polyline(
          points: pts,
          color: color ?? DownloadedChausseesService.downloadedChausseeColor,
          strokeWidth: width.toDouble(),
          pattern: pattern ?? const StrokePattern.solid(),

          // ✅ AJOUT IMPORTANT
          hitValue: PolylineTapData(
            type: 'chaussee_downloaded',
            data: {
              'type_chaussee': type,
              'endroit': endroit,
              'code_piste': codePiste,
              'nb_points': pts.length,
              'start_lat': pts.first.latitude,
              'start_lng': pts.first.longitude,
              'end_lat': pts.last.latitude,
              'end_lng': pts.last.longitude,
              'distance_km': distanceKm,
              'region_name': (r['region_name'] ?? '----').toString(),
              'prefecture_name': (r['prefecture_name'] ?? '----').toString(),
              'commune_name': (r['commune_name'] ?? '----').toString(),
            },
          ),
        );

        polylines.add(pl);
        added++;
      }

      print('🎯 [DL-CHAUSSEES] ajoutées: $added | ignorées: $skipped');
    } catch (e) {
      print('❌ [DL-CHAUSSEES] Erreur chargement: $e');
    }
    return polylines.toList();
  }
}

class DownloadedSpecialLinesService {
  final SimpleStorageHelper _storageHelper = SimpleStorageHelper();

  Future<List<Polyline>> getDownloadedSpecialLinesPolylines({
    required void Function(Map<String, dynamic>) onTapDetails,
  }) async {
    final polylines = <Polyline>{};

    try {
      final db = await _storageHelper.database;
      final loginId = await DatabaseHelper().resolveLoginId();

      if (loginId == null) {
        print('❌ [DL-SPECIAL] Impossible de déterminer login_id (viewer)');
        return [];
      }

      // ✅ change si ton nom de table diffère
      const tableName = 'special_lines';

      final rows = await db.query(
        tableName,
        where: 'downloaded = ? AND saved_by_user_id = ?',
        whereArgs: [
          1,
          loginId
        ],
      );

      int added = 0, skipped = 0;

      for (final r in rows) {
        final id = r['id'];

        final specialTypeRaw = (r['special_type'] ?? r['type'] ?? '').toString();
        final st = specialTypeRaw.toLowerCase().trim();

        final latDebut = r['lat_debut'];
        final lngDebut = r['lng_debut'];
        final latFin = r['lat_fin'];
        final lngFin = r['lng_fin'];

        if (latDebut == null || lngDebut == null || latFin == null || lngFin == null) {
          skipped++;
          continue;
        }

        final start = LatLng((latDebut as num).toDouble(), (lngDebut as num).toDouble());
        final end = LatLng((latFin as num).toDouble(), (lngFin as num).toDouble());

        // ✅ tag logique pour la légende
        final String tag = st.contains('bac') ? 'bac' : (st.contains('passage') ? 'passage_submersible' : 'special');

        // ✅ style comme tes lignes locales
        Color lineColor;
        StrokePattern? linePattern;

        if (tag == 'bac') {
          lineColor = Colors.purple;
          linePattern = StrokePattern.dashed(segments: [
            15,
            5
          ]);
        } else if (tag == 'passage_submersible') {
          lineColor = Colors.cyan;
          linePattern = StrokePattern.dashed(segments: [
            15,
            5
          ]);
        } else {
          lineColor = Colors.blueGrey;
          linePattern = null;
        }

        polylines.add(
          Polyline(
            points: [
              start,
              end
            ],
            color: lineColor,
            strokeWidth: 4.0,
            pattern: linePattern ?? const StrokePattern.solid(),

            // ✅ AJOUT IMPORTANT
            hitValue: PolylineTapData(
              type: 'special_downloaded',
              data: {
                'special_type': specialTypeRaw, // ou specialTypeRaw / r['special_type']
                'start_lat': start.latitude,
                'start_lng': start.longitude,
                'end_lat': end.latitude,
                'end_lng': end.longitude,
                // si tu veux aussi l’afficher :
                'code_piste': (r['code_piste'] ?? '----').toString(),
                // tu peux ajouter distance si tu veux:
                'distance_km': _haversineDistance(start, end),
                'region_name': (r['region_name'] ?? '----').toString(),
                'prefecture_name': (r['prefecture_name'] ?? '----').toString(),
                'commune_name': (r['commune_name'] ?? '----').toString(),
              },
            ),
          ),
        );

        added++;
      }

      print('🎯 [DL-SPECIAL] ajoutées: $added | ignorées: $skipped');
      return polylines.toList();
    } catch (e) {
      print('❌ [DL-SPECIAL] Erreur chargement: $e');
      return [];
    }
  }

  double _haversineDistance(LatLng start, LatLng end) {
    const double R = 6371; // Rayon de la Terre en km
    final dLat = (end.latitude - start.latitude) * pi / 180;
    final dLon = (end.longitude - start.longitude) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(start.latitude * pi / 180) * cos(end.latitude * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}

/// Données associées à une Polyline pour gérer les taps
class PolylineTapData {
  final String type; // 'piste', 'chaussee', 'special_bac', 'special_passage', 'downloaded_piste', etc.
  final Map<String, dynamic> data;

  PolylineTapData({
    required this.type,
    required this.data,
  });
}

class PolygonTapData {
  final String nom;
  final String codePiste;
  final double superficie;
  final int nbSommets;
  final String enqueteur;
  final String dateCreation;
  final bool synced;
  final bool downloaded;
  final String regionName;
  final String prefectureName;
  final String communeName;

  PolygonTapData({
    required this.nom,
    required this.codePiste,
    required this.superficie,
    required this.nbSommets,
    required this.enqueteur,
    required this.dateCreation,
    required this.synced,
    this.downloaded = false,
    this.regionName = '',
    this.prefectureName = '',
    this.communeName = '',
  });

  String get statut {
    if (downloaded) return 'Sauvegardée (downloaded)';
    if (synced) return 'Synchronisée';
    return 'Enregistrée localement';
  }
}
