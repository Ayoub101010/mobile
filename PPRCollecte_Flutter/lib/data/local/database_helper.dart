import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import '../remote/api_service.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  //factory DatabaseHelper() => _instance;
  static Database? _database;
  static bool _isInitializing = false;
// ⭐⭐ EMPÊCHEZ LES INSTANCES MULTIPLES ⭐⭐
  factory DatabaseHelper() {
    return _instance;
  }
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) {
      try {
        await _database!.rawQuery('SELECT 1');
        return _database!;
      } catch (e) {
        print('❌ Connexion DB invalide, fermeture: $e');
        await _database!.close();
        _database = null;
      }
    }

    if (_isInitializing) {
      await Future.delayed(const Duration(milliseconds: 100));
      return database;
    }

    _isInitializing = true;
    try {
      _database = await _initDatabase();
      return _database!;
    } finally {
      _isInitializing = false;
    }
  }

  Future<Database> _initDatabase() async {
    // Utilisation du chemin de base de données interne
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');
    print('📂 Chemin absolu DB: $path');

    // CORRECTION: On ne supprime plus la DB existante automatiquement
    // On vérifie seulement si elle existe pour logging
    final dbExists = await databaseExists(path);
    print(dbExists ? '📁 Base de données existante' : '🆕 Nouvelle base de données');

    // CORRECTION: Création du répertoire si nécessaire
    final dbDir = Directory(dbPath);
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
      print('📁 Répertoire créé: $dbPath');
    }

    return await openDatabase(
      path,
      version: 13, // Version augmentée pour les tables d'enquête
      onCreate: (db, version) async {
        print('🆕 Création de toutes les tables pour la version $version');
        await _createAllTables(db);
        await _insertDefaultUser(db); // Ajout de l'utilisateur par défaut
        await _logTableSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('🔄 Migration $oldVersion → $newVersion');
        if (oldVersion < 10) {
          await _createAllTables(db);
          await _insertDefaultUser(db);
        }
        if (oldVersion < 13) {
          await _createEnqueteTables(db);
        }
        await _logTableSchema(db);
      },
      onOpen: (db) async {
        print('🔌 Base de données ouverte avec succès');
        await _testDatabaseIntegrity(db);
        await _logTableSchema(db);
      },
    );
  }

  Future<void> _createAllTables(Database db) async {
    print('🏗️  Début de la création des tables...');
    await _createSessionTable(db);
    // ============ TABLE USERS ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS users(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      apiId INTEGER,
      nom TEXT,
      prenom TEXT,
      email TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL,
      role TEXT,
      communes_rurales INTEGER,
      commune_nom TEXT,
      prefecture_nom TEXT,
      prefecture_id INTEGER,
      region_nom TEXT,
      region_id INTEGER,
      date_creation TEXT
    )
  ''');
    print('✅ Table users créée');

    // ============ TABLE LOCALITES ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS localites(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER, 
      x_localite REAL NOT NULL,
      y_localite REAL NOT NULL,
      nom TEXT NOT NULL,
      type TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,               
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table localites créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_localites_api_user
ON localites(api_id, saved_by_user_id);

''');
    // ============ TABLE ECOLES ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS ecoles(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      x_ecole REAL NOT NULL,
      y_ecole REAL NOT NULL,
      nom TEXT NOT NULL,
      type TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,               -- ← COLONNE AJOUTÉE
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table ecoles créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_ecoles_api_user
ON ecoles(api_id, saved_by_user_id);

''');
    // ============ TABLE MARCHES ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS marches(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      x_marche REAL NOT NULL,
      y_marche REAL NOT NULL,
      nom TEXT NOT NULL,
      type TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,            
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table marches créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_marches_api_user
ON marches(api_id, saved_by_user_id);

''');
    // ============ TABLE SERVICES_SANTES ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS services_santes(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      x_sante REAL NOT NULL,
      y_sante REAL NOT NULL,
      nom TEXT NOT NULL,
      type TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,            
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table services_santes créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_services_santes_api_user
ON services_santes(api_id, saved_by_user_id);

''');
    // ============ TABLE BATIMENTS_ADMINISTRATIFS ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS batiments_administratifs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      x_batiment_administratif REAL NOT NULL,
      y_batiment_administratif REAL NOT NULL,
      nom TEXT NOT NULL,
      type TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,            
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table batiments_administratifs créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_batiments_administratifs_api_user
ON batiments_administratifs(api_id, saved_by_user_id);

''');
    // ============ TABLE INFRASTRUCTURES_HYDRAULIQUES ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS infrastructures_hydrauliques(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      x_infrastructure_hydraulique REAL NOT NULL,
      y_infrastructure_hydraulique REAL NOT NULL,
      nom TEXT NOT NULL,
      type TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,            
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table infrastructures_hydrauliques créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_infrastructures_hydrauliques_api_user
ON infrastructures_hydrauliques(api_id, saved_by_user_id);

''');
    // ============ TABLE AUTRES_INFRASTRUCTURES ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS autres_infrastructures(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      x_autre_infrastructure REAL NOT NULL,
      y_autre_infrastructure REAL NOT NULL,
      nom TEXT NOT NULL,
      type TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,            
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table autres_infrastructures créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_autres_infrastructures_api_user
ON autres_infrastructures(api_id, saved_by_user_id);

''');
    // ============ TABLE PONTS ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS ponts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      x_pont REAL NOT NULL,
      y_pont REAL NOT NULL,
      nom TEXT NOT NULL,
      situation_pont TEXT NOT NULL,
      type_pont TEXT NOT NULL,
      nom_cours_eau TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,            
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table ponts créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_ponts_api_user
ON ponts(api_id, saved_by_user_id);

''');
    // ============ TABLE BACS ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS bacs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      x_debut_traversee_bac REAL NOT NULL,
      y_debut_traversee_bac REAL NOT NULL,
      x_fin_traversee_bac REAL NOT NULL,
      y_fin_traversee_bac REAL NOT NULL,
      nom TEXT NOT NULL,
      type_bac TEXT NOT NULL,
      nom_cours_eau TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,            
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table bacs créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_bacs_api_user
ON bacs(api_id, saved_by_user_id);

''');
    // ============ TABLE BUSES ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS buses(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      x_buse REAL NOT NULL,
      y_buse REAL NOT NULL,
      nom TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,            
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table buses créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_buses_api_user
ON buses(api_id, saved_by_user_id);

''');
    // ============ TABLE DALOTS ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS dalots(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      x_dalot REAL NOT NULL,
      y_dalot REAL NOT NULL,
      nom TEXT NOT NULL,
      situation_dalot TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,            
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table dalots créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_dalots_api_user
ON dalots(api_id, saved_by_user_id);

''');
    // ============ TABLE PASSAGES_SUBMERSIBLES ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS passages_submersibles(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      x_debut_passage_submersible REAL NOT NULL,
      y_debut_passage_submersible REAL NOT NULL,
      x_fin_passage_submersible REAL NOT NULL,
      y_fin_passage_submersible REAL NOT NULL,
      nom TEXT NOT NULL,
      type_materiau TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,            
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table passages_submersibles créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_passages_submersibles_api_user
ON passages_submersibles(api_id, saved_by_user_id);

''');
    // ============ TABLE POINTS_CRITIQUES ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS points_critiques(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      nom TEXT,
      type TEXT,
      x_point_critique REAL NOT NULL,
      y_point_critique REAL NOT NULL,
      type_point_critique TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,            
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT  
    )
  ''');
    print('✅ Table points_critiques créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_points_critiques_api_user
ON points_critiques(api_id, saved_by_user_id);

''');
    // ============ TABLE POINTS_COUPURES ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS points_coupures(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      nom TEXT,
      type TEXT,
      x_point_coupure REAL NOT NULL,
      y_point_coupure REAL NOT NULL,
      causes_coupures TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      synced INTEGER DEFAULT 0,
    downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,            
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table points_coupures créée');
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_points_coupures_api_user
ON points_coupures(api_id, saved_by_user_id);

''');

    await _createEnqueteTables(db);
    // ============ TABLE TEST ============
    await db.execute('CREATE TABLE IF NOT EXISTS test (id INTEGER)');
    print('✅ Table test créée');

    print("🎉 Toutes les tables ont été créées avec succès !");
// ============ TABLE POUR STOCKER LA DATE DE LA SYNCHRONISATION ============
    await db.execute('''
  CREATE TABLE IF NOT EXISTS app_metadata (
    key TEXT PRIMARY KEY,
    value TEXT
  )
''');
  }

  Future<void> saveLastSyncTime(DateTime dt) async {
    final db = await database;
    final iso = dt.toIso8601String();
    await db.insert(
      'app_metadata',
      {
        'key': 'last_sync_time',
        'value': iso
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DateTime?> getLastSyncTime() async {
    final db = await database;
    final res = await db.query(
      'app_metadata',
      where: 'key = ?',
      whereArgs: [
        'last_sync_time'
      ],
      limit: 1,
    );
    if (res.isEmpty) return null;

    final raw = res.first['value'] as String?;
    if (raw == null) return null;

    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _createSessionTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS app_session (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  current_user_email TEXT,
  last_login TEXT,
  is_logged_in INTEGER DEFAULT 0,
  remember_me INTEGER DEFAULT 0
)
''');

    print('✅ Table app_session créée');
  }

  Future<void> _createEnqueteTables(Database db) async {
    // ============ TABLE SITE_ENQUETE ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS site_enquete(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      x_site REAL NOT NULL,
      y_site REAL NOT NULL,
      nom TEXT NOT NULL,
      type TEXT NOT NULL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      amenage_ou_non_amenage INTEGER,
      entreprise TEXT,
      financement TEXT,
      projet TEXT,
      superficie_digitalisee REAL,
      superficie_estimee_lors_des_enquetes_ha REAL,
      travaux_debut TEXT,
      travaux_fin INTEGER,
      type_de_realisation TEXT,
      synced INTEGER DEFAULT 0,
      downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table site_enquete créée');
    await db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_site_enquete_api_user
    ON site_enquete(api_id, saved_by_user_id);
    ''');

    // ============ TABLE ENQUETE_POLYGONE ============
    await db.execute('''
    CREATE TABLE IF NOT EXISTS enquete_polygone(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_id INTEGER,
      nom TEXT,
      points_json TEXT,
      superficie_en_ha REAL,
      enqueteur TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      date_modification TEXT,
      code_piste TEXT,
      code_gps TEXT,
      synced INTEGER DEFAULT 0,
      downloaded INTEGER DEFAULT 0,
      date_sync TEXT,
      login_id INTEGER,
      saved_by_user_id INTEGER,
      commune_id INTEGER,
      region_name TEXT,
      prefecture_name TEXT,
      commune_name TEXT
    )
  ''');
    print('✅ Table enquete_polygone créée');
    await db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_enquete_polygone_api_user
    ON enquete_polygone(api_id, saved_by_user_id);
    ''');
  }

  Future<void> _insertDefaultUser(Database db) async {
    try {
      await db.insert(
        'users',
        {
          'nom': 'Agent',
          'prenom': 'Test',
          'email': 'test@ppr.com',
          'password': '12345678',
          'role': 'enqueteur',
          'communes_rurales': 0,
          'commune_nom': 'CommuneTest',
          'prefecture_nom': 'test',
          'prefecture_id': 0,
          'region_nom': 'test',
          'region_id': 0,
          'date_creation': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ Utilisateur par défaut inséré');
    } catch (e) {
      print('⚠️ Erreur insertion utilisateur: $e');
    }
  }

  Future<void> _ensureAppSessionTable() async {
    final db = await database;
    await db.execute('''
CREATE TABLE IF NOT EXISTS app_session (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  current_user_email TEXT,
  last_login TEXT,
  is_logged_in INTEGER DEFAULT 0,
  remember_me INTEGER DEFAULT 0
)
''');
  }

  Future<void> setCurrentUserEmail(String email, {required bool remember}) async {
    try {
      final db = await database;
      await _ensureAppSessionTable();

      final existing = await db.query('app_session', limit: 1);

      final values = {
        'current_user_email': email,
        'last_login': DateTime.now().toIso8601String(),
        'is_logged_in': 1,
        'remember_me': remember ? 1 : 0,
      };

      if (existing.isEmpty) {
        await db.insert('app_session', values);
      } else {
        await db.update('app_session', values, where: 'id = ?', whereArgs: [
          existing.first['id']
        ]);
      }

      print('✅ Session: $email | remember=$remember');
    } catch (e) {
      print("❌ Erreur setCurrentUserEmail: $e");
    }
  }

  Future<String?> getSessionUserEmail() async {
    try {
      final db = await database;
      await _ensureAppSessionTable();

      final result = await db.query('app_session', limit: 1);
      if (result.isNotEmpty) {
        final row = result.first;

        final isLoggedRaw = row['is_logged_in'];
        final isLogged = (isLoggedRaw is int) ? isLoggedRaw : int.tryParse(isLoggedRaw.toString()) ?? 0;

        if (isLogged == 1) {
          final email = row['current_user_email'] as String?;
          if (email != null && email.isNotEmpty) return email;
        }
      }
      return null;
    } catch (e) {
      print("❌ Erreur getSessionUserEmail: $e");
      return null;
    }
  }

  Future<String?> getCurrentUserEmail() async {
    try {
      final db = await database;
      await _ensureAppSessionTable();

      final result = await db.query('app_session', limit: 1);
      if (result.isNotEmpty) {
        final row = result.first;

        final rememberRaw = row['remember_me'];
        final remember = (rememberRaw is int) ? rememberRaw : int.tryParse(rememberRaw.toString()) ?? 0;

        if (remember == 1) {
          final email = row['current_user_email'] as String?;
          if (email != null && email.isNotEmpty) return email;
        }
      }
      return null;
    } catch (e) {
      print("❌ Erreur getCurrentUserEmail: $e");
      return null;
    }
  }

  Future<void> clearSession() async {
    try {
      final db = await database;
      await _ensureAppSessionTable();

      final rows = await db.query('app_session', limit: 1);
      if (rows.isEmpty) return;

      final row = rows.first;
      final rememberRaw = row['remember_me'];
      final remember = (rememberRaw is int) ? rememberRaw : int.tryParse(rememberRaw.toString()) ?? 0;

      if (remember == 1) {
        // ✅ on garde l’email remembered, on coupe juste la session
        await db.update(
            'app_session',
            {
              'is_logged_in': 0
            },
            where: 'id = ?',
            whereArgs: [
              row['id']
            ]);
      } else {
        // ❌ pas remembered → on supprime tout
        await db.delete('app_session');
      }

      print('✅ Logout: session effacée, remember=$remember');
    } catch (e) {
      print("❌ Erreur clearSession: $e");
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final db = await database;

      // On lit d’abord l’email de session “remembered”
      final currentEmail = await getCurrentUserEmail();
      if (currentEmail == null || currentEmail.isEmpty) {
        return null; // 🚫 pas de fallback vers “dernier user”
      }

      final result = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [
          currentEmail
        ],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print("❌ Erreur getCurrentUser: $e");
      return null;
    }
  }

  Future<void> _testDatabaseIntegrity(Database db) async {
    try {
      // CORRECTION: On utilise la table test qui a été créée dans _createAllTables
      await db.insert('test', {
        'id': 1
      });
      final results = await db.query('test');
      await db.delete('test', where: 'id = ?', whereArgs: [
        1
      ]);
      print('✅ Accès en écriture confirmé - ${results.length} résultat(s)');
    } catch (e) {
      print('❌ ERREUR ÉCRITURE: $e');
      rethrow;
    }
  }

  Future<void> _logTableSchema(Database db) async {
    print('\n📊 SCHEMA COMPLET DE LA BASE DE DONNÉES:');
    print('=' * 50);

    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';");

    print('📋 Nombre de tables: ${tables.length}');

    for (var t in tables) {
      final tableName = t['name'] as String;
      print('\n📑 Table: $tableName');
      print('─' * 30);

      final columns = await db.rawQuery('PRAGMA table_info($tableName)');

      for (var col in columns) {
        final name = col['name'] as String;
        final type = col['type'] as String;
        final pk = col['pk'] as int;
        final notnull = col['notnull'] as int;

        print('   ├─ $name ($type)'
            '${pk == 1 ? ' [PRIMARY KEY]' : ''}'
            '${notnull == 1 ? ' [NOT NULL]' : ''}');
      }
      // NOUVEAU: Afficher le contenu de la table (sauf pour les tables système)
      if (tableName != 'android_metadata' && tableName != 'test') {
        try {
          final content = await db.query(tableName);
          print('   └─ 📊 CONTENU (${content.length} enregistrement(s)):');

          if (content.isEmpty) {
            print('      └─ Aucune donnée');
          } else {
            for (var i = 0; i < content.length; i++) {
              final row = content[i];
              print('      ${i + 1}.');
              row.forEach((key, value) {
                print('         ├─ $key: $value');
              });
              if (i < content.length - 1) {
                print('         │');
              }
            }
          }
        } catch (e) {
          print('   └─ ❌ Erreur lecture contenu: $e');
        }
      }
    }
    print('=' * 50);
  }

  // ============ MÉTHODES USERS (LOGIN) ============

  Future<String?> getAgentFullName(String email) async {
    try {
      final db = await database;
      final result = await db.query(
        'users',
        columns: [
          'prenom',
          'nom'
        ],
        where: 'email = ?',
        whereArgs: [
          email
        ],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final prenom = result.first['prenom'] as String? ?? '';
        final nom = result.first['nom'] as String? ?? '';
        return '$prenom $nom'.trim();
      }
      return null;
    } catch (e) {
      print("❌ Erreur getAgentFullName: $e");
      return null;
    }
  }

  Future<bool> validateUser(String email, String password) async {
    try {
      final db = await database;
      final result = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [
          email,
          password
        ],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      print("❌ Erreur validateUser: $e");
      return false;
    }
  }

  Future<int> insertUser(String prenom, String nom, String email, String password, int? communeRural, int? prefectureId, int? regionId, String? prefectureNom, String? communeNom, String? regionNom, {String? role, int? apiId}) async {
    try {
      print('🔄 Tentative insertion/mise à jour user: $email');
      final db = await database;

      // Vérifier si l'utilisateur existe déjà
      final existingUser = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [
          email
        ],
        limit: 1,
      );

      final userData = {
        'prenom': prenom,
        'nom': nom,
        'email': email,
        'password': password,
        'role': role ?? 'enqueteur',
        'communes_rurales': communeRural,
        'commune_nom': communeNom,
        'prefecture_nom': prefectureNom,
        'prefecture_id': prefectureId,
        'region_nom': regionNom,
        'region_id': regionId,
        'date_creation': DateTime.now().toIso8601String(),
        'apiId': apiId,
      };

      int result;

      if (existingUser.isNotEmpty) {
        // Mise à jour de l'utilisateur existant
        print('📝 Utilisateur existe déjà, mise à jour...');
        result = await db.update(
          'users',
          userData,
          where: 'email = ?',
          whereArgs: [
            email
          ],
        );
        print('✅ Utilisateur mis à jour: $result ligne affectée');
        return existingUser.first['id'] as int;
      } else {
        // Insertion d'un nouvel utilisateur
        print('➕ Nouvel utilisateur, insertion...');
        result = await db.insert(
          'users',
          userData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ Nouvel utilisateur inséré avec ID: $result');
        return result;
      }
    } catch (e) {
      print("❌ Erreur insertUser: $e");
      print('Stack trace: ${e.toString()}');
      return -1;
    }
  }

  Future<bool> userExists(String email) async {
    try {
      final db = await database;
      final result = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [
          email
        ],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      print("❌ Erreur userExists: $e");
      return false;
    }
  }

  Future<int> updateUser(String prenom, String nom, String email, String password, int? communeRural, int? prefectureId, int? regionId, String? prefectureNom, String? communeNom, String? regionNom, {String? role, int? apiId}) async {
    try {
      final db = await database;
      final result = await db.update(
        'users',
        {
          'prenom': prenom,
          'nom': nom,
          'password': password,
          'role': role ?? 'enqueteur',
          'communes_rurales': communeRural,
          'commune_nom': communeNom,
          'prefecture_nom': prefectureNom,
          'prefecture_id': prefectureId,
          'region_nom': regionNom,
          'region_id': regionId,
          'date_creation': DateTime.now().toIso8601String(),
          'apiId': apiId,
        },
        where: 'email = ?',
        whereArgs: [
          email
        ],
      );
      print('✅ Utilisateur mis à jour: $result ligne affectée');
      return result;
    } catch (e) {
      print("❌ Erreur updateUser: $e");
      return -1;
    }
  }

  Future<int> deleteAllUsers() async {
    try {
      final db = await database;
      return await db.delete('users');
    } catch (e) {
      print("❌ Erreur deleteAllUsers: $e");
      return -1;
    }
  }

  Future<void> resetDatabase() async {
    try {
      final db = await database;
      await db.close();
      _database = null;

      // CORRECTION: Utilisation du bon chemin pour la suppression
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'app_database.db');

      if (await databaseExists(path)) {
        await deleteDatabase(path);
      }

      print('✅ Base de données réinitialisée');
    } catch (e) {
      print("❌ Erreur resetDatabase: $e");
    }
  }

  // ============ MÉTHODES FORMULAIRES (CRUD) ============

  Future<int> insertEntity(String tableName, Map<String, dynamic> data) async {
    final db = await database;
    // CORRECTION: Utilisation du bon chemin
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');
    final userData = {
      ...data,
      'login_id': await resolveLoginId(),
      'commune_id': await _getCommuneId(),
    };
    print('🗂️ Insertion dans: $path');
    print('📋 Table: $tableName');
    print('📍 commune_id: ${userData['commune_id']}');
    // NOUVEAU: Afficher les champs et valeurs qui seront insérés
    print('📝 Champs à insérer:');
    data.forEach((key, value) {
      print('   ├─ $key: $value (${value.runtimeType})');
    });

    final id = await db.insert(tableName, userData);
    print("✅ Entité insérée dans $tableName (ID: $id)");
    return id;
  }

  Future<List<Map<String, dynamic>>> getEntities(String tableName) async {
    final db = await database;
    // CORRECTION: Utilisation du bon chemin
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');
    print('🗂️ Lecture depuis: $path');
    print('📋 Table: $tableName');

    final List<Map<String, dynamic>> maps = await db.query(tableName);
    print("📊 ${maps.length} entité(s) dans $tableName:");
    for (var entity in maps) {
      print("   ➡️ $entity");
    }

    return maps;
  }

  Future<int?> _getCommuneId() async {
    try {
      /* GPS-BASED ATTRIBUTION: 
         We now return null by default to let the backend determine the commune 
         spatially during sync. This prevents forcing a point into the user's 
         home commune if they are working elsewhere.
      */
      return null;

      /* OLD LOGIC (Keep commented for reference if needed)
      // Priorité à l'API
      if (ApiService.communeId != null) {
        print('📍 commune_id depuis API: ${ApiService.communeId}');
        return ApiService.communeId;
      }

      // Fallback: base locale
      final currentUser = await getCurrentUser();
      if (currentUser != null && currentUser['communes_rurales'] != null) {
        final communeId = currentUser['communes_rurales'] as int;
        print('📍 commune_id depuis base locale: $communeId');
        return communeId;
      }

      print('⚠️ commune_id non trouvé, attribution auto par le backend lors du sync');
      return null; 
      */
    } catch (e) {
      print('❌ Erreur _getCommuneId: $e');
      return null;
    }
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    try {
      final result = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'");
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

// Dans database_helper.dart
  Future<void> resetAndRecreateDatabase({bool force = false}) async {
    if (!force) {
      // Demander confirmation en production
      print('⚠️ Méthode dangereuse - utilisez avec caution');
      return;
    }

    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'app_database.db');

      if (await databaseExists(path)) {
        await deleteDatabase(path);
        print('✅ Base corrompue supprimée');
      }

      _database = await _initDatabase();
      print('✅ Nouvelle base créée');
    } catch (e) {
      print('❌ Erreur réinitialisation: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllPoints() async {
    final List<Map<String, dynamic>> allPoints = [];

    print('🔍 Début scan sécurisé de la base...');

    try {
      final db = await database;

      // ⭐⭐ LISTE RACCOURCIE POUR TEST ⭐⭐
      final criticalTables = [
        'points_critiques',
        'points_coupures',
        'localites',
        'ecoles'
      ];

      for (var table in criticalTables) {
        try {
          print('🔎 Scan table: $table');

          // ⭐⭐ MÉTHODE SÉCURISÉE ⭐⭐
          final points = await db.rawQuery('SELECT * FROM $table LIMIT 100');

          print('📍 ${points.length} point(s) récupérés de $table');

          for (var point in points) {
            point['table_name'] = table;
            point['entity_type'] = _getEntityTypeFromTable(table);
            point.addAll(_getCoordinatesMapFromPoint(point));
            allPoints.add(point);
          }
        } catch (e) {
          print("⚠️ Erreur table $table: $e");
          // Continue avec les autres tables
        }
      }
    } catch (e) {
      print('❌ Erreur grave accès base: $e');
    }

    print("🎯 Total points récupérés: ${allPoints.length}");
    return allPoints;
  }

  String _getEntityTypeFromTable(String tableName) {
    const entityTypes = {
      'localites': 'Localité',
      'ecoles': 'École',
      'marches': 'Marché',
      'services_santes': 'Service de Santé',
      'batiments_administratifs': 'Bâtiment Administratif',
      'infrastructures_hydrauliques': 'Infrastructure Hydraulique',
      'autres_infrastructures': 'Autre Infrastructure',
      'ponts': 'Pont',
      'bacs': 'Bac',
      'buses': 'Buse',
      'dalots': 'Dalot',
      'passages_submersibles': 'Passage Submersible',
      'points_critiques': 'Point Critique',
      'points_coupures': 'Point de Coupure',
    };
    return entityTypes[tableName] ?? tableName;
  }

  Map<String, dynamic> _getCoordinatesMapFromPoint(Map<String, dynamic> point) {
    final tableName = point['table_name'];

    final coordinateMappings = {
      'localites': {
        'lng': 'x_localite',
        'lat': 'y_localite'
      },
      'ecoles': {
        'lng': 'x_ecole',
        'lat': 'y_ecole'
      },
      'marches': {
        'lng': 'x_marche',
        'lat': 'y_marche'
      },
      'services_santes': {
        'lng': 'x_sante',
        'lat': 'y_sante'
      },
      'batiments_administratifs': {
        'lng': 'x_batiment_administratif',
        'lat': 'y_batiment_administratif'
      },
      'infrastructures_hydrauliques': {
        'lng': 'x_infrastructure_hydraulique',
        'lat': 'y_infrastructure_hydraulique'
      },
      'autres_infrastructures': {
        'lng': 'x_autre_infrastructure',
        'lat': 'y_autre_infrastructure'
      },
      'ponts': {
        'lng': 'x_pont',
        'lat': 'y_pont'
      },
      'buses': {
        'lng': 'x_buse',
        'lat': 'y_buse'
      },
      'dalots': {
        'lng': 'x_dalot',
        'lat': 'y_dalot'
      },
      'points_critiques': {
        'lng': 'x_point_critique',
        'lat': 'y_point_critique'
      },
      'points_coupures': {
        'lng': 'x_point_coupure',
        'lat': 'y_point_coupure'
      },
    };

    final multiPointMappings = {
      'bacs': {
        'lng': 'x_debut_traversee_bac',
        'lat': 'y_debut_traversee_bac',
        'lng_fin': 'x_fin_traversee_bac',
        'lat_fin': 'y_fin_traversee_bac'
      },
      'passages_submersibles': {
        'lng': 'x_debut_passage_submersible',
        'lat': 'y_debut_passage_submersible',
        'lng_fin': 'x_fin_passage_submersible',
        'lat_fin': 'y_fin_passage_submersible'
      },
    };

    if (multiPointMappings.containsKey(tableName)) {
      final mapping = multiPointMappings[tableName]!;
      return {
        'lat': point[mapping['lat']],
        'lng': point[mapping['lng']],
        'lat_fin': point[mapping['lat_fin']],
        'lng_fin': point[mapping['lng_fin']],
      };
    }

    if (coordinateMappings.containsKey(tableName)) {
      final mapping = coordinateMappings[tableName]!;
      return {
        'lat': point[mapping['lat']],
        'lng': point[mapping['lng']],
      };
    }

    return {
      'lat': 0,
      'lng': 0
    };
  }

  Future<int> deleteEntity(String tableName, int id) async {
    final db = await database;
    final result = await db.delete(tableName, where: 'id = ?', whereArgs: [
      id
    ]);
    print("🗑️  Entité supprimée de $tableName (ID: $id)");
    return result;
  }

  Future<int> updateEntity(String tableName, int id, Map<String, dynamic> data) async {
    final db = await database;
    final result = await db.update(tableName, data, where: 'id = ?', whereArgs: [
      id
    ]);
    print("✏️  Entité mise à jour dans $tableName (ID: $id)");
    return result;
  }

  Future<int> countEntities(String tableName) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $tableName');
    final count = Sqflite.firstIntValue(result) ?? 0;
    print("🔢 $tableName contient $count entité(s)");
    return count;
  }

  Future<Map<String, dynamic>> exportAllData() async {
    final Map<String, dynamic> allData = {};
    final tables = [
      'localites',
      'ecoles',
      'marches',
      'services_santes',
      'batiments_administratifs',
      'infrastructures_hydrauliques',
      'autres_infrastructures',
      'ponts',
      'bacs',
      'buses',
      'dalots',
      'passages_submersibles',
      'points_critiques',
      'points_coupures'
    ];

    for (var table in tables) {
      try {
        final data = await getEntities(table);
        allData[table] = data;
        print("📦 Données exportées de $table: ${data.length} entité(s)");
      } catch (e) {
        print("⚠️ Erreur lors de l'export de $table: $e");
      }
    }

    print("📤 Export complet terminé: ${allData.length} tables exportées");
    return allData;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print("🔒 Base de données fermée");
    }
  }

  // Dans la classe DatabaseHelper, ajoutez:

  Future<List<Map<String, dynamic>>> getUnsyncedEntities(String tableName) async {
    final db = await database;

    // VÉRIFIER TOUTES LES COLONNES EXISTENT
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final hasSyncedColumn = columns.any((col) => col['name'] == 'synced');
    final hasDownloadedColumn = columns.any((col) => col['name'] == 'downloaded');
    final hasLoginIdColumn = columns.any((col) => col['name'] == 'login_id');
    if (hasSyncedColumn && hasDownloadedColumn && hasLoginIdColumn) {
      // ⭐⭐ CORRECTION CRITIQUE : seulement les NON synchronisées ET NON téléchargées
      return await db.query(tableName, where: 'synced = ? AND downloaded = ? AND login_id = ?', whereArgs: [
        0,
        0,
        ApiService.userId
      ] // ← SEULEMENT 0 et 0 !
          );
    } else if (hasSyncedColumn) {
      return await db.query(tableName, where: 'synced = ?', whereArgs: [
        0
      ]);
    } else {
      // Si pas de colonne synced, retourner vide
      return [];
    }
  }

  Future<void> markAsSynced(String tableName, int id) async {
    final db = await database;
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final hasSyncedColumn = columns.any((col) => col['name'] == 'synced');
    final hasDateSyncColumn = columns.any((col) => col['name'] == 'date_sync');
    final hasDownloadedColumn = columns.any((col) => col['name'] == 'downloaded');
    final hasLoginIdColumn = columns.any((col) => col['name'] == 'login_id');

    if (hasSyncedColumn && hasDateSyncColumn && hasDownloadedColumn && hasLoginIdColumn) {
      await db.update(
        tableName,
        {
          'synced': 1,
          'downloaded': 0,
          'date_sync': DateTime.now().toIso8601String()
        },
        where: 'id = ? AND login_id = ?', // ← AJOUTER login_id
        whereArgs: [
          id,
          ApiService.userId
        ],
      );
    } else if (hasSyncedColumn && hasLoginIdColumn) {
      await db.update(
        tableName,
        {
          'synced': 1
        },
        where: 'id = ? AND login_id = ?', // ← AJOUTER login_id
        whereArgs: [
          id,
          ApiService.userId
        ],
      );
    }
  }

  /// Sauvegarde ou met à jour une localité depuis PostgreSQL
  Future<bool?> saveOrUpdateLocalite(Map<String, dynamic> geoJsonData) async {
    final db = await database;

    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      final apiUserId = ApiService.userId;

      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null; // ← AJOUTÉ
      }

      final existing = await db.query(
        'localites',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();
        await db.insert(
          'localites',
          {
            'api_id': sqliteId,
            'x_localite': geometry['coordinates'][0],
            'y_localite': geometry['coordinates'][1],
            'nom': properties['nom'] ?? 'Sans nom',
            'type': properties['type'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ Localité sauvegardée: ${properties['nom']}');
        return true; // ← AJOUTÉ
      }
      return false; // ← AJOUTÉ (déjà existante)
    } catch (e) {
      print('❌ Erreur sauvegarde localité: $e');
      rethrow;
    }
  }

  /// Sauvegarde ou met à jour une école depuis PostgreSQL
  Future<bool?> saveOrUpdateEcole(Map<String, dynamic> geoJsonData) async {
    final db = await database;

    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();
      final apiUserId = ApiService.userId;

      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null; // ← AJOUTÉ
      }

      final existing = await db.query(
        'ecoles',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();
        await db.insert(
          'ecoles',
          {
            'api_id': sqliteId,
            'x_ecole': geometry['coordinates'][0],
            'y_ecole': geometry['coordinates'][1],
            'nom': properties['nom'] ?? 'Sans nom',
            'type': properties['type'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ école sauvegardée: ${properties['nom']}');
        return true; // ← AJOUTÉ
      }
      return false; // ← AJOUTÉ
    } catch (e) {
      print('❌ Erreur sauvegarde école: $e');
      rethrow;
    }
  }

  /// Sauvegarde ou met à jour une marché depuis PostgreSQL
  Future<bool?> saveOrUpdateMarche(Map<String, dynamic> geoJsonData) async {
    final db = await database;

    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      final apiUserId = ApiService.userId;

      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null; // ← AJOUTÉ
      }

      final existing = await db.query(
        'marches',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();
        await db.insert(
          'marches',
          {
            'api_id': sqliteId,
            'x_marche': geometry['coordinates'][0],
            'y_marche': geometry['coordinates'][1],
            'nom': properties['nom'] ?? 'Sans nom',
            'type': properties['type'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ Marché sauvegardée: ${properties['nom']}');
        return true; // ← AJOUTÉ
      }
      return false; // ← AJOUTÉ
    } catch (e) {
      print('❌ Erreur sauvegarde Marché: $e');
      rethrow;
    }
  }

  // ============ SERVICES SANTES ============
  Future<bool?> saveOrUpdateServiceSante(Map<String, dynamic> geoJsonData) async {
    final db = await database;

    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      final apiUserId = ApiService.userId;

      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null;
      }

      final existing = await db.query(
        'services_santes',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();
        await db.insert(
          'services_santes',
          {
            'api_id': sqliteId,
            'x_sante': geometry['coordinates'][0],
            'y_sante': geometry['coordinates'][1],
            'nom': properties['nom'] ?? 'Sans nom',
            'type': properties['type'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ services_santes sauvegardée: ${properties['nom']}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur sauvegarde services_santes: $e');
      rethrow;
    }
  }

// ============ BATIMENTS ADMINISTRATIFS ============
  Future<bool?> saveOrUpdateBatimentAdministratif(Map<String, dynamic> geoJsonData) async {
    final db = await database;
    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      final apiUserId = ApiService.userId;

      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null;
      }

      final existing = await db.query(
        'batiments_administratifs',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();
        await db.insert(
          'batiments_administratifs',
          {
            'api_id': sqliteId,
            'x_batiment_administratif': geometry['coordinates'][0],
            'y_batiment_administratif': geometry['coordinates'][1],
            'nom': properties['nom'] ?? 'Sans nom',
            'type': properties['type'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ batiments_administratifs sauvegardée: ${properties['nom']}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur sauvegarde batiments_administratifs: $e');
      rethrow;
    }
  }

// ============ INFRASTRUCTURES HYDRAULIQUES ============
  Future<bool?> saveOrUpdateInfrastructureHydraulique(Map<String, dynamic> geoJsonData) async {
    final db = await database;
    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      final apiUserId = ApiService.userId;

      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null;
      }

      final existing = await db.query(
        'infrastructures_hydrauliques',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();
        await db.insert(
          'infrastructures_hydrauliques',
          {
            'api_id': sqliteId,
            'x_infrastructure_hydraulique': geometry['coordinates'][0],
            'y_infrastructure_hydraulique': geometry['coordinates'][1],
            'nom': properties['nom'] ?? 'Sans nom',
            'type': properties['type'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ infrastructures_hydrauliques sauvegardée: ${properties['nom']}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur sauvegarde infrastructures_hydrauliques: $e');
      rethrow;
    }
  }

// ============ AUTRES INFRASTRUCTURES ============
  Future<bool?> saveOrUpdateAutreInfrastructure(Map<String, dynamic> geoJsonData) async {
    final db = await database;
    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      final apiUserId = ApiService.userId;

      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null;
      }

      final existing = await db.query(
        'autres_infrastructures',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();
        await db.insert(
          'autres_infrastructures',
          {
            'api_id': sqliteId,
            'x_autre_infrastructure': geometry['coordinates'][0],
            'y_autre_infrastructure': geometry['coordinates'][1],
            'nom': properties['nom'] ?? 'Sans nom',
            'type': properties['type'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ autres_infrastructures sauvegardée: ${properties['nom']}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur sauvegarde autres_infrastructures: $e');
      rethrow;
    }
  }

  Future<void> updateSyncedEntity(String tableName, int localId, Map<String, dynamic> apiResponse) async {
    final db = await database;
    try {
      final updates = <String, dynamic>{
        'synced': 1,
        'date_sync': DateTime.now().toIso8601String(),
        'api_id': apiResponse['id'],
      };

      final props = apiResponse['properties'] as Map<String, dynamic>? ?? apiResponse;

      // ⭐ Mettre à jour le code_piste avec le code officiel du serveur
      final String? newCodePiste = props['code_piste']?.toString();
      if (newCodePiste != null) {
        updates['code_piste'] = newCodePiste;
        print('🔄 Code piste mis à jour localement pour $tableName: $newCodePiste');
      }

      if (props['communes_rurales_id'] != null) {
        updates['commune_id'] = props['communes_rurales_id'];
      } else if (props['commune_id'] != null) {
        updates['commune_id'] = props['commune_id'];
      }
      if (props['region_name'] != null) {
        updates['region_name'] = props['region_name'];
      }
      if (props['prefecture_name'] != null) {
        updates['prefecture_name'] = props['prefecture_name'];
      }
      if (props['commune_name'] != null) {
        updates['commune_name'] = props['commune_name'];
      }

      // 1. Mettre à jour la table principale
      await db.update(
        tableName,
        updates,
        where: 'id = ?',
        whereArgs: [
          localId
        ],
      );

      //  2. Mettre à jour AUSSI displayed_points
      if (newCodePiste != null) {
        try {
          final tableExists = Sqflite.firstIntValue(
            await db.rawQuery("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='displayed_points'"),
          );
          if (tableExists != null && tableExists > 0) {
            final updated = await db.update(
              'displayed_points',
              {
                'code_piste': newCodePiste
              },
              where: 'id = ? AND original_table = ?',
              whereArgs: [
                localId,
                tableName
              ],
            );
            if (updated > 0) {
              print('✅ displayed_points mis à jour: $tableName ID $localId → $newCodePiste');
            }
          }
        } catch (e) {
          print('⚠️ Erreur mise à jour displayed_points: $e');
        }
      }

      print('✅ $tableName ID $localId synchronisé et mis à jour');
    } catch (e) {
      print('❌ Erreur updateSyncedEntity: $e');
    }
  }

// ============ PONTS ============
  Future<bool?> saveOrUpdatePont(Map<String, dynamic> geoJsonData) async {
    final db = await database;
    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      final apiUserId = ApiService.userId;

      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null;
      }

      final existing = await db.query(
        'ponts',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();
        await db.insert(
          'ponts',
          {
            'api_id': sqliteId,
            'x_pont': geometry['coordinates'][0],
            'y_pont': geometry['coordinates'][1],
            'nom': properties['nom'] ?? 'Sans nom',
            'situation_pont': properties['situation_pont'] ?? 'Non spécifié',
            'type_pont': properties['type_pont'] ?? 'Non spécifié',
            'nom_cours_eau': properties['nom_cours_eau'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ ponts sauvegardée: ${properties['nom']}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur sauvegarde ponts: $e');
      rethrow;
    }
  }

// ============ BACS ============
  Future<bool?> saveOrUpdateBac(Map<String, dynamic> geoJsonData) async {
    final db = await database;
    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      print('🔍 DEBUG BAC STRUCTURE:');
      print('   Geometry type: ${geometry['type']}');
      print('   Coordinates: ${geometry['coordinates']}');
      print('   Coordinates type: ${geometry['coordinates'].runtimeType}');

      if (dataUserId == ApiService.userId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null;
      }

      final existing = await db.query(
        'bacs',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();

        double xDebut = 0.0, yDebut = 0.0, xFin = 0.0, yFin = 0.0;

        if (geometry['type'] == 'LineString') {
          final coordinates = geometry['coordinates'];
          if (coordinates.length >= 2) {
            xDebut = coordinates[0][0].toDouble();
            yDebut = coordinates[0][1].toDouble();
            xFin = coordinates[1][0].toDouble();
            yFin = coordinates[1][1].toDouble();
          }
        } else if (geometry['type'] == 'MultiLineString') {
          final coordinates = geometry['coordinates'];
          if (coordinates.isNotEmpty && coordinates[0].length >= 2) {
            xDebut = coordinates[0][0][0].toDouble();
            yDebut = coordinates[0][0][1].toDouble();
            xFin = coordinates[0][1][0].toDouble();
            yFin = coordinates[0][1][1].toDouble();
          }
        } else {
          print('⚠️ Format de géométrie non supporté: ${geometry['type']}');
        }

        print('📍 Coordonnées bac - Début: ($xDebut, $yDebut), Fin: ($xFin, $yFin)');

        await db.insert(
          'bacs',
          {
            'api_id': sqliteId,
            'x_debut_traversee_bac': xDebut,
            'y_debut_traversee_bac': yDebut,
            'x_fin_traversee_bac': xFin,
            'y_fin_traversee_bac': yFin,
            'nom': properties['nom'] ?? 'Sans nom',
            'type_bac': properties['type_bac'] ?? 'Non spécifié',
            'nom_cours_eau': properties['nom_cours_eau'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _saveDownloadedSpecialLine(
          db: db,
          apiId: sqliteId,
          tableName: 'bacs',
          latDebut: yDebut,
          lngDebut: xDebut,
          latFin: yFin,
          lngFin: xFin,
          specialType: 'Bac',
          name: properties['nom'] ?? 'Sans nom',
          codePiste: properties['code_piste'] ?? '',
          viewerId: viewerId,
          regionName: properties['region_name'],
          prefectureName: properties['prefecture_name'],
          communeName: properties['commune_name'],
          enqueteur: properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
        );
        print('✅ Bac sauvegardé: ${properties['nom']}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur sauvegarde bacs: $e');
      print('📋 Données problématiques: ${jsonEncode(geoJsonData)}');
      rethrow;
    }
  }

// ============ BUSES ============
  Future<bool?> saveOrUpdateBuse(Map<String, dynamic> geoJsonData) async {
    final db = await database;
    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      final apiUserId = ApiService.userId;

      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null;
      }

      final existing = await db.query(
        'buses',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();
        await db.insert(
          'buses',
          {
            'api_id': sqliteId,
            'x_buse': geometry['coordinates'][0] ?? 'Non spécifié',
            'y_buse': geometry['coordinates'][1] ?? 'Non spécifié',
            'nom': properties['nom'] ?? 'Sans nom',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ buses sauvegardée: ${properties['nom']}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur sauvegarde buses: $e');
      rethrow;
    }
  }

// ============ DALOTS ============
  Future<bool?> saveOrUpdateDalot(Map<String, dynamic> geoJsonData) async {
    final db = await database;
    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      final apiUserId = ApiService.userId;

      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null;
      }

      final existing = await db.query(
        'dalots',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();
        await db.insert(
          'dalots',
          {
            'api_id': sqliteId,
            'x_dalot': geometry['coordinates'][0] ?? 'Non spécifié',
            'y_dalot': geometry['coordinates'][1] ?? 'Non spécifié',
            'nom': properties['nom'] ?? 'Sans nom',
            'situation_dalot': properties['situation_dalot'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ dalots sauvegardée: ${properties['nom']}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur sauvegarde dalots: $e');
      rethrow;
    }
  }

// ============ PASSAGES SUBMERSIBLES ============
  Future<bool?> saveOrUpdatePassageSubmersible(Map<String, dynamic> geoJsonData) async {
    final db = await database;
    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      print('🔍 DEBUG PASSAGE SUBMERSIBLE STRUCTURE:');
      print('   Geometry type: ${geometry['type']}');
      print('   Coordinates: ${geometry['coordinates']}');
      print('   Coordinates type: ${geometry['coordinates'].runtimeType}');

      if (dataUserId == ApiService.userId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null;
      }

      final existing = await db.query(
        'passages_submersibles',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();

        double xDebut = 0.0, yDebut = 0.0, xFin = 0.0, yFin = 0.0;

        if (geometry['type'] == 'LineString') {
          final coordinates = geometry['coordinates'];
          if (coordinates.length >= 2) {
            xDebut = coordinates[0][0].toDouble();
            yDebut = coordinates[0][1].toDouble();
            xFin = coordinates[1][0].toDouble();
            yFin = coordinates[1][1].toDouble();
          }
        } else if (geometry['type'] == 'MultiLineString') {
          final coordinates = geometry['coordinates'];
          if (coordinates.isNotEmpty && coordinates[0].length >= 2) {
            xDebut = coordinates[0][0][0].toDouble();
            yDebut = coordinates[0][0][1].toDouble();
            xFin = coordinates[0][1][0].toDouble();
            yFin = coordinates[0][1][1].toDouble();
          }
        } else {
          print('⚠️ Format de géométrie non supporté: ${geometry['type']}');
        }

        print('📍 Coordonnées passage - Début: ($xDebut, $yDebut), Fin: ($xFin, $yFin)');

        await db.insert(
          'passages_submersibles',
          {
            'api_id': sqliteId,
            'x_debut_passage_submersible': xDebut,
            'y_debut_passage_submersible': yDebut,
            'x_fin_passage_submersible': xFin,
            'y_fin_passage_submersible': yFin,
            'nom': properties['nom'] ?? 'Sans nom',
            'type_materiau': properties['type_materiau'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _saveDownloadedSpecialLine(
          db: db,
          apiId: sqliteId,
          tableName: 'passages_submersibles',
          latDebut: yDebut,
          lngDebut: xDebut,
          latFin: yFin,
          lngFin: xFin,
          specialType: 'Passage Submersible',
          name: properties['nom'] ?? 'Sans nom',
          codePiste: properties['code_piste'] ?? '',
          viewerId: viewerId,
          regionName: properties['region_name'],
          prefectureName: properties['prefecture_name'],
          communeName: properties['commune_name'],
          enqueteur: properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
        );
        print('✅ Passage submersible sauvegardé: ${properties['nom']}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur sauvegarde passages_submersibles: $e');
      print('📋 Données problématiques: ${jsonEncode(geoJsonData)}');
      rethrow;
    }
  }

// ============ POINTS CRITIQUES ============
  Future<bool?> saveOrUpdatePointCritique(Map<String, dynamic> geoJsonData) async {
    final db = await database;
    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      final apiUserId = ApiService.userId;

      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null;
      }

      double? x;
      double? y;

      if (geometry != null && geometry['coordinates'] != null) {
        final coords = geometry['coordinates'];
        x = (coords[0] as num).toDouble();
        y = (coords[1] as num).toDouble();
      } else {
        x = (properties['x_point_cr'] as num?)?.toDouble();
        y = (properties['y_point_cr'] as num?)?.toDouble();
      }

      if (x == null || y == null) {
        print('🚫 Point critique ignoré (pas de géométrie exploitable) sqlite_id=$sqliteId');
        return false;
      }

      final existing = await db.query(
        'points_critiques',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();

        await db.insert(
          'points_critiques',
          {
            'api_id': sqliteId,
            'x_point_critique': x,
            'y_point_critique': y,
            'type_point_critique': properties['type_point'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ points_critiques sauvegardée: sqlite_id=$sqliteId');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur sauvegarde points_critiques: $e');
      rethrow;
    }
  }

// ============ POINTS COUPURES ============
  Future<bool?> saveOrUpdatePointCoupure(Map<String, dynamic> geoJsonData) async {
    final db = await database;
    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      final apiUserId = ApiService.userId;

      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null;
      }

      final existing = await db.query(
        'points_coupures',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();
        await db.insert(
          'points_coupures',
          {
            'api_id': sqliteId,
            'x_point_coupure': geometry['coordinates'][0],
            'y_point_coupure': geometry['coordinates'][1],
            'causes_coupures': properties['causes_coupures'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ points_coupures sauvegardée: ${properties['nom']}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur sauvegarde points_coupures: $e');
      rethrow;
    }
  }

  // ============  SITE ENQUETE ============
  Future<bool?> saveOrUpdateSiteEnquete(Map<String, dynamic> geoJsonData) async {
    final db = await database;
    try {
      final properties = geoJsonData['properties'];
      final geometry = geoJsonData['geometry'];
      final sqliteId = geoJsonData['id'] ?? properties['sqlite_id'];
      final dataUserId = properties['login_id'];
      final viewerId = await DatabaseHelper().resolveLoginId();

      final apiUserId = ApiService.userId;

      if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
        print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
        return null;
      }

      final existing = await db.query(
        'site_enquete',
        where: 'api_id = ? AND saved_by_user_id = ?',
        whereArgs: [
          sqliteId,
          viewerId
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        final communeId = await _getCommuneId();
        await db.insert(
          'site_enquete',
          {
            'api_id': sqliteId,
            'x_site': geometry['coordinates'][0],
            'y_site': geometry['coordinates'][1],
            'nom': properties['nom'] ?? 'Sans nom',
            'type': properties['type'] ?? 'Non spécifié',
            'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
            'date_creation': properties['created_at'] ?? 'Non spécifié',
            'date_modification': properties['updated_at'] ?? 'Non spécifié',
            'code_piste': properties['code_piste'] ?? 'Non spécifié',
            'code_gps': properties['code_gps'] ?? 'Non spécifié',
            'amenage_ou_non_amenage': properties['amenage_ou_non_amenage'] == true ? 1 : (properties['amenage_ou_non_amenage'] == false ? 0 : null),
            'entreprise': properties['entreprise'],
            'financement': properties['financement'],
            'projet': properties['projet'],
            'superficie_digitalisee': properties['superficie_digitalisee'],
            'superficie_estimee_lors_des_enquetes_ha': properties['superficie_estimee_lors_des_enquetes_ha'],
            'travaux_debut': properties['travaux_debut'],
            'travaux_fin': properties['travaux_fin'],
            'type_de_realisation': properties['type_de_realisation'],
            'synced': 0,
            'downloaded': 1,
            'login_id': dataUserId ?? 'Non spécifié',
            'saved_by_user_id': viewerId,
            'commune_id': properties['communes_rurales_id'],
            'region_name': properties['region_name'],
            'prefecture_name': properties['prefecture_name'],
            'commune_name': properties['commune_name'],
            'date_sync': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ Site enquête sauvegardé: ${properties['nom']}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur sauvegarde site_enquete: $e');
      rethrow;
    }
  }

// ============  ENQUETE POLYGONE ============
  Future<bool?> saveOrUpdateEnquetePolygone(Map<String, dynamic> geoJsonData) async {
    final db = await database;
    final properties = geoJsonData['properties'] as Map<String, dynamic>? ?? {};
    final geometry = geoJsonData['geometry'] as Map<String, dynamic>? ?? {};

    final apiId = geoJsonData['id']; // ← déjà correct
    final dataUserId = properties['login_id'];
    final viewerId = await DatabaseHelper().resolveLoginId(); // ← FIX : comme les autres méthodes
    final communeId = properties['communes_rurales_id'];

    final apiUserId = ApiService.userId;
    if (apiUserId != null && dataUserId != null && dataUserId == apiUserId) {
      print('🚫 Donnée ignorée - créée par le même utilisateur (login_id: $dataUserId)');
      return null;
    }

    // Extraire les coordonnées du polygone (MultiPolygon → premier polygone)
    List<dynamic> coordinates = [];
    if (geometry['type'] == 'MultiPolygon' && geometry['coordinates'] != null) {
      final multiPoly = geometry['coordinates'] as List;
      if (multiPoly.isNotEmpty && multiPoly[0] is List && (multiPoly[0] as List).isNotEmpty) {
        coordinates = multiPoly[0][0];
      }
    } else if (geometry['type'] == 'Polygon' && geometry['coordinates'] != null) {
      final poly = geometry['coordinates'] as List;
      if (poly.isNotEmpty) {
        coordinates = poly[0];
      }
    }

    final pointsJson = coordinates.isNotEmpty ? jsonEncode(coordinates) : null;

    // Vérifier si existe déjà
    final existing = await db.query(
      'enquete_polygone',
      where: 'api_id = ? AND saved_by_user_id = ?',
      whereArgs: [
        apiId,
        viewerId
      ],
    );

    if (existing.isEmpty) {
      await db.insert(
        'enquete_polygone',
        {
          'api_id': apiId,
          'nom': properties['nom'],
          'points_json': pointsJson,
          'superficie_en_ha': properties['superficie_en_ha'],
          'enqueteur': properties['enqueteur_name'] ?? properties['enqueteur'] ?? 'Inconnu',
          'date_creation': properties['created_at'] ?? 'Non spécifié',
          'date_modification': properties['updated_at'] ?? 'Non spécifié',
          'code_piste': properties['code_piste'] ?? 'Non spécifié',
          'code_gps': properties['code_gps'] ?? 'Non spécifié',
          'synced': 0,
          'downloaded': 1,
          'login_id': dataUserId,
          'saved_by_user_id': viewerId,
          'commune_id': communeId,
          'region_name': properties['region_name'],
          'prefecture_name': properties['prefecture_name'],
          'commune_name': properties['commune_name'],
          'date_sync': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    }
    return false;
  }

  /// Sauvegarde une ligne spéciale téléchargée dans special_lines pour l'affichage carte
  Future<void> _saveDownloadedSpecialLine({
    required Database db,
    required dynamic apiId,
    required String tableName,
    required double latDebut,
    required double lngDebut,
    required double latFin,
    required double lngFin,
    required String specialType,
    required String name,
    required String codePiste,
    required dynamic viewerId,
    String? regionName,
    String? prefectureName,
    String? communeName,
    String? enqueteur,
  }) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS special_lines (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          api_id INTEGER,
          original_table TEXT,
          lat_debut REAL,
          lng_debut REAL,
          lat_fin REAL,
          lng_fin REAL,
          special_type TEXT,
          line_name TEXT,
          code_piste TEXT,
          login_id INTEGER,
          saved_by_user_id INTEGER,
          downloaded INTEGER DEFAULT 1,
          date_created TEXT,
          region_name TEXT,
          prefecture_name TEXT,
          commune_name TEXT,
          enqueteur TEXT,
          UNIQUE(api_id, original_table, saved_by_user_id)
        )
      ''');

      await db.insert(
        'special_lines',
        {
          'api_id': apiId,
          'original_table': tableName,
          'lat_debut': latDebut,
          'lng_debut': lngDebut,
          'lat_fin': latFin,
          'lng_fin': lngFin,
          'special_type': specialType,
          'line_name': name,
          'code_piste': codePiste,
          'saved_by_user_id': viewerId,
          'downloaded': 1,
          'date_created': DateTime.now().toIso8601String(),
          'region_name': regionName,
          'prefecture_name': prefectureName,
          'commune_name': communeName,
          'enqueteur': enqueteur,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ Special line ($specialType) ajoutée pour affichage carte');
    } catch (e) {
      print('⚠️ Erreur sauvegarde special_line: $e');
    }
  }

// Dans database_helper.dart
  Future<void> saveDisplayedSpecialLine({
    required int id,
    required String tableName,
    required double latDebut,
    required double lngDebut,
    required double latFin,
    required double lngFin,
    required String specialType,
    required String name,
    required String codePiste,
  }) async {
    final db = await database;

    // Créer une table dédiée pour les lignes spéciales si elle n'existe pas
    await db.execute('''
    CREATE TABLE IF NOT EXISTS displayed_special_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      original_id INTEGER NOT NULL,
      original_table TEXT NOT NULL,
      lat_debut REAL NOT NULL,
      lng_debut REAL NOT NULL,
      lat_fin REAL NOT NULL,
      lng_fin REAL NOT NULL,
      special_type TEXT NOT NULL,
      line_name TEXT NOT NULL,
      code_piste TEXT,
      login_id INTEGER,
      date_created TEXT NOT NULL,
      UNIQUE(original_id, original_table)
    )
  ''');

    final loginId = await _resolveLoginId();

    await db.insert(
      'displayed_special_lines',
      {
        'original_id': id, // Renommé de 'id' à 'original_id'
        'original_table': tableName,
        'lat_debut': latDebut,
        'lng_debut': lngDebut,
        'lat_fin': latFin,
        'lng_fin': lngFin,
        'special_type': specialType,
        'line_name': name,
        'code_piste': codePiste,
        'login_id': loginId,
        'date_created': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('✅ Ligne spéciale sauvegardée: $name (original_id: $id, table: $tableName)');
  }

  Future<void> deleteSpecialLine(int originalId, String originalTable) async {
    final db = await database;
    try {
      // Supprimer de special_lines (downloaded)
      await db.delete(
        'special_lines',
        where: 'api_id = ? AND original_table = ?',
        whereArgs: [
          originalId,
          originalTable
        ],
      );
      // Supprimer aussi de displayed_special_lines (local)
      await db.delete(
        'displayed_special_lines',
        where: 'original_id = ? AND original_table = ?',
        whereArgs: [
          originalId,
          originalTable
        ],
      );
      print('🗑️ Special line supprimée ($originalTable, id: $originalId)');
    } catch (e) {
      print('⚠️ Erreur suppression special_line: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadDisplayedSpecialLines() async {
    final db = await database;
    final loginId = await _resolveLoginId();

    final tableExists = await _tableExists(db, 'displayed_special_lines');
    if (!tableExists) return [];

    return await db.query(
      'displayed_special_lines',
      where: 'login_id = ?',
      whereArgs: [
        loginId
      ],
    );
  }

// Dans DatabaseHelper, ajoutez cette méthode
  Future<void> debugDisplayedSpecialLines() async {
    final db = await database;
    final tableExists = await _tableExists(db, 'displayed_special_lines');
    print('📊 Table displayed_special_lines existe: $tableExists');

    if (tableExists) {
      final lines = await db.query('displayed_special_lines');
      print('📊 Nombre de lignes spéciales dans la table: ${lines.length}');

      for (var line in lines) {
        print('  - ID: ${line['id']}, Type: ${line['special_type']}, Nom: ${line['line_name']}');
      }
    }
  }

  Future<void> saveDisplayedPoint({
    required int id,
    required String tableName,
    required double latitude,
    required double longitude,
    required String type,
    required String name,
    required String codePiste,
  }) async {
    final db = await database;

    // Créer une table dédiée pour l'affichage si elle n'existe pas
    await db.execute('''
    CREATE TABLE IF NOT EXISTS displayed_points (
      id INTEGER NOT NULL,
      original_table TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      point_type TEXT NOT NULL,
      point_name TEXT NOT NULL,
      code_piste TEXT,
      login_id INTEGER ,
      date_created TEXT NOT NULL,
      PRIMARY KEY (id, original_table)
    )
  ''');
    final loginId = await _resolveLoginId();
    await db.insert(
      'displayed_points',
      {
        'id': id,
        'original_table': tableName,
        'latitude': latitude,
        'longitude': longitude,
        'point_type': type,
        'point_name': name,
        'code_piste': codePiste,
        'login_id': loginId,
        'date_created': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('✅ Point sauvegardé pour affichage: $name (ID: $id)');
  }

//  Méthode publique pour les autres fichiers
  Future<int?> resolveLoginId() => _resolveLoginId();
// Helper minimal pour résoudre login_id : API > users > null
  Future<int?> _resolveLoginId() async {
    // 1) Priorité à l'API
    final dynamic apiRaw = ApiService.userId; // peut être int? ou String?
    int? apiId;
    if (apiRaw is int) {
      apiId = apiRaw;
    } else if (apiRaw is String) {
      apiId = int.tryParse(apiRaw);
    }
    if (apiId != null && apiId > 0) return apiId;

    // 2) Sinon, on tente l'utilisateur courant (email) s'il est stocké
    try {
      final email = await getSessionUserEmail();
      // si tu l'as déjà dans DatabaseHelper
      if (email != null && email.isNotEmpty) {
        final db = await database;
        final byMail = await db.query(
          'users',
          columns: [
            'apiId',
            'id'
          ],
          where: 'email = ?',
          whereArgs: [
            email
          ],
          limit: 1,
        );
        if (byMail.isNotEmpty) {
          // ✅ priorité à l'id serveur stocké dans users.apiId
          final vApi = byMail.first['apiId'];
          if (vApi is int && vApi > 0) return vApi;
          if (vApi is String) {
            final parsed = int.tryParse(vApi);
            if (parsed != null && parsed > 0) return parsed;
          }

          // fallback: ancien id local sqlite (au cas où apiId est vide)
          final v = byMail.first['id'];
          if (v is int) return v;
          if (v is String) return int.tryParse(v);
        }
      }
    } catch (_) {
      // si getCurrentUserEmail n'existe pas chez toi, on ignore
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> loadDisplayedPoints() async {
    final db = await database;
    final loginId = await _resolveLoginId();
    final tableExists = await _tableExists(db, 'displayed_points');
    if (!tableExists) return [];

    // ============ AJOUTER LE FILTRE PAR UTILISATEUR ============
    return await db.query(
      'displayed_points',
      where: 'login_id = ?', // ← NOUVEAU FILTRE
      whereArgs: [
        loginId
      ], // ← ID de l'utilisateur connecté
    );
    // ============ FIN ============
  }

  // Dans DatabaseHelper - pour garder la DB propre
  Future<void> cleanupDisplayedPoints() async {
    final db = await database;

    // UNIQUEMENT supprimer les points SANS login_id
    final result = await db.delete(
      'displayed_points',
      where: 'login_id IS NULL', // ← SEULEMENT les points sans utilisateur
      // whereArgs: [ApiService.userId],  // ← SUPPRIMEZ CETTE LIGNE
    );

    print('🧹 $result points sans utilisateur nettoyés');
  }

  // Dans la classe DatabaseHelper
  Future<void> deleteDisplayedPoint(int id, String tableName) async {
    try {
      final db = await database;
      await db.delete(
        'displayed_points',
        where: 'id = ? AND original_table = ?',
        whereArgs: [
          id,
          tableName
        ],
      );
      print('✅ Point affiché supprimé: ID $id de la table $tableName');
    } catch (e) {
      print('❌ Erreur suppression point affiché: $e');
    }
  }
}
