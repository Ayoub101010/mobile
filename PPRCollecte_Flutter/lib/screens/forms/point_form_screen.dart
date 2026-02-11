import 'package:flutter/material.dart';
import '../../widgets/forms/category_selector_widget.dart';
import '../../widgets/forms/type_selector_widget.dart';
import '../../widgets/forms/point_form_widget.dart';

Color _categoryColor(String category) {
  switch (category.toLowerCase()) {
    case "infrastructures rurales":
      return Colors.green;
    case "ouvrages":
      return Colors.orange;
    case "points critiques":
      return Colors.red;
    default:
      return Colors.blueGrey;
  }
}

class PointFormScreen extends StatefulWidget {
  final Map<String, dynamic>? pointData;
  final String? agentName;
  final String? nearestPisteCode;
  final Function(String)? onSpecialTypeSelected; // ← AJOUTEZ CETTE LIGNE
  final Function(String)? onTypeSelected; // ← AJOUTEZ CETTE LIGNE
  const PointFormScreen({
    super.key,
    this.pointData,
    this.agentName,
    this.nearestPisteCode,
    this.onSpecialTypeSelected, // ← AJOUTEZ CETTE LIGNE
    this.onTypeSelected,
  });

  @override
  State<PointFormScreen> createState() => _PointFormScreenState();
}

class _PointFormScreenState extends State<PointFormScreen> {
  String? selectedCategory;
  String? selectedType;

  _handleBack() {
    if (selectedType != null) {
      // 👉 On est dans le formulaire (un type est sélectionné)
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
                // Fermer la boîte de dialogue
                Navigator.of(context).pop();
                // Revenir à la liste des types (et pas à HomePage)
                setState(() {
                  selectedType = null;
                });
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Abandonner"),
            ),
          ],
        ),
      );
    } else if (selectedCategory != null) {
      // 👉 On est sur la page des TYPES (Infrastructures Rurales, Ouvrages...)
      //    → Retour vers la page des 3 catégories
      setState(() {
        selectedCategory = null;
        selectedType = null;
      });
    } else {
      // 👉 On est sur la page des 3 catégories
      //    → Retour vers HomePage
      Navigator.of(context).pop();
    }
  }

  void _onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
      selectedType = null;
    });
  }

  // Dans TypeSelectorWidget
  void _onTypeSelected(String type) {
    if (type == "Bac" || type == "Passage Submersible") {
      // Retourner à la carte pour la collecte spéciale
      Navigator.of(context).pop();
      // Démarrer la collecte spéciale
      if (widget.onSpecialTypeSelected != null) {
        widget.onSpecialTypeSelected!(type);
      }
    } else {
      // Ouvrir le formulaire normal
      setState(() {
        selectedType = type;
      });
    }
  }

  void _onBackToCategories() {
    setState(() {
      selectedCategory = null;
      selectedType = null;
    });
  }

  void _onBackToTypes() {
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
              // Fermer la boîte de dialogue
              Navigator.of(context).pop();
              // Revenir à la liste des types
              setState(() {
                selectedType = null;
              });
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
      backgroundColor: const Color(0xFFF0F8FF), // Même couleur que React Native
      body: SafeArea(
        child: Column(
          children: [
            // Header - Style exactement comme React Native
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
                    onPressed: _handleBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    padding: const EdgeInsets.all(8),
                  ),
                  const Expanded(
                    child: Text(
                      "🎯 Point d'Intérêt",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 40), // Équilibrer avec le bouton back
                ],
              ),
            ),

            // Contenu dynamique
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (selectedCategory == null) {
      return CategorySelectorWidget(
        onCategorySelected: _onCategorySelected,
      );
    } else if (selectedType == null) {
      // Page des types d'infrastructures : on ajoute un sous-titre
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: Text(
              selectedCategory!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _categoryColor(selectedCategory!),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TypeSelectorWidget(
              category: selectedCategory!,
              onTypeSelected: _onTypeSelected,
              onBack: _onBackToCategories,
            ),
          ),
        ],
      );
    } else {
      return PointFormWidget(
        category: selectedCategory!,
        type: selectedType!,
        pointData: widget.pointData,
        onBack: _onBackToTypes,
        onSaved: () {
          Navigator.of(context).pop();
        },
        agentName: widget.agentName,
        nearestPisteCode: widget.nearestPisteCode,
      );
    }
  }
}
