class PassageSubmersible {
  final int? id;
  final double xDebutPassageSubmersible;
  final double yDebutPassageSubmersible;
  final double xFinPassageSubmersible;
  final double yFinPassageSubmersible;
  final String typeMateriau;
  final String enqueteur;
  final String dateCreation;
  final String? dateModification;
  final String? codePiste;
  final String? codeGps;
  final int? communeId;

  PassageSubmersible({
    this.id,
    required this.xDebutPassageSubmersible,
    required this.yDebutPassageSubmersible,
    required this.xFinPassageSubmersible,
    required this.yFinPassageSubmersible,
    required this.typeMateriau,
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
      'x_debut_passage_submersible': xDebutPassageSubmersible,
      'y_debut_passage_submersible': yDebutPassageSubmersible,
      'x_fin_passage_submersible': xFinPassageSubmersible,
      'y_fin_passage_submersible': yFinPassageSubmersible,
      'type_materiau': typeMateriau,
      'enqueteur': enqueteur,
      'date_creation': dateCreation,
      'date_modification': dateModification,
      'code_piste': codePiste,
      'code_gps': codeGps,
      'commune_id': communeId,
    };
  }

  factory PassageSubmersible.fromMap(Map<String, dynamic> map) {
    return PassageSubmersible(
      id: map['id'],
      xDebutPassageSubmersible: map['x_debut_passage_submersible'],
      yDebutPassageSubmersible: map['y_debut_passage_submersible'],
      xFinPassageSubmersible: map['x_fin_passage_submersible'],
      yFinPassageSubmersible: map['y_fin_passage_submersible'],
      typeMateriau: map['type_materiau'],
      enqueteur: map['enqueteur'],
      dateCreation: map['date_creation'],
      dateModification: map['date_modification'],
      codePiste: map['code_piste'],
      codeGps: map['code_gps'],
      communeId: map['commune_id'],
    );
  }
}
