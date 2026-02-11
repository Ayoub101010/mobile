// lib/chaussee_model.dart
import 'dart:convert';
import '../../data/remote/api_service.dart';

int generateTimestampChaussId() {
  final now = DateTime.now();
  final idString = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';

  return int.parse(idString);
}

class ChausseeModel {
  final int? id;
  final String codePiste;
  final String codeGps;
  final String endroit;
  final String? typeChaussee;
  final String? etatPiste;
  final double xDebutChaussee;
  final double yDebutChaussee;
  final double xFinChaussee;
  final double yFinChaussee;
  final String pointsJson;
  final double distanceTotaleM;
  final int nombrePoints;
  final String createdAt;
  final String? updatedAt; // ← NOUVEAU
  final String userLogin; // ← NOUVEAU
  final int? communesRuralesId;
  ChausseeModel({
    int? id,
    required this.codePiste,
    required this.codeGps,
    required this.endroit,
    this.typeChaussee,
    this.etatPiste,
    required this.xDebutChaussee,
    required this.yDebutChaussee,
    required this.xFinChaussee,
    required this.yFinChaussee,
    required this.pointsJson,
    required this.distanceTotaleM,
    required this.nombrePoints,
    required this.createdAt,
    this.updatedAt, // ← NOUVEAU
    required this.userLogin,
    this.communesRuralesId, // ← NOUVEAU
  }) : id = id ?? generateTimestampChaussId();

  factory ChausseeModel.fromFormData(Map<String, dynamic> formData) {
    final pointsData = formData['points_collectes'] as List<dynamic>? ?? [];
    final pointsJson = jsonEncode(pointsData);

    return ChausseeModel(
      id: formData['id'] ?? generateTimestampChaussId(),
      codePiste: formData['code_piste'] ?? '',
      codeGps: formData['code_gps'] ?? '',
      endroit: formData['endroit'] ?? '',
      typeChaussee: formData['type_chaussee'],
      etatPiste: formData['etat_piste'],
      xDebutChaussee: _parseDouble(formData['x_debut_chaussee']),
      yDebutChaussee: _parseDouble(formData['y_debut_chaussee']),
      xFinChaussee: _parseDouble(formData['x_fin_chaussee']),
      yFinChaussee: _parseDouble(formData['y_fin_chaussee']),
      pointsJson: pointsJson,
      distanceTotaleM: _parseDouble(formData['distance_totale_m']),
      nombrePoints: formData['nombre_points'] ?? 0,
      createdAt: formData['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: formData['updated_at'], // ← NOUVEAU
      userLogin: formData['user_login'] ?? '',
      communesRuralesId: formData['communes_rurales_id'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code_piste': codePiste,
      'code_gps': codeGps,
      'endroit': endroit,
      'type_chaussee': typeChaussee,
      'etat_piste': etatPiste,
      'x_debut_chaussee': xDebutChaussee,
      'y_debut_chaussee': yDebutChaussee,
      'x_fin_chaussee': xFinChaussee,
      'y_fin_chaussee': yFinChaussee,
      'points_json': pointsJson,
      'distance_totale_m': distanceTotaleM,
      'nombre_points': nombrePoints,
      'created_at': createdAt,
      'updated_at': updatedAt, // ← NOUVEAU
      'user_login': userLogin,
      'login_id': ApiService.userId, // ← NOUVEAU
      'communes_rurales_id': communesRuralesId,
    };
  }

  factory ChausseeModel.fromMap(Map<String, dynamic> map) {
    return ChausseeModel(
      id: map['id'],
      codePiste: map['code_piste'] ?? '',
      codeGps: map['code_gps'] ?? '',
      endroit: map['endroit'] ?? '',
      typeChaussee: map['type_chaussee'],
      etatPiste: map['etat_piste'],
      xDebutChaussee: _parseDouble(map['x_debut_chaussee']),
      yDebutChaussee: _parseDouble(map['y_debut_chaussee']),
      xFinChaussee: _parseDouble(map['x_fin_chaussee']),
      yFinChaussee: _parseDouble(map['y_fin_chaussee']),
      pointsJson: map['points_json'] ?? '[]',
      distanceTotaleM: _parseDouble(map['distance_totale_m']),
      nombrePoints: map['nombre_points'] ?? 0,
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
      userLogin: map['user_login'] ?? '',
      communesRuralesId: map['communes_rurales_id'] ?? '',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }
}
