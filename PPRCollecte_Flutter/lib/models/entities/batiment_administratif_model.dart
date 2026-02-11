class BatimentAdministratif {
  final int? id;
  final double xBatimentAdministratif;
  final double yBatimentAdministratif;
  final String nom;
  final String type;
  final String enqueteur;
  final String dateCreation;
  final String? dateModification;
  final String? codePiste;
  final String? codeGps;
  final int? communeId;

  BatimentAdministratif({
    this.id,
    required this.xBatimentAdministratif,
    required this.yBatimentAdministratif,
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
      'x_batiment_administratif': xBatimentAdministratif,
      'y_batiment_administratif': yBatimentAdministratif,
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

  factory BatimentAdministratif.fromMap(Map<String, dynamic> map) {
    return BatimentAdministratif(
      id: map['id'],
      xBatimentAdministratif: map['x_batiment_administratif'],
      yBatimentAdministratif: map['y_batiment_administratif'],
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
