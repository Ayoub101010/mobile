import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/local/database_helper.dart';

import '../screens/home/home_page.dart';

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

            //  IMPORTANT : PolylineTapData (comme Chaussees)
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

class DownloadedSpecialLinesService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Polyline>> getDownloadedSpecialLinesPolylines({
    required void Function(Map<String, dynamic>) onTapDetails,
  }) async {
    final polylines = <Polyline>{};

    try {
      final db = await _dbHelper.database;
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
                'enqueteur': (r['enqueteur'] ?? '').toString(),
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
