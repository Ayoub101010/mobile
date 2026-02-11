class Localite {
  final int? id;
  final double xLocalite;
  final double yLocalite;
  final String nom;
  final String type;
  final String enqueteur;
  final String dateCreation;
  final String? dateModification;
  final String? codeGps;
  int? synced;
  final int? communeId;

  Localite({
    this.id,
    required this.xLocalite,
    required this.yLocalite,
    required this.nom,
    required this.type,
    required this.enqueteur,
    this.dateCreation = '',
    this.dateModification,
    this.synced = 0,
    this.codeGps,
    this.communeId,
  });

  // Conversion vers Map (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'x_localite': xLocalite,
      'y_localite': yLocalite,
      'nom': nom,
      'type': type,
      'enqueteur': enqueteur,
      'date_creation': dateCreation.isEmpty ? DateTime.now().toIso8601String() : dateCreation,
      'date_modification': dateModification,
      'synced': synced,
      'commune_id': communeId,
      'code_gps': codeGps,
    };
  }

  // Conversion depuis Map (SQLite)
  factory Localite.fromMap(Map<String, dynamic> map) {
    return Localite(
      id: map['id'],
      xLocalite: map['x_localite'],
      yLocalite: map['y_localite'],
      nom: map['nom'],
      type: map['type'],
      enqueteur: map['enqueteur'],
      dateCreation: map['date_creation'],
      dateModification: map['date_modification'],
      synced: map['synced'] != null ? (map['synced'] as num).toInt() : 0,
      communeId: map['commune_id'],
      codeGps: map['code_gps'],
    ); // valeur par défaut;
  }

  // Conversion vers JSON (string)
  Map<String, dynamic> toJson() => {
        'id': id,
        'x_localite': xLocalite,
        'y_localite': yLocalite,
        'nom': nom,
        'type': type,
        'enqueteur': enqueteur,
        'date_creation': dateCreation.isEmpty ? DateTime.now().toIso8601String() : dateCreation,
        'synced': synced,
      };

  // Conversion depuis JSON
  factory Localite.fromJson(Map<String, dynamic> json) => Localite(
        id: json['id'],
        xLocalite: (json['x_localite'] as num).toDouble(),
        yLocalite: (json['y_localite'] as num).toDouble(),
        nom: json['nom'],
        type: json['type'],
        enqueteur: json['enqueteur'],
        dateCreation: json['date_creation'],
        synced: json['synced'] != null ? json['synced'] as int : 0,
      );
}
