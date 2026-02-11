// pont_model.dart
class Pont {
  final int? id;
  final double xPont;
  final double yPont;
  final String situationPont;
  final String typePont;
  final String nomCoursEau;
  final String enqueteur;
  final String dateCreation;
  final String? dateModification;
  final String? codePiste;
  final String? codeGps;
  final int? communeId;

  Pont({
    this.id,
    required this.xPont,
    required this.yPont,
    required this.situationPont,
    required this.typePont,
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
      'x_pont': xPont,
      'y_pont': yPont,
      'situation_pont': situationPont,
      'type_pont': typePont,
      'nom_cours_eau': nomCoursEau,
      'enqueteur': enqueteur,
      'date_creation': dateCreation,
      'date_modification': dateModification,
      'code_piste': codePiste,
      'code_gps': codeGps,
      'commune_id': communeId,
    };
  }

  factory Pont.fromMap(Map<String, dynamic> map) {
    return Pont(
      id: map['id'],
      xPont: map['x_pont'],
      yPont: map['y_pont'],
      situationPont: map['situation_pont'],
      typePont: map['type_pont'],
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
