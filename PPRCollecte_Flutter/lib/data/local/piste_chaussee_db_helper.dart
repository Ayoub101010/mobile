// lib/simple_storage_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/piste_model.dart';
import '../../models/chaussee_model.dart';
import 'dart:convert'; // Pour jsonEncode/jsonDecode
import 'package:flutter/material.dart'; // Pour Color
import 'package:flutter_map/flutter_map.dart'; // Pour Polyline
import 'package:latlong2/latlong.dart'; // Pour LatLng
import '../remote/api_service.dart';
import 'dart:math';
import 'database_helper.dart';

class SimpleStorageHelper {
  static final SimpleStorageHelper _instance = SimpleStorageHelper._internal();
  factory SimpleStorageHelper() => _instance;
  static Database? _database;

  SimpleStorageHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'piste_chaussee_storage.db');
    print('📂 Base SQLite Piste/Chaussée: $path');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        print('🔨 Création tables Piste et Chaussée...');

        // Table Pistes
        await db.execute('''
          CREATE TABLE pistes (
            id INTEGER PRIMARY KEY ,
            api_id INTEGER,

            code_piste TEXT NOT NULL,
            commune_rurale_id TEXT,
            commune_rurales INTEGER,
            user_login TEXT ,
            heure_debut TEXT ,
            heure_fin TEXT ,
            nom_origine_piste TEXT ,
            x_origine REAL ,
            y_origine REAL ,
            nom_destination_piste TEXT ,
            x_destination REAL ,
            y_destination REAL ,
            existence_intersection INTEGER DEFAULT 0, -- ← NOUVEAU
      x_intersection REAL,                      -- ← NOUVEAU
      y_intersection REAL,                      -- ← NOUVEAU
      intersection_piste_code TEXT,             -- ← NOUVEAU
            type_occupation TEXT,
            debut_occupation TEXT,
            fin_occupation TEXT,
            largeur_emprise REAL,
            frequence_trafic TEXT,
            type_trafic TEXT,
            travaux_realises TEXT,
            date_travaux TEXT,
            entreprise TEXT,
            plateforme TEXT,
            relief TEXT,
            vegetation TEXT,
            debut_travaux TEXT,
            fin_travaux TEXT,
            financement TEXT,
            projet TEXT,
            points_json TEXT NOT NULL,
            created_at TEXT ,
            updated_at TEXT,
            sync_status TEXT DEFAULT 'pending',
            login_id INTEGER,
            saved_by_user_id INTEGER,
            synced INTEGER DEFAULT 0,
            date_sync TEXT,
            downloaded INTEGER DEFAULT 0,
            niveau_service REAL,
            fonctionnalite REAL,
            interet_socio_administratif REAL,
            population_desservie REAL,
            potentiel_agricole REAL,
            cout_investissement REAL,
            protection_environnement REAL,
            note_globale REAL
            
          )
        ''');
        await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_pistes_api_user
ON pistes(api_id, saved_by_user_id);

''');

        // Table Chaussées
        await db.execute('''
          CREATE TABLE chaussees (
            id INTEGER PRIMARY KEY ,
            api_id INTEGER,
            code_piste TEXT NOT NULL,
            code_gps TEXT ,
            communes_rurales_id INTEGER,
            user_login TEXT ,
            endroit TEXT NOT NULL,
            type_chaussee TEXT,
            etat_piste TEXT,
            x_debut_chaussee REAL NOT NULL,
            y_debut_chaussee REAL NOT NULL,
            x_fin_chaussee REAL NOT NULL,
            y_fin_chaussee REAL NOT NULL,
            points_json TEXT NOT NULL,
            distance_totale_m REAL NOT NULL,
            nombre_points INTEGER NOT NULL,
            created_at TEXT NOT NULL,
             updated_at TEXT, -- ← NOUVEAU
    
    sync_status TEXT DEFAULT 'pending', 
    login_id INTEGER, 
    saved_by_user_id INTEGER,
    synced INTEGER DEFAULT 0,
    date_sync TEXT,
    downloaded INTEGER DEFAULT 0

          )
        ''');
        await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_chaussees_api_user
ON chaussees(api_id, saved_by_user_id);

''');
        // Table pour le cache des pistes affichées
        await db.execute('''
CREATE TABLE IF NOT EXISTS displayed_pistes (
  id INTEGER PRIMARY KEY,
  login_id INTEGER NOT NULL,
  code_piste TEXT NOT NULL,
  points_json TEXT NOT NULL,
  color INTEGER NOT NULL,
  width REAL NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
''');

        await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_displayed_pistes_user_code
ON displayed_pistes(login_id, code_piste);
''');

        await db.execute('''
  CREATE TABLE IF NOT EXISTS displayed_chaussees (
    id INTEGER PRIMARY KEY,
    points_json TEXT NOT NULL,
    color INTEGER ,
    width INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    login_id INTEGER NOT NULL,
    code_piste TEXT,
    type_chaussee TEXT,
    endroit TEXT
  )
''');

        print('✅ Tables créées avec succès');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          print('🔨 Mise à jour de la base de données vers version 2...');
          await db.execute('ALTER TABLE pistes ADD COLUMN plateforme TEXT');
          await db.execute('ALTER TABLE pistes ADD COLUMN relief TEXT');
          await db.execute('ALTER TABLE pistes ADD COLUMN vegetation TEXT');
          await db.execute('ALTER TABLE pistes ADD COLUMN debut_travaux TEXT');
          await db.execute('ALTER TABLE pistes ADD COLUMN fin_travaux TEXT');
          await db.execute('ALTER TABLE pistes ADD COLUMN financement TEXT');
          await db.execute('ALTER TABLE pistes ADD COLUMN projet TEXT');
          print('✅ Nouvelles colonnes ajoutées à la table pistes');
        }
        if (oldVersion < 3) {
          print('🔨 Mise à jour de la base de données vers version 3...');
          await db.execute('ALTER TABLE pistes ADD COLUMN niveau_service REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN fonctionnalite REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN interet_socio_administratif REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN population_desservie REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN potentiel_agricole REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN cout_investissement REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN protection_environnement REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN note_globale REAL');
          print('✅ Colonnes d\'évaluation ajoutées à la table pistes');
        }
      },
    );
  }

  Future<void> saveDisplayedChaussee(
    List<LatLng> points,
    String typeChaussee,
    double width,
    String codePiste,
    String endroit,
  ) async {
    try {
      final db = await database;
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();
      final pointsJson = jsonEncode(points
          .map((p) => {
                'lat': p.latitude,
                'lng': p.longitude
              })
          .toList());

      final existing = await db.query(
        'displayed_chaussees',
        where: 'login_id = ? AND code_piste = ?',
        whereArgs: [
          loginId,
          codePiste
        ],
      );

      if (existing.isNotEmpty) {
        await db.update(
          'displayed_chaussees',
          {
            'points_json': pointsJson,
            'type_chaussee': typeChaussee, // ✅ enregistré
            'width': width.toInt(),
            'endroit': endroit,
            'created_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND login_id = ?',
          whereArgs: [
            existing.first['id'],
            loginId
          ],
        );
      } else {
        await db.insert('displayed_chaussees', {
          'points_json': pointsJson,
          'type_chaussee': typeChaussee, // ✅ enregistré
          'width': width.toInt(),
          'login_id': loginId,
          'code_piste': codePiste,
          'endroit': endroit,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      print('✅ Chaussée sauvegardée avec type: $typeChaussee');
    } catch (e) {
      print('❌ Erreur sauvegarde chaussée: $e');
    }
  }

  Color getChausseeColor(String type) {
    switch (type.toLowerCase()) {
      case 'bitume':
        return Colors.black;
      case 'terre':
        return Colors.brown;
      case 'latérite': // ← minuscule
        return Colors.red.shade700;
      case 'bouwal':
        return Colors.yellow.shade700;
      default:
        return Colors.blueGrey; // inconnu / autre
    }
  }

  StrokePattern? getChausseePattern(String type) {
    switch (type.toLowerCase()) {
      case 'bitume':
      case 'asphalte':
        return null; // ligne continue
      case 'terre':
        return StrokePattern.dashed(segments: [
          20,
          10
        ]);
      case 'latérite':
        return StrokePattern.dashed(segments: [
          15,
          8
        ]);
      case 'bouwal':
        return StrokePattern.dashed(segments: [
          12,
          6
        ]);
      case 'béton':
        return StrokePattern.dotted(spacingFactor: 1.5);
      case 'pavée':
        return StrokePattern.dashed(segments: [
          10,
          5
        ]);
      default:
        return null; // ligne continue par défaut
    }
  }

// Sauvegarder une piste affichée
  Future<void> saveDisplayedPiste(
    String codePiste,
    List<LatLng> points,
    Color color,
    double width,
  ) async {
    try {
      final db = await database;
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();

      if (loginId == null) {
        print('❌ [saveDisplayedPiste] Impossible de déterminer login_id');
        return;
      }

      final pointsJson = jsonEncode(points
          .map((p) => {
                'lat': p.latitude,
                'lng': p.longitude
              })
          .toList());

      await db.insert(
        'displayed_pistes',
        {
          'login_id': loginId,
          'code_piste': codePiste, // ✅ IMPORTANT
          'points_json': pointsJson,
          'color': color.value,
          'width': width, // ✅ REAL, pas toInt
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace, // ✅ UPSERT
      );

      print('✅ Piste sauvegardée: $codePiste (user=$loginId)');
    } catch (e) {
      print('❌ Erreur sauvegarde piste: $e');
    }
  }

  Future<List<Polyline>> loadDisplayedChaussees() async {
    try {
      final db = await database;
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();
      // ⭐⭐ FILTRER PAR UTILISATEUR ⭐⭐
      final List<Map<String, dynamic>> maps = await db.query(
        'displayed_chaussees',
        where: 'login_id = ?',
        whereArgs: [
          loginId
        ],
      );

      final List<Polyline> polylines = [];

      for (final map in maps) {
        final pointsData = jsonDecode(map['points_json']) as List;
        final List<LatLng> points = [];
        final typeChaussee = map['type_chaussee'] as String? ?? "inconnu";
        for (final p in pointsData) {
          final lat = p['lat'] as double?;
          final lng = p['lng'] as double?;
          if (lat != null && lng != null) {
            points.add(LatLng(lat, lng));
          }
        }

        if (points.isNotEmpty) {
          polylines.add(Polyline(
            points: points,
            color: getChausseeColor(typeChaussee),
            strokeWidth: (map['width'] as int).toDouble(),
            pattern: getChausseePattern(typeChaussee) ?? const StrokePattern.solid(),
          ));
        }
      }

      print('✅ ${polylines.length} chaussées affichées chargées pour user: $loginId');
      return polylines;
    } catch (e) {
      print('❌ Erreur chargement chaussées affichées: $e');
      return [];
    }
  }

  // Charger toutes les pistes affichées
  Future<List<Polyline>> loadDisplayedPistes() async {
    try {
      final db = await database;
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();

      if (loginId == null) {
        print('❌ [loadDisplayedPistes] loginId null → aucune piste chargée');
        return [];
      }
      //  FILTRER PAR UTILISATEUR
      final List<Map<String, dynamic>> maps = await db.query(
        'displayed_pistes',
        where: 'login_id = ?', // ← FILTRE IMPORTANT
        whereArgs: [
          loginId
        ], // ← ID de l'utilisateur connecté
      );

      final List<Polyline> polylines = [];

      for (final map in maps) {
        final pointsData = jsonDecode(map['points_json']) as List;
        final List<LatLng> points = [];

        for (final p in pointsData) {
          final lat = p['lat'] as double?;
          final lng = p['lng'] as double?;
          if (lat != null && lng != null) {
            points.add(LatLng(lat, lng));
          }
        }

        if (points.isNotEmpty) {
          polylines.add(Polyline(
            points: points,
            color: Color(map['color'] as int),
            strokeWidth: (map['width'] as int).toDouble(),
          ));
        }
      }

      print('✅ ${polylines.length} pistes chargées pour user: $loginId');
      return polylines;
    } catch (e) {
      print('❌ Erreur chargement pistes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> loadDisplayedPistesMaps() async {
    try {
      final db = await database;
      final loginId = await DatabaseHelper().resolveLoginId();

      if (loginId == null) {
        print('❌ [loadDisplayedPistesMaps] loginId null');
        return [];
      }

      return await db.query(
        'displayed_pistes',
        where: 'login_id = ?',
        whereArgs: [
          loginId
        ],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      print('❌ Erreur loadDisplayedPistesMaps: $e');
      return [];
    }
  }

  /// Sauvegarder une piste depuis le formulaire
  Future<int?> savePiste(Map<String, dynamic> formData) async {
    try {
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();
      print('🔄 Début sauvegarde piste...');
      print('📋 commune_rurales reçu: ${formData['commune_rurales']}');
      // Ajouter le login_id aux données du formulaire
      final formDataWithLoginId = Map<String, dynamic>.from(formData);
      formDataWithLoginId['login_id'] = loginId;
      print('🔄 Début sauvegarde piste...');
      print('📋 Données reçues:');
      formData.forEach((key, value) {
        // Ne pas logger les données trop longues (comme points_json)
        if (key != 'points' && key != 'points_json') {
          print('   $key: $value');
        }
      });

      final piste = PisteModel.fromFormData(formData);
      final db = await database;
      final id = await db.insert('pistes', piste.toMap());

      print('✅ Piste "${piste.codePiste}" sauvegardée avec ID: $id pour login_id = $loginId');

      // AFFICHER TOUS LES CHAMPS DE LA PISTE
      print('📊 Détails de la piste enregistrée:');
      final pisteMap = piste.toMap();
      pisteMap.forEach((key, value) {
        if (key != 'points_json') {
          // Éviter le JSON trop long
          print('   $key: $value');
        } else {
          print('   $key: [JSON contenant ${piste.pointsJson.length} caractères]');
        }
      });

      return id;
    } catch (e) {
      print('❌ Erreur sauvegarde piste: $e');
      print('📋 Données qui ont causé l\'erreur:');
      formData.forEach((key, value) {
        print('   $key: $value (type: ${value.runtimeType})');
      });
      return null;
    }
  }

// Dans SimpleStorageHelper, ajoutez cette méthode
  Future<void> debugPrintAllPistes() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> pistes = await db.query('pistes');

      print('📊 === LISTE COMPLÈTE DES PISTES ===');
      print('📈 Nombre total de pistes: ${pistes.length}');

      for (var i = 0; i < pistes.length; i++) {
        final piste = pistes[i];
        print('\n🎯 PISTE #${i + 1}');
        piste.forEach((key, value) {
          if (key != 'points_json') {
            print('   $key: $value');
          } else {
            final pointsJson = value.toString();
            print('   $key: [${pointsJson.length} caractères]');
            // Pour voir un extrait du JSON :
            if (pointsJson.length > 50) {
              print('        Extrait: ${pointsJson.substring(0, 50)}...');
            }
          }
        });
      }
      print('====================================');
    } catch (e) {
      print('❌ Erreur lecture pistes: $e');
    }
  }

// Dans la classe SimpleStorageHelper (piste_chaussee_db_helper.dart)
  Future<int?> _getCommuneId() async {
    try {
      // Priorité à l'API
      if (ApiService.communeId != null) {
        print('📍 commune_id depuis API: ${ApiService.communeId}');
        return ApiService.communeId;
      }

      // Fallback: base locale
      final currentUser = await DatabaseHelper().getCurrentUser();
      if (currentUser != null && currentUser['communes_rurales'] != null) {
        final communeId = currentUser['communes_rurales'] as int;
        print('📍 commune_id depuis base locale: $communeId');
        return communeId;
      }

      print('⚠️ commune_id non trouvé, utilisation valeur par défaut: 1');
      return 1; // Valeur par défaut
    } catch (e) {
      print('❌ Erreur _getCommuneId: $e');
      return 1; // Valeur par défaut en cas d'erreur
    }
  }

  /// Sauvegarder une chaussée depuis le formulaire
  /// Sauvegarder une chaussée depuis le formulaire
  Future<int?> saveChaussee(Map<String, dynamic> formData) async {
    try {
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();
      final communeId = await _getCommuneId();

      // Vérifier si on est en mode édition
      final bool isEditing = formData['is_editing'] ?? false;
      final int? existingId = formData['id'];

      if (isEditing && existingId != null) {
        // MODE ÉDITION: Mise à jour
        await updateChaussee(formData);
        print('✅ Chaussée "${formData['code_piste']}" mise à jour (ID: $existingId)');
        return existingId;
      } else {
        // MODE CRÉATION: Insertion
        final formDataWithLoginId = Map<String, dynamic>.from(formData);
        formDataWithLoginId['login_id'] = loginId;
        formDataWithLoginId['communes_rurales_id'] = communeId;
        final chaussee = ChausseeModel.fromFormData(formDataWithLoginId);
        final db = await database;
        final id = await db.insert('chaussees', chaussee.toMap());

        print('✅ Chaussée "${chaussee.codePiste}" sauvegardée avec ID: $id');
        return id;
      }
    } catch (e) {
      print('❌ Erreur sauvegarde chaussée: $e');
      return null;
    }
  }

  Future<void> updateChaussee(Map<String, dynamic> chausseeData) async {
    try {
      final db = await database;
      final communeId = await _getCommuneId();
      // Préparer les données pour la mise à jour
      final updateData = {
        'code_piste': chausseeData['code_piste'],
        'code_gps': chausseeData['code_gps'],
        'endroit': chausseeData['endroit'],
        'type_chaussee': chausseeData['type_chaussee'],
        'etat_piste': chausseeData['etat_piste'],
        'x_debut_chaussee': chausseeData['x_debut_chaussee'],
        'y_debut_chaussee': chausseeData['y_debut_chaussee'],
        'x_fin_chaussee': chausseeData['x_fin_chaussee'],
        'y_fin_chaussee': chausseeData['y_fin_chaussee'],
        'points_json': jsonEncode(chausseeData['points_collectes']),
        'distance_totale_m': chausseeData['distance_totale_m'],
        'nombre_points': chausseeData['nombre_points'],
        'updated_at': DateTime.now().toIso8601String(), // ← FORCER l'heure actuelle
        'user_login': chausseeData['user_login'],
        'login_id': chausseeData['login_id'],
        'communes_rurales_id': communeId,
      };

      await db.update(
        'chaussees',
        updateData,
        where: 'id = ?',
        whereArgs: [
          chausseeData['id']
        ],
      );

      print('✅ Chaussée ${chausseeData['id']} mise à jour avec succès');
    } catch (e) {
      print('❌ Erreur mise à jour chaussée: $e');
      rethrow;
    }
  }

// Dans SimpleStorageHelper class
  Future<void> debugPrintAllChaussees() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> chaussees = await db.query('chaussees');

      print('📊 === LISTE COMPLÈTE DES CHAUSSÉES ===');
      print('📈 Nombre total de chaussées: ${chaussees.length}');

      for (var i = 0; i < chaussees.length; i++) {
        final chaussee = chaussees[i];
        print('\n🎯 CHAUSSÉE #${i + 1}');
        chaussee.forEach((key, value) {
          if (key != 'points_json') {
            print('   $key: $value');
          } else {
            final pointsJson = value.toString();
            print('   $key: [${pointsJson.length} caractères]');
            // Pour voir un extrait du JSON :
            if (pointsJson.length > 50) {
              print('        Extrait: ${pointsJson.substring(0, 50)}...');
            }
          }
        });
      }
      print('=====================================');
    } catch (e) {
      print('❌ Erreur lecture chaussées: $e');
    }
  }

  /// Lister toutes les pistes (optionnel pour debug)
  Future<List<PisteModel>> getAllPistes() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('pistes', orderBy: 'created_at DESC');
      return maps.map((map) => PisteModel.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erreur lecture pistes: $e');
      return [];
    }
  }

  /// Lister toutes les chaussées (optionnel pour debug)
  Future<List<ChausseeModel>> getAllChaussees() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('chaussees', orderBy: 'created_at DESC');
      return maps.map((map) => ChausseeModel.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erreur lecture chaussées: $e');
      return [];
    }
  }

  /// Compter le total d'éléments sauvegardés (optionnel pour debug)
  Future<Map<String, int>> getCount() async {
    try {
      final db = await database;
      final pisteCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM pistes')) ?? 0;
      final chausseeCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM chaussees')) ?? 0;

      return {
        'pistes': pisteCount,
        'chaussees': chausseeCount,
        'total': pisteCount + chausseeCount,
      };
    } catch (e) {
      print('❌ Erreur comptage: $e');
      return {
        'pistes': 0,
        'chaussees': 0,
        'total': 0
      };
    }
  }

// Récupérer seulement les pistes créées par l'utilisateur (à synchroniser)
  Future<List<Map<String, dynamic>>> getUserPistes() async {
    final db = await database;
    return await db.query(
      'pistes',
      where: 'synced = ? AND downloaded = ?',
      whereArgs: [
        0,
        0
      ], // Créées par user, pas encore synchronisées
    );
  }

// Récupérer seulement les pistes téléchargées (autres users)
  Future<List<Map<String, dynamic>>> getDownloadedPistes() async {
    final db = await database;
    return await db.query(
      'pistes',
      where: 'synced = ? AND downloaded = ?',
      whereArgs: [
        0,
        1
      ], // Téléchargées, pas créées par cet user
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedPistes() async {
    try {
      final db = await database;
      final loginId = await DatabaseHelper().resolveLoginId();
      final List<Map<String, dynamic>> maps = await db.query(
        'pistes',
        where: 'synced = ? AND downloaded = ? AND login_id = ?',
        whereArgs: [
          0,
          0,
          loginId
        ],
        columns: [
          // ⭐⭐ SPÉCIFIEZ EXPLICITEMENT TOUTES LES COLONNES
          'id', 'code_piste', 'commune_rurale_id', 'commune_rurales', 'user_login',
          'heure_debut', 'heure_fin', 'nom_origine_piste', 'x_origine',
          'y_origine', 'nom_destination_piste', 'x_destination', 'y_destination',
          'existence_intersection', 'x_intersection', 'y_intersection',
          'intersection_piste_code', 'type_occupation', 'debut_occupation',
          'fin_occupation', 'largeur_emprise', 'frequence_trafic', 'type_trafic',
          'travaux_realises', 'date_travaux', 'entreprise', 
          'plateforme', 'relief', 'vegetation', 'debut_travaux', 'fin_travaux', 'financement', 'projet',
          'points_json',
          'niveau_service', 'fonctionnalite', 'interet_socio_administratif', 
          'population_desservie', 'potentiel_agricole', 'cout_investissement', 
          'protection_environnement', 'note_globale',
          'created_at', 'updated_at', 'login_id', 'synced', 'date_sync' // ⭐⭐ AJOUTEZ login_id ICI
        ],
      );

      // ⭐⭐ LOG POUR VÉRIFIER
      print('📊 Pistes non synchronisées trouvées: ${maps.length}');
      if (maps.isNotEmpty) {
        print('🔍 Premier piste - login_id: ${maps.first['login_id']}');
      }

      return maps;
    } catch (e) {
      print('❌ Erreur lecture pistes non synchronisées: $e');
      return [];
    }
  }

  Future<void> markPisteAsSynced(int pisteId) async {
    try {
      final db = await database;
      await db.update(
        'pistes',
        {
          'synced': 1,
          'downloaded': 0,
          'date_sync': DateTime.now().toIso8601String(),
          'sync_status': 'synced',
        },
        where: 'id = ? AND login_id = ?',
        whereArgs: [
          pisteId,
          ApiService.userId
        ],
      );
      print('✅ Piste $pisteId marquée comme synchronisée');
    } catch (e) {
      print('❌ Erreur marquage piste synchronisée: $e');
    }
  }

  Future<void> markPisteAsSyncedAndUpdated(int pisteId, Map<String, dynamic> apiResponse) async {
    try {
      final db = await database;
      final updates = <String, dynamic>{
        'synced': 1,
        'downloaded': 0,
        'date_sync': DateTime.now().toIso8601String(),
        'sync_status': 'synced',
        'api_id': apiResponse['id'], // ID serveur
      };

      if (apiResponse.containsKey('communes_rurales_id') && apiResponse['communes_rurales_id'] != null) {
        updates['commune_rurale_id'] = apiResponse['communes_rurales_id'].toString();
      }

      await db.update(
        'pistes',
        updates,
        where: 'id = ?',
        whereArgs: [pisteId],
      );
      print('✅ Piste $pisteId marquée comme synchronisée et mise à jour (api_id: ${apiResponse['id']})');
    } catch (e) {
      print('❌ Erreur markPisteAsSyncedAndUpdated: $e');
    }
  }

  Future<int> getUnsyncedPistesCount() async {
    try {
      final db = await database;
      final loginId = await DatabaseHelper().resolveLoginId();
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM pistes WHERE synced = 0 AND downloaded = 0 AND login_id = ?', [
        loginId
      ]));
      return count ?? 0;
    } catch (e) {
      print('❌ Erreur comptage pistes non synchronisées: $e');
      return 0;
    }
  }

  // Ajouter cette méthode dans la classe SimpleStorageHelper
  Future<void> saveOrUpdatePiste(Map<String, dynamic> pisteData) async {
    try {
      final db = await database;
      final properties = pisteData['properties'];
      final geometry = pisteData['geometry'];

      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();
      final apiUserId = ApiService.userId;

      // ✅ ignorer SEULEMENT si les deux ids existent et sont égaux
      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return;
      }

      // id serveur postgres (celui qui posait conflit)
      final serverId = pisteData['id'];

      // Extraire les coordonnées du MultiLineString GeoJSON
      final coordinates = geometry['coordinates'][0];
      final pointsJson = jsonEncode(
        coordinates
            .map((coord) => {
                  'longitude': coord[0],
                  'latitude': coord[1]
                })
            .toList(),
      );

      // Convertir les dates du format PostgreSQL
      String formatDate(String? dateString) {
        if (dateString == null) return '';
        return dateString.replaceFirst('T', ' ');
      }

      // ✅ Vérifier si la piste existe déjà (par api_id + viewer)
      final existing = await db.query(
        'pistes',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          serverId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        // ✅ INSERT : id local (unique), api_id = id serveur
        final localId = DateTime.now().millisecondsSinceEpoch;

        await db.insert(
          'pistes',
          {
            'id': localId, // ✅ ID local (dateNow)
            'api_id': serverId, // ✅ ID serveur (Postgres)
            'code_piste': properties['code_piste'],
            'commune_rurale_id': properties['communes_rurales_id']?.toString(),
            'user_login': properties['user_login'] ?? '',
            'heure_debut': properties['heure_debut'],
            'heure_fin': properties['heure_fin'],
            'nom_origine_piste': properties['nom_origine_piste'],
            'x_origine': properties['x_origine'],
            'y_origine': properties['y_origine'],
            'nom_destination_piste': properties['nom_destination_piste'],
            'x_destination': properties['x_destination'],
            'y_destination': properties['y_destination'],
            'existence_intersection': properties['existence_intersection'] ?? 0,
            'x_intersection': properties['x_intersection'],
            'y_intersection': properties['y_intersection'],
            'intersection_piste_code': properties['intersection_piste_code'],
            'type_occupation': properties['type_occupation'],
            'debut_occupation': formatDate(properties['debut_occupation']),
            'fin_occupation': formatDate(properties['fin_occupation']),
            'largeur_emprise': properties['largeur_emprise'],
            'frequence_trafic': properties['frequence_trafic'],
            'type_trafic': properties['type_trafic'],
            'travaux_realises': properties['travaux_realises'],
            'date_travaux': properties['date_travaux'],
            'entreprise': properties['entreprise'],
            'points_json': pointsJson,
            'created_at': formatDate(properties['created_at']),
            'updated_at': formatDate(properties['updated_at']),
            'login_id': dataUserId, // ✅ id serveur du créateur (peut être null)
            'saved_by_user_id': viewerId,
            'sync_status': 'downloaded',
            'synced': 0,
            'date_sync': DateTime.now().toIso8601String(),
            'downloaded': 1,
          },
          // (optionnel) si tu as mis UNIQUE(api_id, saved_by_user_id), tu peux activer replace :
          // conflictAlgorithm: ConflictAlgorithm.replace,
        );

        print('✅ Piste ${properties['code_piste']} sauvegardée (api_id: $serverId, local id: $localId)');
      } else {
        // ✅ UPDATE : toujours sur api_id + viewer
        await db.update(
          'pistes',
          {
            'code_piste': properties['code_piste'],
            'commune_rurale_id': properties['communes_rurales_id']?.toString(),
            'heure_debut': properties['heure_debut'],
            'heure_fin': properties['heure_fin'],
            'nom_origine_piste': properties['nom_origine_piste'],
            'x_origine': properties['x_origine'],
            'y_origine': properties['y_origine'],
            'nom_destination_piste': properties['nom_destination_piste'],
            'x_destination': properties['x_destination'],
            'y_destination': properties['y_destination'],
            'existence_intersection': properties['existence_intersection'] ?? 0,
            'x_intersection': properties['x_intersection'],
            'y_intersection': properties['y_intersection'],
            'intersection_piste_code': properties['intersection_piste_code'],
            'type_occupation': properties['type_occupation'],
            'debut_occupation': formatDate(properties['debut_occupation']),
            'fin_occupation': formatDate(properties['fin_occupation']),
            'largeur_emprise': properties['largeur_emprise'],
            'frequence_trafic': properties['frequence_trafic'],
            'type_trafic': properties['type_trafic'],
            'travaux_realises': properties['travaux_realises'],
            'date_travaux': properties['date_travaux'],
            'entreprise': properties['entreprise'],
            'points_json': pointsJson,
            'updated_at': DateTime.now().toIso8601String(),
            'login_id': dataUserId,
            'sync_status': 'downloaded',
            'synced': 0,
            'date_sync': DateTime.now().toIso8601String(),
            'downloaded': 1,
          },
          where: 'api_id = ? AND saved_by_user_id = ?',
          whereArgs: [
            serverId,
            viewerId
          ],
        );

        print('🔄 Piste ${properties['code_piste']} mise à jour (api_id: $serverId)');
      }
    } catch (e) {
      print('❌ Erreur sauvegarde piste: $e');
      print('📋 Données problématiques: ${jsonEncode(pisteData)}');
    }
  }

  // Dans SimpleStorageHelper class
  Future<List<Map<String, dynamic>>> getAllPistesMaps() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('pistes', orderBy: 'created_at DESC');
      return maps;
    } catch (e) {
      print('❌ Erreur lecture pistes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllChausseesMaps() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('chaussees', orderBy: 'created_at DESC');
      return maps;
    } catch (e) {
      print('❌ Erreur lecture chaussées: $e');
      return [];
    }
  }

  Future<void> updatePiste(Map<String, dynamic> pisteData) async {
    try {
      final db = await database;

      int? communeRurales;
      if (ApiService.communeId != null) {
        communeRurales = ApiService.communeId;
      } else {
        final currentUser = await DatabaseHelper().getCurrentUser();
        communeRurales = currentUser?['communes_rurales'] as int?;
      }
      // ✅ PRÉPARER UNIQUEMENT LES CHAMPS MODIFIABLES
      final updateData = {
        'code_piste': pisteData['code_piste'],
        'commune_rurale_id': pisteData['commune_rurale_id'],
        'commune_rurales': communeRurales,
        'user_login': pisteData['user_login'],
        'heure_debut': pisteData['heure_debut'],
        'heure_fin': pisteData['heure_fin'],
        'nom_origine_piste': pisteData['nom_origine_piste'],
        'x_origine': pisteData['x_origine'],
        'y_origine': pisteData['y_origine'],
        'nom_destination_piste': pisteData['nom_destination_piste'],
        'x_destination': pisteData['x_destination'],
        'y_destination': pisteData['y_destination'],
        'existence_intersection': pisteData['existence_intersection'],
        'x_intersection': pisteData['x_intersection'],
        'y_intersection': pisteData['y_intersection'],
        'intersection_piste_code': pisteData['intersection_piste_code'],
        'type_occupation': pisteData['type_occupation'],
        'debut_occupation': pisteData['debut_occupation'],
        'fin_occupation': pisteData['fin_occupation'],
        'largeur_emprise': pisteData['largeur_emprise'],
        'frequence_trafic': pisteData['frequence_trafic'],
        'type_trafic': pisteData['type_trafic'],
        'travaux_realises': pisteData['travaux_realises'],
        'date_travaux': pisteData['date_travaux'],
        'entreprise': pisteData['entreprise'],
        'points_json': jsonEncode(pisteData['points']), // ← CONVERTIR en JSON
        'updated_at': pisteData['updated_at'],
        'login_id': pisteData['login_id'],
      };

      // ✅ NE PAS METTRE À JOUR L'ID - juste l'utiliser pour WHERE
      await db.update(
        'pistes',
        updateData, // ← SEULEMENT les champs modifiables
        where: 'id = ?',
        whereArgs: [
          pisteData['id']
        ], // ← ID seulement pour WHERE
      );

      print('✅ Piste ${pisteData['id']} mise à jour avec succès');
    } catch (e) {
      print('❌ Erreur mise à jour piste: $e');
      rethrow;
    }
  }

  Future<void> deletePiste(int id) async {
    final db = await database;
    await db.delete(
      'pistes',
      where: 'id = ?',
      whereArgs: [
        id
      ],
    );
  }

  // Dans SimpleStorageHelper
  Future<List<Map<String, dynamic>>> getUnsyncedChaussees() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'chaussees',
        where: 'synced = ? AND downloaded = ? AND login_id = ?',
        whereArgs: [
          0,
          0,
          ApiService.userId
        ],
        columns: [
          // ⭐⭐ SPÉCIFIEZ EXPLICITEMENT LES COLONNES ⭐⭐
          'id',
          'code_piste',
          'code_gps',
          'user_login',
          'endroit',
          'type_chaussee',
          'etat_piste',
          'x_debut_chaussee',
          'y_debut_chaussee',
          'x_fin_chaussee',
          'y_fin_chaussee',
          'points_json',
          'distance_totale_m',
          'nombre_points',
          'created_at',
          'updated_at',
          'sync_status',
          'login_id',
          'synced',
          'date_sync', 'communes_rurales_id'
          // ⭐⭐ NE INCLUEZ PAS downloaded ⭐⭐
        ],
      );

      print('📊 Chaussées non synchronisées trouvées: ${maps.length}');
      return maps;
    } catch (e) {
      print('❌ Erreur lecture chaussées non synchronisées: $e');
      return [];
    }
  }

  // Dans SimpleStorageHelper
  Future<void> markChausseeAsSynced(int chausseeId) async {
    try {
      final db = await database;
      await db.update(
        'chaussees',
        {
          'synced': 1,
          'downloaded': 0,
          'date_sync': DateTime.now().toIso8601String(),
          'sync_status': 'synced',
        },
        where: 'id = ? AND login_id = ?',
        whereArgs: [
          chausseeId,
          ApiService.userId
        ],
      );
      print('✅ Chaussée $chausseeId marquée comme synchronisée');
    } catch (e) {
      print('❌ Erreur marquage chaussée synchronisée: $e');
    }
  }

  Future<void> markChausseeAsSyncedAndUpdated(int chausseeId, Map<String, dynamic> apiResponse) async {
    try {
      final db = await database;
      final updates = <String, dynamic>{
        'synced': 1,
        'downloaded': 0,
        'date_sync': DateTime.now().toIso8601String(),
        'sync_status': 'synced',
        'api_id': apiResponse['id'],
      };

      if (apiResponse.containsKey('communes_rurales_id') && apiResponse['communes_rurales_id'] != null) {
        updates['communes_rurales_id'] = apiResponse['communes_rurales_id'];
      }

      await db.update(
        'chaussees',
        updates,
        where: 'id = ?',
        whereArgs: [chausseeId],
      );
      print('✅ Chaussée $chausseeId marquée comme synchronisée et mise à jour');
    } catch (e) {
      print('❌ Erreur markChausseeAsSyncedAndUpdated: $e');
    }
  }

  // Dans SimpleStorageHelper
  Future<int> getUnsyncedChausseesCount() async {
    try {
      final db = await database;
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM chaussees WHERE synced = 0 AND downloaded = 0 AND login_id = ?', [
        ApiService.userId
      ]));
      return count ?? 0;
    } catch (e) {
      print('❌ Erreur comptage chaussées non synchronisées: $e');
      return 0;
    }
  }

  Future<void> saveOrUpdateChausseeTest(Map<String, dynamic> chausseeData) async {
    try {
      final db = await database;
      final properties = chausseeData['properties'];
      final geometry = chausseeData['geometry'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();
      final apiUserId = ApiService.userId;

      // ✅ ignorer SEULEMENT si les deux ids existent et sont égaux
      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return;
      }

      // Extraire les coordonnées du MultiLineString GeoJSON
      final coordinates = geometry['coordinates'][0];
      final pointsJson = jsonEncode(
        coordinates
            .map((coord) => {
                  'longitude': coord[0],
                  'latitude': coord[1]
                })
            .toList(),
      );

      final int apiChausseeId = (chausseeData['id'] as num).toInt(); // id PostgreSQL

      // ✅ Vérifier si la chaussée existe déjà (par api_id + viewer)
      final existing = await db.query(
        'chaussees',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          apiChausseeId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        // ✅ Insertion nouvelle chaussée (id sqlite auto) + api_id = id serveur
        await db.insert(
          'chaussees',
          {
            'api_id': apiChausseeId, //  ID PostgreSQL stocké ici
            'code_piste': properties['code_piste'],
            'code_gps': properties['code_gps'],
            'user_login': properties['login']?.toString() ?? 'Autre utilisateur',
            'endroit': properties['endroit'],
            'type_chaussee': properties['type_chaus'],
            'etat_piste': properties['etat_piste'],
            'x_debut_chaussee': properties['x_debut_ch'],
            'y_debut_chaussee': properties['y_debut_ch'],
            'x_fin_chaussee': properties['x_fin_ch'],
            'y_fin_chaussee': properties['y_fin_chau'],
            'points_json': pointsJson,
            'distance_totale_m': 0.0,
            'nombre_points': coordinates.length,
            'created_at': properties['created_at'],
            'updated_at': properties['updated_at'],
            'sync_status': 'downloaded',
            'login_id': dataUserId, // laisse null si null
            'saved_by_user_id': viewerId,
            'synced': 0,
            'date_sync': DateTime.now().toIso8601String(),
            'downloaded': 1,
            'communes_rurales_id': properties['communes_rurales_id'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        print('✅ Chaussée ${properties['code_piste']} téléchargée (api_id: $apiChausseeId)');
      } else {
        // ✅ Mise à jour (par api_id + viewer)
        await db.update(
          'chaussees',
          {
            'code_piste': properties['code_piste'],
            'code_gps': properties['code_gps'],
            'user_login': properties['login']?.toString() ?? 'Autre utilisateur',
            'endroit': properties['endroit'],
            'type_chaussee': properties['type_chaus'],
            'etat_piste': properties['etat_piste'],
            'x_debut_chaussee': properties['x_debut_ch'],
            'y_debut_chaussee': properties['y_debut_ch'],
            'x_fin_chaussee': properties['x_fin_ch'],
            'y_fin_chaussee': properties['y_fin_chau'],
            'points_json': pointsJson,
            'updated_at': properties['updated_at'],
            'sync_status': 'downloaded',
            'login_id': dataUserId, // optionnel mais cohérent
            'saved_by_user_id': viewerId,
            'synced': 0,
            'date_sync': DateTime.now().toIso8601String(),
            'downloaded': 1,
            'communes_rurales_id': properties['communes_rurales_id'],
          },
          where: 'api_id = ? AND saved_by_user_id = ?',
          whereArgs: [
            apiChausseeId,
            viewerId
          ],
        );

        print('🔄 Chaussée ${properties['code_piste']} mise à jour (api_id: $apiChausseeId)');
      }
    } catch (e) {
      print('❌ Erreur sauvegarde chaussée téléchargée: $e');
    }
  }

  // Dans piste_chaussee_db_helper.dart
  Future<void> deleteChaussee(int id) async {
    final db = await database;
    await db.delete(
      'chaussees',
      where: 'id = ?',
      whereArgs: [
        id
      ],
    );
  }

  Future<String?> findNearestPisteCode(LatLng position, {String? activePisteCode}) async {
    try {
      final db = await database;

      // ⭐⭐ PRIORITÉ ABSOLUE: Si une piste est active, utiliser son code ⭐⭐
      if (activePisteCode != null) {
        print('📍 Utilisation piste active: $activePisteCode');
        return activePisteCode;
      }
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();

      if (loginId == null) {
        print('❌ Impossible de déterminer le login_id (API + local)');
        return null;
      }
      // Récupérer toutes les pistes de l'utilisateur
      final List<Map<String, dynamic>> pistes = await db.query(
        'pistes',
        where: 'login_id = ?',
        whereArgs: [
          loginId
        ],
      );

      if (pistes.isEmpty) return null;

      String? nearestCode;
      double minDistance = double.maxFinite;

      for (final piste in pistes) {
        try {
          final pointsJson = piste['points_json'] as String;
          final pointsData = jsonDecode(pointsJson) as List;

          for (final pointData in pointsData) {
            final lat = pointData['latitude'] as double?;
            final lng = pointData['longitude'] as double?;

            if (lat != null && lng != null) {
              final pistePoint = LatLng(lat, lng);
              final distance = _calculateDistance(position, pistePoint);

              if (distance < minDistance) {
                minDistance = distance;
                nearestCode = piste['code_piste'] as String?;
              }
            }
          }
        } catch (e) {
          print('❌ Erreur lecture piste ${piste['id']}: $e');
        }
      }

      print('📍 Piste la plus proche: $nearestCode (${minDistance.toStringAsFixed(0)} m)');
      return nearestCode;
    } catch (e) {
      print('❌ Erreur recherche piste proche: $e');
      return null;
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    // Formule de Haversine simplifiée
    const double earthRadius = 6371000; // Rayon de la Terre en mètres

    final double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final double dLon = _degreesToRadians(point2.longitude - point1.longitude);

    final double a = sin(dLat / 2) * sin(dLat / 2) + cos(_degreesToRadians(point1.latitude)) * cos(_degreesToRadians(point2.latitude)) * sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Dans la classe SimpleStorageHelper
  // Pour les pistes - même principe que chaussées
  Future<void> deleteDisplayedPiste(int pisteId) async {
    try {
      final db = await database;
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();

      // ⭐⭐ 1. TROUVER LA PISTE POUR AVOIR SON CODE_PISTE ⭐⭐
      final piste = await db.query('pistes',
          where: 'id = ?',
          whereArgs: [
            pisteId
          ],
          limit: 1);

      if (piste.isNotEmpty) {
        final codePiste = piste.first['code_piste'] as String?;

        if (codePiste != null) {
          // ⭐⭐ 2. SUPPRIMER TOUTES LES PISTES AFFICHÉES AVEC CE CODE_PISTE ⭐⭐
          await db.delete(
            'displayed_pistes',
            where: 'login_id = ?', // On supprime tout pour l'utilisateur
            whereArgs: [
              loginId
            ],
          );
          print('✅ Toutes les pistes affichées supprimées pour rechargement propre');
        }
      }
    } catch (e) {
      print('❌ Erreur suppression piste affichée: $e');
    }
  }

  // Ajoutez cette méthode
  Future<void> deleteDisplayedChaussee(int chausseeId) async {
    try {
      final db = await database;
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();
      // 1. Trouver le code_piste de la chaussée à supprimer
      final chaussee = await db.query('chaussees',
          where: 'id = ?',
          whereArgs: [
            chausseeId
          ],
          limit: 1);

      if (chaussee.isNotEmpty) {
        final codePiste = chaussee.first['code_piste'] as String?;

        if (codePiste != null) {
          // 2. Supprimer la chaussée affichée avec le même code_piste
          await db.delete(
            'displayed_chaussees',
            where: 'code_piste = ? AND login_id = ?',
            whereArgs: [
              codePiste,
              loginId
            ],
          );
          print('✅ Chaussée affichée supprimée: $codePiste');
        }
      }
    } catch (e) {
      print('❌ Erreur suppression chaussée affichée: $e');
    }
  }
}
