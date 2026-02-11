class Ecole {
  final int? id;
  final double xEcole;
  final double yEcole;
  final String nom;
  final String type;
  final String enqueteur;
  final String dateCreation;
  final String? dateModification;
  final String? codePiste;
  final String? codeGps;
  final int? communeId;

  Ecole({
    this.id,
    required this.xEcole,
    required this.yEcole,
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
      'x_ecole': xEcole,
      'y_ecole': yEcole,
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

  factory Ecole.fromMap(Map<String, dynamic> map) {
    return Ecole(
      id: map['id'],
      xEcole: map['x_ecole'],
      yEcole: map['y_ecole'],
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
