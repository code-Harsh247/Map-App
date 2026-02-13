import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';
import '../providers/auth_provider.dart';

class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({Key? key}) : super(key: key);

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      mapProvider.setMapController(_mapController);
      // Fetch user's GPS location and center the map
      mapProvider.getUserLocation();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  List<Polyline> _buildPolylines(MapProvider mapProvider) {
    if (mapProvider.optimizedRoute == null) return [];

    List<LatLng> polylineCoordinates = mapProvider.optimizedRoute!.path
        .map((coord) => LatLng(coord['latitude']!, coord['longitude']!))
        .toList();

    return [
      Polyline(
        points: polylineCoordinates,
        color: const Color(0xFFB1FF8E),
        strokeWidth: 5.0,
      ),
    ];
  }

  List<Marker> _buildMarkers(MapProvider mapProvider) {
    List<Marker> markers = [];

    // Current user location "me" marker
    if (mapProvider.userLocation != null) {
      markers.add(
        Marker(
          point: mapProvider.userLocation!,
          width: 30,
          height: 30,
          child: _buildMeMarker(),
        ),
      );
    }

    // Start marker
    if (mapProvider.startLocation != null) {
      markers.add(
        Marker(
          point: LatLng(
            mapProvider.startLocation!.latitude,
            mapProvider.startLocation!.longitude,
          ),
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on,
            color: Color(0xFFB1FF8E),
            size: 40,
          ),
        ),
      );
    }

    // Stop markers
    for (int i = 0; i < mapProvider.stops.length; i++) {
      markers.add(
        Marker(
          point: LatLng(
            mapProvider.stops[i].latitude,
            mapProvider.stops[i].longitude,
          ),
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.location_on,
                color: Colors.blue,
                size: 40,
              ),
              Positioned(
                top: 8,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Destination marker
    if (mapProvider.destination != null) {
      markers.add(
        Marker(
          point: LatLng(
            mapProvider.destination!.latitude,
            mapProvider.destination!.longitude,
          ),
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 40,
          ),
        ),
      );
    }

    return markers;
  }

  /// Current location "me" marker — concentric green circles
  Widget _buildMeMarker() {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow circle
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFB1FF8E).withValues(alpha: 0.17),
            ),
          ),
          // Middle solid green circle
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFB1FF8E),
            ),
          ),
          // Inner dark circle
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF171717),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF262F3D),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Full-screen dark map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(12.9716, 77.5946),
              initialZoom: 14,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mapnow.map_now',
                maxZoom: 19,
              ),
              PolylineLayer(polylines: _buildPolylines(mapProvider)),
              MarkerLayer(markers: _buildMarkers(mapProvider)),
            ],
          ),

          // ── Bottom gradient overlay ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 160,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFF171717),
                      Color(0x00262F3D),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Search bar + Profile avatar ──
          Positioned(
            top: topPadding + 10,
            left: 8,
            right: 8,
            child: Container(
              height: 75,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF212121),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Search input area
                  Expanded(
                    child: Container(
                      height: 55,
                      decoration: BoxDecoration(
                        color: const Color(0xFF292929),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search Location',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 14, right: 10),
                            child: Icon(
                              Icons.search,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 24,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 24,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            mapProvider.searchAddress(value);
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Profile avatar
                  GestureDetector(
                    onTap: () {
                      _showProfileMenu(context);
                    },
                    child: Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFD2C2),
                            Color(0xFFFFC9B3),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFFD4845A),
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Compass button (bottom-right, above route button) ──
          Positioned(
            right: 20,
            bottom: 170,
            child: GestureDetector(
              onTap: () {
                // Re-center on user location
                if (mapProvider.userLocation != null) {
                  _mapController.move(mapProvider.userLocation!, 15);
                  _mapController.rotate(0);
                } else {
                  _mapController.rotate(0);
                  mapProvider.getUserLocation();
                }
              },
              child: Container(
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/compass_icon.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // ── Route / Navigate button (bottom-right) ──
          Positioned(
            right: 12,
            bottom: 80,
            child: GestureDetector(
              onTap: () {
                if (mapProvider.canOptimizeRoute && !mapProvider.isLoading) {
                  mapProvider.findOptimizedRoute();
                }
              },
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB1FF8E),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB1FF8E).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: 0.785398, // 45 degrees
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF171717),
                          width: 2.5,
                        ),
                      ),
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.785398, // rotate icon back
                          child: const Icon(
                            Icons.turn_right,
                            color: Color(0xFF171717),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Loading indicator ──
          if (mapProvider.isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFB1FF8E),
              ),
            ),

          // ── Error snackbar area ──
          if (mapProvider.errorMessage != null)
            Positioned(
              bottom: 160,
              left: 16,
              right: 90,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF292929),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  mapProvider.errorMessage!,
                  style: GoogleFonts.poppins(
                    color: Colors.red[300],
                    fontSize: 13,
                  ),
                ),
              ),
            ),

          // ── Distance badge (shown when route found) ──
          if (mapProvider.optimizedRoute != null)
            Positioned(
              bottom: 165,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF212121),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFB1FF8E).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.route,
                      color: Color(0xFFB1FF8E),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${mapProvider.optimizedRoute!.distanceInKm.toStringAsFixed(1)} km',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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

  void _showProfileMenu(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF292929),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // User info
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFD2C2), Color(0xFFFFC9B3)],
                    ),
                  ),
                  child: const Icon(Icons.person, color: Color(0xFFD4845A), size: 28),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authProvider.currentUser?.name ?? 'User',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      authProvider.currentUser?.mobile ?? '',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Reset map
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.white),
              title: Text(
                'Reset Map',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                mapProvider.reset();
                Navigator.pop(ctx);
              },
            ),

            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                'Logout',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                authProvider.logout();
                Navigator.pop(ctx);
                Navigator.of(context).pushReplacementNamed('/welcome');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
