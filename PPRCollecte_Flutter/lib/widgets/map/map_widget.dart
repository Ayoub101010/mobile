import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapWidget extends StatefulWidget {
  final LatLng userPosition;
  final bool gpsEnabled;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final Function(MapController) onMapCreated;
  final List<Marker> formMarkers;
  final bool isSatellite;
  final Function(Object?)? onPolylineTap;

  const MapWidget({
    super.key,
    required this.userPosition,
    required this.gpsEnabled,
    required this.markers,
    required this.polylines,
    required this.onMapCreated,
    required this.formMarkers,
    this.isSatellite = false,
    this.onPolylineTap,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late final MapController _mapController;
  bool _controllerReady = false;
// Notifier pour détecter les taps sur les polylines
  final _polylineHitNotifier = ValueNotifier<LayerHitResult<Object>?>(null);
  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Notifier le parent après le premier frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMapCreated(_mapController);
      setState(() {
        _controllerReady = true;
      });
    });
    // Écouter les taps sur les polylines
    _polylineHitNotifier.addListener(_onPolylineHit);
  }

  @override
  void dispose() {
    _polylineHitNotifier.removeListener(_onPolylineHit);
    _mapController.dispose();
    super.dispose();
  }

  void _onPolylineHit() {
    final hitResult = _polylineHitNotifier.value;
    print('🖱️ [MapWidget] _onPolylineHit appelé');
    print('🖱️ [MapWidget] hitResult: $hitResult');

    if (hitResult != null) {
      print('🖱️ [MapWidget] hitValues: ${hitResult.hitValues}');
      print('🖱️ [MapWidget] hitValues.length: ${hitResult.hitValues.length}');

      if (hitResult.hitValues.isNotEmpty) {
        final hitValue = hitResult.hitValues.first;
        print('🖱️ [MapWidget] hitValue trouvé: $hitValue (type: ${hitValue.runtimeType})');

        if (widget.onPolylineTap != null) {
          widget.onPolylineTap!(hitValue);
        }
      }
    } else {
      print('⚠️ [MapWidget] hitResult est null');
    }
  }

  void _zoomIn() {
    if (_controllerReady) {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, currentZoom + 1);
    }
  }

  void _zoomOut() {
    if (_controllerReady) {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, currentZoom - 1);
    }
  }

  void _goToUserLocation() {
    if (_controllerReady) {
      _mapController.move(widget.userPosition, 17);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fusionner tous les marqueurs
    final allMarkers = [
      ...widget.markers,
      ...widget.formMarkers,
      // Marqueur de position utilisateur (si GPS activé)
      if (widget.gpsEnabled)
        Marker(
          point: widget.userPosition,
          width: 18,
          height: 18,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
    ];

    // URL des tuiles selon le mode (normal ou satellite)
    final String tileUrl = widget.isSatellite ? 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}' : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.userPosition,
            initialZoom: 15,
            minZoom: 3,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            // Couche de tuiles (fond de carte)
            TileLayer(
              urlTemplate: tileUrl,
              userAgentPackageName: 'com.example.pprcollecte',
              maxZoom: 19,
            ),
            // Couche des polylignes
            PolylineLayer(
              polylines: widget.polylines,
              hitNotifier: _polylineHitNotifier,
            ),
            // Couche des marqueurs
            MarkerLayer(
              markers: allMarkers,
            ),
          ],
        ),
        Positioned(
          top: 8,
          right: 10,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.my_location, color: Colors.blue),
              onPressed: _goToUserLocation,
              tooltip: 'Ma position',
            ),
          ),
        ),

        // Boutons de zoom (+/-)
        Positioned(
          right: 5,
          bottom: 10, // ajuste
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.black87),
                  onPressed: _zoomIn,
                  tooltip: 'Zoom avant',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.remove, color: Colors.black87),
                  onPressed: _zoomOut,
                  tooltip: 'Zoom arrière',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MapTypeToggle extends StatelessWidget {
  final bool isSatellite;
  final Function(bool) onMapTypeChanged;

  const MapTypeToggle({
    super.key,
    required this.isSatellite,
    required this.onMapTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 55,
      right: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              onMapTypeChanged(!isSatellite);
            },
            child: Container(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSatellite ? Icons.map : Icons.satellite,
                    size: 24,
                    color: isSatellite ? Colors.blue : Colors.orange,
                  ),
                  SizedBox(width: 8),
                  Text(
                    isSatellite ? 'Carte' : 'Satellite',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DownloadedPistesToggle extends StatelessWidget {
  final bool isOn;
  final int count;
  final ValueChanged<bool> onChanged;

  const DownloadedPistesToggle({
    super.key,
    required this.isOn,
    required this.onChanged,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      right: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(!isOn),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.alt_route,
                    size: 22,
                    color: isOn ? const Color(0xFFB86E1D) : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pistes téléchargées',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOn ? const Color(0xFFB86E1D).withOpacity(0.12) : Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOn ? const Color(0xFFB86E1D) : Colors.grey,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOn ? const Color(0xFFB86E1D) : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DownloadedChausseesToggle extends StatelessWidget {
  final bool isOn;
  final int count;
  final ValueChanged<bool> onChanged;

  const DownloadedChausseesToggle({
    super.key,
    required this.isOn,
    required this.onChanged,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 206,
      right: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(!isOn),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.alt_route_rounded,
                    size: 22,
                    color: isOn ? const Color(0xFFB86E1D) : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Chaussées téléchargées',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOn ? const Color(0xFFB86E1D).withOpacity(0.12) : Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOn ? const Color(0xFFB86E1D) : Colors.grey,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOn ? const Color(0xFFB86E1D) : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
