// lib/infrastructure_config.dart
class InfrastructureConfig {
  static const Map<String, Map<String, dynamic>> config = {
    "Infrastructures Rurales": {
      "icon": "location_city",
      "color": 0xFF4CAF50,
      "entities": {
        "Localité": {
          "tableName": "localites",
          "fields": [
            "code_piste",
            "code_gps",
            "x_localite",
            "y_localite",
            "nom",
            "type",
            "date_creation",
            "date_modification",
            "enqueteur"
          ],
          "typeOptions": [
            "village",
            "chef-lieu de district",
            "chef-lieu de préfecture",
            "ville",
            "autre"
          ]
        },
        "École": {
          "tableName": "ecoles",
          "fields": [
            "code_piste",
            "code_gps",
            "x_ecole",
            "y_ecole",
            "nom",
            "type",
            "date_creation",
            "date_modification",
            "enqueteur"
          ],
          "typeOptions": [
            "primaire",
            "secondaire",
            "universitaire"
          ]
        },
        "Marché": {
          "tableName": "marches",
          "fields": [
            "code_piste",
            "code_gps",
            "x_marche",
            "y_marche",
            "nom",
            "type",
            "date_creation",
            "date_modification",
            "enqueteur"
          ],
          "typeOptions": [
            "quotidien",
            "hebdomadaire"
          ]
        },
        "Service de Santé": {
          "tableName": "services_santes",
          "fields": [
            "code_piste",
            "code_gps",
            "x_sante",
            "y_sante",
            "nom",
            "type",
            "date_creation",
            "date_modification",
            "enqueteur"
          ],
          "typeOptions": [
            "dispensaire",
            "centre de santé",
            "hôpital"
          ]
        },
        "Bâtiment Administratif": {
          "tableName": "batiments_administratifs",
          "fields": [
            "code_piste",
            "code_gps",
            "x_batiment_administratif",
            "y_batiment_administratif",
            "nom",
            "type",
            "date_creation",
            "date_modification",
            "enqueteur"
          ],
          "typeOptions": [
            "mairie",
            "poste de police",
            "bureau de poste",
            "autre"
          ]
        },
        "Infrastructure Hydraulique": {
          "tableName": "infrastructures_hydrauliques",
          "fields": [
            "code_piste",
            "code_gps",
            "x_infrastructure_hydraulique",
            "y_infrastructure_hydraulique_2",
            "nom",
            "type",
            "date_creation",
            "date_modification",
            "enqueteur"
          ],
          "typeOptions": [
            "forage",
            "source améliorée",
            "autre"
          ]
        },
        "Autre Infrastructure": {
          "tableName": "autres_infrastructures",
          "fields": [
            "code_piste",
            "code_gps",
            "x_autre_infrastructure",
            "y_autre_infrastructure",
            "nom",
            "type",
            "date_creation",
            "date_modification",
            "enqueteur"
          ],
          "typeOptions": [
            "Église",
            "Mosquée",
            "Terrain de foot",
            "Cimetière",
            "Antenne orange",
            "Centre d'alphabétisation",
            "Magasin de stockage",
            "Maison des jeunes",
            "Étang"
          ]
        }
      }
    },
    "Ouvrages": {
      "icon": "construction",
      "color": 0xFFFF9800,
      "entities": {
        "Pont": {
          "tableName": "ponts",
          "fields": [
            "code_piste",
            "code_gps",
            "x_pont",
            "y_pont",
            "situation_pont",
            "type_pont",
            "nom_cours_eau",
            "date_creation",
            "date_modification",
            "enqueteur"
          ],
          "situationOptions": [
            "à réaliser",
            "en cours de réalisation",
            "existant",
            "ancien",
            "nouveau",
            "nouveau (1ans)"
          ],
          "typePontOptions": [
            "béton",
            "bois",
            "métallique",
            "autre"
          ]
        },
        "Bac": {
          "tableName": "bacs",
          "fields": [
            "code_piste",
            "code_gps",
            "x_debut_traversee_bac",
            "y_debut_traversee_bac",
            "x_fin_traversee_bac",
            "y_fin_traversee_bac",
            "type_bac",
            "nom_cours_eau",
            "date_creation",
            "date_modification",
            "enqueteur"
          ],
          "typeBacOptions": [
            "Manuel",
            "Motorisé"
          ]
        },
        "Buse": {
          "tableName": "buses",
          "fields": [
            "code_piste",
            "code_gps",
            "x_buse",
            "y_buse",
            "date_creation",
            "date_modification",
            "enqueteur"
          ]
        },
        "Dalot": {
          "tableName": "dalots",
          "fields": [
            "code_piste",
            "code_gps",
            "x_dalot",
            "y_dalot",
            "situation_dalot",
            "date_creation",
            "date_modification",
            "enqueteur"
          ],
          "situationOptions": [
            "à réaliser",
            "en cours",
            "existant"
          ]
        },
        "Passage Submersible": {
          "tableName": "passages_submersibles",
          "fields": [
            "code_piste",
            "code_gps",
            "x_debut_passage_submersible",
            "y_debut_passage_submersible",
            "x_fin_passage_submersible",
            "y_fin_passage_submersible",
            "type_materiau",
            "date_creation",
            "date_modification",
            "enqueteur"
          ],
          "typeOptions": [
            "béton",
            "bloc de pierre",
            "gabion",
            "autre"
          ]
        }
      }
    },
    "Points Critiques": {
      "icon": "warning",
      "color": 0xFFF44336,
      "entities": {
        "Point Critique": {
          "tableName": "points_critiques",
          "parentTable": "chaussees",
          "fields": [
            "code_piste",
            "code_gps",
            "x_point_critique",
            "y_point_critique",
            "type_point_critique",
            "date_creation",
            "date_modification",
            "enqueteur"
          ],
          "typeOptions": [
            "nid de poule",
            "trou"
          ]
        },
        "Point de Coupure": {
          "tableName": "points_coupures",
          "parentTable": "chaussees",
          "fields": [
            "code_piste",
            "code_gps",
            "x_point_coupure",
            "y_point_coupure",
            "causes_coupures",
            "date_creation",
            "date_modification",
            "enqueteur"
          ],
          "causesOptions": [
            "Détruit (permanent)",
            "Inondé (temporaire)"
          ]
        }
      }
    }
  };

  // Méthodes utilitaires exactement comme dans React Native
  static Map<String, dynamic>? getCategoryConfig(String category) {
    return config[category];
  }

  static Map<String, dynamic>? getEntityConfig(String category, String entity) {
    final categoryConfig = getCategoryConfig(category);
    if (categoryConfig != null) {
      final entities = categoryConfig['entities'] as Map<String, dynamic>?;
      return entities?[entity];
    }
    return null;
  }

  static List<String> getCategories() {
    return config.keys.toList();
  }

  static List<String> getEntitiesForCategory(String category) {
    final categoryConfig = getCategoryConfig(category);
    if (categoryConfig != null) {
      final entities = categoryConfig['entities'] as Map<String, dynamic>?;
      return entities?.keys.toList() ?? [];
    }
    return [];
  }

  static int getCategoryColor(String category) {
    final categoryConfig = getCategoryConfig(category);
    return categoryConfig?['color'] ?? 0xFF757575;
  }

  static String getCategoryIcon(String category) {
    final categoryConfig = getCategoryConfig(category);
    return categoryConfig?['icon'] ?? 'help';
  }

  static List<String> getTypeOptions(String category, String entity) {
    final entityConfig = getEntityConfig(category, entity);
    if (entityConfig != null) {
      return List<String>.from(entityConfig['typeOptions'] ?? []);
    }
    return [];
  }
}
