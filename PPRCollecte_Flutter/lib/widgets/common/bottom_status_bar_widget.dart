import 'package:flutter/material.dart';

class BottomStatusBarWidget extends StatelessWidget {
  final bool gpsEnabled;
  final bool isOnline;
  final String? lastSyncTime;

  const BottomStatusBarWidget({
    super.key,
    required this.gpsEnabled,
    required this.isOnline,
    this.lastSyncTime,
  });

  @override
  Widget build(BuildContext context) {
    final String onlineText = isOnline ? 'En ligne' : 'Hors ligne';
    final Color onlineColor = isOnline ? Colors.green.shade700 : Colors.red.shade700;
    final String syncText = lastSyncTime ?? '--:--';
    return Container(
      color: const Color(0xFFE3F2FD),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
          children: [
            TextSpan(
              text: "📡 GPS: ${gpsEnabled ? 'Activé' : 'Désactivé'} | 🔄 Sync: $syncText | ",
            ),
            TextSpan(
              text: "🌐 $onlineText",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: onlineColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
