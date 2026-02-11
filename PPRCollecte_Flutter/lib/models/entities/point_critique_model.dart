class PointCritique {
  final int? id;
  final double xPointCritique;
  final double yPointCritique;
  final String typePointCritique;
  final String enqueteur;
  final String dateCreation;
  final String? dateModification;
  final String? codePiste;
  final String? codeGps;
  final int? communeId;

  PointCritique({
    this.id,
    required this.xPointCritique,
    required this.yPointCritique,
    required this.typePointCritique,
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
      'x_point_critique': xPointCritique,
      'y_point_critique': yPointCritique,
      'type_point_critique': typePointCritique,
      'enqueteur': enqueteur,
      'date_creation': dateCreation,
      'date_modification': dateModification,
      'code_piste': codePiste,
      'code_gps': codeGps,
      'commune_id': communeId,
    };
  }

  factory PointCritique.fromMap(Map<String, dynamic> map) {
    return PointCritique(
      id: map['id'],
      xPointCritique: map['x_point_critique'],
      yPointCritique: map['y_point_critique'],
      typePointCritique: map['type_point_critique'],
      enqueteur: map['enqueteur'],
      dateCreation: map['date_creation'],
      dateModification: map['date_modification'],
      codePiste: map['code_piste'],
      codeGps: map['code_gps'],
      communeId: map['commune_id'],
    );
  }
}
