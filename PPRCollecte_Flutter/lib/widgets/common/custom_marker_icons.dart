// custom_marker_icons.dart - VERSION FLUTTER_MAP
import 'package:flutter/material.dart';

class CustomMarkerIcons {
  // Configuration des icônes par table
  static final Map<String, MarkerIconConfig> iconConfig = {
    'localites': MarkerIconConfig(
      icon: Icons.home,
      color: Color(0xFFE67E22), // Orange
    ),
    'ecoles': MarkerIconConfig(
      icon: Icons.school,
      color: Color(0xFF27AE60), // Vert
    ),
    'marches': MarkerIconConfig(
      icon: Icons.shopping_cart,
      color: Color(0xFFF1C40F), // Jaune
    ),
    'services_santes': MarkerIconConfig(
      icon: Icons.local_hospital,
      color: Color(0xFFE74C3C), // Rouge
    ),
    'batiments_administratifs': MarkerIconConfig(
      icon: Icons.business,
      color: Color(0xFF34495E), // Gris foncé
    ),
    'infrastructures_hydrauliques': MarkerIconConfig(
      icon: Icons.water_drop,
      color: Color(0xFF3498DB), // Bleu
    ),
    'autres_infrastructures': MarkerIconConfig(
      icon: Icons.location_pin,
      color: Color(0xFF95A5A6), // Gris
    ),
    'ponts': MarkerIconConfig(
      icon: Icons.account_balance,
      color: Color(0xFF9B59B6), // Violet
    ),
    'buses': MarkerIconConfig(
      icon: Icons.circle,
      color: Color(0xFF7F8C8D), // Gris moyen
    ),
    'dalots': MarkerIconConfig(
      icon: Icons.water,
      color: Color(0xFF3498DB), // Bleu
    ),
    'points_critiques': MarkerIconConfig(
      icon: Icons.warning,
      color: Color(0xFFD35400), // Orange foncé
    ),
    'points_coupures': MarkerIconConfig(
      icon: Icons.close,
      color: Color(0xFFC0392B), // Rouge foncé
    ),
  };

  /// Retourne un Widget pour le marqueur (utilisé dans flutter_map)
  static Widget getMarkerWidget(String tableName, {double size = 40.0, VoidCallback? onTap}) {
    final config = iconConfig[tableName];

    if (config == null) {
      return _buildDefaultMarker(size, onTap);
    }

    return _buildCustomMarker(config, size, onTap);
  }

  /// Construit un marqueur personnalisé
  static Widget _buildCustomMarker(MarkerIconConfig config, double size, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: config.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          config.icon,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }

  /// Marqueur par défaut (rouge)
  static Widget _buildDefaultMarker(double size, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.location_pin,
        color: Colors.red,
        size: size,
      ),
    );
  }

  /// Retourne la couleur pour une table donnée
  static Color getColorForTable(String tableName) {
    return iconConfig[tableName]?.color ?? Colors.red;
  }

  /// Retourne l'icône pour une table donnée
  static IconData getIconForTable(String tableName) {
    return iconConfig[tableName]?.icon ?? Icons.location_pin;
  }

  // Méthodes de compatibilité (pour ne pas casser le code existant)
  static int getCacheSize() => 0; // Plus de cache nécessaire
  static void clearCache() {} // Plus de cache nécessaire
}

class MarkerIconConfig {
  final IconData icon;
  final Color color;

  MarkerIconConfig({
    required this.icon,
    required this.color,
  });
}
