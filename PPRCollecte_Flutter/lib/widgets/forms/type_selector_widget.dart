import 'package:flutter/material.dart';
import '../../core/config/infrastructure_config.dart';

class TypeSelectorWidget extends StatelessWidget {
  final String category;
  final Function(String) onTypeSelected;
  final VoidCallback onBack;
  final bool showBackButton;

  const TypeSelectorWidget({
    super.key,
    required this.category,
    required this.onTypeSelected,
    required this.onBack,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final entities = InfrastructureConfig.getEntitiesForCategory(category);
    final categoryColor = Color(
      InfrastructureConfig.getCategoryColor(category),
    );

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // SUPPRIMER COMPLÈTEMENT la section du bouton retour
          // On garde seulement le titre

          const SizedBox(height: 24),

          // Titre de la catégorie

          // Liste des types
          Expanded(
            child: ListView.builder(
              itemCount: entities.length,
              itemBuilder: (context, index) {
                final type = entities[index];
                final config = InfrastructureConfig.getEntityConfig(
                  category,
                  type,
                );
                final tableName = config?['tableName'] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTypeSelected(type),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _getIconData(category),
                            size: 24,
                            color: const Color(0xFF666666),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                                if (tableName.isNotEmpty)
                                  Text(
                                    'Table: $tableName',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF999999),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Color(0xFF999999),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String category) {
    switch (category) {
      case "Infrastructures Rurales":
        return Icons.location_city;
      case "Ouvrages":
        return Icons.construction;
      case "Points Critiques":
        return Icons.warning;
      default:
        return Icons.help;
    }
  }
}
