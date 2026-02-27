// lib/piste_model.dart
import 'dart:convert';

int generateTimestampId() {
  final now = DateTime.now();
  final idString = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';

  return int.parse(idString);
}

String generateCodePiste() {
  final now = DateTime.now();
  final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';

  return 'Piste_$timestamp';
}

class PisteModel {
  final int? id;
  final String codePiste;
  final String? communeRuraleId;
  final int? communeRurales;
  final String userLogin;
  final String heureDebut;
  final String heureFin;
  final String nomOriginePiste;
  final double xOrigine;
  final double yOrigine;
  final String nomDestinationPiste;
  final double xDestination;
  final double yDestination;
  final String? typeOccupation;
  final String? debutOccupation;
  final String? finOccupation;
  final double? largeurEmprise;
  final String? frequenceTrafic;
  final String? typeTrafic;
  final String? travauxRealises;
  final String? dateTravaux;
  final String? entreprise;
  final String pointsJson;
  final String createdAt;
  final String? updatedAt;
  final bool existenceIntersection;
  final int nombreIntersections;
  final String intersectionsJson; // JSON string : "[{piste_id, code_piste, x, y}, ...]"
  final int? loginId;
  final String? plateforme;
  final String? relief;
  final String? vegetation;
  final String? debutTravaux;
  final String? finTravaux;
  final String? financement;
  final String? projet;
  final double? niveauService;
  final double? fonctionnalite;
  final double? interetSocioAdministratif;
  final double? populationDesservie;
  final double? potentielAgricole;
  final double? coutInvestissement;
  final double? protectionEnvironnement;
  final double? noteGlobale;

  PisteModel({
    int? id,
    String? codePiste,
    this.communeRuraleId,
    this.communeRurales,
    required this.userLogin,
    required this.heureDebut,
    required this.heureFin,
    required this.nomOriginePiste,
    required this.xOrigine,
    required this.yOrigine,
    required this.nomDestinationPiste,
    required this.xDestination,
    required this.yDestination,
    this.typeOccupation,
    this.debutOccupation,
    this.finOccupation,
    this.largeurEmprise,
    this.frequenceTrafic,
    this.typeTrafic,
    this.travauxRealises,
    this.dateTravaux,
    this.entreprise,
    required this.pointsJson,
    required this.createdAt,
    required this.updatedAt,
    this.existenceIntersection = false,
    this.nombreIntersections = 0,
    this.intersectionsJson = '[]',
    this.loginId,
    this.plateforme,
    this.relief,
    this.vegetation,
    this.debutTravaux,
    this.finTravaux,
    this.financement,
    this.projet,
    this.niveauService,
    this.fonctionnalite,
    this.interetSocioAdministratif,
    this.populationDesservie,
    this.potentielAgricole,
    this.coutInvestissement,
    this.protectionEnvironnement,
    this.noteGlobale,
  })  : id = id ?? generateTimestampId(),
        codePiste = codePiste ?? generateCodePiste();

  factory PisteModel.fromFormData(Map<String, dynamic> formData) {
    final pointsData = formData['points'] as List<dynamic>? ?? [];
    final pointsJson = jsonEncode(pointsData);

    return PisteModel(
      id: formData['id'] ?? generateTimestampId(),
      codePiste: formData['code_piste'] ?? generateCodePiste(),
      communeRuraleId: formData['commune_rurale_id'],
      communeRurales: formData['commune_rurales'],
      userLogin: formData['user_login'] ?? '',
      heureDebut: formData['heure_debut'] ?? '',
      heureFin: formData['heure_fin'] ?? '',
      nomOriginePiste: formData['nom_origine_piste'] ?? '',
      xOrigine: _parseDouble(formData['x_origine']),
      yOrigine: _parseDouble(formData['y_origine']),
      nomDestinationPiste: formData['nom_destination_piste'] ?? '',
      xDestination: _parseDouble(formData['x_destination']),
      yDestination: _parseDouble(formData['y_destination']),
      typeOccupation: formData['type_occupation'],
      debutOccupation: formData['debut_occupation'],
      finOccupation: formData['fin_occupation'],
      largeurEmprise: formData['largeur_emprise'],
      frequenceTrafic: formData['frequence_trafic'],
      typeTrafic: formData['type_trafic'],
      travauxRealises: formData['travaux_realises'],
      dateTravaux: formData['date_travaux'],
      entreprise: formData['entreprise'],
      pointsJson: pointsJson,
      createdAt: formData['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: formData['updated_at'],
      existenceIntersection: _parseBool(formData['existence_intersection']),
      nombreIntersections: _parseInt(formData['nombre_intersections']),
      intersectionsJson: formData['intersections_json'] is String ? formData['intersections_json'] : jsonEncode(formData['intersections_json'] ?? []),
      loginId: formData['login_id'],
      plateforme: formData['plateforme'],
      relief: formData['relief'],
      vegetation: formData['vegetation'],
      debutTravaux: formData['debut_travaux'],
      finTravaux: formData['fin_travaux'],
      financement: formData['financement'],
      projet: formData['projet'],
      niveauService: _parseDouble(formData['niveau_service']),
      fonctionnalite: _parseDouble(formData['fonctionnalite']),
      interetSocioAdministratif: _parseDouble(formData['interet_socio_administratif']),
      populationDesservie: _parseDouble(formData['population_desservie']),
      potentielAgricole: _parseDouble(formData['potentiel_agricole']),
      coutInvestissement: _parseDouble(formData['cout_investissement']),
      protectionEnvironnement: _parseDouble(formData['protection_environnement']),
      noteGlobale: _parseDouble(formData['note_globale']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code_piste': codePiste,
      'commune_rurale_id': communeRuraleId,
      'commune_rurales': communeRurales,
      'user_login': userLogin,
      'heure_debut': heureDebut,
      'heure_fin': heureFin,
      'nom_origine_piste': nomOriginePiste,
      'x_origine': xOrigine,
      'y_origine': yOrigine,
      'nom_destination_piste': nomDestinationPiste,
      'x_destination': xDestination,
      'y_destination': yDestination,
      'type_occupation': typeOccupation,
      'debut_occupation': debutOccupation,
      'fin_occupation': finOccupation,
      'largeur_emprise': largeurEmprise,
      'frequence_trafic': frequenceTrafic,
      'type_trafic': typeTrafic,
      'travaux_realises': travauxRealises,
      'date_travaux': dateTravaux,
      'entreprise': entreprise,
      'points_json': pointsJson,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'existence_intersection': existenceIntersection ? 1 : 0,
      'nombre_intersections': nombreIntersections,
      'intersections_json': intersectionsJson,
      'login_id': loginId,
      'plateforme': plateforme,
      'relief': relief,
      'vegetation': vegetation,
      'debut_travaux': debutTravaux,
      'fin_travaux': finTravaux,
      'financement': financement,
      'projet': projet,
      'niveau_service': niveauService,
      'fonctionnalite': fonctionnalite,
      'interet_socio_administratif': interetSocioAdministratif,
      'population_desservie': populationDesservie,
      'potentiel_agricole': potentielAgricole,
      'cout_investissement': coutInvestissement,
      'protection_environnement': protectionEnvironnement,
      'note_globale': noteGlobale,
    };
  }

  factory PisteModel.fromMap(Map<String, dynamic> map) {
    return PisteModel(
      id: map['id'],
      codePiste: map['code_piste'] ?? '',
      communeRuraleId: map['commune_rurale_id'],
      userLogin: map['user_login'] ?? '',
      heureDebut: map['heure_debut'] ?? '',
      heureFin: map['heure_fin'] ?? '',
      nomOriginePiste: map['nom_origine_piste'] ?? '',
      xOrigine: _parseDouble(map['x_origine']),
      yOrigine: _parseDouble(map['y_origine']),
      nomDestinationPiste: map['nom_destination_piste'] ?? '',
      xDestination: _parseDouble(map['x_destination']),
      yDestination: _parseDouble(map['y_destination']),
      typeOccupation: map['type_occupation'],
      debutOccupation: map['debut_occupation'],
      finOccupation: map['fin_occupation'],
      largeurEmprise: _parseDouble(map['largeur_emprise']),
      frequenceTrafic: map['frequence_trafic'],
      typeTrafic: map['type_trafic'],
      travauxRealises: map['travaux_realises'],
      dateTravaux: map['date_travaux'],
      entreprise: map['entreprise'],
      pointsJson: map['points_json'] ?? '[]',
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(), // ← NOUVEAU
      existenceIntersection: _parseBool(map['existence_intersection']),
      nombreIntersections: _parseInt(map['nombre_intersections']),
      intersectionsJson: map['intersections_json']?.toString() ?? '[]',
      loginId: map['login_id'],
      plateforme: map['plateforme'],
      relief: map['relief'],
      vegetation: map['vegetation'],
      debutTravaux: map['debut_travaux'],
      finTravaux: map['fin_travaux'],
      financement: map['financement'],
      projet: map['projet'],
      niveauService: _parseDouble(map['niveau_service']),
      fonctionnalite: _parseDouble(map['fonctionnalite']),
      interetSocioAdministratif: _parseDouble(map['interet_socio_administratif']),
      populationDesservie: _parseDouble(map['population_desservie']),
      potentielAgricole: _parseDouble(map['potentiel_agricole']),
      coutInvestissement: _parseDouble(map['cout_investissement']),
      protectionEnvironnement: _parseDouble(map['protection_environnement']),
      noteGlobale: _parseDouble(map['note_globale']),
    );
  }
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  /// Retourne la liste des intersections parsées depuis le JSON
  List<Map<String, dynamic>> get intersections {
    try {
      final decoded = jsonDecode(intersectionsJson);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
