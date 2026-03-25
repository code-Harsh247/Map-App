import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import '../models/place_model.dart';

/// Full-screen map picker. Long-press or tap to drop a pin.
/// Returns [PlaceModel] via Navigator.pop when the user confirms.
class MapPickerScreen extends StatefulWidget {
  /// Already-picked points to display as context (start, stops, destination).
  final List<ExistingMarker> existingMarkers;

  const MapPickerScreen({super.key, this.existingMarkers = const []});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

/// A lightweight marker definition for context points shown on the picker map.
class ExistingMarker {
  final LatLng point;
  final Color color;
  final String? label;

  const ExistingMarker({required this.point, required this.color, this.label});
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedPoint;
  String? _address;
  bool _isResolving = false;

  LatLng _initialCenter = const LatLng(20, 0);
  double _initialZoom = 2;

  @override
  void initState() {
    super.initState();
    _tryGetCurrentLocation();
  }

  Future<void> _tryGetCurrentLocation() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        setState(() {
          _initialCenter = LatLng(pos.latitude, pos.longitude);
          _initialZoom = 14;
        });
        _mapController.move(_initialCenter, _initialZoom);
      }
    } catch (_) {}
  }

  Future<void> _onMapTap(LatLng point) async {
    setState(() {
      _selectedPoint = point;
      _address = null;
      _isResolving = true;
    });

    try {
      final placemarks = await geo.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.street != null && p.street!.isNotEmpty) p.street!,
          if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
          if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea!,
          if (p.country != null && p.country!.isNotEmpty) p.country!,
        ];
        setState(() {
          _address = parts.isNotEmpty ? parts.join(', ') : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
          _isResolving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _address = '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
          _isResolving = false;
        });
      }
    }
  }

  void _confirmSelection() {
    if (_selectedPoint == null) return;
    Navigator.pop(
      context,
      PlaceModel(
        fullAddress: _address ?? '${_selectedPoint!.latitude.toStringAsFixed(5)}, ${_selectedPoint!.longitude.toStringAsFixed(5)}',
        latitude: _selectedPoint!.latitude,
        longitude: _selectedPoint!.longitude,
        placeId: 'map_pick_${_selectedPoint!.latitude}_${_selectedPoint!.longitude}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF171717),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              onTap: (_, point) => _onMapTap(point),
              onLongPress: (_, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                retinaMode: true,
              ),
              // Existing context markers (start, stops, destination)
              if (widget.existingMarkers.isNotEmpty)
                MarkerLayer(
                  markers: widget.existingMarkers.map((m) {
                    return Marker(
                      point: m.point,
                      width: 28,
                      height: 28,
                      child: _buildContextMarker(m.color, m.label),
                    );
                  }).toList(),
                ),
              // Selected pin
              if (_selectedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint!,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                    ),
                  ],
                ),
            ],
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(12, topPadding + 10, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF212121).withOpacity(0.92),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFF333333), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      customBorder: const CircleBorder(),
                      splashColor: Colors.white.withOpacity(0.2),
                      child: Ink(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pick on Map',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Crosshair center indicator

          // Hint text
          if (_selectedPoint == null)
            Positioned(
              top: topPadding + 70,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF292929).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tap on the map to drop a pin',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ),

          // Bottom confirm card
          if (_selectedPoint != null)
            Positioned(
              bottom: bottomPadding + 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF212121),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF333333)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_pin, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _isResolving
                              ? Text('Resolving address...', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13))
                              : Text(
                                  _address ?? '',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isResolving ? null : _confirmSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB1FF8E),
                          disabledBackgroundColor: const Color(0xFFB1FF8E).withOpacity(0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Select this location',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContextMarker(Color color, String? label) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.18),
            ),
          ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF171717),
            ),
            child: label != null
                ? Center(
                    child: Text(
                      label,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 7),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
