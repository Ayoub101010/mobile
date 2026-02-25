import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import '../../data/local/piste_chaussee_db_helper.dart';
import '../../data/remote/api_service.dart';
import '../../data/local/database_helper.dart';

class FormulaireChausseePage extends StatefulWidget {
  final List<LatLng> chausseePoints;
  final int? provisionalId;
  final String? agentName;
  final Map<String, dynamic>? initialData; // ← NOUVEAU: Données existantes
  final bool isEditingMode; // ← NOUVEAU: Mode édition
  final String? nearestPisteCode;
  const FormulaireChausseePage({
    super.key,
    required this.chausseePoints,
    this.provisionalId,
    this.agentName,
    this.initialData, // ← NOUVEAU
    this.isEditingMode = false, // ← NOUVEAU
    this.nearestPisteCode,
  });

  @override
  State<FormulaireChausseePage> createState() => _FormulaireChausseePageState();
}

class _FormulaireChausseePageState extends State<FormulaireChausseePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // ✅ CHAMPS SELON VOS SPÉCIFICATIONS
  final _codePisteController = TextEditingController();
  final _codeGpsController = TextEditingController();
  final _endroitController = TextEditingController();
  final _userLoginController = TextEditingController();

  String? _typeChaussee; // Radio buttons
  String? _etatPiste; // Radio buttons
  DateTime? _dateCreation; // ← NOUVEAU
  DateTime? _dateModification;

  // ✅ OPTIONS SELON LA DOCUMENTATION OFFICIELLE
  final List<String> _typeChausseeOptions = [
    "Bitume",
    "Latérite",
    "Terre",
    "Bouwal",
    "Autre"
  ];

  final List<String> _etatPisteOptions = [
    "Bon état",
    "Moyennement dégradée",
    "Fortement dégradée"
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _setupAutoCapitalize();
  }

  void _initializeForm() {
    if (widget.isEditingMode && widget.initialData != null) {
      _fillFormWithExistingData();
      // 👉 En édition : on ne touche pas au code piste existant
      _codePisteController.text = widget.initialData!['code_piste'] ?? 'CH_${DateTime.now().millisecondsSinceEpoch}';
    } else {
      // 👉 En création : utiliser la piste la plus proche
      final String codePisteToUse = (widget.nearestPisteCode != null && widget.nearestPisteCode!.isNotEmpty) ? widget.nearestPisteCode! : 'CH_${DateTime.now().millisecondsSinceEpoch}';

      _codePisteController.text = codePisteToUse;
    }

    // Récupérer automatiquement l'utilisateur connecté
    _userLoginController.text = widget.agentName ?? _getCurrentUser(); // selon ton système d’auth

    // Date de création = maintenant (par défaut en création)
    _dateCreation = DateTime.now();

    // Date de modification = null au départ (mise à jour lors de l’édition)
    _dateModification = null;

    // 👉 Les coordonnées seront calculées automatiquement depuis chausseePoints
  }

  void _fillFormWithExistingData() {
    final data = widget.initialData!;
    setState(() {
      _codePisteController.text = data['code_piste'] ?? '';
      _codeGpsController.text = data['code_gps'] ?? '';
      _endroitController.text = data['endroit'] ?? '';
      _userLoginController.text = data['user_login'] ?? '';
      _typeChaussee = data['type_chaussee'];
      _etatPiste = data['etat_piste'];
      _dateCreation = data['created_at'] != null ? DateTime.parse(data['created_at']) : null;
      _dateModification = DateTime.now(); // Mise à jour à maintenant
    });

    setState(() {});
  }

  String _getCurrentUser() {
    // je vais complèter ça après

    return 'user_demo'; // Valeur temporaire pour test
  }

  void _setupAutoCapitalize() {
    final textControllers = [
      _codeGpsController,
      _endroitController,
    ];
    for (var ctrl in textControllers) {
      ctrl.addListener(() {
        final text = ctrl.text;
        if (text.isEmpty) return;
        final corrected = text[0].toUpperCase() + text.substring(1).toLowerCase();
        if (text != corrected) {
          final pos = ctrl.selection;
          ctrl.value = ctrl.value.copyWith(
            text: corrected,
            selection: pos,
          );
        }
      });
    }
  }

  Future<void> _selectDateCreation(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateCreation ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _dateCreation = picked;
      });
    }
  }

  double _calculateTotalDistance(List<LatLng> points) {
    if (points.length < 2) return 0.0;

    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _distanceBetween(points[i], points[i + 1]);
    }
    return total;
  }

  double _distanceBetween(LatLng point1, LatLng point2) {
    const double p = 0.017453292519943295;
    final a = 0.5 - (cos((point2.latitude - point1.latitude) * p) / 2) + cos(point1.latitude * p) * cos(point2.latitude * p) * (1 - cos((point2.longitude - point1.longitude) * p)) / 2;
    return 12742000 * asin(sqrt(a));
  }

  Future<void> _saveChaussee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 1));
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();

      if (loginId == null) {
        print('❌ [_saveChaussee] Impossible de déterminer login_id');
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
      String codePiste;
      if (widget.isEditingMode && widget.initialData != null) {
        codePiste = widget.initialData!['code_piste'] ?? _codePisteController.text;
      } else {
        codePiste = _codePisteController.text;
      }
      // ✅ DONNÉES SELON VOS SPÉCIFICATIONS
      final chausseeData = {
        // Champs saisis par l'utilisateur
        'code_piste': codePiste,
        'code_gps': _codeGpsController.text,
        'endroit': _endroitController.text,
        'type_chaussee': _typeChaussee,
        'etat_piste': _etatPiste,
        'user_login': _userLoginController.text,

        // ✅ Coordonnées auto-gérées (les 4)
        'x_debut_chaussee': widget.chausseePoints.isNotEmpty ? widget.chausseePoints.first.latitude : 0.0, // ← LATITUDE
        'y_debut_chaussee': widget.chausseePoints.isNotEmpty ? widget.chausseePoints.first.longitude : 0.0, // ← LONGITUDE
        'x_fin_chaussee': widget.chausseePoints.isNotEmpty ? widget.chausseePoints.last.latitude : 0.0, // ← LATITUDE
        'y_fin_chaussee': widget.chausseePoints.isNotEmpty ? widget.chausseePoints.last.longitude : 0.0, // ← LONGITUDE

        // Métadonnées de collecte
        'points_collectes': widget.chausseePoints
            .map((p) => {
                  'latitude': p.latitude,
                  'longitude': p.longitude,
                })
            .toList(),
        'distance_totale_m': _calculateTotalDistance(widget.chausseePoints),
        'nombre_points': widget.chausseePoints.length,
        'created_at': widget.isEditingMode && widget.initialData != null ? widget.initialData!['created_at'] : DateTime.now().toIso8601String(),
        'updated_at': widget.isEditingMode && widget.initialData != null
            ? DateTime.now().toIso8601String() // ← uniquement si modification
            : null, // ← jamais à la création

        'is_editing': widget.isEditingMode,

        'sync_status': 'pending',
        'login_id': loginId,
      };
      if (widget.isEditingMode && widget.initialData != null) {
        chausseeData['id'] = widget.initialData!['id'];
      }
      final storageHelper = SimpleStorageHelper();
      final savedId = await storageHelper.saveChaussee(chausseeData);
      if (savedId != null) {
        print('✅ Chaussée sauvegardée en local avec ID: $savedId');
        await storageHelper.debugPrintAllChaussees();
        await storageHelper.saveDisplayedChaussee(
            widget.chausseePoints, // Points de la chaussée
            chausseeData['type_chaussee'] ?? 'inconnu', // Couleur orange
            4.0, // Épaisseur de la ligne
            chausseeData['code_piste'], // ⭐⭐ MÊME CODE_PISTE ⭐⭐
            chausseeData['endroit'] ?? 'Sans endroit' // Endroit
            );
        print('✅ Chaussée affichée sauvegardée avec code_piste: ${chausseeData['code_piste']}');
      }

      if (mounted) {
        Navigator.of(context).pop(chausseeData);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateModification(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateModification ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _dateModification = picked;
      });
    }
  }

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
      _codeGpsController.clear();
      _endroitController.clear();

      // Réinitialiser les sélections
      _typeChaussee = null;
      _etatPiste = null;

      // Garder les champs en lecture seule
      // _codePisteController - Garder le code piste
      // _userLoginController - Garder le nom de l'agent
      // _dateCreation - Garder la date de création
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Formulaire effacé'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Abandonner la saisie ?"),
        content: const Text("Les données non sauvegardées seront perdues."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Abandonner"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFF9800),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _confirmExit,
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    padding: const EdgeInsets.all(8),
                  ),
                  const Expanded(
                    child: Text(
                      "🛣️ Formulaire Chaussée",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
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
                    // Section Identification
                    _buildFormSection(
                      title: '🏷️ Identification',
                      children: [
                        //  Code Piste - Affichage conditionnel
                        Builder(builder: (context) {
                          final String codePiste = _codePisteController.text;
                          final bool isTemporary = codePiste.isEmpty || codePiste.startsWith('Piste_0_0_0_') || codePiste.startsWith('TEMP_') || codePiste.startsWith('CH_');

                          if (isTemporary) {
                            // CAS 1 : Code temporaire → message
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.sync, size: 20, color: Color(0xFF4CAF50)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Code Piste',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF388E3C),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Attribué automatiquement lors de la synchronisation',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            return Column(
                              children: [
                                const Text(
                                  'Code Piste',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified, size: 20, color: Color(0xFF1976D2)),
                                      const SizedBox(width: 12),
                                      Text(
                                        codePiste,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          }
                        }),
                        _buildTextField(
                          controller: _codeGpsController,
                          label: 'Code GPS ',
                          hint: 'Identifiant GPS terrain',
                          required: false,
                        ),
                        _buildTextField(
                          controller: _endroitController,
                          label: 'Endroit ',
                          hint: 'Lieu/localisation',
                          required: false,
                        ),
                      ],
                    ),

                    // ✅ Section Coordonnées (AFFICHAGE SEULEMENT)
                    _buildFormSection(
                      title: '📍 Coordonnées (Auto-calculées)',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildCoordinateDisplay(
                                label: 'X Début chaussée',
                                value: widget.chausseePoints.isNotEmpty ? widget.chausseePoints.first.longitude.toStringAsFixed(8) : 'N/A',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildCoordinateDisplay(
                                label: 'Y Début chaussée',
                                value: widget.chausseePoints.isNotEmpty ? widget.chausseePoints.first.latitude.toStringAsFixed(8) : 'N/A',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCoordinateDisplay(
                                label: 'X Fin chaussée',
                                value: widget.chausseePoints.isNotEmpty ? widget.chausseePoints.last.longitude.toStringAsFixed(8) : 'N/A',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildCoordinateDisplay(
                                label: 'Y Fin chaussée',
                                value: widget.chausseePoints.isNotEmpty ? widget.chausseePoints.last.latitude.toStringAsFixed(8) : 'N/A',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildDateCreationField(),
                    _buildDateModificationField(),
                    _buildReadOnlyField(
                      label: 'Agent enquêteur',
                      icon: Icons.person,
                      value: _userLoginController.text,
                    ),
                    // ✅ Section Caractéristiques (RADIO BUTTONS)
                    _buildFormSection(
                      title: '🛣️ Caractéristiques',
                      children: [
                        _buildRadioGroupField(
                          label: 'Type de chaussée ',
                          value: _typeChaussee,
                          options: _typeChausseeOptions,
                          onChanged: (value) => setState(() => _typeChaussee = value),
                          required: false,
                        ),
                        _buildRadioGroupField(
                          label: 'État de la piste ',
                          value: _etatPiste,
                          options: _etatPisteOptions,
                          onChanged: (value) => setState(() => _etatPiste = value),
                          required: false,
                        ),
                      ],
                    ),

                    // Section GPS (info collecte)
                    _buildFormSection(
                      title: '📱 Données de collecte',
                      children: [
                        _buildGpsInfo(),
                      ],
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),

            // Bouton Sauvegarder
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
                  onPressed: _isLoading ? null : _saveChaussee,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
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
                              'Enregistrer la chaussée',
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
        ),
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
                color: Color(0xFFFF9800),
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
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    bool enabled = true,
  }) {
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
            enabled: enabled,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB), // ← TOUJOURS la même couleur
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)), // ← Même bordure
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFF9800)),
              ),
            ),
            style: const TextStyle(
              // ← Style du texte
              fontSize: 14,
              color: Color(0xFF374151), // ← Même couleur que les champs normaux
            ),
            validator: required
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '$label est obligatoire';
                    }
                    return null;
                  }
                : null,
          ),
        ],
      ),
    );
  }

  // ✅ WIDGET POUR AFFICHAGE DES COORDONNÉES (LECTURE SEULE)
  Widget _buildCoordinateDisplay({
    required String label,
    required String value,
  }) {
    return Column(
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
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.gps_fixed,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ WIDGET POUR RADIO BUTTONS
  Widget _buildRadioGroupField({
    required String label,
    required String? value,
    required List<String> options,
    required Function(String?) onChanged,
    bool required = false,
  }) {
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
            padding: const EdgeInsets.all(12),
            child: Column(
              children: options.map((option) {
                return RadioListTile<String>(
                  title: Text(
                    option,
                    style: const TextStyle(fontSize: 14),
                  ),
                  value: option,
                  groupValue: value,
                  onChanged: onChanged,
                  activeColor: const Color(0xFFFF9800),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              }).toList(),
            ),
          ),
          if (required && (value == null || value.isEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                '$label est obligatoire',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGpsInfo() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gps_fixed, size: 20, color: Color(0xFFFF9800)),
              SizedBox(width: 8),
              Text(
                'Tracé GPS collecté',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF9800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGpsInfoRow('Points collectés:', '${widget.chausseePoints.length}'),
          _buildGpsInfoRow('Distance totale:', '${(_calculateTotalDistance(widget.chausseePoints) / 1000).toStringAsFixed(2)} km'),
          if (widget.chausseePoints.isNotEmpty) ...[
            _buildGpsInfoRow('Premier point:', '${widget.chausseePoints.first.latitude.toStringAsFixed(6)}°, ${widget.chausseePoints.first.longitude.toStringAsFixed(6)}°'),
            _buildGpsInfoRow('Dernier point:', '${widget.chausseePoints.last.latitude.toStringAsFixed(6)}°, ${widget.chausseePoints.last.longitude.toStringAsFixed(6)}°'),
          ],
        ],
      ),
    );
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

  Widget _buildDateCreationField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Date de création *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB), // ← Même couleur que les champs normaux
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Color(0xFF1976D2)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _dateCreation != null
                        ? "${_dateCreation!.day.toString().padLeft(2, '0')}/${_dateCreation!.month.toString().padLeft(2, '0')}/${_dateCreation!.year} "
                            "${_dateCreation!.hour.toString().padLeft(2, '0')}:${_dateCreation!.minute.toString().padLeft(2, '0')}" // ← Ajouter l'heure
                        : "Date/heure automatique",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151), // ← Même couleur de texte
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateModificationField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Date de modification',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: widget.isEditingMode ? () => _selectDateModification(context) : null,
            child: Container(
              decoration: BoxDecoration(
                color: widget.isEditingMode ? const Color(0xFFF9FAFB) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: widget.isEditingMode ? const Color(0xFF1976D2) : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _dateModification != null ? "${_dateModification!.day.toString().padLeft(2, '0')}/${_dateModification!.month.toString().padLeft(2, '0')}/${_dateModification!.year}" : "Sélectionner une date",
                      style: TextStyle(
                        fontSize: 14,
                        color: _dateModification != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
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

  Widget _buildReadOnlyField({
    required String label,
    required IconData icon,
    required String value,
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
                  value,
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
}
