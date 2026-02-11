class AutreInfrastructure {
  final int? id;
  final double xAutreInfrastructure;
  final double yAutreInfrastructure;
  final String nom;
  final String type;
  final String enqueteur;
  final String dateCreation;
  final String? dateModification;
  final String? codePiste;
  final String? codeGps;
  final int? communeId;

  AutreInfrastructure({
    this.id,
    required this.xAutreInfrastructure,
    required this.yAutreInfrastructure,
    required this.nom,
    required this.type,
    required this.enqueteur,
    required this.dateCreation,
    this.dateModification,
    this.codePiste,
    this.codeGps,
    this.communeId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'x_autre_infrastructure': xAutreInfrastructure,
      'y_autre_infrastructure': yAutreInfrastructure,
      'nom': nom,
      'type': type,
      'enqueteur': enqueteur,
      'date_creation': dateCreation,
      'date_modification': dateModification,
      'code_piste': codePiste,
      'code_gps': codeGps,
      'commune_id': communeId,
    };
  }

  factory AutreInfrastructure.fromMap(Map<String, dynamic> map) {
    return AutreInfrastructure(
      id: map['id'],
      xAutreInfrastructure: map['x_autre_infrastructure'],
      yAutreInfrastructure: map['y_autre_infrastructure'],
      nom: map['nom'],
      type: map['type'],
      enqueteur: map['enqueteur'],
      dateCreation: map['date_creation'],
      dateModification: map['date_modification'],
      codePiste: map['code_piste'],
      codeGps: map['code_gps'],
      communeId: map['commune_id'],
    );
  }
}
