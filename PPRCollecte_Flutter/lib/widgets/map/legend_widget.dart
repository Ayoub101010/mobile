// legend_widget.dart - VERSION COMPLÈTE
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class LegendData {
  final String id;
  final String name;
  final Widget icon;
  final Color color;
  bool isVisible;
  final String type;

  LegendData({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.isVisible = true,
  });
}

class LegendWidget extends StatefulWidget {
  final Map<String, bool> initialVisibility;
  final Function(Map<String, bool>) onVisibilityChanged;
  final List<Polyline> allPolylines;
  final List<Marker> allMarkers;

  const LegendWidget({
    super.key,
    required this.initialVisibility,
    required this.onVisibilityChanged,
    required this.allPolylines,
    required this.allMarkers,
  });

  @override
  State<LegendWidget> createState() => _LegendWidgetState();
}

class _LegendWidgetState extends State<LegendWidget> {
  late Map<String, bool> _visibility;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _visibility = Map<String, bool>.from(widget.initialVisibility);
  }

  // Compter le nombre d'éléments par type
  int _countItemsByType(String type) {
    if (type == 'point') {
      return widget.allMarkers.length;
    } else if (type == 'piste') {
      // ⭐⭐ CORRECTION: Pistes = brown + strokeWidth 3.0 ⭐⭐
      return widget.allPolylines.where((p) {
        final colorValue = p.color.value;
        final isPisteColor = colorValue == Colors.brown.value || colorValue == const Color(0xFFB86E1D).value;
        // Différencier des chaussées par strokeWidth (pistes = 3.0)
        return isPisteColor && p.strokeWidth <= 3.5;
      }).length;
    } else if (type.startsWith('chaussee_')) {
      final chausseeType = type.replaceFirst('chaussee_', '');
      // ⭐⭐ CORRECTION: Chaussées = strokeWidth > 3.5 ⭐⭐
      return widget.allPolylines.where((p) {
        return _getChausseeTypeFromColor(p.color) == chausseeType && p.strokeWidth > 3.5;
      }).length;
    } else if (type == 'bac') {
      return widget.allPolylines.where((p) => p.color.value == Colors.purple.value).length;
    } else if (type == 'passage_submersible') {
      return widget.allPolylines.where((p) => p.color.value == Colors.cyan.value).length;
    }
    return 0;
  }

  // Déterminer le type de chaussée depuis sa couleur
  String _getChausseeTypeFromColor(Color color) {
    if (color == Colors.black) return 'bitume';
    if (color == Colors.brown) return 'terre';
    if (color.value == Colors.red.shade700.value) return 'latérite';
    if (color.value == Colors.yellow.shade700.value) return 'bouwal';
    if (color == Colors.blueGrey) return 'autre';
    return 'inconnu';
  }

// Obtenir la couleur par type de chaussée
  Color _getColorForChausseeType(String type) {
    switch (type.toLowerCase()) {
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

// Obtenir le motif par type de chaussée
  StrokePattern? _getPatternForChausseeType(String type) {
    switch (type.toLowerCase()) {
      case 'bitume':
        return null; // ligne continue
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

  @override
  Widget build(BuildContext context) {
    final List<LegendData> legendItems = [
      // === POINTS ===
      LegendData(
        id: 'points',
        name: 'Points',
        icon: Icon(Icons.location_on, color: Colors.red),
        color: Colors.red,
        type: 'point',
        isVisible: _visibility['points'] ?? true,
      ),

      // === PISTES ===
      LegendData(
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
        color: Colors.brown,
        type: 'piste',
        isVisible: _visibility['pistes'] ?? true,
      ),

      // === CHAUSSÉES ===
      ...[
        'bitume',
        'terre',
        'latérite',
        'bouwal',
        'autre'
      ].map((type) {
        final color = _getColorForChausseeType(type);
        final pattern = _getPatternForChausseeType(type);

        return LegendData(
          id: 'chaussee_$type',
          name: 'Chaussée ($type)',
          icon: Container(
            width: 24,
            height: 3,
            child: CustomPaint(
              painter: _PatternPainter(
                color: color,
                pattern: pattern,
              ),
            ),
          ),
          color: color,
          type: 'chaussee_$type',
          isVisible: _visibility['chaussee_$type'] ?? true,
        );
      }).toList(),

      // === BACS ===
      LegendData(
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
        color: Colors.purple,
        type: 'bac',
        isVisible: _visibility['bac'] ?? true,
      ),

      // === PASSAGES SUBMERSIBLES ===
      LegendData(
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
        color: Colors.cyan,
        type: 'passage_submersible',
        isVisible: _visibility['passage_submersible'] ?? true,
      ),
    ];

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
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton pour ouvrir/fermer la légende
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isExpanded ? Icons.legend_toggle : Icons.legend_toggle_outlined, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Légende',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Contenu de la légende (visible uniquement si étendue)
            if (_isExpanded) ...[
              Divider(height: 1, color: Colors.grey[300]),
              Container(
                constraints: BoxConstraints(
                  maxHeight: 420, // ← AUGMENTEZ LA HAUTEUR (350 → 420)
                  maxWidth: 250,
                ),
                padding: EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: legendItems.map((item) {
                      final count = (item.isVisible) ? _countItemsByType(item.type) : 0;

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            // Case à cocher
                            Checkbox(
                              value: item.isVisible,
                              onChanged: (value) {
                                setState(() {
                                  item.isVisible = value ?? false;
                                  _visibility[item.id] = item.isVisible;
                                  widget.onVisibilityChanged(_visibility);
                                });
                              },
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),

                            // Icône
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              child: item.icon,
                            ),

                            SizedBox(width: 8),

                            // Nom
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(fontSize: 13),
                              ),
                            ),

                            // Compteur
                            if (count > 0)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  count.toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Peintre pour dessiner les motifs sur les chaussées
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
      // Ligne continue
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    } else {
      // Tiretés ou pointillés
      _drawDashedLine(canvas, size, paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Size size, Paint paint) {
    double startX = 0;
    const double dashWidth = 10;
    const double gapWidth = 5;

    while (startX < size.width) {
      final endX = startX + dashWidth;
      if (endX > size.width) break;

      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(endX, size.height / 2),
        paint,
      );

      startX = endX + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
