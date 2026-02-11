import 'package:flutter/material.dart';
import '../../controllers/home_controller.dart';

class MapControlsWidget extends StatelessWidget {
  final HomeController controller;
  final VoidCallback onAddPoint;
  final VoidCallback onStartLigne;
  final VoidCallback onStartChaussee;
  final VoidCallback onToggleLigne;
  final VoidCallback onToggleChaussee;
  final VoidCallback onFinishLigne;
  final VoidCallback onFinishChaussee;
  final VoidCallback onRefresh;
  final bool isSpecialCollection;
  final VoidCallback onStopSpecial;

  const MapControlsWidget({
    Key? key,
    required this.controller,
    required this.onAddPoint,
    required this.onStartLigne,
    required this.onStartChaussee,
    required this.onToggleLigne,
    required this.onToggleChaussee,
    required this.onFinishLigne,
    required this.onFinishChaussee,
    required this.onRefresh,
    required this.isSpecialCollection, // ← NOUVEAU
    required this.onStopSpecial, // ← NOUVEAU
  }) : super(key: key);

  @override
  @override
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Bouton Rafraîchir en haut à droite (à ajuster si nécessaire)
        Positioned(
          top: 8,
          right: 55,
          child: FloatingActionButton(
            heroTag: "refreshBtn",
            mini: true,
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            onPressed: onRefresh,
            elevation: 6,
            child: const Icon(Icons.refresh, size: 20),
          ),
        ),

        // Boutons Point, Piste, Chaussée alignés horizontalement en bas
        Positioned(
          bottom: 10,
          left: 0,
          right: 50,
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // BOUTON POINT/ARRÊT (MODIFIÉ)
                if (!controller.hasActiveCollection || controller.specialCollection != null)
                  SizedBox(
                    width: 110,
                    child: isSpecialCollection
                        ? FloatingActionButton.extended(
                            heroTag: "stopSpecialBtn",
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: const Icon(Icons.stop),
                            label: const Text("Arrêt"),
                            onPressed: onStopSpecial,
                            elevation: 6,
                            highlightElevation: 12,
                          )
                        : FloatingActionButton.extended(
                            heroTag: "pointBtn",
                            backgroundColor: const Color(0xFFE53E3E),
                            foregroundColor: Colors.white,
                            icon: const Icon(Icons.place),
                            label: const Text("Point"),
                            onPressed: onAddPoint,
                            elevation: 6,
                            highlightElevation: 12,
                          ),
                  ),
                SizedBox(width: 110, child: _buildLigneControls()),
                SizedBox(width: 110, child: _buildChausseeControls()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLigneControls() {
    final ligneCollection = controller.ligneCollection;

    if (ligneCollection == null || ligneCollection.isInactive) {
      // Bouton démarrer ligne/piste
      return FloatingActionButton.extended(
        heroTag: "ligneBtn",
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.timeline),
        label: const Text("Piste"),
        onPressed: onStartLigne,
        elevation: 6,
        highlightElevation: 12,
      );
    } else {
      // Contrôles ligne active/en pause
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "pauseLigneBtn",
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            onPressed: onToggleLigne,
            mini: true,
            elevation: 4,
            child: Icon(
              ligneCollection.isPaused ? Icons.play_arrow : Icons.pause,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),

          // Bouton stop
          FloatingActionButton(
            heroTag: "stopLigneBtn",
            backgroundColor: const Color(0xFFE53E3E),
            foregroundColor: Colors.white,
            onPressed: onFinishLigne,
            mini: true,
            elevation: 4,
            child: const Icon(Icons.stop, size: 20),
          ),
        ],
      );
    }
  }

  Widget _buildChausseeControls() {
    final chausseeCollection = controller.chausseeCollection;

    if (chausseeCollection == null || chausseeCollection.isInactive) {
      // Bouton démarrer chaussée
      return FloatingActionButton.extended(
        heroTag: "chausseeBtn",
        backgroundColor: const Color(0xFFFF9800),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.alt_route),
        label: const Text("Chaussée"),
        onPressed: onStartChaussee,
        elevation: 6,
        highlightElevation: 12,
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "pauseChausseeBtn",
            backgroundColor: const Color(0xFFFF9800),
            foregroundColor: Colors.white,
            onPressed: onToggleChaussee,
            mini: true,
            elevation: 4,
            child: Icon(
              chausseeCollection.isPaused ? Icons.play_arrow : Icons.pause,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),

          // Bouton stop
          FloatingActionButton(
            heroTag: "stopChausseeBtn",
            backgroundColor: const Color(0xFFE53E3E),
            foregroundColor: Colors.white,
            onPressed: onFinishChaussee,
            mini: true,
            elevation: 4,
            child: const Icon(Icons.stop, size: 20),
          ),
        ],
      );
    }
  }
}
