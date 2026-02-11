class InfrastructureHydraulique {
  final int? id;
  final double xInfrastructureHydraulique;
  final double yInfrastructureHydraulique;
  final String nom;
  final String type;
  final String enqueteur;
  final String dateCreation;
  final String? dateModification;
  final String? codePiste;
  final String? codeGps;
  final int? communeId;

  InfrastructureHydraulique({
    this.id,
    required this.xInfrastructureHydraulique,
    required this.yInfrastructureHydraulique,
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
      'x_infrastructure_hydraulique': xInfrastructureHydraulique,
      'y_infrastructure_hydraulique': yInfrastructureHydraulique,
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

  factory InfrastructureHydraulique.fromMap(Map<String, dynamic> map) {
    return InfrastructureHydraulique(
      id: map['id'],
      xInfrastructureHydraulique: map['x_infrastructure_hydraulique'],
      yInfrastructureHydraulique: map['y_infrastructure_hydraulique'],
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
