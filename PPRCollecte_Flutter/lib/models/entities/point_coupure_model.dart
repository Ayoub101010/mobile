class PointCoupure {
  final int? id;
  final double xPointCoupure;
  final double yPointCoupure;
  final String causesCoupures;
  final String enqueteur;
  final String dateCreation;
  final String? dateModification;
  final String? codePiste;
  final String? codeGps;
  final int? communeId;

  PointCoupure({
    this.id,
    required this.xPointCoupure,
    required this.yPointCoupure,
    required this.causesCoupures,
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
      'x_point_coupure': xPointCoupure,
      'y_point_coupure': yPointCoupure,
      'causes_coupures': causesCoupures,
      'enqueteur': enqueteur,
      'date_creation': dateCreation,
      'date_modification': dateModification,
      'code_piste': codePiste,
      'code_gps': codeGps,
      'commune_id': communeId,
    };
  }

  factory PointCoupure.fromMap(Map<String, dynamic> map) {
    return PointCoupure(
      id: map['id'],
      xPointCoupure: map['x_point_coupure'],
      yPointCoupure: map['y_point_coupure'],
      causesCoupures: map['causes_coupures'],
      enqueteur: map['enqueteur'],
      dateCreation: map['date_creation'],
      dateModification: map['date_modification'],
      codePiste: map['code_piste'],
      codeGps: map['code_gps'],
      communeId: map['commune_id'],
    );
  }
}
