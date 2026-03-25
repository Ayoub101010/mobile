import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async'; // pour TimeoutException
import 'dart:io'; // pour SocketException

class ApiService {
  static const String baseUrl = "http://192.168.1.144/mobile";

  static String? authToken;
  static int? userId;
  static int? communeId;
  static int? prefectureId;
  static int? regionId;
  static String? communeNom;
  static String? prefectureNom;
  static String? regionNom;
  // ===== NOUVEAU : RBAC =====
  static String? userRole;
  static List<Map<String, dynamic>> assignedRegions = [];
  static List<Map<String, dynamic>> assignedPrefectures = [];
  static List<int> accessibleCommuneIds = [];
  // Remplace par l'IP de ton PC ou le serveur API

  /// Fonction pour se connecter via API
  /// Retourne un Map<String, dynamic> contenant au minimum :
  /// { "nom": "...", "prenom": "...", "mail": "...", "role": "..." }
  static Future<Map<String, dynamic>> login(String mail, String mdp) async {
    final url = Uri.parse('$baseUrl/api/login/');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'mail': mail,
        'mdp': mdp,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      // 1. Détecter la source des données utilisateur (objet "user" ou top-level)
      final bool hasUserKey = data.containsKey('user') && data['user'] is Map;
      final Map<String, dynamic> userMap = hasUserKey ? Map<String, dynamic>.from(data['user']) : data;

      // 2. Extraire le token (access pour JWT, token pour legacy)
      authToken = data['access'] ?? data['token'] ?? userMap['token'];

      // 3. Extraire l'ID (fallback entre userMap et data)
      userId = userMap['id'] ?? data['id'];

      // 4. Extraction de la hiérarchie géographique
      final commune = userMap['commune'];
      final prefecture = userMap['prefecture'];
      final region = userMap['region'];

      communeId = (commune != null && commune is Map) ? commune['id'] : (userMap['communes_rurales'] ?? data['communes_rurales']);
      prefectureId = (prefecture != null && prefecture is Map) ? prefecture['id'] : (userMap['prefecture_id'] ?? data['prefecture_id']);
      regionId = (region != null && region is Map) ? region['id'] : (userMap['region_id'] ?? data['region_id']);

      communeNom = (commune != null && commune is Map) ? commune['nom'] : (userMap['commune_nom'] ?? data['commune_nom']);
      prefectureNom = (prefecture != null && prefecture is Map) ? prefecture['nom'] : (userMap['prefecture_nom'] ?? data['prefecture_nom']);
      regionNom = (region != null && region is Map) ? region['nom'] : (userMap['region_nom'] ?? data['region_nom']);

      // 5. Préparer le résultat final "à plat" pour LoginPage et DatabaseHelper
      final Map<String, dynamic> result = Map<String, dynamic>.from(userMap);

      // S'assurer que les champs clés sont présents même si au top-level du JSON
      result['nom'] = result['nom'] ?? data['nom'];
      result['prenom'] = result['prenom'] ?? data['prenom'];
      result['id'] = userId;
      result['token'] = authToken;
      result['communes_rurales'] = communeId;
      result['prefecture_id'] = prefectureId;
      result['region_id'] = regionId;
      result['commune_nom'] = communeNom;
      result['prefecture_nom'] = prefectureNom;
      result['region_nom'] = regionNom;

      // ===== NOUVEAU : Stocker les données RBAC =====
      userRole = result['role'];

      // Régions assignées (pour BTGR)
      if (data['assigned_regions'] != null) {
        assignedRegions = List<Map<String, dynamic>>.from((data['assigned_regions'] as List).map((e) => Map<String, dynamic>.from(e)));
      } else {
        assignedRegions = [];
      }
      result['assigned_regions'] = assignedRegions;

      // Préfectures assignées (pour SPGR)
      if (data['assigned_prefectures'] != null) {
        assignedPrefectures = List<Map<String, dynamic>>.from((data['assigned_prefectures'] as List).map((e) => Map<String, dynamic>.from(e)));
      } else {
        assignedPrefectures = [];
      }
      result['assigned_prefectures'] = assignedPrefectures;

      // Communes accessibles (calculées par le serveur selon le rôle)
      if (data['accessible_commune_ids'] != null) {
        accessibleCommuneIds = List<int>.from(data['accessible_commune_ids']);
      } else {
        accessibleCommuneIds = [];
      }
      result['accessible_commune_ids'] = accessibleCommuneIds;

      print('🔐 RBAC: role=$userRole | régions=${assignedRegions.length} | '
          'préfectures=${assignedPrefectures.length} | '
          'communes accessibles=${accessibleCommuneIds.length}');

      // Validation finale du minimum vital

      // Validation finale du minimum vital
      if (result['nom'] != null && result['prenom'] != null) {
        return result;
      } else {
        print('❌ Données manquantes dans la réponse: $result');
        throw Exception("Réponse API invalide : nom ou prenom manquant");
      }
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['error'] ?? 'Erreur inconnue');
    }
  }

// Méthode générique pour envoyer des données
// Méthode générique pour envoyer des données
  static Future<dynamic> postData(String endpoint, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$baseUrl/api/$endpoint/');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (authToken != null) 'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          return jsonDecode(utf8.decode(response.bodyBytes));
        } catch (e) {
          return true; // Fallback si le body n'est pas du JSON mais que c'est 200 OK
        }
      } else {
        print('❌ Erreur API ($endpoint): ${response.statusCode} - ${response.body}');
        return null; // Échec
      }
    } on TimeoutException catch (e) {
      print('⏰ Timeout lors de l\'appel à $endpoint: $e');
      return null;
    } on SocketException catch (e) {
      print('📡 Erreur réseau lors de l\'appel à $endpoint: $e');
      return null;
    } catch (e) {
      print('❌ Exception lors de l\'envoi à $endpoint: $e');
      return null;
    }
  }

// Dans votre api_service.dart

  /// Méthodes spécifiques pour chaque type de données - RETOURNENT LE BODY (Map) ou NULL
  static Future<dynamic> syncPiste(Map<String, dynamic> data) async {
    return await postData('pistes', data);
  }

// Dans ApiService.dart
  static Future<dynamic> syncChausseeTest(Map<String, dynamic> data) async {
    return await postData('chaussees', data);
  }

  static Future<dynamic> syncLocalite(Map<String, dynamic> data) async {
    return await postData('localites', _mapLocaliteToApi(data));
  }

  static Future<dynamic> syncEcole(Map<String, dynamic> data) async {
    return await postData('ecoles', _mapEcoleToApi(data));
  }

  static Future<dynamic> syncMarche(Map<String, dynamic> data) async {
    return await postData('marches', _mapMarcheToApi(data));
  }

  static Future<dynamic> syncServiceSante(Map<String, dynamic> data) async {
    return await postData('services_santes', _mapServiceSanteToApi(data));
  }

  static Future<dynamic> syncBatimentAdministratif(Map<String, dynamic> data) async {
    return await postData('batiments_administratifs', _mapBatimentAdministratifToApi(data));
  }

  static Future<dynamic> syncInfrastructureHydraulique(Map<String, dynamic> data) async {
    return await postData('infrastructures_hydrauliques', _mapInfrastructureHydrauliqueToApi(data));
  }

  static Future<dynamic> syncAutreInfrastructure(Map<String, dynamic> data) async {
    return await postData('autres_infrastructures', _mapAutreInfrastructureToApi(data));
  }

  static Future<dynamic> syncPont(Map<String, dynamic> data) async {
    return await postData('ponts', _mapPontToApi(data));
  }

  static Future<dynamic> syncBac(Map<String, dynamic> data) async {
    return await postData('bacs', _mapBacToApi(data));
  }

  static Future<dynamic> syncBuse(Map<String, dynamic> data) async {
    return await postData('buses', _mapBuseToApi(data));
  }

  static Future<dynamic> syncDalot(Map<String, dynamic> data) async {
    return await postData('dalots', _mapDalotToApi(data));
  }

  static Future<dynamic> syncPassageSubmersible(Map<String, dynamic> data) async {
    return await postData('passages_submersibles', _mapPassageSubmersibleToApi(data));
  }

  static Future<dynamic> syncPointCritique(Map<String, dynamic> data) async {
    return await postData('points_critiques', _mapPointCritiqueToApi(data));
  }

  static Future<dynamic> syncPointCoupure(Map<String, dynamic> data) async {
    return await postData('points_coupures', _mapPointCoupureToApi(data));
  }

  static Future<dynamic> syncSiteEnquete(Map<String, dynamic> data) async {
    return await postData('site_enquete', _mapSiteEnqueteToApi(data));
  }

  static Future<dynamic> syncEnquetePolygone(Map<String, dynamic> data) async {
    return await postData('enquete_polygone', _mapEnquetePolygoneToApi(data));
  }

  /// Mapping des données locales vers le format API
  static Map<String, dynamic> _mapLocaliteToApi(Map<String, dynamic> localData) {
    // Convertir la date au format PostgreSQL
    String formatDateForPostgres(String? dateString) {
      if (dateString == null) return '';
      try {
        final date = DateTime.parse(dateString);

        // Si l'heure est minuit (00:00:00), utiliser l'heure actuelle
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          // Sinon utiliser l'heure de la date
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString;
      }
    }

    return {
      'sqlite_id': localData['id'],
      'x_localite': localData['x_localite'],
      'y_localite': localData['y_localite'],
      'nom': localData['nom'],
      'type': localData['type'],
      'enqueteur': localData['enqueteur'],
      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),
      'code_piste': localData['code_piste'],
      'code_gps': localData['code_gps'],
      'login_id': userId,
      'commune_id': localData['commune_id'],
    };
  }

  static Map<String, dynamic> _mapEcoleToApi(Map<String, dynamic> localData) {
    // Convertir la date au format PostgreSQL
    String formatDateForPostgres(String? dateString) {
      if (dateString == null) return '';
      try {
        final date = DateTime.parse(dateString);

        // Si l'heure est minuit (00:00:00), utiliser l'heure actuelle
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          // Sinon utiliser l'heure de la date
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString;
      }
    }

    return {
      'sqlite_id': localData['id'],
      'x_ecole': localData['x_ecole'],
      'y_ecole': localData['y_ecole'],
      'nom': localData['nom'],
      'type': localData['type'],
      'enqueteur': localData['enqueteur'],
      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),
      'code_piste': localData['code_piste'],
      'code_gps': localData['code_gps'],
      'login_id': userId,
      'commune_id': localData['commune_id'],
    };
  }

  static Map<String, dynamic> _mapMarcheToApi(Map<String, dynamic> localData) {
    // Convertir la date au format PostgreSQL
    String formatDateForPostgres(String? dateString) {
      if (dateString == null) return '';
      try {
        final date = DateTime.parse(dateString);

        // Si l'heure est minuit (00:00:00), utiliser l'heure actuelle
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          // Sinon utiliser l'heure de la date
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString;
      }
    }

    return {
      'sqlite_id': localData['id'],
      'x_marche': localData['x_marche'],
      'y_marche': localData['y_marche'],
      'nom': localData['nom'],
      'type': localData['type'],
      'enqueteur': localData['enqueteur'],
      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),
      'code_piste': localData['code_piste'],
      'code_gps': localData['code_gps'],
      'login_id': userId,
      'commune_id': localData['commune_id'],
    };
  }

  static Map<String, dynamic> _mapServiceSanteToApi(Map<String, dynamic> localData) {
    // Convertir la date au format PostgreSQL
    String formatDateForPostgres(String? dateString) {
      if (dateString == null) return '';
      try {
        final date = DateTime.parse(dateString);

        // Si l'heure est minuit (00:00:00), utiliser l'heure actuelle
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          // Sinon utiliser l'heure de la date
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString;
      }
    }

    return {
      'sqlite_id': localData['id'],
      'x_sante': localData['x_sante'],
      'y_sante': localData['y_sante'],
      'nom': localData['nom'],
      'type': localData['type'],
      'enqueteur': localData['enqueteur'],
      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),
      'code_piste': localData['code_piste'],
      'code_gps': localData['code_gps'],
      'login_id': userId,
      'commune_id': localData['commune_id'],
    };
  }

  static Map<String, dynamic> _mapBatimentAdministratifToApi(Map<String, dynamic> localData) {
    // Convertir la date au format PostgreSQL
    String formatDateForPostgres(String? dateString) {
      if (dateString == null) return '';
      try {
        final date = DateTime.parse(dateString);

        // Si l'heure est minuit (00:00:00), utiliser l'heure actuelle
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          // Sinon utiliser l'heure de la date
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString;
      }
    }

    return {
      'sqlite_id': localData['id'],
      'x_batiment': localData['x_batiment_administratif'],
      'y_batiment': localData['y_batiment_administratif'],
      'nom': localData['nom'],
      'type': localData['type'],
      'enqueteur': localData['enqueteur'],
      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),
      'code_piste': localData['code_piste'],
      'code_gps': localData['code_gps'],
      'login_id': userId,
      'commune_id': localData['commune_id'],
    };
  }

  static Map<String, dynamic> _mapInfrastructureHydrauliqueToApi(Map<String, dynamic> localData) {
    // Convertir la date au format PostgreSQL
    String formatDateForPostgres(String? dateString) {
      if (dateString == null) return '';
      try {
        final date = DateTime.parse(dateString);

        // Si l'heure est minuit (00:00:00), utiliser l'heure actuelle
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          // Sinon utiliser l'heure de la date
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString;
      }
    }

    return {
      'sqlite_id': localData['id'],
      'x_infrastr': localData['x_infrastructure_hydraulique'],
      'y_infrastr': localData['y_infrastructure_hydraulique'],
      'nom': localData['nom'],
      'type': localData['type'],
      'enqueteur': localData['enqueteur'],
      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),
      'code_piste': localData['code_piste'],
      'code_gps': localData['code_gps'],
      'login_id': userId,
      'commune_id': localData['commune_id'],
    };
  }

  static Map<String, dynamic> _mapAutreInfrastructureToApi(Map<String, dynamic> localData) {
    // Convertir la date au format PostgreSQL
    String formatDateForPostgres(String? dateString) {
      if (dateString == null) return '';
      try {
        final date = DateTime.parse(dateString);

        // Si l'heure est minuit (00:00:00), utiliser l'heure actuelle
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          // Sinon utiliser l'heure de la date
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString;
      }
    }

    return {
      'sqlite_id': localData['id'],
      'x_autre_in': localData['x_autre_infrastructure'],
      'y_autre_in': localData['y_autre_infrastructure'],
      'nom': localData['nom'],
      'type': localData['type'],
      'enqueteur': localData['enqueteur'],
      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),
      'code_piste': localData['code_piste'],
      'code_gps': localData['code_gps'],
      'login_id': userId,
      'commune_id': localData['commune_id'],
    };
  }

  static Map<String, dynamic> _mapPontToApi(Map<String, dynamic> localData) {
    // Convertir la date au format PostgreSQL
    String formatDateForPostgres(String? dateString) {
      if (dateString == null) return '';
      try {
        final date = DateTime.parse(dateString);

        // Si l'heure est minuit (00:00:00), utiliser l'heure actuelle
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          // Sinon utiliser l'heure de la date
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString;
      }
    }

    return {
      'sqlite_id': localData['id'],
      'x_pont': localData['x_pont'],
      'y_pont': localData['y_pont'],
      'nom': localData['nom'],
      'situation': localData['situation_pont'],
      'type_pont': localData['type_pont'],
      'nom_cours': localData['nom_cours_eau'],
      'enqueteur': localData['enqueteur'],
      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),
      'code_piste': localData['code_piste'],
      'code_gps': localData['code_gps'],
      'login_id': userId,
      'commune_id': localData['commune_id'],
    };
  }

  static Map<String, dynamic> _mapBacToApi(Map<String, dynamic> localData) {
    String formatDateForPostgres(String? dateString) {
      if (dateString == null) return '';
      try {
        final date = DateTime.parse(dateString);

        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString;
      }
    }

    return {
      "sqlite_id": localData["id"],
      "geom": {
        "type": "LineString",
        "coordinates": [
          [
            localData["x_debut_traversee_bac"],
            localData["y_debut_traversee_bac"]
          ],
          [
            localData["x_fin_traversee_bac"],
            localData["y_fin_traversee_bac"]
          ]
        ]
      },
      "x_debut_tr": localData["x_debut_traversee_bac"],
      "y_debut_tr": localData["y_debut_traversee_bac"],
      "x_fin_trav": localData["x_fin_traversee_bac"],
      "y_fin_trav": localData["y_fin_traversee_bac"],
      "nom": localData["nom"],
      "type_bac": localData["type_bac"],
      "nom_cours": localData["nom_cours_eau"],
      "created_at": formatDateForPostgres(localData["date_creation"]),
      "updated_at": formatDateForPostgres(localData["date_modification"]),
      "code_piste": localData["code_piste"],
      "code_gps": localData["code_gps"],
      "endroit": localData["endroit"],
      "login_id": userId,
      "commune_id": localData["commune_id"],
    };
  }

  static Map<String, dynamic> _mapBuseToApi(Map<String, dynamic> localData) {
    // Convertir la date au format PostgreSQL
    String formatDateForPostgres(String? dateString) {
      if (dateString == null) return '';
      try {
        final date = DateTime.parse(dateString);

        // Si l'heure est minuit (00:00:00), utiliser l'heure actuelle
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          // Sinon utiliser l'heure de la date
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString;
      }
    }

    return {
      'sqlite_id': localData['id'],
      'x_buse': localData['x_buse'],
      'y_buse': localData['y_buse'],
      'nom': localData['nom'],
      'enqueteur': localData['enqueteur'],
      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),
      'code_piste': localData['code_piste'],
      'code_gps': localData['code_gps'],
      'login_id': userId,
      'commune_id': localData['commune_id'],
    };
  }

  static Map<String, dynamic> _mapDalotToApi(Map<String, dynamic> localData) {
    // Convertir la date au format PostgreSQL
    String formatDateForPostgres(String? dateString) {
      if (dateString == null) return '';
      try {
        final date = DateTime.parse(dateString);

        // Si l'heure est minuit (00:00:00), utiliser l'heure actuelle
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          // Sinon utiliser l'heure de la date
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString;
      }
    }

    return {
      'sqlite_id': localData['id'],
      'x_dalot': localData['x_dalot'],
      'y_dalot': localData['y_dalot'],
      'nom': localData['nom'],
      'situation': localData['situation_dalot'],
      'enqueteur': localData['enqueteur'],
      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),
      'code_piste': localData['code_piste'],
      'code_gps': localData['code_gps'],
      'login_id': userId,
      'commune_id': localData['commune_id'],
    };
  }

  static Map<String, dynamic> _mapPassageSubmersibleToApi(Map<String, dynamic> localData) {
    String formatDateForPostgres(String? dateString) {
      if (dateString == null) return '';
      try {
        final date = DateTime.parse(dateString);
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString;
      }
    }

    return {
      'sqlite_id': localData['id'],
      'geom': {
        'type': 'LineString',
        'coordinates': [
          [
            localData['x_debut_passage_submersible'],
            localData['y_debut_passage_submersible']
          ],
          [
            localData['x_fin_passage_submersible'],
            localData['y_fin_passage_submersible']
          ],
        ]
      },
      'x_debut_pa': localData['x_debut_passage_submersible'],
      'y_debut_pa': localData['y_debut_passage_submersible'],
      'x_fin_pass': localData['x_fin_passage_submersible'],
      'y_fin_pass': localData['y_fin_passage_submersible'],
      'nom': localData['nom'],
      'type_mater': localData['type_materiau'],
      'enqueteur': localData['enqueteur'],
      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),
      'code_piste': localData['code_piste'],
      'code_gps': localData['code_gps'],
      'endroit': localData['endroit'],
      'login_id': userId,
      'commune_id': localData['commune_id'],
    };
  }

  static Map<String, dynamic> _mapPointCritiqueToApi(Map<String, dynamic> localData) {
    // Convertir la date au format PostgreSQL
    String formatDateForPostgres(String? dateString) {
      if (dateString == null || dateString.isEmpty) return '';
      try {
        final date = DateTime.parse(dateString);

        // Si l'heure est minuit (00:00:00), utiliser l'heure actuelle
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          // Sinon utiliser l'heure de la date
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString ?? '';
      }
    }

    // On choisit le type :
    // - si type_point_critique est "Non spécifié", on prend le champ générique "type"
    final String? typeSpecifique = localData['type_point_critique'];
    final String? typeGenerique = localData['type'];
    final String? typePoint = (typeSpecifique == null || typeSpecifique == 'Non spécifié') ? typeGenerique : typeSpecifique;

    return {
      // id SQLite local
      'sqlite_id': localData['id'],

      'x_point_cr': localData['x_point_critique'],
      'y_point_cr': localData['y_point_critique'],
      'type_point': typePoint,

      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),

      'code_gps': localData['code_gps'],
      'code_piste': localData['code_piste'],
      'commune_id': localData['commune_id'],

      'chaussee_id': localData['chaussee_id'] ?? null,

      'login_id': userId,
    };
  }

  static Map<String, dynamic> _mapPointCoupureToApi(Map<String, dynamic> localData) {
    // Convertir la date au format PostgreSQL
    String formatDateForPostgres(String? dateString) {
      if (dateString == null || dateString.isEmpty) return '';
      try {
        final date = DateTime.parse(dateString);

        // Si l'heure est minuit (00:00:00), utiliser l'heure actuelle
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          // Sinon utiliser l'heure de la date
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString ?? '';
      }
    }

    return {
      // id SQLite local
      'sqlite_id': localData['id'], //  "local_id", c'est bien "id" dans tes logs

      // Noms attendus par le backend
      'x_point_co': localData['x_point_coupure'],
      'y_point_co': localData['y_point_coupure'],
      'cause_coup': localData['causes_coupures'],

      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),

      'code_gps': localData['code_gps'],
      'commune_id': localData['commune_id'],
      'code_piste': localData['code_piste'],
      'chaussee_id': localData['chaussee_id'] ?? null,

      'login_id': userId,
    };
  }

  /// Formate une date en YYYY-MM-DD uniquement
  static String? _formatDateOnly(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str == 'null') return null;
    try {
      final date = DateTime.parse(str);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(str)) return str;
      return null;
    }
  }

  static Map<String, dynamic> _mapSiteEnqueteToApi(Map<String, dynamic> localData) {
    String formatDateForPostgres(String? dateString) {
      if (dateString == null || dateString.isEmpty) return '';
      try {
        final date = DateTime.parse(dateString);
        if (date.hour == 0 && date.minute == 0 && date.second == 0) {
          final now = DateTime.now();
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        } else {
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        return dateString ?? '';
      }
    }

    return {
      'sqlite_id': localData['id'],
      'x_site': localData['x_site'],
      'y_site': localData['y_site'],
      'nom': localData['nom'],
      'type': localData['type'],
      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),
      'code_gps': localData['code_gps'],
      'code_piste': localData['code_piste'],
      'login_id': userId,
      'commune_id': localData['commune_id'],
      // 9 champs ex-ppr_itial
      'amenage_ou_non_amenage': localData['amenage_ou_non_amenage'] == 1 ? true : (localData['amenage_ou_non_amenage'] == 0 ? false : null),
      'entreprise': localData['entreprise'],
      'financement': localData['financement'],
      'projet': localData['projet'],
      'superficie_digitalisee': localData['superficie_digitalisee'],
      'superficie_estimee_lors_des_enquetes_ha': localData['superficie_estimee_lors_des_enquetes_ha'],
      'travaux_debut': _formatDateOnly(localData['travaux_debut']),
      'travaux_fin': _formatDateOnly(localData['travaux_fin']),
      'type_de_realisation': localData['type_de_realisation'],
    };
  }

  static Map<String, dynamic> _mapEnquetePolygoneToApi(Map<String, dynamic> localData) {
    String formatDateForPostgres(String? dateString) {
      if (dateString == null || dateString.isEmpty) return '';
      try {
        final date = DateTime.parse(dateString);
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
      } catch (e) {
        return dateString ?? '';
      }
    }

    List<dynamic> coordinates = [];
    if (localData['points_json'] != null) {
      try {
        coordinates = jsonDecode(localData['points_json']);
      } catch (e) {
        print('❌ Error decoding points_json: $e');
      }
    }

    return {
      'sqlite_id': localData['id'],
      'geom': {
        'type': 'Polygon',
        'coordinates': [
          coordinates
        ] // Le serializer convertira en MultiPolygon
      },
      'nom': localData['nom'],
      'superficie_en_ha': localData['superficie_en_ha'],
      'created_at': formatDateForPostgres(localData['date_creation']),
      'updated_at': formatDateForPostgres(localData['date_modification']),
      'code_piste': localData['code_piste'],
      'code_gps': localData['code_gps'],
      'login_id': userId,
      'communes_rurales_id': localData['commune_id'],
    };
  }

  // ============ MÉTHODES GET POUR TÉLÉCHARGER LES DONNÉES ============

  /// Méthode générique pour récupérer des données
  static Future<List<dynamic>> fetchData(String endpoint) async {
    final url = Uri.parse('$baseUrl/api/$endpoint/?login_id=$userId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 30)); //  timeout GET

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['features'];
      } else {
        print('❌ Erreur GET ($endpoint): ${response.statusCode} - ${response.body}');
        throw Exception('Erreur GET ($endpoint): ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      throw Exception('Timeout GET $endpoint');
    } on SocketException catch (e) {
      throw Exception('Erreur réseau GET $endpoint');
    } catch (e) {
      throw Exception('Erreur inconnue GET $endpoint: $e');
    }
  }

  /// Méthodes spécifiques pour chaque type de données
  static Future<List<dynamic>> fetchLocalites() async {
    return await fetchData('localites');
  }

  static Future<List<dynamic>> fetchEcoles() async {
    return await fetchData('ecoles');
  }

  static Future<List<dynamic>> fetchMarches() async {
    return await fetchData('marches');
  }

  static Future<List<dynamic>> fetchServicesSantes() async {
    return await fetchData('services_santes');
  }

  static Future<List<dynamic>> fetchBatimentsAdministratifs() async {
    return await fetchData('batiments_administratifs');
  }

  static Future<List<dynamic>> fetchInfrastructuresHydrauliques() async {
    return await fetchData('infrastructures_hydrauliques');
  }

  static Future<List<dynamic>> fetchAutresInfrastructures() async {
    return await fetchData('autres_infrastructures');
  }

  static Future<List<dynamic>> fetchPonts() async {
    return await fetchData('ponts');
  }

  static Future<List<dynamic>> fetchBacs() async {
    return await fetchData('bacs');
  }

  static Future<List<dynamic>> fetchBuses() async {
    return await fetchData('buses');
  }

  static Future<List<dynamic>> fetchDalots() async {
    return await fetchData('dalots');
  }

  static Future<List<dynamic>> fetchPassagesSubmersibles() async {
    return await fetchData('passages_submersibles');
  }

  static Future<List<dynamic>> fetchPointsCritiques() async {
    return await fetchData('points_critiques');
  }

  static Future<List<dynamic>> fetchPointsCoupures() async {
    return await fetchData('points_coupures');
  }

  static Future<List<dynamic>> fetchSiteEnquetes() async {
    return await fetchData('site_enquete');
  }

  static Future<List<dynamic>> fetchEnquetePolygones() async {
    return await fetchData('enquete_polygone');
  }

  /// Méthode pour extraire les données du GeoJSON
  static Map<String, dynamic> extractFromGeoJson(Map<String, dynamic> geoJson) {
    return {
      'properties': geoJson['properties'],
      'geometry': geoJson['geometry'],
      'id': geoJson['id'],
    };
  }

  static Future<List<dynamic>> fetchChausseesTest() async {
    final url = Uri.parse('$baseUrl/api/chaussees/?login_id=$userId');
    print('🌐 Téléchargement chaussées pour login_id: $userId (RBAC)');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        return data['features'];
      } else {
        print('❌ Erreur GET (chaussees): ${response.statusCode} - ${response.body}');
        throw Exception('Erreur GET (chaussees): ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('⏰ Timeout lors du GET chaussees: $e');
      throw Exception('Timeout GET chaussees');
    } on SocketException catch (e) {
      print('📡 Erreur réseau lors du GET chaussees: $e');
      throw Exception('Erreur réseau GET chaussees');
    } catch (e) {
      print('❌ Exception lors de la récupération des chaussees: $e');
      throw Exception('Erreur inconnue GET chaussees: $e');
    }
  }

  // Dans ApiService, ajouter cette méthode
  static Future<List<dynamic>> fetchPistes() async {
    final url = Uri.parse('$baseUrl/api/pistes/?login_id=$userId');
    print('🌐 Téléchargement pistes pour login_id: $userId (RBAC)');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('✅ ${data['features']?.length ?? 0} pistes récupérées');
        return data['features'];
      } else {
        print('❌ Erreur GET (pistes): ${response.statusCode} - ${response.body}');
        throw Exception('Erreur GET (pistes): ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('⏰ Timeout lors du GET pistes: $e');
      throw Exception('Timeout GET pistes');
    } on SocketException catch (e) {
      print('📡 Erreur réseau lors du GET pistes: $e');
      throw Exception('Erreur réseau GET pistes');
    } catch (e) {
      print('❌ Exception lors de la récupération des pistes: $e');
      throw Exception('Erreur inconnue GET pistes: $e');
    }
  }
}
