// lib/provisional_form_dialog.dart - VERSION CHAMP IMMODIFIABLE
import 'package:flutter/material.dart';

class ProvisionalFormDialog {
  static Future<Map<String, String>?> show({
    required BuildContext context,
    String initialCode = '',
  }) async {
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1976D2),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.route, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nouvelle Piste',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          titlePadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ⭐⭐ REMPLACER TextField PAR TextFormField en lecture seule
              TextFormField(
                initialValue: initialCode, // ⭐⭐ Utiliser initialValue au lieu de controller
                readOnly: true, // ⭐⭐ CHAMP EN LECTURE SEULE
                decoration: InputDecoration(
                  labelText: 'Code Piste *',
                  hintText: 'Ex: 1B-02CR03P01',
                  prefixIcon: const Icon(Icons.qr_code, color: Color(0xFF1976D2)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100], // ⭐⭐ Fond gris pour indiquer lecture seule
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800], // ⭐⭐ Style pour indiquer que c'est auto-généré
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF1976D2).withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFF1976D2),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Code généré automatiquement - Non modifiable',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop({
                  'code_piste': initialCode, // ⭐⭐ Utiliser directement initialCode
                });
              },
              child: const Text('Commencer la collecte'),
            ),
          ],
        );
      },
    );
  }
}
