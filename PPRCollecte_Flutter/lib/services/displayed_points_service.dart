import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/local/database_helper.dart';
import '../widgets/common/custom_marker_icons.dart';
import '../screens/home/home_page.dart';
import '../data/remote/api_service.dart';

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
