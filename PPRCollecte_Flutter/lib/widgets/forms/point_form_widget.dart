// lib/point_form_widget.dart
import 'package:flutter/material.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';
import '../../core/config/infrastructure_config.dart';

class PointFormWidget extends StatefulWidget {
  final String category;
  final String type;
  final Map<String, dynamic>? pointData;
  final VoidCallback onBack;
  final VoidCallback onSaved;
  final String? agentName;
  final String? nearestPisteCode;
  final bool isSpecialLine;
  const PointFormWidget({
    super.key,
    required this.category,
    required this.type,
    this.pointData,
    required this.onBack,
    required this.onSaved,
    this.agentName,
    this.nearestPisteCode,
    this.isSpecialLine = false,
  });

  @override
  State<PointFormWidget> createState() => _PointFormWidgetState();
}

class _PointFormWidgetState extends State<PointFormWidget> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> _formData = {};
  bool _isLoading = false;
  late TextEditingController agentController;
  bool _typeValidated = true;
  String? _typeError;

  @override
  void initState() {
    super.initState();
    print('PointFormWidget.agentName = ${widget.agentName}');
    agentController = TextEditingController(text: widget.agentName ?? 'N/A');

    _initializeFormData();
  }

  @override
  void dispose() {
    agentController.dispose();
    super.dispose();
  }

  void _initializeFormData() {
    print('🔄 Début _initializeFormData() - isSpecialLine: ${widget.isSpecialLine}');
    print('   widget.pointData: ${widget.pointData}');

    // RÉINITIALISER _formData EN COPIANT TOUTES LES DONNÉES EXISTANTES
    _formData = Map<String, dynamic>.from(widget.pointData ?? {});

    if (widget.pointData != null && widget.pointData!['id'] != null) {
      // ============ MODIFICATION ============
      print('📝 Mode MODIFICATION');

      final config = InfrastructureConfig.getEntityConfig(widget.category, widget.type);
      final tableName = config?['tableName'] ?? '';
      final coordinatePrefix = _getCoordinatePrefix(tableName);

      // AJOUTEZ SEULEMENT LES CHAMPS MANQUANTS, NE REMPLACEZ PAS TOUT
      _formData['id'] = widget.pointData!['id'];
      _formData['code_piste'] = widget.pointData!['code_piste'];
      _formData['nom'] = widget.pointData!['nom'];
      _formData['type'] = widget.pointData!['type'];
      _formData['enqueteur'] = widget.pointData!['enqueteur'] ?? widget.agentName ?? 'N/A';
      _formData['date_creation'] = widget.pointData!['date_creation'];
      _formData['date_modification'] = widget.pointData!['date_modification'] ?? DateTime.now().toIso8601String();
      _formData['latitude'] = widget.pointData!['y_$coordinatePrefix'];
      _formData['longitude'] = widget.pointData!['x_$coordinatePrefix'];
      _formData['code_gps'] = widget.pointData!['code_gps'];
      _addSpecificFormDataFromPointData(widget.pointData!, widget.type);
    } else {
      // ============ CRÉATION ============
      print('🆕 Mode CRÉATION');

      // AJOUTEZ SEULEMENT LES CHAMPS MANQUANTS, NE REMPLACEZ PAS TOUT
      _formData['id'] = _formData['id'] ?? null;
      _formData['code_piste'] = _formData['code_piste'] ?? widget.nearestPisteCode;
      _formData['nom'] = _formData['nom'] ?? null;
      _formData['type'] = _formData['type'] ?? null;
      _formData['enqueteur'] = _formData['enqueteur'] ?? widget.agentName ?? 'N/A';
      _formData['date_creation'] = _formData['date_creation'] ?? DateTime.now().toIso8601String();
      _formData['date_modification'] = _formData['date_modification'] ?? null;

      // ASSUREZ-VOUS QUE LES COORDONNÉES PRINCIPALES EXISTENT
      if (!_formData.containsKey('latitude') && _formData.containsKey('latitude_debut')) {
        _formData['latitude'] = _formData['latitude_debut'];
      }
      if (!_formData.containsKey('longitude') && _formData.containsKey('longitude_debut')) {
        _formData['longitude'] = _formData['longitude_debut'];
      }

      print('📍 Coordonnées extraites:');
      print('   latitude: ${_formData['latitude']}');
      print('   longitude: ${_formData['longitude']}');
      print('   code_piste: ${_formData['code_piste']}');
    }

    print('✅ _initializeFormData() terminé:');
    print('   _formData: $_formData');
  }

  @override
  void didUpdateWidget(PointFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Re-initialiser si les données pointData changent
    if (oldWidget.pointData != widget.pointData) {
      print('🔄 didUpdateWidget - pointData changé');
      _initializeFormData();
    }

    // Mettre à jour le controller agent si besoin
    if (oldWidget.agentName != widget.agentName) {
      agentController.text = widget.agentName ?? 'N/A';
      _formData['enqueteur'] = widget.agentName ?? 'N/A';
    }
  }

  void _addSpecificFormDataFromPointData(Map<String, dynamic> pointData, String entityType) {
    // Champs communs pour plusieurs entités
    if (pointData.containsKey('nom_cours_eau')) {
      _formData['nom_cours_eau'] = pointData['nom_cours_eau'];
    }

    // Champs spécifiques par type d'entité
    switch (entityType) {
      case 'Pont':
        _formData['situation'] = pointData['situation_pont'];
        _formData['type_pont'] = pointData['type_pont'];
        break;

      case 'Bac':
        _formData['type_bac'] = pointData['type_bac'];
        _formData['nom_cours_eau'] = pointData['nom_cours_eau'];
        _formData['latitude_fin'] = pointData['y_fin_traversee_bac'];
        _formData['longitude_fin'] = pointData['x_fin_traversee_bac'];
        break;

      case 'Dalot':
        _formData['situation'] = pointData['situation_dalot'];
        break;

      case 'Passage Submersible':
        _formData['type'] = pointData['type_materiau'];
        _formData['latitude_fin'] = pointData['y_fin_passage_submersible'];
        _formData['longitude_fin'] = pointData['x_fin_passage_submersible'];
        break;

      case 'Point Critique':
        _formData['type_point_critique'] = pointData['type_point_critique'];
        break;

      case 'Point de Coupure':
        _formData['causes_coupures'] = pointData['causes_coupures'];
        break;

      case 'Site de Plaine':
        _formData['amenage_ou_non_amenage'] = pointData['amenage_ou_non_amenage'] == 1 ? 'Aménagé' : 'Non aménagé';
        _formData['projet'] = pointData['projet'];
        _formData['entreprise'] = pointData['entreprise'];
        _formData['financement'] = pointData['financement'];
        _formData['type_de_realisation'] = pointData['type_de_realisation'];
        _formData['travaux_debut'] = pointData['travaux_debut'];
        _formData['travaux_fin'] = pointData['travaux_fin']?.toString();
        _formData['superficie_digitalisee'] = pointData['superficie_digitalisee']?.toString();
        _formData['superficie_estimee_lors_des_enquetes_ha'] = pointData['superficie_estimee_lors_des_enquetes_ha']?.toString();
        break;
      // Pour les infrastructures rurales (écoles, marchés, etc.)
      default:
        // Les champs de base sont déjà mappés
        break;
    }
  }

  Future<void> _handleSave() async {
    if (!_validateForm()) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final config = InfrastructureConfig.getEntityConfig(widget.category, widget.type);
      final tableName = config?['tableName'];

      if (tableName == null) {
        throw Exception('Table non configurée pour ${widget.type}');
      }
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();

      if (loginId == null) {
        print('❌ [_handleSave] Impossible de déterminer login_id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de déterminer l’utilisateur (login_id).'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final coordinatePrefix = _getCoordinatePrefix(tableName);
// CORRECTION: Formater la date avec l'heure actuelle
      String formatDateWithCurrentTime(String? dateString) {
        if (dateString == null) return DateTime.now().toIso8601String();
        try {
          final selectedDate = DateTime.parse(dateString);
          final now = DateTime.now();
          // Garder la date sélectionnée mais avec l'heure actuelle
          final dateWithTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, now.hour, now.minute, now.second);
          return dateWithTime.toIso8601String();
        } catch (e) {
          return DateTime.now().toIso8601String();
        }
      }

      // Préparer les données de base avec le bon préfixe
      final entityData = {
        'nom': _formData['nom'] ?? 'Sans nom',
        'enqueteur': _formData['enqueteur'] ?? 'Anonyme',
        'code_piste': _formData['code_piste'],
        'login_id': loginId,
        'code_gps': _formData['code_gps'],
      };
      entityData['x_$coordinatePrefix'] = _formData['longitude'] ?? 0.0;
      entityData['y_$coordinatePrefix'] = _formData['latitude'] ?? 0.0;
      if (widget.isSpecialLine) {
        if (widget.type == "Bac") {
          entityData['x_debut_traversee_bac'] = _formData['longitude_debut'] ?? _formData['latitude'] ?? 0.0;
          entityData['y_debut_traversee_bac'] = _formData['latitude_debut'] ?? _formData['longitude'] ?? 0.0;
          entityData['x_fin_traversee_bac'] = _formData['longitude_fin'] ?? _formData['latitude'] ?? 0.0;
          entityData['y_fin_traversee_bac'] = _formData['latitude_fin'] ?? _formData['longitude'] ?? 0.0;
        } else if (widget.type == "Passage Submersible") {
          entityData['x_debut_passage_submersible'] = _formData['longitude_debut'] ?? _formData['latitude'] ?? 0.0;
          entityData['y_debut_passage_submersible'] = _formData['latitude_debut'] ?? _formData['longitude'] ?? 0.0;
          entityData['x_fin_passage_submersible'] = _formData['longitude_fin'] ?? _formData['latitude'] ?? 0.0;
          entityData['y_fin_passage_submersible'] = _formData['latitude_fin'] ?? _formData['longitude'] ?? 0.0;
        }
      }
      // Si c'est une modification, ajouter l'ID
      if (widget.pointData != null && widget.pointData!['id'] != null) {
        entityData['id'] = widget.pointData!['id'];
        // ⚠️ CORRECTION IMPORTANTE ⚠️
        // NE PAS modifier la date de création originale
        entityData['date_creation'] = _formData['date_creation']; // Garder l'original

        // Seulement mettre à jour la date de modification avec l'heure actuelle
        final now = DateTime.now();
        entityData['date_modification'] = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second).toIso8601String();
      } else {
        // Si c'est une création, ajouter la date de création avec l'heure actuelle
        entityData['date_creation'] = formatDateWithCurrentTime(_formData['date_creation']);
      }
      // Ajouter le type si présent dans le formulaire
      if (_formData['type'] != null) {
        // Vérifiez si cette entité utilise 'type' ou 'type_materiau'
        if (widget.type == "Passage Submersible") {
          entityData['type_materiau'] = _formData['type']; // ← Pour Passage Submersible
        } else if (widget.type == "Bac") {
          entityData['type_bac'] = _formData['type']; // ← Pour Bac
        } else {
          entityData['type'] = _formData['type']; // ← Pour les autres entités
        }
      }
// JUSTE AVANT la sauvegarde, ajoutez ce debug
      print('🔍 === DEBUG TYPE_MATERIAU ===');
      print('Valeur dans _formData: ${_formData['type_materiau']}');
      print('Valeur dans entityData: ${entityData['type_materiau']}');
      print('Options disponibles: ${InfrastructureConfig.getTypeOptions(widget.category, widget.type)}');
      print('=============================');
      // Ajouter les champs spécifiques selon le type d'entité
      _addSpecificFields(entityData, widget.type, config);

      // Insertion ou mise à jour dans la base

      int id;

      if (widget.pointData != null && widget.pointData!['id'] != null) {
        // MISE À JOUR de l'entité existante
        id = await dbHelper.updateEntity(tableName, widget.pointData!['id'], entityData);
        print('✅ Entité mise à jour avec ID: $id');
      } else {
        // INSERTION d'une nouvelle entité
        id = await dbHelper.insertEntity(tableName, entityData);
        print('✅ Nouvelle entité enregistrée avec ID: $id');
        // ⭐⭐ DEBUG DÉTAILLÉ ⭐⭐
        print('🔍 === DEBUG LIGNE SPÉCIALE ===');
        print('isSpecialLine: ${widget.isSpecialLine}');
        print('Type: ${widget.type}');
        print('Données de ligne disponibles:');
        print('  latDebut: ${_formData['latitude_debut']}');
        print('  lngDebut: ${_formData['longitude_debut']}');
        print('  latFin: ${_formData['latitude_fin']}');
        print('  lngFin: ${_formData['longitude_fin']}');
        print('=============================');
        final entityConfig = InfrastructureConfig.getEntityConfig(widget.category, widget.type);
        final originalTableName = entityConfig?['tableName'] ?? ''; // ← NOM DIFFÉRENT

        if (widget.isSpecialLine) {
          print('🟣 Tentative de sauvegarde comme ligne spéciale...');
          // POUR LES LIGNES SPÉCIALES (Bac, Passage Submersible)
          await dbHelper.saveDisplayedSpecialLine(
            id: id,
            tableName: originalTableName,
            latDebut: _formData['latitude_debut'] ?? _formData['latitude'] ?? 0.0,
            lngDebut: _formData['longitude_debut'] ?? _formData['longitude'] ?? 0.0,
            latFin: _formData['latitude_fin'] ?? _formData['latitude'] ?? 0.0,
            lngFin: _formData['longitude_fin'] ?? _formData['longitude'] ?? 0.0,
            specialType: widget.type,
            name: _formData['nom'] ?? 'Sans nom',
            codePiste: _formData['code_piste'] ?? 'Non spécifié',
          );
        } else {
          // POUR LES POINTS NORMaux (comme avant)
          await dbHelper.saveDisplayedPoint(
            id: id,
            tableName: originalTableName,
            latitude: _formData['latitude'] ?? 0.0,
            longitude: _formData['longitude'] ?? 0.0,
            type: widget.type,
            name: _formData['nom'] ?? 'Sans nom',
            codePiste: _formData['code_piste'] ?? 'Non spécifié',
          );
        }
      }

      // ============ AJOUTER CE CODE POUR LA CONFIRMATION ============
      if (mounted) {
        // RÉINITIALISER L'ÉTAT DU FORMULAIRE APRÈS SUCCÈS
        _formKey.currentState?.reset();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Succès'),
              ],
            ),
            content: Text('${widget.type} "${_formData['nom']}" enregistré avec succès\n'
                'Coordonnées: ${_formData['latitude']?.toStringAsFixed(6)}, '
                '${_formData['longitude']?.toStringAsFixed(6)}\n'
                'Code Piste: ${_formData['code_piste'] ?? 'Non spécifié'}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onSaved();
                  // Fermer la boîte de dialogue
                  // ← CETTE LIGNE EST CRUCIALE
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      // ============ FIN DE L'AJOUT ============
    } catch (error) {
      print('❌ Erreur détaillée: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _validateForm() {
    // Valider les champs requis standards
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    // Validation spécifique pour le type
    final config = InfrastructureConfig.getEntityConfig(widget.category, widget.type);
    final typeOptions = InfrastructureConfig.getTypeOptions(widget.category, widget.type);

    if (typeOptions.isNotEmpty && (_formData['type'] == null || _formData['type'].toString().trim().isEmpty)) {
      setState(() {
        _typeValidated = false;
        _typeError = 'Veuillez sélectionner un type';
      });

      // Faire défiler jusqu'au champ erroné
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      return false;
    }

    return true;
  }

// AJOUTEZ dans _PointFormWidgetState
  void _refreshAndNavigate() {
    // Fermer le formulaire
    widget.onSaved();

    // Optionnel: Afficher un message de rafraîchissement
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Carte rafraîchie avec le nouveau point'),
        duration: Duration(seconds: 2),
      ),
    );
  }
// AJOUTEZ cette méthode dans la classe _PointFormWidgetState

// MÉTHODE COMPLÈTEMENT CORRIGÉE POUR LES PRÉFIXES :
  String _getCoordinatePrefix(String tableName) {
    // Mapping COMPLET de tous les cas spéciaux
    final Map<String, String> coordinatePrefixes = {
      // Infrastructures Rurales
      'localites': 'localite',
      'ecoles': 'ecole',
      'marches': 'marche',
      'services_santes': 'sante',
      'batiments_administratifs': 'batiment_administratif',
      'infrastructures_hydrauliques': 'infrastructure_hydraulique',
      'autres_infrastructures': 'autre_infrastructure',

      // Ouvrages
      'ponts': 'pont',
      'bacs': 'debut_traversee_bac', // Special case for bac
      'buses': 'buse',
      'dalots': 'dalot',
      'passages_submersibles': 'debut_passage_submersible', // Special case

      // Points Critiques
      'points_critiques': 'point_critique',
      'points_coupures': 'point_coupure',

      // Enquête
      'site_enquete': 'site',
    };

    // Retourne le préfixe spécifique ou le premier mot de la table
    return coordinatePrefixes[tableName] ?? tableName.split('_').first;
  }

// MÉTHODE POUR AJOUTER LES CHAMPS SPÉCIFIQUES :
  void _addSpecificFields(Map<String, dynamic> entityData, String entityType, Map<String, dynamic>? config) {
    // Champs communs basés sur la configuration
    if (config?['fields']?.contains('nom_cours_eau') == true && _formData['nom_cours_eau'] != null) {
      entityData['nom_cours_eau'] = _formData['nom_cours_eau'];
    }

    // Champs spécifiques par type d'entité
    switch (entityType) {
      case 'Pont':
        entityData['situation_pont'] = _formData['situation'] ?? 'Non spécifié';
        entityData['type_pont'] = _formData['type_pont'] ?? 'Non spécifié';
        break;

      case 'Bac':
        entityData['type_bac'] = _formData['type_bac'] ?? 'Non spécifié';
        entityData['nom_cours_eau'] = _formData['nom_cours_eau'] ?? 'Non spécifié';
        // Les coordonnées de début sont déjà dans entityData via le préfixe
        entityData['x_fin_traversee_bac'] = _formData['longitude_fin'] ?? _formData['latitude'] ?? 0.0;
        entityData['y_fin_traversee_bac'] = _formData['latitude_fin'] ?? _formData['longitude'] ?? 0.0;
        break;

      case 'Dalot':
        entityData['situation_dalot'] = _formData['situation'] ?? 'Non spécifié';
        break;

      case 'Passage Submersible':
        entityData['type_materiau'] = _formData['type'] ?? 'Non spécifié';
        // Les coordonnées de début sont déjà dans entityData via le préfixe
        entityData['x_fin_passage_submersible'] = _formData['longitude_fin'] ?? _formData['latitude'] ?? 0.0;
        entityData['y_fin_passage_submersible'] = _formData['latitude_fin'] ?? _formData['longitude'] ?? 0.0;
        break;

      case 'Point Critique':
        entityData['type_point_critique'] = _formData['type_point_critique'] ?? 'Non spécifié';
        break;

      case 'Point de Coupure':
        entityData['causes_coupures'] = _formData['causes_coupures'] ?? 'Non spécifié';
        break;

      case 'Site de Plaine':
        if (_formData['amenage_ou_non_amenage'] != null) {
          entityData['amenage_ou_non_amenage'] = _formData['amenage_ou_non_amenage'] == 'Aménagé' ? 1 : 0;
        }
        entityData['projet'] = _formData['projet'];
        entityData['entreprise'] = _formData['entreprise'];
        entityData['financement'] = _formData['financement'];
        entityData['type_de_realisation'] = _formData['type_de_realisation'];
        entityData['travaux_debut'] = _formData['travaux_debut'];
        if (_formData['travaux_fin'] != null && _formData['travaux_fin'].toString().isNotEmpty) {
          entityData['travaux_fin'] = int.tryParse(_formData['travaux_fin'].toString());
        }
        if (_formData['superficie_digitalisee'] != null && _formData['superficie_digitalisee'].toString().isNotEmpty) {
          entityData['superficie_digitalisee'] = double.tryParse(_formData['superficie_digitalisee'].toString());
        }
        if (_formData['superficie_estimee_lors_des_enquetes_ha'] != null && _formData['superficie_estimee_lors_des_enquetes_ha'].toString().isNotEmpty) {
          entityData['superficie_estimee_lors_des_enquetes_ha'] = double.tryParse(_formData['superficie_estimee_lors_des_enquetes_ha'].toString());
        }
        break;
      // Pour TOUTES les autres entités (écoles, marchés, etc.)
      default:
        // Utilisent les champs de base déjà définis + nom_cours_eau si configuré
        break;
    }

    // Ajouter les champs optionnels supplémentaires
    _addOptionalFields(entityData, config);
  }

// MÉTHODE POUR LES CHAMPS OPTIONNELS :
  void _addOptionalFields(Map<String, dynamic> entityData, Map<String, dynamic>? config) {
    final optionalFields = {
      'description': _formData['description'],
      'etat': _formData['etat'],
      'capacite': _formData['capacite'],
      'materiau': _formData['materiau'],
      'hauteur': _formData['hauteur'],
      'largeur': _formData['largeur'],
    };

    optionalFields.forEach((key, value) {
      if (value != null && config?['fields']?.contains(key) == true) {
        entityData[key] = value;
      }
    });
  }

// Remplacer la méthode _clearForm par:
  void _clearForm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Êtes-vous sûr de vouloir effacer tous les champs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performClear();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }

  void _performClear() {
    setState(() {
      // Réinitialiser seulement les champs modifiables
      _formData['nom'] = null;
      _formData['type'] = null;
      _formData['nom_cours_eau'] = null;
      _formData['situation'] = null;
      _formData['type_pont'] = null;
      _formData['type_bac'] = null;
      _formData['causes_coupures'] = null;
      _formData['type_point_critique'] = null;
      _formData['code_gps'] = null;

      // Réinitialiser l'état de validation
      _typeValidated = true;
      _typeError = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Formulaire effacé'),
        duration: Duration(seconds: 2),
      ),
    );
  }

// MÉTHODE DE VALIDATION :
  void _validateRequiredFields(Map<String, dynamic> entityData, Map<String, dynamic>? config) {
    final requiredFields = config?['fields'] as List<String>? ?? [];
    final nullableFields = [
      'date_modification'
    ]; // Seulement ce champ
    for (var field in requiredFields) {
      if (nullableFields.contains(field)) continue;
      if (entityData[field] == null || entityData[field].toString().isEmpty) {
        throw Exception('Le champ $field est requis mais est vide');
      }
    }

    // Validation spécifique pour les entités avec coordonnées multiples
    if (widget.type == 'Bac' || widget.type == 'Passage Submersible') {
      final latDebut = entityData['x_debut_traversee_bac'] ?? entityData['x_debut_passage_submersible'];
      final lngDebut = entityData['y_debut_traversee_bac'] ?? entityData['y_debut_passage_submersible'];
      final latFin = entityData['x_fin_traversee_bac'] ?? entityData['x_fin_passage_submersible'];
      final lngFin = entityData['y_fin_traversee_bac'] ?? entityData['y_fin_passage_submersible'];

      if (latDebut == latFin && lngDebut == lngFin) {
        print('⚠️ Attention: Coordonnées identiques pour début et fin');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Afficher l'état des données
    print('🔄 PointFormWidget rebuild:');
    print('   category: ${widget.category}');
    print('   type: ${widget.type}');
    print('   pointData: ${widget.pointData}');
    print('   formData: $_formData');
    print('   agentName: ${widget.agentName}');
    final categoryColor = Color(InfrastructureConfig.getCategoryColor(widget.category));
    final config = InfrastructureConfig.getEntityConfig(widget.category, widget.type);
    final typeOptions = InfrastructureConfig.getTypeOptions(widget.category, widget.type);
    final bool isCreation = widget.pointData == null || widget.pointData!['id'] == null;
    print('🏗️ Build - Mode: ${isCreation ? "CRÉATION" : "MODIFICATION"}');
    print('   date_modification: ${_formData['date_modification']}');
    return Column(
      children: [
        // Header du formulaire - Style React Native
        Container(
          decoration: BoxDecoration(
            color: categoryColor,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      widget.type,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Table: ${config?['tableName'] ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withAlpha((0.9 * 255).round()),
                      ),
                    ),
                  ],
                ),
              ),
              // Bouton Effacer dans le header
              TextButton.icon(
                onPressed: _clearForm,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Effacer'),
              ),
            ],
          ),
        ),

        // Contenu du formulaire
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Section Association
                _buildFormSection(
                  title: '🔗 Association',
                  children: [
                    _buildInfoBox(
                      'Ce point sera associé à une piste lors de la synchronisation.',
                      Colors.blue,
                    ),

                    // ⭐⭐ AJOUTER CET INDICATEUR ICI ⭐⭐
                    if (widget.nearestPisteCode != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 20, color: Colors.green[700]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Piste la plus proche détectée:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                  Text(
                                    widget.nearestPisteCode!,
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                _buildCodePisteField(),
                // Section Identification
                _buildFormSection(
                  title: '🏷️ Identification',
                  children: [
                    _buildTextField(
                      label: 'Nom *',
                      hint: 'Nom de ${widget.type.toLowerCase()}',
                      key: 'nom',
                      required: true,
                    ),
                    _buildTextField(
                      label: 'Code GPS',
                      hint: 'Code GPS optionnel',
                      key: 'code_gps',
                      required: false, // Non requis
                    ),
                    if (typeOptions.isNotEmpty)
                      (config?['multiSelectType'] == true)
                          ? _buildMultiSelectField(
                              label: 'Type *',
                              hint: 'Sélectionner un ou plusieurs types',
                              options: typeOptions,
                              key: 'type',
                              required: true,
                            )
                          : _buildDropdownField(
                              label: 'Type *',
                              hint: 'Sélectionner un type',
                              options: typeOptions,
                              key: 'type',
                              required: true,
                            ),

                    if (config?['fields']?.contains('nom_cours_eau') == true)
                      _buildTextField(
                        label: 'Nom du cours d\'eau *',
                        hint: 'Nom du cours d\'eau traversé',
                        key: 'nom_cours_eau',
                        required: true,
                      ),
                    // Champ date de création
                    _buildDateField(
                      label: 'Date de création *',
                      key: 'date_creation',
                      required: true,
                      readOnly: true,
                    ),
                    _buildDateModificationField(),
                  ],
                ),

                // Section Caractéristiques spécifiques
                if (_hasSpecificFields(config))
                  _buildFormSection(
                    title: '⚙️ Caractéristiques',
                    children: _buildSpecificFields(config, categoryColor),
                  ),

                // Section GPS et Métadonnées
                _buildFormSection(
                  title: '📍 Géolocalisation',
                  children: [
                    _buildGpsInfo(),
                    _buildReadOnlyField(
                      label: 'Agent enquêteur',
                      icon: Icons.person,
                    ),
                  ],
                ),

                const SizedBox(height: 120), // Espace pour le bouton flottant
              ],
            ),
          ),
        ),

        // Bouton Sauvegarder - Style React Native
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: categoryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Enregistrer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateModificationField() {
    final bool isCreation = widget.pointData == null || widget.pointData!['id'] == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date de modification',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isCreation ? Colors.grey : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: isCreation
                ? null
                : () async {
                    // DÉSACTIVÉ en création
                    DateTime initialDate = DateTime.now();
                    if (_formData['date_modification'] != null) {
                      initialDate = DateTime.tryParse(_formData['date_modification']) ?? DateTime.now();
                    }

                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _formData['date_modification'] = picked.toIso8601String();
                      });
                    }
                  },
            child: Container(
              decoration: BoxDecoration(
                color: isCreation ? const Color(0xFFF5F5F5) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCreation ? const Color(0xFFE0E0E0) : const Color(0xFFE5E7EB),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: isCreation ? Colors.grey : const Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isCreation
                          ? "Non modifié"
                          : (_formData['date_modification'] != null
                              ? (DateTime.tryParse(_formData['date_modification']) != null
                                  ? "${DateTime.parse(_formData['date_modification']).day.toString().padLeft(2, '0')}/"
                                      "${DateTime.parse(_formData['date_modification']).month.toString().padLeft(2, '0')}/"
                                      "${DateTime.parse(_formData['date_modification']).year}"
                                  : _formData['date_modification'].toString())
                              : "Sélectionner une date"),
                      style: TextStyle(
                        fontSize: 14,
                        color: isCreation ? const Color(0xFF9E9E9E) : (_formData['date_modification'] != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodePisteField() {
    // ⭐⭐ PRÉ-REMPLIR AVEC LE CODE PISTE ⭐⭐
    if (widget.nearestPisteCode != null && _formData['code_piste'] == null) {
      _formData['code_piste'] = widget.nearestPisteCode;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Code Piste *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.confirmation_number, size: 20, color: Color(0xFF1976D2)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: TextEditingController(
                      text: _formData['code_piste']?.toString() ?? '',
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Entrez le code de la piste',
                      hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF374151),
                    ),
                    enabled: false, // ← DÉSACTIVÉ
                    readOnly: true, // ← LECTURE SEULE
                    onChanged: (value) {
                      _formData['code_piste'] = value;
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Le code piste est obligatoire';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modifier la méthode _buildDateField() pour le champ date_creation:
  Widget _buildDateField({
    required String label,
    required String key,
    bool required = false,
    bool readOnly = false,
  }) {
    final bool isReadOnly = readOnly || key == 'date_creation';

    // Formater la date pour l'affichage
    String formatDisplayDate(String dateString) {
      try {
        final date = DateTime.parse(dateString);
        return "${date.day.toString().padLeft(2, '0')}/"
            "${date.month.toString().padLeft(2, '0')}/"
            "${date.year} "
            "${date.hour.toString().padLeft(2, '0')}:"
            "${date.minute.toString().padLeft(2, '0')}";
      } catch (e) {
        return dateString;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Color(0xFF1976D2)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formData[key] != null ? formatDisplayDate(_formData[key]) : "Date non disponible",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isReadOnly)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Date automatique (non modifiable)',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormSection({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE3F2FD))),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1976D2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required String key,
    bool required = false,
    int maxLines = 1,
  }) {
    // Créer un contrôleur avec la valeur pré-remplie
    final controller = TextEditingController(text: _formData[key]?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1976D2)),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red), // ← Même rouge que le type
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red), // ← Même rouge que le type
              ),
              errorStyle: const TextStyle(color: Colors.red), // ← Même rouge que le type
            ),
            maxLines: maxLines,
            textAlignVertical: maxLines > 1 ? TextAlignVertical.top : null,
            validator: required
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '$label est obligatoire';
                    }
                    return null;
                  }
                : null,
            onChanged: (value) {
              _formData[key] = value;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required List<String> options,
    required String key,
    bool required = false,
  }) {
    final bool hasError = !_typeValidated && _formData[key] == null && required;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: hasError ? Colors.red : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasError ? Colors.red : const Color(0xFFE5E7EB),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: options.map((option) {
                final isSelected = _formData[key] == option;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque, // Ensures the entire row area catches taps
                  onTap: () {
                    setState(() {
                      _formData[key] = option;
                      _typeValidated = true;
                      _typeError = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE3F2FD).withOpacity(0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF1976D2) : (hasError ? Colors.red : const Color(0xFFD1D5DB)),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(
                                    Icons.circle,
                                    size: 14,
                                    color: Color(0xFF1976D2),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 16,
                              color: isSelected ? const Color(0xFF1976D2) : (hasError ? Colors.red : const Color(0xFF374151)),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                _typeError ?? 'Veuillez sélectionner un type',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.red, // ← Même rouge que le nom
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectField({
    required String label,
    required String hint,
    required List<String> options,
    required String key,
    bool required = false,
  }) {
    // Parse les valeurs déjà sélectionnées (stockées en "primaire,secondaire")
    final String currentValue = (_formData[key] ?? '').toString();
    final Set<String> selectedValues = currentValue.isNotEmpty ? currentValue.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet() : <String>{};

    final bool hasError = !_typeValidated && selectedValues.isEmpty && required;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: hasError ? Colors.red : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasError ? Colors.red : const Color(0xFFE5E7EB),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: options.map((option) {
                final isSelected = selectedValues.contains(option);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      final newSelected = Set<String>.from(selectedValues);
                      if (isSelected) {
                        newSelected.remove(option);
                      } else {
                        newSelected.add(option);
                      }
                      // Stocker comme chaîne séparée par virgules
                      _formData[key] = newSelected.join(',');
                      _typeValidated = newSelected.isNotEmpty || !required;
                      _typeError = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE3F2FD).withOpacity(0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF1976D2) : (hasError ? Colors.red : const Color(0xFFD1D5DB)),
                              width: 2,
                            ),
                            color: isSelected ? const Color(0xFF1976D2) : Colors.transparent,
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? const Color(0xFF1976D2) : const Color(0xFF374151),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Veuillez sélectionner au moins un type',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGpsInfo() {
    final dynamic lat = _formData['latitude'];
    final dynamic lng = _formData['longitude'];
    print('🔍 _formData dans _buildGpsInfo:');
    print('   latitude: ${_formData['latitude']}');
    print('   longitude: ${_formData['longitude']}');
    print('   latitude_debut: ${_formData['latitude_debut']}');
    print('   longitude_debut: ${_formData['longitude_debut']}');
    print('   latitude_fin: ${_formData['latitude_fin']}');
    print('   longitude_fin: ${_formData['longitude_fin']}');
    print('   distance: ${_formData['distance']}');
    print('   isSpecialLine: ${widget.isSpecialLine}');
    String latStr = 'N/A';
    String lngStr = 'N/A';

    if (lat != null) latStr = lat is double ? lat.toStringAsFixed(6) : lat.toString();
    if (lng != null) lngStr = lng is double ? lng.toStringAsFixed(6) : lng.toString();
    if (widget.isSpecialLine) {
      print('🔍 Données de ligne spéciale: $_formData'); // ← DEBUG
      // AFFICHAGE SPÉCIAL POUR LES LIGNES (BAC ET PASSAGE)
      final dynamic latDebut = _formData['latitude_debut'];
      final dynamic lngDebut = _formData['longitude_debut'];
      final dynamic latFin = _formData['latitude_fin'];
      final dynamic lngFin = _formData['longitude_fin'];
      final dynamic distance = _formData['distance'];

      String latDebutStr = 'N/A';
      String lngDebutStr = 'N/A';
      String latFinStr = 'N/A';
      String lngFinStr = 'N/A';
      String distanceStr = 'N/A';

      if (latDebut != null && latDebut != 0.0) {
        latDebutStr = latDebut is double ? latDebut.toStringAsFixed(6) : latDebut.toString();
      }

      if (lngDebut != null && lngDebut != 0.0) {
        lngDebutStr = lngDebut is double ? lngDebut.toStringAsFixed(6) : lngDebut.toString();
      }

      if (latFin != null && latFin != 0.0) {
        latFinStr = latFin is double ? latFin.toStringAsFixed(6) : latFin.toString();
      }

      if (lngFin != null && lngFin != 0.0) {
        lngFinStr = lngFin is double ? lngFin.toStringAsFixed(6) : lngFin.toString();
      }

      if (distance != null && distance != 0.0) {
        distanceStr = distance is double ? '${distance.toStringAsFixed(2)} m' : distance.toString();
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F8FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3F2FD)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gps_fixed, size: 20, color: Color(0xFF1976D2)),
                SizedBox(width: 8),
                Text(
                  'Géolocalisation de la ligne',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildGpsInfoRow('Point de début:', '$latDebutStr°, $lngDebutStr°'),
            _buildGpsInfoRow('Point de fin:', '$latFinStr°, $lngFinStr°'),
            _buildGpsInfoRow('Distance totale:', distanceStr),
          ],
        ),
      );
    } else {
      // AFFICHAGE NORMAL POUR LES POINTS
      final dynamic lat = _formData['latitude'];
      final dynamic lng = _formData['longitude'];

      String latStr = 'N/A';
      String lngStr = 'N/A';

      if (lat != null) latStr = lat is double ? lat.toStringAsFixed(6) : lat.toString();
      if (lng != null) lngStr = lng is double ? lng.toStringAsFixed(6) : lng.toString();

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F8FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3F2FD)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gps_fixed, size: 20, color: Color(0xFF1976D2)),
                SizedBox(width: 8),
                Text(
                  'Position GPS collectée',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildGpsInfoRow('Latitude:', '$latStr°'),
            _buildGpsInfoRow('Longitude:', '$lngStr°'),
          ],
        ),
      );
    }
  }

  Widget _buildGpsInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF333333),
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.agentName ?? 'Non spécifié',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: color.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasSpecificFields(Map<String, dynamic>? config) {
    return config?.containsKey('situationOptions') == true || config?.containsKey('typePontOptions') == true || config?.containsKey('typeBacOptions') == true || config?.containsKey('causesOptions') == true || config?.containsKey('amenageOptions') == true;
  }

  List<Widget> _buildSpecificFields(Map<String, dynamic>? config, Color categoryColor) {
    List<Widget> fields = [];

    // Champs spécifiques selon l'entité
    if (config?.containsKey('situationOptions') == true) {
      fields.add(_buildDropdownField(
        label: 'Situation *',
        hint: 'Sélectionner une situation',
        options: List<String>.from(config!['situationOptions']),
        key: 'situation',
        required: true,
      ));
    }

    if (config?.containsKey('typePontOptions') == true) {
      fields.add(_buildDropdownField(
        label: 'Type du pont *',
        hint: 'Sélectionner un type',
        options: List<String>.from(config!['typePontOptions']),
        key: 'type_pont',
        required: true,
      ));
    }

    if (config?.containsKey('typeBacOptions') == true) {
      fields.add(_buildDropdownField(
        label: 'Type du bac *',
        hint: 'Sélectionner un type',
        options: List<String>.from(config!['typeBacOptions']),
        key: 'type_bac',
        required: true,
      ));
    }

    if (config?.containsKey('causesOptions') == true) {
      fields.add(_buildDropdownField(
        label: 'Cause de la coupure *',
        hint: 'Sélectionner une cause',
        options: List<String>.from(config!['causesOptions']),
        key: 'causes_coupures',
        required: true,
      ));
    }
// ===== Champs spécifiques Site de Plaine =====
    if (config?.containsKey('amenageOptions') == true) {
      fields.add(_buildDropdownField(
        label: 'Aménagé ou non *',
        hint: 'Sélectionner',
        options: List<String>.from(config!['amenageOptions']),
        key: 'amenage_ou_non_amenage',
        required: true,
      ));
      fields.add(_buildTextField(
        label: 'Projet',
        hint: 'Nom du projet',
        key: 'projet',
      ));
      fields.add(_buildTextField(
        label: 'Entreprise',
        hint: 'Nom de l\'entreprise',
        key: 'entreprise',
      ));
      fields.add(_buildTextField(
        label: 'Financement',
        hint: 'Source de financement',
        key: 'financement',
      ));
      if (config?.containsKey('typeRealisationOptions') == true) {
        fields.add(_buildDropdownField(
          label: 'Type de réalisation',
          hint: 'Sélectionner',
          options: List<String>.from(config!['typeRealisationOptions']),
          key: 'type_de_realisation',
        ));
      }
      fields.add(_buildTextField(
        label: 'Début des travaux',
        hint: 'Date ou année de début',
        key: 'travaux_debut',
      ));
      fields.add(_buildTextField(
        label: 'Fin des travaux',
        hint: 'Année de fin (ex: 2025)',
        key: 'travaux_fin',
      ));
      fields.add(_buildTextField(
        label: 'Superficie digitalisée (ha)',
        hint: 'En hectares',
        key: 'superficie_digitalisee',
      ));
      fields.add(_buildTextField(
        label: 'Superficie estimée lors des enquêtes (ha)',
        hint: 'En hectares',
        key: 'superficie_estimee_lors_des_enquetes_ha',
      ));
    }
    return fields;
  }
}
