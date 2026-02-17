// legend_widget.dart - VERSION AVEC SECTIONS DÉPLIABLES + CHECKBOXES SUR SOUS-TYPES
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../common/custom_marker_icons.dart';

class LegendWidget extends StatefulWidget {
  final Map<String, bool> initialVisibility;
  final Function(Map<String, bool>) onVisibilityChanged;
  final List<Polyline> allPolylines;
  final List<Marker> allMarkers;
  final int polygonCount;
  final Map<String, int> pointCountsByTable;

  const LegendWidget({
    super.key,
    required this.initialVisibility,
    required this.onVisibilityChanged,
    required this.allPolylines,
    required this.allMarkers,
    this.polygonCount = 0,
    this.pointCountsByTable = const {},
  });

  @override
  State<LegendWidget> createState() => _LegendWidgetState();
}

class _LegendWidgetState extends State<LegendWidget> {
  late Map<String, bool> _visibility;
  bool _isExpanded = false;
  bool _pointsExpanded = false;
  bool _chausseesExpanded = false;

  // Sous-types de points
  static const List<Map<String, dynamic>> _pointTypes = [
    {
      'table': 'localites',
      'name': 'Localités'
    },
    {
      'table': 'ecoles',
      'name': 'Écoles'
    },
    {
      'table': 'marches',
      'name': 'Marchés'
    },
    {
      'table': 'services_santes',
      'name': 'Services de santé'
    },
    {
      'table': 'batiments_administratifs',
      'name': 'Bâtiments admin.'
    },
    {
      'table': 'infrastructures_hydrauliques',
      'name': 'Infra. hydrauliques'
    },
    {
      'table': 'autres_infrastructures',
      'name': 'Autres infra.'
    },
    {
      'table': 'ponts',
      'name': 'Ponts'
    },
    {
      'table': 'buses',
      'name': 'Buses'
    },
    {
      'table': 'dalots',
      'name': 'Dalots'
    },
    {
      'table': 'points_critiques',
      'name': 'Points critiques'
    },
    {
      'table': 'points_coupures',
      'name': 'Points de coupure'
    },
    {
      'table': 'site_enquete',
      'name': 'Sites d\'enquête'
    },
  ];

  // Sous-types de chaussées
  static const List<Map<String, String>> _chausseeTypes = [
    {
      'id': 'bitume',
      'name': 'Bitume'
    },
    {
      'id': 'terre',
      'name': 'Terre'
    },
    {
      'id': 'latérite',
      'name': 'Latérite'
    },
    {
      'id': 'bouwal',
      'name': 'Bouwal'
    },
    {
      'id': 'autre',
      'name': 'Autre'
    },
  ];

  @override
  void initState() {
    super.initState();
    _visibility = Map<String, bool>.from(widget.initialVisibility);
  }

  // ===== Compteurs =====

  int get _totalPoints {
    int total = 0;
    for (var entry in widget.pointCountsByTable.entries) {
      total += entry.value;
    }
    // Aussi compter les markers si pointCountsByTable est vide
    if (total == 0) total = widget.allMarkers.length;
    return total;
  }

  int _countPistes() {
    return widget.allPolylines.where((p) {
      final colorValue = p.color.value;
      final isPisteColor = colorValue == Colors.brown.value || colorValue == const Color(0xFFB86E1D).value;
      return isPisteColor && p.strokeWidth <= 3.5;
    }).length;
  }

  int _countBacs() {
    return widget.allPolylines.where((p) => p.color.value == Colors.purple.value).length;
  }

  int _countPassages() {
    return widget.allPolylines.where((p) => p.color.value == Colors.cyan.value).length;
  }

  int get _totalChaussees {
    return widget.allPolylines.where((p) => p.strokeWidth > 3.5).where((p) {
      final c = p.color;
      return c == Colors.black || c == Colors.brown || c.value == Colors.red.shade700.value || c.value == Colors.yellow.shade700.value || c == Colors.blueGrey;
    }).length;
  }

  int _countChausseeByType(String type) {
    return widget.allPolylines.where((p) {
      return _getChausseeTypeFromColor(p.color) == type && p.strokeWidth > 3.5;
    }).length;
  }

  String _getChausseeTypeFromColor(Color color) {
    if (color == Colors.black) return 'bitume';
    if (color == Colors.brown) return 'terre';
    if (color.value == Colors.red.shade700.value) return 'latérite';
    if (color.value == Colors.yellow.shade700.value) return 'bouwal';
    if (color == Colors.blueGrey) return 'autre';
    return 'inconnu';
  }

  Color _getColorForChausseeType(String type) {
    switch (type) {
      case 'bitume':
        return Colors.black;
      case 'terre':
        return Colors.brown;
      case 'latérite':
        return Colors.red.shade700;
      case 'bouwal':
        return Colors.yellow.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  StrokePattern? _getPatternForChausseeType(String type) {
    switch (type) {
      case 'terre':
        return StrokePattern.dashed(segments: [
          20,
          10
        ]);
      case 'latérite':
        return StrokePattern.dashed(segments: [
          10,
          10
        ]);
      case 'bouwal':
        return StrokePattern.dotted(spacingFactor: 1.5);
      default:
        return null;
    }
  }

  void _toggleVisibility(String id, bool value) {
    setState(() {
      _visibility[id] = value;
      widget.onVisibilityChanged(_visibility);
    });
  }

  // ===== Toggle parent → cascade sur tous les enfants =====
  void _togglePointsParent(bool value) {
    setState(() {
      _visibility['points'] = value;
      for (var pt in _pointTypes) {
        _visibility['point_${pt['table']}'] = value;
      }
      widget.onVisibilityChanged(_visibility);
    });
  }

  void _toggleChausseesParent(bool value) {
    setState(() {
      // Mettre à jour le parent
      _visibility['chaussees'] = value;
      for (var ct in _chausseeTypes) {
        _visibility['chaussee_${ct['id']}'] = value;
      }
      widget.onVisibilityChanged(_visibility);
    });
  }

  // Vérifier si au moins un sous-type est coché (pour l'état du parent)
  bool _isAnyPointSubTypeVisible() {
    for (var pt in _pointTypes) {
      if (_visibility['point_${pt['table']}'] ?? true) return true;
    }
    return false;
  }

  bool _isAnyChausseeSubTypeVisible() {
    for (var ct in _chausseeTypes) {
      if (_visibility['chaussee_${ct['id']}'] ?? true) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 105,
      right: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton ouvrir/fermer
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isExpanded ? Icons.legend_toggle : Icons.legend_toggle_outlined, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('Légende', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ),

            // Contenu
            if (_isExpanded) ...[
              Divider(height: 1, color: Colors.grey[300]),
              Container(
                constraints: const BoxConstraints(maxHeight: 480, maxWidth: 260),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== POINTS (dépliable) =====
                      _buildPointsSection(),

                      // ===== PISTES =====
                      _buildSimpleItem(
                        id: 'pistes',
                        name: 'Pistes',
                        icon: Container(
                          width: 24,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.brown,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        count: _countPistes(),
                      ),

                      // ===== CHAUSSÉES (dépliable) =====
                      _buildChausseesSection(),

                      // ===== BACS =====
                      _buildSimpleItem(
                        id: 'bac',
                        name: 'Bacs',
                        icon: Container(
                          width: 24,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        count: _countBacs(),
                      ),

                      // ===== PASSAGES SUBMERSIBLES =====
                      _buildSimpleItem(
                        id: 'passage_submersible',
                        name: 'Passages submersibles',
                        icon: Container(
                          width: 24,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.cyan,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        count: _countPassages(),
                      ),

                      // ===== ZONES DE PLAINE =====
                      _buildSimpleItem(
                        id: 'zone_plaine',
                        name: 'Zones de Plaine',
                        icon: Container(
                          width: 24,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.3),
                            border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        count: widget.polygonCount,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =====================================================================
  //  SECTION POINTS DÉPLIABLE
  // =====================================================================
  Widget _buildPointsSection() {
    final bool parentVisible = _visibility['points'] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header parent
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: parentVisible,
                onChanged: (v) => _togglePointsParent(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                child: const Icon(Icons.location_on, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _pointsExpanded = !_pointsExpanded),
                  child: const Text('Points', style: TextStyle(fontSize: 13)),
                ),
              ),
              _buildCountBadge(_totalPoints),
              GestureDetector(
                onTap: () => setState(() => _pointsExpanded = !_pointsExpanded),
                child: Icon(
                  _pointsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // Sous-types
        if (_pointsExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: _pointTypes.map((pt) {
                final table = pt['table'] as String;
                final name = pt['name'] as String;
                final count = widget.pointCountsByTable[table] ?? 0;
                final config = CustomMarkerIcons.iconConfig[table];
                final subId = 'point_$table';
                final subVisible = _visibility[subId] ?? true;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Checkbox(
                        value: parentVisible && subVisible,
                        onChanged: parentVisible
                            ? (v) {
                                _toggleVisibility(subId, v ?? false);
                                // Si tous les sous-types sont décochés, décocher le parent aussi
                                if (v == false && !_isAnyPointSubTypeVisible()) {
                                  // Garder le parent coché mais les sous-types contrôlent l'affichage
                                }
                              }
                            : null, // Désactivé si parent décoché
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      Icon(
                        config?.icon ?? Icons.location_pin,
                        color: (parentVisible && subVisible) ? (config?.color ?? Colors.red) : Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(name, style: TextStyle(fontSize: 12, color: (parentVisible && subVisible) ? Colors.grey[700] : Colors.grey[400])),
                      ),
                      if (count > 0) _buildCountBadge(count, small: true),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // =====================================================================
  //  SECTION CHAUSSÉES DÉPLIABLE
  // =====================================================================
  Widget _buildChausseesSection() {
    final bool parentVisible = _visibility['chaussees'] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header parent
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: parentVisible,
                onChanged: (v) => _toggleChausseesParent(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              Container(
                width: 24,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _chausseesExpanded = !_chausseesExpanded),
                  child: const Text('Chaussées', style: TextStyle(fontSize: 13)),
                ),
              ),
              _buildCountBadge(_totalChaussees),
              GestureDetector(
                onTap: () => setState(() => _chausseesExpanded = !_chausseesExpanded),
                child: Icon(
                  _chausseesExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // Sous-types
        if (_chausseesExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: _chausseeTypes.map((ct) {
                final id = ct['id']!;
                final name = ct['name']!;
                final subId = 'chaussee_$id';
                final subVisible = _visibility[subId] ?? true;
                final color = _getColorForChausseeType(id);
                final pattern = _getPatternForChausseeType(id);
                final count = _countChausseeByType(id);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Checkbox(
                        value: parentVisible && subVisible,
                        onChanged: parentVisible ? (v) => _toggleVisibility(subId, v ?? false) : null,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      SizedBox(
                        width: 24,
                        height: 3,
                        child: CustomPaint(
                          painter: _PatternPainter(
                            color: (parentVisible && subVisible) ? color : Colors.grey,
                            pattern: pattern,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(name, style: TextStyle(fontSize: 12, color: (parentVisible && subVisible) ? Colors.grey[700] : Colors.grey[400])),
                      ),
                      if (count > 0) _buildCountBadge(count, small: true),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // =====================================================================
  //  WIDGETS UTILITAIRES
  // =====================================================================

  Widget _buildSimpleItem({
    required String id,
    required String name,
    required Widget icon,
    required int count,
  }) {
    final isVisible = _visibility[id] ?? true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: isVisible,
            onChanged: (v) => _toggleVisibility(id, v ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Container(width: 24, height: 24, alignment: Alignment.center, child: icon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 13)),
          ),
          _buildCountBadge(count),
        ],
      ),
    );
  }

  Widget _buildCountBadge(int count, {bool small = false}) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 6, vertical: small ? 1 : 2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(fontSize: small ? 10 : 11, color: Colors.grey[700]),
      ),
    );
  }
}

// Peintre pour les motifs chaussée
class _PatternPainter extends CustomPainter {
  final Color color;
  final StrokePattern? pattern;

  _PatternPainter({required this.color, required this.pattern});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (pattern == null) {
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    } else {
      double startX = 0;
      const double dashWidth = 10;
      const double gapWidth = 5;
      while (startX < size.width) {
        final endX = startX + dashWidth;
        if (endX > size.width) break;
        canvas.drawLine(Offset(startX, size.height / 2), Offset(endX, size.height / 2), paint);
        startX = endX + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
