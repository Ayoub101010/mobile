import 'package:flutter/material.dart';

class TopBarWidget extends StatelessWidget {
  final String agentName;
  final VoidCallback onLogout;

  const TopBarWidget({
    super.key,
    required this.agentName,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1976D2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                agentName.isNotEmpty ? agentName : "Agent",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64B5F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            ),
            onPressed: onLogout,
            child: const Text(
              "Se déconnecter",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          )
        ],
      ),
    );
  }
}
