class Bac {
  final int? id;
  final double xDebutTraverseeBac;
  final double yDebutTraverseeBac;
  final double xFinTraverseeBac;
  final double yFinTraverseeBac;
  final String typeBac;
  final String nomCoursEau;
  final String enqueteur;
  final String dateCreation;
  final String? dateModification;
  final String? codePiste;
  final String? codeGps;
  final int? communeId;

  Bac({
    this.id,
    required this.xDebutTraverseeBac,
    required this.yDebutTraverseeBac,
    required this.xFinTraverseeBac,
    required this.yFinTraverseeBac,
    required this.typeBac,
    required this.nomCoursEau,
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
      'x_debut_traversee_bac': xDebutTraverseeBac,
      'y_debut_traversee_bac': yDebutTraverseeBac,
      'x_fin_traversee_bac': xFinTraverseeBac,
      'y_fin_traversee_bac': yFinTraverseeBac,
      'type_bac': typeBac,
      'nom_cours_eau': nomCoursEau,
      'enqueteur': enqueteur,
      'date_creation': dateCreation,
      'date_modification': dateModification,
      'code_piste': codePiste,
      'code_gps': codeGps,
      'commune_id': communeId,
    };
  }

  factory Bac.fromMap(Map<String, dynamic> map) {
    return Bac(
      id: map['id'],
      xDebutTraverseeBac: map['x_debut_traversee_bac'],
      yDebutTraverseeBac: map['y_debut_traversee_bac'],
      xFinTraverseeBac: map['x_fin_traversee_bac'],
      yFinTraverseeBac: map['y_fin_traversee_bac'],
      typeBac: map['type_bac'],
      nomCoursEau: map['nom_cours_eau'],
      enqueteur: map['enqueteur'],
      dateCreation: map['date_creation'],
      dateModification: map['date_modification'],
      codePiste: map['code_piste'],
      codeGps: map['code_gps'],
      communeId: map['commune_id'],
    );
  }
}
