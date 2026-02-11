import 'package:flutter/material.dart';
import 'data_categories_display.dart';

class DataSubcategoriesPage extends StatelessWidget {
  final String categoryType;
  final String dataFilter; // "unsynced", "synced", "saved"
  final bool isOnline;
  final String agentName;
  const DataSubcategoriesPage({
    super.key,
    required this.categoryType,
    required this.dataFilter,
    required this.isOnline,
    required this.agentName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: Text(
          '📊 $categoryType',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sélectionnez une sous-catégorie de $categoryType',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 1,
                mainAxisSpacing: 16,
                childAspectRatio: 3.0,
                children: [
                  _buildSubcategoryCard(
                    context,
                    title: 'Pistes',
                    description: 'Données des pistes collectées',
                    icon: Icons.timeline,
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      // Navigation vers les données des pistes
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DataCategoriesDisplay(
                            mainCategory: "Pistes",
                            dataFilter: dataFilter,
                            isOnline: isOnline,
                            agentName: agentName,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildSubcategoryCard(
                    context,
                    title: 'Chaussées',
                    description: 'Données des chaussées collectées',
                    icon: Icons.route,
                    color: const Color(0xFF2196F3),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DataCategoriesDisplay(
                            mainCategory: "Chaussées",
                            dataFilter: dataFilter,
                            isOnline: isOnline,
                            agentName: agentName,
                          ),
                        ),
                      );
                      // Navigation vers les données des chaussées
                    },
                  ),
                  _buildSubcategoryCard(
                    context,
                    title: 'Infrastructures Rurales',
                    description: 'Écoles, marchés, services de santé...',
                    icon: Icons.location_city,
                    color: const Color(0xFFFF9800),
                    onTap: () {
                      // Navigation vers les infrastructures rurales
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DataCategoriesDisplay(
                            mainCategory: "Infrastructures Rurales",
                            dataFilter: dataFilter,
                            isOnline: isOnline,
                            agentName: agentName,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildSubcategoryCard(
                    context,
                    title: 'Ouvrages',
                    description: 'Ponts, bacs, buses, dalots...',
                    icon: Icons.construction,
                    color: const Color(0xFF9C27B0),
                    onTap: () {
                      // Navigation vers les ouvrages
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DataCategoriesDisplay(
                            mainCategory: "Ouvrages",
                            dataFilter: dataFilter,
                            isOnline: isOnline,
                            agentName: agentName,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildSubcategoryCard(
                    context,
                    title: 'Points Critiques',
                    description: 'Points de coupure, problèmes...',
                    icon: Icons.warning,
                    color: const Color(0xFFF44336),
                    onTap: () {
                      // Navigation vers les points critiques
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DataCategoriesDisplay(
                            mainCategory: "Points Critiques",
                            dataFilter: dataFilter,
                            isOnline: isOnline,
                            agentName: agentName,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubcategoryCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 24,
                color: Color(0xFF999999),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
