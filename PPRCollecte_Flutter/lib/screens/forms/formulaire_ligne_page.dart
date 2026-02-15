import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import '../../data/local/piste_chaussee_db_helper.dart';
import '../../data/remote/api_service.dart';
import '../../data/local/database_helper.dart';

class FormulaireLignePage extends StatefulWidget {
  final List<LatLng> linePoints;
  final String? provisionalCode;
  final DateTime? startTime; // 🆕 Heure de début de collecte
  final DateTime? endTime; // 🆕 Heure de fin de collecte
  final String? agentName;
  final Map<String, dynamic>? initialData; // ← NOUVEAU: Données existantes
  final bool isEditingMode; // ← NOUVEAU: Mode édition

  const FormulaireLignePage({
    super.key,
    required this.linePoints,
    this.provisionalCode, // AJOUTER cette ligne
    this.startTime, // 🆕 Passé depuis la page de collecte GPS
    this.endTime, // 🆕 Passé depuis la page de collecte GPS
    this.agentName,
    this.initialData, // ← NOUVEAU
    this.isEditingMode = false, // ← NOUVEAU
  });

  @override
  State<FormulaireLignePage> createState() => _FormulairePageState();
}

class _FormulairePageState extends State<FormulaireLignePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Champs du formulaire selon le MCD
  final _codeController = TextEditingController();
  final _nomOrigineController = TextEditingController();
  final _nomDestinationController = TextEditingController();
  final _xOrigineController = TextEditingController();
  final _yOrigineController = TextEditingController();
  final _xDestinationController = TextEditingController();
  final _yDestinationController = TextEditingController();
  final _userLoginController = TextEditingController();
  final _heureDebutController = TextEditingController();
  final _heureFinController = TextEditingController();
  final _entrepriseController = TextEditingController();
  final _travauxRealisesController = TextEditingController();

  // Évaluation et Priorisation
  final _niveauServiceController = TextEditingController();
  final _fonctionnaliteController = TextEditingController();
  final _interetSocioAdminController = TextEditingController();
  final _populationDesservieController = TextEditingController();
  final _potentielAgricoleController = TextEditingController();
  final _coutInvestissementController = TextEditingController();
  final _protectionEnvController = TextEditingController();
// ===== CHAMPS TERRAIN =====
  final _plateformeController = TextEditingController();
  final _reliefController = TextEditingController();
  final _vegetationController = TextEditingController();
  final _debutTravauxController = TextEditingController();
  final _finTravauxController = TextEditingController();
  final _financementController = TextEditingController();
  final _projetController = TextEditingController();
  double _noteGlobale = 0.0;

  String? _communeRurale;
  String? _typeOccupation;
  DateTime? _debutOccupation;
  DateTime? _finOccupation;
  double? _largeurEmprise; // Largeur de l'emprise de la piste
  String? _frequenceTrafic;
  String? _typeTrafic;
  DateTime? _dateDebutTravaux;
  DateTime? _dateCreation; // ← NOUVEAU
  DateTime? _dateModification;
  String _communeAuto = '';
  // Options pour les dropdowns
  final List<String> _communesRuralesOptions = [
    "Boffa-Centre",
    "Colia",
    "Douprou",
    "Koba-Tatema",
    "Lisso",
    "Mankountan",
    "Tamita",
    "Boké-Centre",
    "Fermessadou-Pombo",
    "Tougnifili",
    "Bintimodiya",
    "Dabiss",
    "Kamsar",
    "Kanfarandé",
    "Kolaboui",
    "Malapouyah",
    "Sangarédi",
    "Sansalé",
    "Baguinet",
    "Banguigny",
    "Fria-Centre",
    "Tormélin",
    "Foulamory",
    "Gaoual-Centre",
    "Kakony",
    "Koumbia",
    "Kounsitel",
    "Malanta",
    "Wendou M'Bour",
    "Saréboido",
    "Banankoro",
    "Guingan",
    "Kamaby",
    "Koundara-Centre",
    "Sambailo",
    "Gnaléah",
    "Termessé",
    "Youkounkoun",
    "Dixinn",
    "Kaloum",
    "Matam",
    "Matoto",
    "Ratoma",
    "Arfamoussaya",
    "Banko",
    "Hérémakonon",
    "Bissikrima",
    "Dabola-Centre",
    "Dogomet",
    "Kankama",
    "Kindoyé",
    "Konindou",
    "N'Déma",
    "Kobikoro",
    "Banora",
    "Diatiféré",
    "Dinguiraye-Centre",
    "Marela",
    "Gagnakaly",
    "Kalinko",
    "Lansanya",
    "Sélouma",
    "Banian",
    "Faranah-Centre",
    "Passayah",
    "Sandéniah",
    "Songoyah",
    "Tiro",
    "Albadariah",
    "Banama",
    "Bardou",
    "Firawa",
    "Gbangbadou",
    "Kissidougou-Centre",
    "Kondiadou",
    "Manfran",
    "Sangardo",
    "Yendé-Millimou",
    "Yombiro",
    "Damaro",
    "Kérouané-Centre",
    "Komodou",
    "Kounsankoro",
    "Linko",
    "Sibiribaro",
    "Soromaya",
    "Balandougou",
    "Baté-Nafadji",
    "Boula",
    "Gbérédou-Baranama",
    "Kanfamoriyah",
    "Kankan-Centre",
    "Kiniéran",
    "Koumban",
    "Mamouroudou",
    "Missamana",
    "Moribayah",
    "Sabadou-Baranama",
    "Tinti-Oulen",
    "Tokounou",
    "Babila",
    "Balato",
    "Banfélé",
    "Baro",
    "Cisséla",
    "Diountou",
    "Douako",
    "Doura",
    "Kiniéro",
    "Komola-Khoura",
    "Koumana",
    "Kouroussa-Centre",
    "Sanguiana",
    "Balandougouba",
    "Faralako",
    "Kantoumanina",
    "Sansando",
    "Koundianakoro",
    "Koundian",
    "Mandiana-Centre",
    "Morodou",
    "Niantanina",
    "Saladou",
    "Bankon",
    "Doko",
    "Franwalia",
    "Kiniébakoura",
    "Kintinian",
    "Maléah",
    "Lafou",
    "Naboun",
    "Niagassola",
    "Niandankoro",
    "Norassoba",
    "Popodara",
    "Siguiri-Centre",
    "Siguirini",
    "Coyah-Centre",
    "Kouriah",
    "Manéah  Coyah",
    "Wonkifong",
    "Badi",
    "Ouassou",
    "Dubréka-Centre",
    "Faléssadé",
    "Khorira",
    "Sannou",
    "Tondon",
    "Alassoya",
    "Benty",
    "Maférinya",
    "Farmoriah",
    "Forécariah-Centre",
    "Kaback",
    "Moussayah",
    "Hérico",
    "Kakossa",
    "Kallia",
    "Korbé",
    "Sikhourou",
    "Bangouyah",
    "Damankanyah",
    "Friguiagbé",
    "Kindia-Centre",
    "Kolenté",
    "Daramagnaky",
    "Lélouma-Centre",
    "Madina-Oula",
    "Mambia",
    "Molota",
    "Samayah",
    "Souguéta",
    "Bourouwal",
    "Gougoudjé",
    "Konsotami",
    "Santou",
    "Sarékaly",
    "Sinta",
    "Sogolon",
    "Télimélé-Centre",
    "Kollet_Kindia",
    "Koba_Mamou",
    "Tarihoye",
    "Thionthian",
    "Fafaya",
    "Gadha-Woundou",
    "Koubia-Centre",
    "Matakaou",
    "Pilimini",
    "Balaya",
    "Linsan-Saran",
    "Manda",
    "Parawol",
    "Sagalé",
    "Tyanguel-Bori",
    "Dalein",
    "Diari",
    "Dionfo",
    "Hafia",
    "Kaalan",
    "Noussy",
    "Unknown",
    "Balaki",
    "Donghol-Sigon",
    "Dougountouny",
    "Fougou",
    "Gayah",
    "Hidayatou",
    "Lébékéren",
    "Madina-Wora",
    "Mali-Centre",
    "Salambandé",
    "Téliré",
    "Yimbéring",
    "Fatako",
    "Fello-Koundoua",
    "Kansangui",
    "Koïn",
    "Kolangui",
    "Konah",
    "Kouratongo",
    "Tangali",
    "Tougué-Centre",
    "Bodié",
    "Dalaba-Centre",
    "Ditinn",
    "Kébali",
    "Kaala",
    "Kankalabé",
    "Koba",
    "Mafara",
    "Mitty",
    "Mombéyah",
    "Bouliwel",
    "Dounet",
    "Gongoret",
    "Kégnéko",
    "Konkouré",
    "Mamou-Centre",
    "Nyagara",
    "Ouré-Kaba",
    "Porédaka",
    "Saramoussayah",
    "Soyah",
    "Ninguélandé",
    "Téguéréyah",
    "Timbo",
    "Tolo",
    "Bantignel",
    "Bourouwal-Tappé",
    "Dongol-Touma",
    "Gongore",
    "Ley-Miro",
    "Maci",
    "Pita-Centre",
    "Sangaréah",
    "Sintali",
    "Timbi-Madina",
    "Timbi-Touni",
    "Beyla-Centre",
    "Boola",
    "Sokourala",
    "Diaraguéréla",
    "Diassodou",
    "Fouala",
    "Gbakédou",
    "Gbessoba",
    "Bolodou",
    "Karala",
    "Koumandou",
    "Moussadou",
    "Nionsomoridou",
    "Samana",
    "Sinko",
    "Fangamadou",
    "Guéckédou-Centre",
    "Guendembou",
    "Kassadou",
    "Koundou",
    "Nongoa",
    "Ouendé-Kénéma",
    "Tékoulo",
    "Termessadou-Dibo",
    "Bossou",
    "Foumbadou",
    "Gama-Béréma",
    "Bofossou",
    "Guéassou",
    "Kokota",
    "Lainé",
    "Lola-Centre",
    "N'Zoo",
    "Tounkarata",
    "Balizia",
    "Binikala",
    "Daro",
    "Fassankoni",
    "Kouankan",
    "Koyamah",
    "Macenta-Centre",
    "N'Zébéla",
    "Soulouta",
    "Ourémaï",
    "Panziazou",
    "Sérédou",
    "Sengbédou",
    "Vassérédou",
    "Watanka",
    "Bounouma",
    "Gouécké",
    "Kobéla",
    "Koropara",
    "Koulé",
    "N'Zérékoré-Centre",
    "Palé",
    "Samoé",
    "Womey",
    "Yalenzou",
    "Banié",
    "Bheeta",
    "Bignamou",
    "Bowé",
    "Diécké",
    "Péla",
    "Yomou-Centre",
    "Missira_Boke",
    "Missira_Labe",
    "Beindou_01_Faranah",
    "Beindou_02_Faranah",
    "Tanéné_Boke",
    "Tanéné_Kindia",
    "Kollet_Labe",
    "Dialakoro_Faranah",
    "Dialakoro_Kankan",
    "Touba_Boke",
    "Touba_Labe"
  ];

  final List<String> _typeOccupationOptions = [
    "Urbain",
    "Semi Urbain",
    "Rural",
    "Rizipiscicole",
    "Autre"
  ];

  final List<String> _typeTraficOptions = [
    "Véhicules Légers",
    "Poids Lourds",
    "Motos",
    "Piétons",
    "Autre"
  ];

  final List<String> _frequenceTraficOptions = [
    "Quotidien",
    "Hebdomadaire",
    "Mensuel",
    "Saisonnier"
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _setupNoteGlobaleListeners();
  }

  void _setupNoteGlobaleListeners() {
    final controllers = [
      _niveauServiceController,
      _fonctionnaliteController,
      _interetSocioAdminController,
      _populationDesservieController,
      _potentielAgricoleController,
      _coutInvestissementController,
      _protectionEnvController,
    ];

    for (var controller in controllers) {
      controller.addListener(_calculateNoteGlobale);
    }
  }

  void _calculateNoteGlobale() {
    double ns = double.tryParse(_niveauServiceController.text) ?? 0.0;
    double fo = double.tryParse(_fonctionnaliteController.text) ?? 0.0;
    double isa = double.tryParse(_interetSocioAdminController.text) ?? 0.0;
    double p = double.tryParse(_populationDesservieController.text) ?? 0.0;
    double pa = double.tryParse(_potentielAgricoleController.text) ?? 0.0;
    double ci = double.tryParse(_coutInvestissementController.text) ?? 0.0;
    double pe = double.tryParse(_protectionEnvController.text) ?? 0.0;

    setState(() {
      _noteGlobale = (0.05 * ns) + (0.05 * fo) + (0.15 * isa) + (0.20 * p) + (0.30 * pa) + (0.20 * ci) + (0.05 * pe);
    });
  }

  void _initializeForm() {
    if (widget.isEditingMode && widget.initialData != null) {
      _fillFormWithExistingData();
    }
    if (widget.provisionalCode != null) {
      _codeController.text = widget.provisionalCode!;
    }
    _determineCommuneAuto();
    // Récupérer automatiquement l'utilisateur connecté et l'heure actuelle
    _userLoginController.text = widget.agentName ?? _getCurrentUser(); // À implémenter selon votre système d'auth
    // Date de création = maintenant par défaut
    _dateCreation = DateTime.now();

    // Date de modification = maintenant (automatique)
    _dateModification = null;
    if (widget.startTime != null) {
      final startTime = TimeOfDay.fromDateTime(widget.startTime!);
      _heureDebutController.text = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";
    } else {
      // Fallback : heure actuelle
      final now = TimeOfDay.now();
      _heureDebutController.text = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    }

    // 🚀 NOUVEAU : Heure de fin automatique
    if (widget.endTime != null) {
      final endTime = TimeOfDay.fromDateTime(widget.endTime!);
      _heureFinController.text = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}";
    } else {
      // Cas exceptionnel : utiliser l'heure actuelle comme fallback
      final now = TimeOfDay.now();
      _heureFinController.text = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    }

    // Calculer et remplir automatiquement les coordonnées d'origine et destination
    if (widget.linePoints.isNotEmpty) {
      final firstPoint = widget.linePoints.first;
      final lastPoint = widget.linePoints.last;

      _xOrigineController.text = firstPoint.longitude.toStringAsFixed(6);
      _yOrigineController.text = firstPoint.latitude.toStringAsFixed(6);
      _xDestinationController.text = lastPoint.longitude.toStringAsFixed(6);
      _yDestinationController.text = lastPoint.latitude.toStringAsFixed(6);
    }
  }

  void _fillFormWithExistingData() {
    final data = widget.initialData!;

    setState(() {
      _codeController.text = data['code_piste'] ?? '';
      _communeRurale = data['commune_rurale_id'];
      _userLoginController.text = data['user_login'] ?? '';
      _heureDebutController.text = data['heure_debut'] ?? '';
      _heureFinController.text = data['heure_fin'] ?? '';
      _nomOrigineController.text = data['nom_origine_piste'] ?? '';
      _xOrigineController.text = data['x_origine']?.toString() ?? '';
      _yOrigineController.text = data['y_origine']?.toString() ?? '';
      _nomDestinationController.text = data['nom_destination_piste'] ?? '';
      _xDestinationController.text = data['x_destination']?.toString() ?? '';
      _yDestinationController.text = data['y_destination']?.toString() ?? '';
      _typeOccupation = data['type_occupation'];
      _debutOccupation = data['debut_occupation'] != null ? DateTime.parse(data['debut_occupation']) : null;
      _finOccupation = data['fin_occupation'] != null ? DateTime.parse(data['fin_occupation']) : null;
      _largeurEmprise = data['largeur_emprise'];
      _frequenceTrafic = data['frequence_trafic'];
      _typeTrafic = data['type_trafic'];
      _travauxRealisesController.text = data['travaux_realises'] ?? '';
      _dateDebutTravaux = data['date_travaux'] != null ? DateTime.parse(data['date_travaux']) : null;
      _entrepriseController.text = data['entreprise'] ?? '';
      _dateCreation = data['created_at'] != null ? DateTime.parse(data['created_at']) : null;
      _dateModification = DateTime.now(); // ← Date modif actuelle

      _niveauServiceController.text = data['niveau_service']?.toString() ?? '';
      _fonctionnaliteController.text = data['fonctionnalite']?.toString() ?? '';
      _interetSocioAdminController.text = data['interet_socio_administratif']?.toString() ?? '';
      _populationDesservieController.text = data['population_desservie']?.toString() ?? '';
      _potentielAgricoleController.text = data['potentiel_agricole']?.toString() ?? '';
      _coutInvestissementController.text = data['cout_investissement']?.toString() ?? '';
      _protectionEnvController.text = data['protection_environnement']?.toString() ?? '';
      _noteGlobale = data['note_globale']?.toDouble() ?? 0.0;
      // ===== CHAMPS TERRAIN =====
      _plateformeController.text = data['plateforme'] ?? '';
      _reliefController.text = data['relief'] ?? '';
      _vegetationController.text = data['vegetation'] ?? '';
      _debutTravauxController.text = data['debut_travaux'] ?? '';
      _finTravauxController.text = data['fin_travaux'] ?? '';
      _financementController.text = data['financement'] ?? '';
      _projetController.text = data['projet'] ?? '';
    });
  }

  void _determineCommuneAuto() {
    // 1. Essayer d'abord depuis l'API
    if (ApiService.communeNom != null) {
      _communeAuto = ApiService.communeNom!;
      _communeRurale = _communeAuto;
      print('📍 Commune API: $_communeAuto');
      return;
    }

    // 2. Si pas d'API, essayer base locale (mais sans async)
    _communeAuto = 'Non spécifié'; // Valeur par défaut
    _communeRurale = 'Non spécifié';

    // Chargement asynchrone sans attendre
    _loadCommuneFromDatabase();
  }

  void _loadCommuneFromDatabase() async {
    try {
      final currentUser = await DatabaseHelper().getCurrentUser();
      if (currentUser != null && currentUser['commune_nom'] != null) {
        final commune = currentUser['commune_nom'] as String;
        setState(() {
          _communeAuto = commune;
          _communeRurale = commune;
        });
        print('📍 Commune base locale: $commune');
      }
    } catch (e) {
      print('❌ Erreur chargement commune: $e');
    }
  }

  // Méthode pour récupérer l'utilisateur actuel
  String _getCurrentUser() {
    // je vais complèter ça après

    return 'user_demo'; // Valeur temporaire pour test
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
    // Formule de Haversine
    const double p = 0.017453292519943295; // pi/180

    final dLat = (point2.latitude - point1.latitude) * p;
    final dLon = (point2.longitude - point1.longitude) * p;

    final a = sin(dLat / 2) * sin(dLat / 2) + cos(point1.latitude * p) * cos(point2.latitude * p) * sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return 6371000 * c; // Rayon de la Terre en mètres
  }

  Future<DateTime?> _showDatePickerWithValidation(BuildContext context, DateTime initialDate) async {
    return await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      selectableDayPredicate: (DateTime day) {
        // Bloquer les dates passées
        return !day.isBefore(DateTime.now().subtract(const Duration(days: 1)));
      },
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1976D2), // Couleur principale
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await _showDatePickerWithValidation(context, DateTime.now());

    if (picked != null) {
      setState(() {
        _dateDebutTravaux = picked;
      });
    }
  }

  Future<void> _selectOccupationDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await _showDatePickerWithValidation(context, DateTime.now());

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _debutOccupation = picked;
        } else {
          _finOccupation = picked;
        }
      });
    }
  }

  Future<void> _savePiste() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 1));
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();

      if (loginId == null) {
        print('❌ [_savePiste] Impossible de déterminer login_id');
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
      int? communeRuralesId;
      /* GPS-BASED ATTRIBUTION: 
         The commune is now determined by the backend during sync 
         based on the coordinates. We don't force the user's home commune anymore.
      
      if (ApiService.communeId != null) {
        // En ligne : utiliser l'API
        communeRuralesId = ApiService.communeId;
      } else {
        // Hors ligne : utiliser la base locale
        final currentUser = await DatabaseHelper().getCurrentUser();
        communeRuralesId = currentUser?['communes_rurales'] as int?;
      }
      */
      communeRuralesId = null; // Backend will handle this via ST_Contains during sync

      final pisteData = {
        // ✅ L'ID sera auto-généré par la BDD, ne pas l'inclure ici
        if (widget.isEditingMode) 'id': widget.initialData!['id'],
        'code_piste': _codeController.text,
        'commune_rurale_id': _communeRurale,
        'commune_rurales': communeRuralesId,
        'user_login': widget.agentName,
        'heure_debut': _heureDebutController.text,
        'heure_fin': _heureFinController.text,
        'nom_origine_piste': _nomOrigineController.text,
        'nom_destination_piste': _nomDestinationController.text,
        'type_occupation': _typeOccupation,
        'debut_occupation': _debutOccupation?.toIso8601String(),
        'fin_occupation': _finOccupation?.toIso8601String(),
        'largeur_emprise': _largeurEmprise,
        'frequence_trafic': _frequenceTrafic,
        'type_trafic': _typeTrafic,
        'travaux_realises': _travauxRealisesController.text.isNotEmpty ? _travauxRealisesController.text : null,
        'date_travaux': _dateDebutTravaux?.toIso8601String(),
        'entreprise': _entrepriseController.text.isNotEmpty ? _entrepriseController.text : null,
        'niveau_service': double.tryParse(_niveauServiceController.text),
        'fonctionnalite': double.tryParse(_fonctionnaliteController.text),
        'interet_socio_administratif': double.tryParse(_interetSocioAdminController.text),
        'population_desservie': double.tryParse(_populationDesservieController.text),
        'potentiel_agricole': double.tryParse(_potentielAgricoleController.text),
        'cout_investissement': double.tryParse(_coutInvestissementController.text),
        'protection_environnement': double.tryParse(_protectionEnvController.text),
        'note_globale': _noteGlobale,
        // ===== CHAMPS TERRAIN =====
        'plateforme': _plateformeController.text.isNotEmpty ? _plateformeController.text : null,
        'relief': _reliefController.text.isNotEmpty ? _reliefController.text : null,
        'vegetation': _vegetationController.text.isNotEmpty ? _vegetationController.text : null,
        'debut_travaux': _debutTravauxController.text.isNotEmpty ? _debutTravauxController.text : null,
        'fin_travaux': _finTravauxController.text.isNotEmpty ? _finTravauxController.text : null,
        'financement': _financementController.text.isNotEmpty ? _financementController.text : null,
        'projet': _projetController.text.isNotEmpty ? _projetController.text : null,

        // ✅ TOUS les points de la piste (MultiLineString)
        'points': widget.linePoints
            .map((p) => {
                  'latitude': p.latitude,
                  'longitude': p.longitude,
                })
            .toList(),

        // ✅ Coordonnées EXTRACTIVES (depuis les points, pas les TextFields)
        'x_origine': widget.linePoints.first.latitude, // ← Premier point
        'y_origine': widget.linePoints.first.longitude, // ← Premier point
        'x_destination': widget.linePoints.last.latitude, // ← Dernier point
        'y_destination': widget.linePoints.last.longitude, // ← Dernier point

        // ✅ Dates
        'created_at': widget.initialData != null ? widget.initialData!['created_at'] : DateTime.now().toIso8601String(),
        'updated_at': widget.initialData != null
            ? DateTime.now().toIso8601String() // seulement si modification
            : null,
        'is_editing': widget.isEditingMode,

        'sync_status': 'pending',
        'login_id': loginId,
      };
      print('🔍 Données envoyées à savePiste:');
      print('   commune_rurale_id (nom): ${pisteData['commune_rurale_id']}');
      print('   commune_rurales (id): ${pisteData['commune_rurales']}');
      final storageHelper = SimpleStorageHelper();
      if (widget.isEditingMode) {
        // ✅ MODE ÉDITION: Mise à jour
        await storageHelper.updatePiste(pisteData);
        print('✅ Piste "${pisteData['code_piste']}" mise à jour (ID: ${pisteData['id']})');
      } else {
        final savedId = await storageHelper.savePiste(pisteData);
        if (savedId != null) {
          print('✅ Piste sauvegardée en local avec ID: $savedId');
          await storageHelper.debugPrintAllPistes();
          await storageHelper.saveDisplayedPiste(_codeController.text, widget.linePoints, Colors.blue, 4.0);
        }
      }

      if (mounted) {
        Navigator.of(context).pop(pisteData);
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

  Future<void> _showCommuneSearchDialog() async {
    final TextEditingController searchController = TextEditingController();
    List<String> filteredCommunes = _communesRuralesOptions;

    final String? selectedCommune = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Rechercher une commune'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Tapez pour rechercher...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (query) {
                        setState(() {
                          if (query.isEmpty) {
                            filteredCommunes = _communesRuralesOptions;
                          } else {
                            filteredCommunes = _communesRuralesOptions.where((commune) => commune.toLowerCase().contains(query.toLowerCase())).toList();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      width: 400,
                      child: filteredCommunes.isEmpty
                          ? const Center(
                              child: Text('Aucune commune trouvée'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredCommunes.length,
                              itemBuilder: (context, index) {
                                final commune = filteredCommunes[index];
                                return ListTile(
                                  title: Text(commune),
                                  onTap: () {
                                    Navigator.of(context).pop(commune);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedCommune != null) {
      setState(() {
        _communeRurale = selectedCommune;
      });
    }
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
      _nomOrigineController.clear();
      _entrepriseController.clear();
      _travauxRealisesController.clear();
      _niveauServiceController.clear();
      _fonctionnaliteController.clear();
      _interetSocioAdminController.clear();
      _populationDesservieController.clear();
      _potentielAgricoleController.clear();
      _coutInvestissementController.clear();
      _protectionEnvController.clear();
      _noteGlobale = 0.0;
      // ===== CHAMPS TERRAIN =====
      _plateformeController.clear();
      _reliefController.clear();
      _vegetationController.clear();
      _debutTravauxController.clear();
      _finTravauxController.clear();
      _financementController.clear();
      _projetController.clear();

      _entrepriseController.clear();

      // Réinitialiser les sélections

      _typeOccupation = null;
      _debutOccupation = null;
      _finOccupation = null;
      _largeurEmprise = null;
      _frequenceTrafic = null;
      _typeTrafic = null;
      _dateDebutTravaux = null;

      // Garder les champs en lecture seule (ils seront réinitialisés automatiquement)
      // _codeController - Garder le code piste
      // _userLoginController - Garder le nom de l'agent
      // _heureDebutController - Garder l'heure de début
      // _heureFinController - Garder l'heure de fin
      // _xOrigineController - Garder les coordonnées
      // _yOrigineController - Garder les coordonnées
      // _xDestinationController - Garder les coordonnées
      // _yDestinationController - Garder les coordonnées
      // _dateCreation - Garder la date de création
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Formulaire effacé'),
        duration: Duration(seconds: 2),
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
            // Remplacer tout le header actuel par ceci :
// Header du formulaire - Style React Native
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1976D2),
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
                    onPressed: () => _confirmExit(), // ← On va créer cette méthode
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    padding: const EdgeInsets.all(8),
                  ),
                  const Expanded(
                    child: Text(
                      "🛤️ Formulaire Piste",
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
                  ), // Équilibrer avec le bouton back
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
                        _buildTextField(
                          controller: _codeController,
                          label: 'Code Piste *',
                          hint: 'Code unique de la piste',
                          required: true,
                          enabled: false,
                        ),
                        _buildReadOnlyCommuneField(),
                        _buildDateCreationField(),
                        _buildDateModificationField(),
                        // Remplacer le TextField "Utilisateur" par :
                        _buildReadOnlyField(
                          label: 'Agent enquêteur',
                          icon: Icons.person,
                          value: _userLoginController.text,
                        ),
                        //  la section des heures - les deux en lecture seule
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimeField(
                                label: 'Heure Début',
                                controller: _heureDebutController,
                                enabled: false, // 🔒 Lecture seule
                                // onTap supprimé car non nécessaire
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTimeField(
                                label: 'Heure Fin',
                                controller: _heureFinController,
                                enabled: false, // 🔒 Lecture seule
                                // onTap supprimé car non nécessaire
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Section Points
                    _buildFormSection(
                      title: '🎯 Points de la Piste',
                      children: [
                        _buildTextField(
                          controller: _nomOrigineController,
                          label: 'Nom Origine *',
                          hint: 'Point de départ de la piste',
                          required: true,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _xOrigineController,
                                label: 'X Origine',
                                hint: 'Longitude origine',
                                keyboardType: TextInputType.number,
                                enabled: false, // CORRECTION : Lecture seule
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _yOrigineController,
                                label: 'Y Origine',
                                hint: 'Latitude origine',
                                keyboardType: TextInputType.number,
                                enabled: false, // CORRECTION : Lecture seule
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _nomDestinationController,
                          label: 'Nom Destination *',
                          hint: 'Point d\'arrivée de la piste',
                          required: true,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _xDestinationController,
                                label: 'X Destination',
                                hint: 'Longitude destination',
                                keyboardType: TextInputType.number,
                                enabled: false, // CORRECTION : Lecture seule
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _yDestinationController,
                                label: 'Y Destination',
                                hint: 'Latitude destination',
                                keyboardType: TextInputType.number,
                                enabled: false, // CORRECTION : Lecture seule
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Section Occupation
                    _buildFormSection(
                      title: '🏘️ Occupation du Sol',
                      children: [
                        _buildRadioGroupField(
                          label: 'Type d\'Occupation',
                          value: _typeOccupation,
                          options: _typeOccupationOptions,
                          onChanged: (value) => setState(() => _typeOccupation = value),
                        ),
                        Column(
                          children: [
                            _buildDateField(
                              label: 'Début Occupation',
                              value: _debutOccupation,
                              onTap: () => _selectOccupationDate(context, true),
                            ),
                            _buildDateField(
                              label: 'Fin Occupation',
                              value: _finOccupation,
                              onTap: () => _selectOccupationDate(context, false),
                            ),
                          ],
                        ),
                        _buildTextFieldWithCallback(
                          controller: TextEditingController(text: _largeurEmprise?.toString() ?? ''),
                          label: 'Largeur Emprise (m)',
                          hint: 'Largeur de l\'emprise en mètres',
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _largeurEmprise = double.tryParse(value),
                        ),
                      ],
                    ),

                    // REMPLACER TOUTE LA SECTION PAR :
                    _buildFormSection(
                      title: '🚗 Caractéristiques du Trafic',
                      children: [
                        _buildRadioGroupField(
                          label: 'Fréquence du Trafic',
                          value: _frequenceTrafic,
                          options: _frequenceTraficOptions,
                          onChanged: (value) => setState(() => _frequenceTrafic = value),
                        ),
                        _buildRadioGroupField(
                          label: 'Type de Trafic',
                          value: _typeTrafic,
                          options: _typeTraficOptions,
                          onChanged: (value) => setState(() => _typeTrafic = value),
                        ),
                      ],
                    ),

                    // Section Évaluation et Priorisation
                    _buildFormSection(
                      title: '📊 Évaluation et Priorisation',
                      children: [
                        _buildTextField(
                          controller: _niveauServiceController,
                          label: 'Niveau de service (NS)',
                          hint: 'Note (0-10)',
                          keyboardType: TextInputType.number,
                        ),
                        _buildTextField(
                          controller: _fonctionnaliteController,
                          label: 'Fonctionnalité (FO)',
                          hint: 'Note (0-10)',
                          keyboardType: TextInputType.number,
                        ),
                        _buildTextField(
                          controller: _interetSocioAdminController,
                          label: 'Intérêt socio-administratif (ISA)',
                          hint: 'Note (0-10)',
                          keyboardType: TextInputType.number,
                        ),
                        _buildTextField(
                          controller: _populationDesservieController,
                          label: 'Population desservie (P)',
                          hint: 'Note (0-10)',
                          keyboardType: TextInputType.number,
                        ),
                        _buildTextField(
                          controller: _potentielAgricoleController,
                          label: 'Potentiel agricole (PA)',
                          hint: 'Note (0-10)',
                          keyboardType: TextInputType.number,
                        ),
                        _buildTextField(
                          controller: _coutInvestissementController,
                          label: 'Coût d’investissement (CI)',
                          hint: 'Note (0-10)',
                          keyboardType: TextInputType.number,
                        ),
                        _buildTextField(
                          controller: _protectionEnvController,
                          label: 'Protection de l’environnement (PE)',
                          hint: 'Note (0-10)',
                          keyboardType: TextInputType.number,
                        ),
                        const Divider(height: 32, thickness: 1, color: Colors.blueAccent),
                        _buildReadOnlyField(
                          label: 'Note Globale (NG)',
                          icon: Icons.star,
                          value: _noteGlobale.toStringAsFixed(2),
                        ),
                      ],
                    ),

                    // Section Travaux
                    _buildFormSection(
                      title: '🔧 Travaux',
                      children: [
                        _buildTextField(
                          controller: _travauxRealisesController,
                          label: 'Travaux réalisés',
                          hint: 'Description des travaux réalisés',
                          maxLines: 3,
                        ),
                        _buildDateField(
                          label: 'Date des Travaux',
                          value: _dateDebutTravaux,
                          onTap: () => _selectDate(context, true),
                        ),
                        _buildTextField(
                          controller: _entrepriseController,
                          label: 'Entreprise',
                          hint: 'Nom de l\'entreprise',
                        ),
                      ],
                    ),
// Section Caractéristiques Terrain
                    _buildFormSection(
                      title: '🌍 Caractéristiques Terrain',
                      children: [
                        _buildTextField(
                          controller: _plateformeController,
                          label: 'Plateforme',
                          hint: 'Ex: Latérite, Terre, Sable...',
                        ),
                        _buildTextField(
                          controller: _reliefController,
                          label: 'Relief',
                          hint: 'Ex: Plat, Vallonné, Montagneux...',
                        ),
                        _buildTextField(
                          controller: _vegetationController,
                          label: 'Végétation',
                          hint: 'Ex: Savane, Forêt, Steppe...',
                        ),
                        _buildTextField(
                          controller: _financementController,
                          label: 'Financement',
                          hint: 'Source de financement',
                        ),
                        _buildTextField(
                          controller: _projetController,
                          label: 'Projet',
                          hint: 'Nom du projet',
                        ),
                        _buildTextField(
                          controller: _debutTravauxController,
                          label: 'Début des travaux',
                          hint: 'Ex: 2024',
                        ),
                        _buildTextField(
                          controller: _finTravauxController,
                          label: 'Fin des travaux',
                          hint: 'Ex: 2025',
                        ),
                      ],
                    ),
                    // Section GPS
                    _buildFormSection(
                      title: '📍 Géolocalisation',
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
                  onPressed: _isLoading ? null : _savePiste,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
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
                              'Enregistrer la Piste',
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

// AJOUTER cette méthode
  Widget _buildReadOnlyCommuneField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Commune Rurale *',
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 20, color: Color(0xFF1976D2)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _communeRurale ?? 'Non spécifié',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
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
                    style: TextStyle(
                      fontSize: 14,
                      color: _dateCreation != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
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
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
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
            keyboardType: keyboardType,
            maxLines: maxLines,
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
                borderSide: const BorderSide(color: Color(0xFF1976D2)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(
              // ← Style du texte
              fontSize: 14,
              color: Color(0xFF374151), // ← Même couleur que les champs normaux
            ),
            textAlignVertical: maxLines > 1 ? TextAlignVertical.top : null,
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

  Widget _buildTextFieldWithCallback({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    Function(String)? onChanged,
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
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: onChanged,
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
            ),
            textAlignVertical: maxLines > 1 ? TextAlignVertical.top : null,
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

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required Function(String?) onChanged,
    bool required = false,
  }) {
    final bool isCommuneRurale = label == 'Commune Rurale *';

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
          if (isCommuneRurale)
            // Bouton spécial pour la commune avec recherche
            InkWell(
              onTap: _showCommuneSearchDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value ?? 'Sélectionner une commune',
                        style: TextStyle(
                          fontSize: 14,
                          color: value != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    const Icon(Icons.search, color: Color(0xFF666666)),
                  ],
                ),
              ),
            )
          else
            // Dropdown normal pour les autres champs
            DropdownButtonFormField<String>(
              value: value,
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              isExpanded: true,
              menuMaxHeight: 300,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF666666)),
              borderRadius: BorderRadius.circular(8),
              decoration: InputDecoration(
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
              ),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
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
          GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: Color(0xFF666666)),
                  const SizedBox(width: 12),
                  Text(
                    value != null ? "${value.day}/${value.month}/${value.year}" : "Sélectionner une date",
                    style: TextStyle(
                      fontSize: 14,
                      color: value != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
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

  Widget _buildTimeField({
    required String label,
    required TextEditingController controller,
    VoidCallback? onTap,
    bool enabled = true,
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
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB), // ← Même couleur de fond
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)), // ← Même bordure
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: 20,
                color: enabled ? const Color(0xFF666666) : const Color(0xFF666666), // ← Même couleur d'icône
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  controller.text.isEmpty ? "Heure automatique" : controller.text,
                  style: const TextStyle(
                    // ← Même style de texte
                    fontSize: 14,
                    color: Color(0xFF374151), // ← Même couleur de texte
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGpsInfo() {
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
                'Tracé GPS collecté',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1976D2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGpsInfoRow('Points collectés:', '${widget.linePoints.length}'),
          _buildGpsInfoRow('Distance totale:', '${(_calculateTotalDistance(widget.linePoints) / 1000).toStringAsFixed(2)} km'),
          if (widget.linePoints.isNotEmpty) ...[
            _buildGpsInfoRow('Premier point:', '${widget.linePoints.first.latitude.toStringAsFixed(6)}°, ${widget.linePoints.first.longitude.toStringAsFixed(6)}°'),
            _buildGpsInfoRow('Dernier point:', '${widget.linePoints.last.latitude.toStringAsFixed(6)}°, ${widget.linePoints.last.longitude.toStringAsFixed(6)}°'),
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
                  activeColor: const Color(0xFF1976D2),
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
}
