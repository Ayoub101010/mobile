import 'package:flutter/material.dart';
import '../../models/collection_models.dart';

class LigneStatusWidget extends StatelessWidget {
  final LigneCollection collection;
  final double? topOffset;

  const LigneStatusWidget({
    super.key,
    required this.collection,
    this.topOffset,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topOffset ?? 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: collection.isActive ? const Color(0xFF1976D2) : Colors.orange,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 2),
              blurRadius: 4,
            )
          ],
        ),
        child: Row(
          children: [
            Icon(
              collection.isActive ? Icons.radio_button_checked : Icons.pause_circle_filled,
              color: collection.isActive ? const Color(0xFF1976D2) : Colors.orange,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                collection.isActive ? "Collecte piste active" : "Piste en pause",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
              ),
            ),
            Text(
              "${collection.points.length} pts • ${collection.totalDistance.round()}m",
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}

class ChausseeStatusWidget extends StatelessWidget {
  final ChausseeCollection collection;
  final double? topOffset;

  const ChausseeStatusWidget({
    super.key,
    required this.collection,
    this.topOffset,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topOffset ?? 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: collection.isActive ? const Color(0xFFFF9800) : Colors.deepOrange,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 2),
              blurRadius: 4,
            )
          ],
        ),
        child: Row(
          children: [
            Icon(
              collection.isActive ? Icons.radio_button_checked : Icons.pause_circle_filled,
              color: collection.isActive ? const Color(0xFFFF9800) : Colors.deepOrange,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                collection.isActive ? "Collecte chaussée active" : "Chaussée en pause",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
              ),
            ),
            Text(
              "${collection.points.length} pts • ${collection.totalDistance.round()}m",
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}

// Ajouter après ChausseeStatusWidget
class SpecialStatusWidget extends StatelessWidget {
  final SpecialCollection collection;
  final double? topOffset;

  const SpecialStatusWidget({
    super.key,
    required this.collection,
    this.topOffset,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topOffset ?? 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF9C27B0),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 2),
              blurRadius: 4,
            )
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.radio_button_checked,
              color: const Color(0xFF9C27B0),
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Collecte ${collection.specialType} active",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
              ),
            ),
            Text(
              "${collection.points.length} pts • ${collection.totalDistance.round()}m",
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
// Ajouter à la fin de collection_status_widgets.dart
class GlobalCountdownWidget extends StatelessWidget {
  final int seconds;
  final bool isVisible;

  const GlobalCountdownWidget({
    super.key,
    required this.seconds,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    // Couleur changeante selon l'urgence
    final Color color = seconds <= 4 ? Colors.red : const Color(0xFF1976D2);

    return Positioned(
      bottom: 120, // Position au-dessus des boutons du bas
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              seconds <= 4 ? Icons.timer_outlined : Icons.timer,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              "Capture : ${seconds}s",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
