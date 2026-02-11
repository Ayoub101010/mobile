import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BottomButtonsWidget extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onSync;
  final VoidCallback onMenu;

  const BottomButtonsWidget({
    super.key,
    required this.onSave,
    required this.onSync,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const FaIcon(FontAwesomeIcons.save, size: 14),
              label: const Text("Sauvegarder", style: TextStyle(fontWeight: FontWeight.w500)),
              onPressed: onSave,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const FaIcon(FontAwesomeIcons.sync, size: 14),
              label: const Text("Synchroniser", style: TextStyle(fontWeight: FontWeight.w500)),
              onPressed: onSync,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 167, 94, 196),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.analytics, size: 18), // 📊
              label: const Text("Données", style: TextStyle(fontWeight: FontWeight.w500)),
              onPressed: onMenu,
            ),
          ),
        ],
      ),
    );
  }
}
