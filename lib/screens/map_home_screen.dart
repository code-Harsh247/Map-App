import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';
import '../providers/auth_provider.dart';
import '../models/place_model.dart';
import 'location_search_screen.dart';
import 'map_picker_screen.dart';
import 'navigation_screen.dart';
import 'feedback_screen.dart';
import 'widgets/pulsing_marker.dart';
import 'package:geolocator/geolocator.dart';

class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  late AnimationController _panelAnimController;
  late Animation<Offset> _panelSlideAnimation;
  bool _showNavPanel = false;

  // Route panel state
  late AnimationController _routePanelAnimController;
  late Animation<Offset> _routePanelSlideAnimation;
  late AnimationController _shadowAnimController;
  late Animation<double> _shadowAnimation;
  bool _showRoutePanel = false;
  bool _routePanelMinimized = false;
  late AnimationController _minimizedPanelAnimController;
  late Animation<Offset> _minimizedPanelSlideAnimation;
  final List<TextEditingController> _stopControllers = [];
  MapProvider? _mapProvider;
  String? _lastSeenError;

  @override
  void initState() {
    super.initState();
    _panelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _panelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _panelAnimController,
      curve: Curves.easeOutCubic,
    ));

    _routePanelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _routePanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _routePanelAnimController,
      curve: Curves.easeOutCubic,
    ));

    _shadowAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shadowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shadowAnimController,
      curve: Curves.easeIn,
    ));

    _minimizedPanelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _minimizedPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _minimizedPanelAnimController,
      curve: Curves.easeOutCubic,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      mapProvider.setMapController(_mapController);
      mapProvider.getUserLocation();
      // Start with clean map view - panel opens when user taps navigation
      // _openNavPanel(); // Removed auto-open
    });
    
    // Auto-zoom to route when calculated
    _mapProvider = Provider.of<MapProvider>(context, listen: false);
    _mapProvider!.addListener(_onRouteChanged);

    _locationController.addListener(_onFieldChanged);
    _destinationController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _mapProvider?.removeListener(_onRouteChanged);

    _locationController.removeListener(_onFieldChanged);
    _destinationController.removeListener(_onFieldChanged);
    _locationController.dispose();
    _destinationController.dispose();
    _panelAnimController.dispose();
    _routePanelAnimController.dispose();
    _shadowAnimController.dispose();
    _minimizedPanelAnimController.dispose();
    for (final c in _stopControllers) {
      c.dispose();
    }
    _mapController.dispose();
    super.dispose();
  }

  void _onRouteChanged() {
    final mp = Provider.of<MapProvider>(context, listen: false);

    // Auto-fill start location once GPS becomes available (if panel is open and field is empty)
    if (_showNavPanel &&
        _locationController.text.trim().isEmpty &&
        mp.startLocation == null &&
        mp.userLocation != null) {
      final currentLoc = PlaceModel(
        fullAddress: 'My Location',
        latitude: mp.userLocation!.latitude,
        longitude: mp.userLocation!.longitude,
        placeId: 'current_location',
      );
      mp.setStartLocation(currentLoc);
      setState(() {
        _locationController.text = 'My Location';
      });
    }

    // Show errors via Modal as requested
    if (mp.errorMessage != null && mp.errorMessage!.isNotEmpty) {
      if (mp.errorMessage != _lastSeenError &&
          !mp.errorMessage!.contains('Location services are disabled')) {
        _lastSeenError = mp.errorMessage;
        // Schedule dialog to avoid frame build issues
        Future.microtask(() {
          if (mounted) _showErrorDialog(mp.errorMessage!);
        });
      }
    } else {
      _lastSeenError = null;
    }

    // If we have an optimized route, fit camera to it
    if (mp.optimizedRoute != null && mp.optimizedRoute!.path.isNotEmpty) {
      // Calculate bounds
      double? minLat, maxLat, minLng, maxLng;
      for (var point in mp.optimizedRoute!.path) {
        if (minLat == null || point[0] < minLat) minLat = point[0];
        if (maxLat == null || point[0] > maxLat) maxLat = point[0];
        if (minLng == null || point[1] < minLng) minLng = point[1];
        if (maxLng == null || point[1] > maxLng) maxLng = point[1];
      }

      if (minLat != null && maxLat != null && minLng != null && maxLng != null) {
        // Add padding
        final bounds = LatLngBounds(
          LatLng(minLat, minLng),
          LatLng(maxLat, maxLng),
        );
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.only(
                top: 100, bottom: 200, left: 50, right: 50),
          ),
        );
      }
    }
    
    // Check for Location Permission Error to show dialog
    if (mp.errorMessage != null && 
        mp.errorMessage!.contains('Location services are disabled')) {
      _showLocationDialog();
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF292929),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Message',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: const Color(0xFFB1FF8E)),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location Disabled'),
        content: const Text('Please enable location services to use this feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Geolocator.openLocationSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _onFieldChanged() {
    setState(() {}); // rebuild to re-evaluate Find Route enabled state
  }

  void _fitMapToPoints() {
    final mp = Provider.of<MapProvider>(context, listen: false);
    final points = <LatLng>[];
    if (mp.startLocation != null) {
      points.add(LatLng(mp.startLocation!.latitude, mp.startLocation!.longitude));
    }
    for (final stop in mp.stops) {
      points.add(LatLng(stop.latitude, stop.longitude));
    }
    if (mp.destination != null) {
      points.add(LatLng(mp.destination!.latitude, mp.destination!.longitude));
    }
    if (points.length == 1) {
      _animatedMapMove(points.first, 14);
      return;
    }
    if (points.length < 2) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.only(top: 120, bottom: 320, left: 60, right: 60),
      ),
    );
  }

  /// Build context markers from current provider state.
  /// [exclude] can be 'start', 'destination', or 'stop:N' to skip the point being edited.
  List<ExistingMarker> _buildExistingMarkers({String? exclude}) {
    final mp = Provider.of<MapProvider>(context, listen: false);
    final markers = <ExistingMarker>[];
    if (mp.startLocation != null && exclude != 'start') {
      markers.add(ExistingMarker(
        point: LatLng(mp.startLocation!.latitude, mp.startLocation!.longitude),
        color: const Color(0xFFB1FF8E),
      ));
    }
    for (int i = 0; i < mp.stops.length; i++) {
      if (exclude == 'stop:$i') continue;
      markers.add(ExistingMarker(
        point: LatLng(mp.stops[i].latitude, mp.stops[i].longitude),
        color: const Color(0xFF64B5F6),
        label: '${i + 1}',
      ));
    }
    if (mp.destination != null && exclude != 'destination') {
      markers.add(ExistingMarker(
        point: LatLng(mp.destination!.latitude, mp.destination!.longitude),
        color: const Color(0xFFFF4444),
      ));
    }
    return markers;
  }

  Future<void> _openLocationSearch({
    required String label,
    required TextEditingController controller,
    required Function(PlaceModel) onSelected,
    List<ExistingMarker> existingMarkers = const [],
  }) async {
    final result = await Navigator.push<PlaceModel>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSearchScreen(
          fieldLabel: label,
          initialValue: controller.text,
          existingMarkers: existingMarkers,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        controller.text = result.fullAddress;
      });
      onSelected(result);
      _fitMapToPoints();

      // Auto-recalculate route when start or destination changes while route panel is open
      if (_showRoutePanel) {
        final mp = Provider.of<MapProvider>(context, listen: false);
        if (mp.startLocation != null && mp.destination != null) {
          if (mp.stops.isNotEmpty) {
            mp.calculateChainedRoute();
          } else {
            mp.findDirectRoute();
          }
        }
      }
    }
  }

  void _openNavPanel() {
    setState(() => _showNavPanel = true);
    
    // Sync UI controllers with MapProvider stops state
    // This fixes the issue where waypoints are plotted but not editable after returning to panel
    final mp = Provider.of<MapProvider>(context, listen: false);
    if (mp.stops.isNotEmpty && _stopControllers.isEmpty) {
        for (var stop in mp.stops) {
            final controller = TextEditingController(text: stop.fullAddress);
            controller.addListener(_onFieldChanged);
            _stopControllers.add(controller);
        }
    } else if (mp.stops.length != _stopControllers.length) {
        // Full resync if mismatch
        for (var c in _stopControllers) {
          c.dispose();
        }
        _stopControllers.clear();
        for (var stop in mp.stops) {
            final controller = TextEditingController(text: stop.fullAddress);
            controller.addListener(_onFieldChanged);
            _stopControllers.add(controller);
        }
    }
    
    _panelAnimController.forward();

    // Auto-set start location to current GPS if not already set
    final hasStart = _locationController.text.trim().isNotEmpty;
    if (!hasStart && mp.userLocation != null && mp.startLocation == null) {
      final currentLoc = PlaceModel(
        fullAddress: 'My Location',
        latitude: mp.userLocation!.latitude,
        longitude: mp.userLocation!.longitude,
        placeId: 'current_location',
      );
      mp.setStartLocation(currentLoc);
      setState(() {
        _locationController.text = 'My Location';
      });
    }
  }

  void _closeNavPanel() {
    _panelAnimController.reverse().then((_) {
      if (mounted) setState(() => _showNavPanel = false);
    });
  }

  void _onFindRoute() {
    // If no start location selected, default to current GPS location
    final mp = Provider.of<MapProvider>(context, listen: false);
    if (_locationController.text.trim().isEmpty && mp.userLocation != null) {
      final currentLoc = PlaceModel(
        fullAddress: 'Current Location',
        latitude: mp.userLocation!.latitude,
        longitude: mp.userLocation!.longitude,
        placeId: 'current_location',
      );
      mp.setStartLocation(currentLoc);
      _locationController.text = 'Current Location';
    }

    // Close nav panel, then open route panel with animated shadow
    _panelAnimController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _showNavPanel = false;
        _showRoutePanel = true;
      });
      _routePanelAnimController.forward();
      // Delay shadow slightly for a staggered feel
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _shadowAnimController.forward();
      });

      // Call routing API
      final mapProv = Provider.of<MapProvider>(context, listen: false);
      if (mapProv.stops.isNotEmpty) {
        mapProv.calculateChainedRoute();
      } else {
        mapProv.findDirectRoute();
      }
    });
  }

  void _closeRoutePanel() {
    _shadowAnimController.reverse();
    _routePanelAnimController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _showRoutePanel = false;
        _routePanelMinimized = false;
        for (final c in _stopControllers) {
          c.dispose();
        }
        _stopControllers.clear();
      });
    });
  }

  void _resetNavigation() {
    final mp = Provider.of<MapProvider>(context, listen: false);
    // Close whichever panel is showing
    if (_routePanelMinimized) {
      _minimizedPanelAnimController.reverse();
    } else {
      _routePanelAnimController.reverse();
    }
    _shadowAnimController.reverse();
    // Clear all state
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _showRoutePanel = false;
        _routePanelMinimized = false;
        _locationController.clear();
        _destinationController.clear();
        for (final c in _stopControllers) {
          c.dispose();
        }
        _stopControllers.clear();
      });
      mp.reset();
    });
  }

  void _minimizeRoutePanel() {
    _routePanelAnimController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _routePanelMinimized = true);
      _minimizedPanelAnimController.forward();
    });
  }

  void _expandRoutePanel() {
    _minimizedPanelAnimController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _routePanelMinimized = false);
      _routePanelAnimController.forward();
    });
  }

  void _addStop() async {
    final result = await Navigator.push<PlaceModel>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSearchScreen(
          fieldLabel: 'Add Stop',
          existingMarkers: _buildExistingMarkers(),
        ),
      ),
    );
    if (result != null && mounted) {
      final mp = Provider.of<MapProvider>(context, listen: false);
      mp.addStop(result);
      setState(() {
        _stopControllers.add(TextEditingController(text: result.fullAddress));
      });
      _fitMapToPoints();
      // Re-calculate route (chained) whenever a stop is added
      if (mp.startLocation != null && mp.destination != null) {
         mp.calculateChainedRoute();
      }
    }
  }

  void _removeStop(int index) {
    if (index >= 0 && index < _stopControllers.length) {
      final mp = Provider.of<MapProvider>(context, listen: false);
      mp.removeStop(index);
      setState(() {
        _stopControllers[index].dispose();
        _stopControllers.removeAt(index);
      });
      // Re-calculate route (chained) whenever a stop is removed
      if (mp.startLocation != null && mp.destination != null) {
        mp.calculateChainedRoute();
      }
    }
  }

  void _reorderWaypoints(int oldIndex, int newIndex) {
    final mp = Provider.of<MapProvider>(context, listen: false);
    mp.reorderWaypoints(oldIndex, newIndex);
    
    // Sync controllers with new provider state
    _syncControllersWithProvider(mp);
    
    // Re-calculate route
    if (mp.startLocation != null && mp.destination != null) {
      mp.calculateChainedRoute();
    }
  }
  
  void _syncControllersWithProvider(MapProvider mp) {
      setState(() {
          // Sync Start
          if (mp.startLocation != null) {
            _locationController.text = mp.startLocation!.fullAddress;
          }
          
          // Sync Destination
          if (mp.destination != null) {
            _destinationController.text = mp.destination!.fullAddress;
          }
          
          // Sync Stops (Count is constant in a swap, but let's be safe)
          // Actually, in a reorder, the count of intermediate stops should be constant unless I dragged start to dest?
          // No, logic is [Start, ...Stops, Dest]. Size is constant. 
          // Stops size is (Total - 2). So it is constant.
          for (int i = 0; i < mp.stops.length; i++) {
              if (i < _stopControllers.length) {
                  _stopControllers[i].text = mp.stops[i].fullAddress;
              }
          }
      });
  }

  void _reorderStop(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final mp = Provider.of<MapProvider>(context, listen: false);
    mp.reorderStops(oldIndex, newIndex);
    setState(() {
      final controller = _stopControllers.removeAt(oldIndex);
      _stopControllers.insert(newIndex, controller);
    });
     // Re-calculate route (chained) whenever stops are reordered
     if (mp.startLocation != null && mp.destination != null) {
         mp.calculateChainedRoute();
      }
  }

  List<Polyline> _buildPolylines(MapProvider mapProvider) {
    if (mapProvider.optimizedRoute == null) return [];

    List<LatLng> polylineCoordinates = mapProvider.optimizedRoute!.path
        .map((coord) => LatLng(coord[0], coord[1]))
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

    // Start marker
    if (mapProvider.startLocation != null) {
      markers.add(
        Marker(
          point: LatLng(
            mapProvider.startLocation!.latitude,
            mapProvider.startLocation!.longitude,
          ),
          width: 32,
          height: 32,
          child: _buildCircleMarker(
            color: const Color(0xFFB1FF8E),
            innerColor: const Color(0xFF171717),
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
          width: 32,
          height: 32,
          child: _buildCircleMarker(
            color: const Color(0xFF64B5F6),
            innerColor: const Color(0xFF171717),
            label: '${i + 1}',
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
          width: 32,
          height: 32,
          child: _buildCircleMarker(
            color: const Color(0xFFFF4444),
            innerColor: const Color(0xFF171717),
          ),
        ),
      );
    }

    return markers;
  }

  /// Current location "me" marker — concentric green circles
  Widget _buildMeMarker() {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFB1FF8E).withValues(alpha: 0.17),
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFB1FF8E),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF171717),
            ),
          ),
        ],
      ),
    );
  }

  /// Map marker — concentric circles with optional number label
  Widget _buildCircleMarker({
    required Color color,
    required Color innerColor,
    String? label,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
            ),
          ),
          // Middle solid ring
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          // Inner dark circle
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: innerColor,
            ),
            child: label != null
                ? Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  /// Destination icon for nav panel — small red concentric circles
  Widget _buildDestinationIcon() {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF4444).withValues(alpha: 0.17),
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF4444),
            ),
          ),
          Container(
            width: 10,
            height: 10,
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
              initialCenter: mapProvider.userLocation ?? const LatLng(20, 0),
              initialZoom: mapProvider.userLocation != null ? 15.0 : 2.0,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mapnow.map_now',
                maxZoom: 19,
              ),
              PolylineLayer(polylines: _buildPolylines(mapProvider)),
              MarkerLayer(markers: [
                ..._buildMarkers(mapProvider),
                // Add pulsing marker for user location if available
                if (mapProvider.userLocation != null)
                   Marker(
                    point: mapProvider.userLocation!,
                    width: 80,
                    height: 80,
                    child: const PulsingLocationMarker(color: Color(0xFF4285F4)), // Google Blue
                  ),
              ]),
            ],
          ),

          // ── GPS loading indicator (top-center) ──
          if (mapProvider.locationLoading && mapProvider.userLocation == null)
            Positioned(
              top: topPadding + 14,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF212121),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Color(0xFFB1FF8E),
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Finding your location...',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Hamburger menu button (top-left) ──
          Positioned(
            top: topPadding + 12,
            left: 14,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: mapProvider.isLoading ? null : () => _showProfileMenu(context),
                borderRadius: BorderRadius.circular(12),
                splashColor: Colors.white.withOpacity(0.15),
                highlightColor: Colors.white.withOpacity(0.08),
                child: Ink(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF212121),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.menu,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Compass button (bottom-right, above route button) ──
          if (!_showNavPanel && !_showRoutePanel)
            Positioned(
            right: 20,
            bottom: 170,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: mapProvider.isLoading ? null : () {
                  // Re-center on user location with animation
                  if (mapProvider.userLocation != null) {
                    _animatedMapMove(mapProvider.userLocation!, 15);
                    _mapController.rotate(0);
                  } else {
                    _mapController.rotate(0);
                    mapProvider.getUserLocation();
                  }
                },
                customBorder: const CircleBorder(),
                splashColor: Colors.black.withOpacity(0.12),
                highlightColor: Colors.black.withOpacity(0.06),
                child: Ink(
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
                  child: Center(
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
          ),

          // ── Route / Navigate button (bottom-right) ──
          if (!_showNavPanel && !_showRoutePanel)
            Positioned(
              right: 12,
              bottom: 80,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                onTap: mapProvider.isLoading ? null : _openNavPanel,
                customBorder: const CircleBorder(),
                splashColor: Colors.black.withOpacity(0.15),
                highlightColor: Colors.black.withOpacity(0.08),
                child: Ink(
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
          ),

          // ── Navigation Panel (slides up) ──
          if (_showNavPanel)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _panelSlideAnimation,
                child: _buildNavigationPanel(mapProvider),
              ),
            ),



          // ── Tap-outside to minimize route panel (passes touches to map) ──
          if (_showRoutePanel && !_routePanelMinimized)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: mapProvider.isLoading ? null : _minimizeRoutePanel,
                child: const SizedBox.shrink(),
              ),
            ),

          // ── Route Panel (slides up after Find Route) ──
          if (_showRoutePanel && !_routePanelMinimized)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _routePanelSlideAnimation,
                child: _buildRoutePanel(mapProvider),
              ),
            ),

          // ── Minimized Route Panel ──
          if (_showRoutePanel && _routePanelMinimized)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _minimizedPanelSlideAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: mapProvider.isLoading ? null : _expandRoutePanel,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    splashColor: Colors.white.withOpacity(0.08),
                    highlightColor: Colors.white.withOpacity(0.04),
                    child: _buildMinimizedRoutePanel(),
                  ),
                ),
              ),
            ),

          // ── Loading indicator with backdrop ──
          if (mapProvider.isLoading)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: const Color(0xFF212121),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFB1FF8E).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: Color(0xFFB1FF8E),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Finding route',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Please wait...',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Distance badge (shown when route found, upper right) ──
          if (mapProvider.optimizedRoute != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
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
                    Container(
                      width: 1,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const Icon(
                      Icons.access_time,
                      color: Color(0xFFB1FF8E),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      mapProvider.optimizedRoute!.etaLabel,
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

  Widget _buildNavigationPanel(MapProvider mapProvider) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF212121),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: Color(0xFF4B4B4B), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Inner card ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF292929),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: "Navigation" + close button ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Navigation',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: mapProvider.isLoading ? null : _closeNavPanel,
                          customBorder: const CircleBorder(),
                          splashColor: Colors.white.withOpacity(0.2),
                          child: Ink(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            child: Transform.rotate(
                              angle: 0.785398, // 45 degrees
                              child: const Icon(
                                Icons.add,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Location + Destination fields with connector ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column: icons + dotted line
                      SizedBox(
                        width: 24,
                        child: Column(
                          children: [
                            // "Me" marker — centered in 38px to match field height
                            SizedBox(
                              height: 38,
                              child: Center(child: _buildMeMarker()),
                            ),
                            // Dotted connector — matches 12px gap between fields
                            SizedBox(
                              height: 12,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  3,
                                  (_) => Container(
                                    width: 2,
                                    height: 2,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 0.8),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Red circle — centered in 38px to match field height
                            SizedBox(
                              height: 38,
                              child: Center(
                                child: _buildDestinationIcon(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Right column: text fields
                      Expanded(
                        child: Column(
                          children: [
                            // Your Location
                            Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF444444),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _locationController,
                                readOnly: true,
                                onTap: () => _openLocationSearch(
                                  label: 'Your Location',
                                  controller: _locationController,
                                  existingMarkers: _buildExistingMarkers(exclude: 'start'),
                                  onSelected: (place) {
                                    final mp = Provider.of<MapProvider>(context, listen: false);
                                    mp.setStartLocation(place);
                                  },
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: InputDecoration(
                                  hintText: 'Your Location',
                                  hintStyle: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 11,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Your Destination
                            Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF444444),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _destinationController,
                                readOnly: true,
                                onTap: () => _openLocationSearch(
                                  label: 'Your Destination',
                                  controller: _destinationController,
                                  existingMarkers: _buildExistingMarkers(exclude: 'destination'),
                                  onSelected: (place) {
                                    final mp = Provider.of<MapProvider>(context, listen: false);
                                    mp.setDestination(place);
                                  },
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: InputDecoration(
                                  hintText: 'Your Destination',
                                  hintStyle: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),


                ],
              ),
            ),
          ),

          // ── Find Route button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            child: Builder(
              builder: (context) {
                final mp = Provider.of<MapProvider>(context);
                final hasStart = _locationController.text.trim().isNotEmpty || mp.userLocation != null;
                final isEnabled = hasStart &&
                    _destinationController.text.trim().isNotEmpty;
                return Opacity(
                  opacity: isEnabled ? 1.0 : 0.35,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isEnabled ? _onFindRoute : null,
                      borderRadius: BorderRadius.circular(12),
                      splashColor: Colors.black.withOpacity(0.15),
                      highlightColor: Colors.black.withOpacity(0.08),
                      child: Ink(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB1FF8E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Find Route',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ),
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

  // ── Route Panel (shown after pressing Find Route) ──
  Widget _buildRoutePanel(MapProvider mapProvider) {
    return AnimatedBuilder(
      animation: _shadowAnimation,
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Main panel container
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF212121),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: const Border(
                  top: BorderSide(color: Color(0xFF4B4B4B), width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB1FF8E)
                        .withValues(alpha: 0.5 * _shadowAnimation.value),
                    blurRadius: 134.5 * _shadowAnimation.value,
                    spreadRadius: 5 * _shadowAnimation.value,
                    offset: Offset(0, 33 * _shadowAnimation.value),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 14), // space for overlapping icon

                  // ── Inner card ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF292929),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── Unified Reorderable List (Start - Stops - Dest) ──
                                ReorderableListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  buildDefaultDragHandles: false,
                                  proxyDecorator: (child, index, animation) {
                                    return Material(
                                      color: Colors.transparent,
                                      elevation: 0,
                                      child: child,
                                    );
                                  },
                                  onReorder: _reorderWaypoints, 
                                  // Total items = Start (1) + Stops + Dest (1)
                                  itemCount: 2 + _stopControllers.length,
                                  itemBuilder: (context, index) {
                                    final isStart = index == 0;
                                    final isDest = index == (_stopControllers.length + 1);
                                    final isStop = !isStart && !isDest;
                                    final stopIndex = isStop ? index - 1 : -1;

                                    return Column(
                                      key: ValueKey('waypoint_$index'),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Connector above item (except for Start)
                                        if (!isStart) _buildDottedConnector(),
                                        
                                        _buildFieldRow(
                                          icon: ReorderableDragStartListener(
                                            index: index,
                                            child: isStart 
                                                ? _buildMeMarker() 
                                                : (isDest ? _buildDestinationIcon() : _buildStopMarker()),
                                          ),
                                          child: Container(
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF444444),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: isStart 
                                                        ? _locationController 
                                                        : (isDest ? _destinationController : _stopControllers[stopIndex]),
                                                    readOnly: true,
                                                    onTap: () => _openLocationSearch(
                                                      label: isStart 
                                                          ? 'Your Location' 
                                                          : (isDest ? 'Your Destination' : 'Stop ${stopIndex + 1}'),
                                                      controller: isStart 
                                                          ? _locationController 
                                                          : (isDest ? _destinationController : _stopControllers[stopIndex]),
                                                      existingMarkers: _buildExistingMarkers(
                                                        exclude: isStart ? 'start' : (isDest ? 'destination' : 'stop:$stopIndex'),
                                                      ),
                                                      onSelected: (place) {
                                                        final mp = Provider.of<MapProvider>(context, listen: false);
                                                        if (isStart) {
                                                          mp.setStartLocation(place);
                                                        } else if (isDest) {
                                                          mp.setDestination(place);
                                                        } else {
                                                          // Replace existing stop
                                                          mp.removeStop(stopIndex);
                                                          mp.addStop(place); 
                                                        }
                                                      },
                                                    ),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 13,
                                                      color: Colors.white,
                                                    ),
                                                    textAlignVertical: TextAlignVertical.center,
                                                    decoration: InputDecoration(
                                                      hintText: isStart 
                                                          ? 'Your Location' 
                                                          : (isDest ? 'Your Destination' : 'Stop ${stopIndex + 1}'),
                                                      hintStyle: GoogleFonts.poppins(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w400,
                                                        fontStyle: FontStyle.italic,
                                                        color: Colors.white.withValues(alpha: 0.35),
                                                      ),
                                                      border: InputBorder.none,
                                                      isCollapsed: true,
                                                      contentPadding: const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 11,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                
                                                // Drag Handle (Right side)
                                                ReorderableDragStartListener(
                                                    index: index,
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                                      child: Icon(
                                                        Icons.drag_handle_rounded,
                                                        color: Colors.white.withValues(alpha: 0.4),
                                                        size: 20,
                                                      ),
                                                    ),
                                                ),

                                                // Close/Remove Button (Only for stops)
                                                if (isStop)
                                                  Column(
                                                    children: [
                                                        Container(
                                                            width: 1,
                                                            height: 16,
                                                            color: Colors.white.withValues(alpha: 0.1),
                                                        ),
                                                    ],
                                                  ),
                                                if (isStop)
                                                  GestureDetector(
                                                    onTap: () => _removeStop(stopIndex),
                                                    child: Padding(
                                                      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                                                      child: Icon(
                                                        Icons.close,
                                                        size: 18,
                                                        color: Colors.white.withValues(alpha: 0.5),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  const SizedBox(width: 12), // Spacer for non-removable items
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                    ),
                  ),

                  // ── Action buttons ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Optimise Route — only shown when there are stops
                            if (_stopControllers.isNotEmpty)
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final mp = Provider.of<MapProvider>(context);
                                    final canOptimize = mp.stopsNeedOptimization;
                                    return Opacity(
                                      opacity: canOptimize ? 1.0 : 0.35,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: canOptimize
                                              ? () {
                                                  final mp = Provider.of<MapProvider>(context, listen: false);
                                                  mp.optimizeRoute();
                                                }
                                              : null,
                                          borderRadius: BorderRadius.circular(12),
                                          splashColor: Colors.black.withOpacity(0.15),
                                          highlightColor: Colors.black.withOpacity(0.08),
                                          child: Ink(
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFB1FF8E),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Optimise Route',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            if (_stopControllers.isNotEmpty)
                              const SizedBox(width: 10),
                            // Add Stop — takes full width when no stops exist
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final canAdd = _stopControllers.length < 3;
                                  return Opacity(
                                    opacity: canAdd ? 1.0 : 0.35,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: canAdd ? _addStop : null,
                                        borderRadius: BorderRadius.circular(12),
                                        splashColor: Colors.black.withOpacity(0.15),
                                        highlightColor: Colors.black.withOpacity(0.08),
                                        child: Ink(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFB1FF8E),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Add Stop +',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        // ── Start Navigation Button (full width) ──
                        if (mapProvider.optimizedRoute != null) ...[
                          const SizedBox(height: 12),
                          // Show "too far" hint if user isn't near the route
                          if (!mapProvider.isUserLocationPartOfRoute)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.info_outline, color: Colors.orange.shade300, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Move closer to the start or destination to begin',
                                    style: GoogleFonts.poppins(
                                      color: Colors.orange.shade300,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Opacity(
                            opacity: mapProvider.isUserLocationPartOfRoute ? 1.0 : 0.4,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  final mp = Provider.of<MapProvider>(context, listen: false);
                                  if (mp.destination == null) return;
                                  
                                  if (!mp.isUserLocationPartOfRoute) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'You must be at the start or destination to begin navigation',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        backgroundColor: Colors.orange.shade700,
                                      ),
                                    );
                                    return;
                                  }
                                  
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => NavigationScreen(
                                        route: mp.optimizedRoute!,
                                        startPosition: mp.userLocation!,
                                        destination: mp.destination!,
                                        startLocation: mp.startLocation,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                splashColor: Colors.black.withOpacity(0.15),
                                highlightColor: Colors.black.withOpacity(0.08),
                                child: Ink(
                                  width: double.infinity,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB1FF8E),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.navigation,
                                          color: Colors.black,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Start Navigation',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Overlapping route icon at top (center) ──
            Positioned(
              top: -18,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _closeRoutePanel,
                    customBorder: const CircleBorder(),
                    splashColor: Colors.black.withOpacity(0.15),
                    child: Ink(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFB1FF8E),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB1FF8E).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Transform.rotate(
                          angle: 0.785398,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: const Color(0xFF171717), width: 2),
                            ),
                            child: Center(
                              child: Transform.rotate(
                                angle: -0.785398,
                                child: const Icon(Icons.turn_right, color: Color(0xFF171717), size: 11),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Floating reset (×) button at top-left ──
            Positioned(
              top: -18,
              left: 16,
              child: GestureDetector(
                onTap: _resetNavigation,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF333333),
                    border: Border.all(
                      color: const Color(0xFF4B4B4B),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Minimized route panel (Next Stop) ──
  Widget _buildMinimizedRoutePanel() {
    return AnimatedBuilder(
      animation: _shadowAnimation,
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF212121),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: const Border(
                  top: BorderSide(color: Color(0xFF4B4B4B), width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB1FF8E)
                        .withValues(alpha: 0.5 * _shadowAnimation.value),
                    blurRadius: 134.5 * _shadowAnimation.value,
                    spreadRadius: 5 * _shadowAnimation.value,
                    offset: Offset(0, 33 * _shadowAnimation.value),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 34, 14, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // "Next Stop" label
                    Text(
                      'Next Stop',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Display next upcoming stop (read-only)
                    Builder(
                      builder: (context) {
                        final mp = Provider.of<MapProvider>(context);
                        final nextStopText = mp.stops.isNotEmpty
                            ? mp.stops.first.fullAddress
                            : mp.destination != null
                                ? mp.destination!.fullAddress
                                : 'No stops added';
                        return Container(
                          width: double.infinity,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF444444),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            nextStopText,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: mp.stops.isNotEmpty || mp.destination != null
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),

                    // ── Start Navigation Button (in minimized panel) ──
                    Builder(
                      builder: (context) {
                        final mp = Provider.of<MapProvider>(context);
                        if (mp.optimizedRoute != null) {
                          final canStart = mp.isUserLocationPartOfRoute;
                          return Column(
                            children: [
                              if (!canStart)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.orange.shade300, size: 13),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Move closer to start or destination',
                                        style: GoogleFonts.poppins(
                                          color: Colors.orange.shade300,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Opacity(
                                  opacity: canStart ? 1.0 : 0.4,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        if (mp.destination == null) return;
                                        
                                        if (!mp.isUserLocationPartOfRoute) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'You must be at the start or destination to begin navigation',
                                                style: GoogleFonts.poppins(),
                                              ),
                                              backgroundColor: Colors.orange.shade700,
                                            ),
                                          );
                                          return;
                                        }
                                        
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => NavigationScreen(
                                              route: mp.optimizedRoute!,
                                              startPosition: mp.userLocation!,
                                              destination: mp.destination!,
                                              startLocation: mp.startLocation,
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      splashColor: Colors.black.withOpacity(0.15),
                                      highlightColor: Colors.black.withOpacity(0.08),
                                      child: Ink(
                                        width: double.infinity,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFB1FF8E),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.navigation,
                                                color: Colors.black,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Start Navigation',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Overlapping route icon ──
            Positioned(
              top: -18,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFB1FF8E),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB1FF8E).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: 0.785398,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF171717), width: 2),
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.785398,
                            child: const Icon(Icons.turn_right, color: Color(0xFF171717), size: 11),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Floating reset (×) button at top-left ──
            Positioned(
              top: -18,
              left: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _resetNavigation,
                  customBorder: const CircleBorder(),
                  splashColor: Colors.white.withOpacity(0.2),
                  child: Ink(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF333333),
                      border: Border.all(
                        color: const Color(0xFF4B4B4B),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// A single row: [30px icon] [18px gap] [expanded field]
  Widget _buildFieldRow({required Widget icon, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 24, height: 24, child: Center(child: icon)),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }

  /// Dotted vertical connector between fields
  Widget _buildDottedConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 11), // center under the 24px icon
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (_) => Container(
                width: 2,
                height: 3,
                margin: const EdgeInsets.symmetric(vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Grey stop marker (muted version of the "me" marker)
  Widget _buildStopMarker() {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF171717),
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

            // Feedback
            ListTile(
              leading: const Icon(Icons.feedback_outlined, color: Colors.white),
              title: Text(
                'Send Feedback',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const FeedbackScreen()));
              },
            ),

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
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF292929),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Reset Map?',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                    content: Text(
                      'This will clear your route, stops, and all map data.',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel',
                            style: GoogleFonts.poppins(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () {
                          mapProvider.reset();
                          Navigator.pop(context);
                        },
                        child: Text('Reset',
                            style: GoogleFonts.poppins(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
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
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF292929),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Logout?',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                    content: Text(
                      'Are you sure you want to log out?',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel',
                            style: GoogleFonts.poppins(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () {
                          authProvider.logout();
                          Navigator.pop(context);
                          Navigator.of(context).pushReplacementNamed('/welcome');
                        },
                        child: Text('Logout',
                            style: GoogleFonts.poppins(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Animates the map movement to a destination with a "zoom in/out" bounce effect
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final startLat = _mapController.camera.center.latitude;
    final startLng = _mapController.camera.center.longitude;
    final startZoom = _mapController.camera.zoom;

    final latTween = Tween<double>(begin: startLat, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: startLng, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: startZoom, end: destZoom);

    // Create a controller locally. Note: we need to dispose it carefully.
    // If we fire multiple animations, we might want to cancel previous ones,
    // but for now we assume one at a time.
    final controller = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this);
    
    // easeOutBack gives a slight overshoot (zoom in past target then back out)
    final Animation<double> animation = CurvedAnimation(
        parent: controller, curve: Curves.easeOutBack);

    controller.addListener(() {
      _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }
}
