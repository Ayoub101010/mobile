import 'package:flutter/material.dart';
import '../../core/config/infrastructure_config.dart';

class CategorySelectorWidget extends StatelessWidget {
  final Function(String) onCategorySelected;

  const CategorySelectorWidget({super.key, required this.onCategorySelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text(
            'Sélectionnez une catégorie',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: InfrastructureConfig.getCategories().length,
              itemBuilder: (context, index) {
                final category = InfrastructureConfig.getCategories()[index];
                final color = Color(InfrastructureConfig.getCategoryColor(category));
                final entities = InfrastructureConfig.getEntitiesForCategory(category);

                return GestureDetector(
                  onTap: () => onCategorySelected(category),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Icon(
                            _getIconData(category),
                            size: 32,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${entities.length} types',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
