import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../models/route_model.dart';
import '../models/place_model.dart';
import '../services/routing_service.dart';

class NavigationScreen extends StatefulWidget {
  final RouteModel route;
  final LatLng startPosition;
  final PlaceModel destination; // Added to enable recalculation
  final PlaceModel? startLocation; // Added start model

  const NavigationScreen({
    super.key,
    required this.route,
    required this.startPosition,
    required this.destination,
    this.startLocation,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final RoutingService _routingService = RoutingService();
  
  // Navigation Path
  late List<LatLng> _currentPath;
  RouteModel? _activeRoute;

  // Navigation State
  late LatLng _currentLocation;
  double _currentHeading = 0.0;
  double _deviceHeading = 0.0; // From Compass
  bool _isNavigationActive = true;
  bool _isDriverView = true; // Default to Driver View (3D-ish/Rotated)
  
  // Off-route Detection
  int _offRouteCounter = 0;
  final double _offRouteThreshold = 100.0; // meters
  bool _isRecalculating = false;
  double _remainingDistance = 0.0; // Real-time distance updates
  
  bool _mapReady = false; // Add map readiness flag

  // Stream & Timer
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<CompassEvent>? _compassStreamSubscription;
  Timer? _simulationTimer;
  Timer? _cleanupTimer;

  // Animation for smooth marker movement
  late AnimationController _markerAnimController;
  late Animation<double> _latAnimation;
  late Animation<double> _lngAnimation;
  late Animation<double> _headingAnimation;
  LatLng _markerPosition = const LatLng(0, 0); // Display position (animated)
  double _markerHeading = 0.0; // Display heading (animated)

  // Simulation State (Debug only)
  bool _isSimulating = false;
  int _simulationIndex = 0;

  @override
  void initState() {
    super.initState();
    _activeRoute = widget.route;
    _currentPath = widget.route.path.map((e) => LatLng(e[0], e[1])).toList();
    _currentLocation = widget.startPosition;
    _markerPosition = widget.startPosition;
    _remainingDistance = widget.route.distanceInKm;

    // Setup animation controller for smoothing updates
    _markerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Interpolate over 1s
    );
    
    _latAnimation = Tween<double>(begin: _currentLocation.latitude, end: _currentLocation.latitude)
        .animate(_markerAnimController);
    _lngAnimation = Tween<double>(begin: _currentLocation.longitude, end: _currentLocation.longitude)
        .animate(_markerAnimController);
    _headingAnimation = Tween<double>(begin: 0, end: 0)
        .animate(_markerAnimController);

    _markerAnimController.addListener(() {
      if (!mounted) return;
      setState(() {
        _markerPosition = LatLng(_latAnimation.value, _lngAnimation.value);
        _markerHeading = _headingAnimation.value;
      });
      
      // Update camera if following user
      if (_isNavigationActive) {
        _updateCamera();
      }
    });

    _startCompassUpdates();
    _startLocationUpdates();
    
    // Periodic check to trim path and check off-route
    _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!_isSimulating && !_isRecalculating && mounted) {
            _checkRouteStatus();
        }
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _compassStreamSubscription?.cancel();
    _simulationTimer?.cancel();
    _cleanupTimer?.cancel();
    _markerAnimController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _startCompassUpdates() {
    _compassStreamSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null && mounted) {
        setState(() {
          _deviceHeading = event.heading!;
        });
      }
    });
  }

  void _startLocationUpdates() {
    // location settings optimized for navigation
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings
    ).listen((Position position) {
      if (!_isSimulating && mounted) {
        _updatePosition(
          LatLng(position.latitude, position.longitude),
          position.heading,
        );
      }
    });
  }

  void _updatePosition(LatLng newPos, double newHeading) {
    if (!mounted) return;
    
    // Reset animation to start from current display position
    final startLat = _markerPosition.latitude;
    final startLng = _markerPosition.longitude;
    final startHeading = _markerHeading;
    
    // Determine shortest rotation direction for heading
    double endHeading = newHeading;
    if ((newHeading - startHeading).abs() > 180) {
      if (newHeading > startHeading) {
        endHeading -= 360;
      } else {
        endHeading += 360;
      }
    }

    _latAnimation = Tween<double>(begin: startLat, end: newPos.latitude).animate(CurvedAnimation(parent: _markerAnimController, curve: Curves.linear));
    _lngAnimation = Tween<double>(begin: startLng, end: newPos.longitude).animate(CurvedAnimation(parent: _markerAnimController, curve: Curves.linear));
    _headingAnimation = Tween<double>(begin: startHeading, end: endHeading).animate(CurvedAnimation(parent: _markerAnimController, curve: Curves.linear));

    _currentLocation = newPos;
    _currentHeading = newHeading;

    _markerAnimController.reset();
    _markerAnimController.forward();
  }

  void _updateCamera() {
    if (!_mapReady) return; // Guard against early calls
    
    // In Driver View, rotate map so "up" is where we are heading
    // In North Up, rotation is 0
    final rotation = _isDriverView ?
      // If we have compass data and GPS heading is 0/none, use compass.
      // But GPS Heading (Bearing) is key for movement.
      // The user wants 'like Google Maps': Map rotates to match travel direction.
      -_markerHeading 
      : 0.0;
    
    // We can't really "tilt" (pitch) easily in standard flutter_map without plugins,
    // but rotation + close zoom gives a good effect.
    _mapController.moveAndRotate(
      _markerPosition, 
      18.0, // High zoom for navigation
      rotation,
    );
  }

  // --- Route Logic: Trimming & Recalculation ---

  /// Calculate total remaining distance in KM
  double _calculateRemainingDistance(LatLng currentPos, List<LatLng> path) {
    if (path.isEmpty) return 0.0;
    
    double dist = 0.0;
    final Distance distance = const Distance();
    
    // 1. Distance from current to first point
    dist += distance.as(LengthUnit.Meter, currentPos, path.first);
    
    // 2. Sum of path segments
    for (int i = 0; i < path.length - 1; i++) {
        dist += distance.as(LengthUnit.Meter, path[i], path[i+1]);
    }
    
    return dist / 1000.0; // Convert to km
  }

  /// Find nearest point index on the path
  int _findNearestPointIndex(LatLng point, List<LatLng> path) {
    if (path.isEmpty) return -1;
    double minDst = double.infinity;
    int minIndex = -1;

    // Search a subset if path is huge, but for now simple loop
    // Optimization: Only search the first 50 points if we assume we are moving forward
    // But for off-route check, we should search all or use a spatial index.
    // Let's stick to full search for correctness first.
    
    for (int i = 0; i < path.length; i++) {
        final p = path[i];
        final dist = const Distance().as(LengthUnit.Meter, point, p);
        if (dist < minDst) {
            minDst = dist;
            minIndex = i;
        }
    }
    return minIndex;
  }
  
  void _checkRouteStatus() async {
    if (_currentPath.isEmpty) return;

    // 1. Find nearest point on current route
    final nearestIndex = _findNearestPointIndex(_currentLocation, _currentPath);
    if (nearestIndex == -1) return;

    final nearestPoint = _currentPath[nearestIndex];
    final distanceToRoute = const Distance().as(LengthUnit.Meter, _currentLocation, nearestPoint);

    // 2. Off-Route Check
    if (distanceToRoute > _offRouteThreshold) {
      _offRouteCounter++;
      if (_offRouteCounter >= 3) {
        // Trigger recalculation
        _offRouteCounter = 0;
        await _recalculateRoute();
      }
    } else {
      _offRouteCounter = 0;
      
      // 3. Trim Tail (Moving along route)
      // Only trim if we have passed points (nearest index > 0)
      if (nearestIndex > 0) {
        if (mounted) {
          setState(() {
            _currentPath = _currentPath.sublist(nearestIndex);
            // Update Remaining Distance
            _remainingDistance = _calculateRemainingDistance(_currentLocation, _currentPath);
          });
        }
      } else {
         // Even if we didn't trim, update distance based on current location to nearest point + rest
          if (mounted) {
             setState(() {
                 _remainingDistance = _calculateRemainingDistance(_currentLocation, _currentPath);
             });
          }
      }
    }
  }

  Future<void> _recalculateRoute() async {
      if (!mounted) return;
      setState(() {
          _isRecalculating = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Rerouting..."), 
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
        )
      );

      try {
          final newRoute = await _routingService.getDirectRoute(
              start: [_currentLocation.latitude, _currentLocation.longitude], 
              destination: [widget.destination.latitude, widget.destination.longitude]
          );
          
          if (newRoute != null && mounted) {
              setState(() {
                  _remainingDistance = newRoute.distanceInKm;
                  _activeRoute = newRoute;
                  _currentPath = newRoute.path.map((e) => LatLng(e[0], e[1])).toList();
                  // Reset simulation index if simulating
                  if (_isSimulating) _simulationIndex = 0; 
              });
          }
      } catch (e) {
          debugPrint("Rerouting failed: $e");
      } finally {
          if (mounted) {
              setState(() => _isRecalculating = false);
          }
      }
  }

  // --- Simulation Logic (Debug Only) ---
  void _toggleSimulation() {
    if (_isSimulating) {
      if (mounted) setState(() => _isSimulating = false);
    } else {
      if (mounted) setState(() => _isSimulating = true);
      _startSimulation();
    }
  }

  void _startSimulation() {
    // Simulate along the CURRENT modified path
    if (_currentPath.isEmpty) return;

    // Use a faster timer for smoother simulation look
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Logic refactored to use _currentPath instead of widget.route.path
      if (_simulationIndex >= _currentPath.length - 1) {
         // Stop at end
         timer.cancel();
         if (mounted) timer.cancel();
         setState(() => _isSimulating = false);
         return;
      }
      
      // Use local simulation index. However, since path changes (gets trimmed), 
      // index 0 is always "current nearest".
      // So if we trim, we should always move from 0 to 1?
      // Actually, if we trim, the path gets shorter. 
      // Let's simplified simulation: Just move through points.
      // If path is trimmed, _simulationIndex needs adjustment or reset?
      
      // Simple Approach: Simulation updates _currentLocation.
      // Main loop trims path.
      // So simulation should just pick "next point after current location distance"?
      // For now, let's keep it dumb: Simulation forces location to Path[i], 
      // Main loop will trim Path[0...i].
      // So Path becomes shorter. 
      // We should always simulate moving to Path[1] (since Path[0] is roughly where we are).
      
      if (_currentPath.length < 2) return;
      
      final current = _currentPath[0];
      final next = _currentPath[1];

      final bearing = Geolocator.bearingBetween(
        current.latitude, current.longitude, 
        next.latitude, next.longitude
      );

      _updatePosition(next, bearing);
      
      // Trim the point we just passed
      if (mounted) {
        setState(() {
          _currentPath.removeAt(0);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.startPosition,
              onMapReady: () {
                _mapReady = true;
              },
              initialZoom: 18.0,
              initialRotation: 0,
              interactionOptions: const InteractionOptions(
                 flags: InteractiveFlag.all & ~InteractiveFlag.rotate, 
              ),
              onPositionChanged: (pos, hasGesture) {
                  if (hasGesture && _isNavigationActive) {
                      // User panned away, disable auto-follow
                      setState(() {
                          _isNavigationActive = false;
                      });
                  }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.map_now',
              ),
              // Route Line
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _currentPath,
                    color: Colors.blueAccent,
                    strokeWidth: 6.0,
                  ),
                ],
              ),
              // Current Position Marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: _markerPosition,
                    width: 60,
                    height: 60,
                    child: Transform.rotate(
                      // If simulating, rely purely on Heading (Bearing)
                      // If real, use Compass Heading (_deviceHeading) to show "Where phone is pointing"
                      // UNLESS user is moving fast, then use Bearing.
                      // For now, let's just use Compass if not simulating for that 'Flashlight' feel.
                      angle: (
                          (_isSimulating ? _markerHeading : _deviceHeading) 
                          * (3.14159 / 180)
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.blue, 
                        size: 40,
                      )
                    ),
                  ),
                ],
              ),
            ],
          ),

          // --- UI Overlays ---

          // Top Banner (Mock Navigation Info)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF292929),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                   BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.turn_right, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text("Follow the route", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                        Text(
                            "${_remainingDistance.toStringAsFixed(1)} km remaining",
                            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)
                        ),
                        ],
                    ),
                  )
                ],
              ),
            ),
          ),
          
          // Compass Button (Top Right)
          // Show compass if map is rotated (not North-up)
          if (_mapReady && _mapController.camera.rotation != 0)
          Positioned(
              top: 180, // Moved down to avoid collision
              right: 20,
              child: FloatingActionButton(
                heroTag: 'compass_btn',
                mini: true,
                backgroundColor: Colors.white,
                onPressed: () {
                    // Reset to North Up
                    if (_mapReady) _mapController.rotate(0);
                },
                child: Transform.rotate(
                    angle: _mapReady ? (_mapController.camera.rotation * (3.14159 / 180)) : 0,
                    child: const Icon(Icons.explore, color: Colors.redAccent),
                ),
              ),
          ),

          // Controls (Bottom Right)
          Positioned(
            bottom: 40,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                
                // Dev Simulation Button (Debug Only)
                if (kDebugMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FloatingActionButton(
                      heroTag: 'simulate_btn',
                      backgroundColor: _isSimulating ? Colors.green : Colors.orange,
                      onPressed: _toggleSimulation,
                      child: Icon(_isSimulating ? Icons.pause : Icons.play_arrow),
                    ),
                  ),
                  
                // Re-center / Driver View Toggle
                FloatingActionButton(
                  heroTag: 'recenter_btn',
                  backgroundColor: _isNavigationActive ? Colors.blue : Colors.white,
                  onPressed: () {
                    setState(() {
                      _isNavigationActive = true;
                      _isDriverView = true; // Snap back to driver view usually
                    });
                    _updateCamera();
                  },
                  child: Icon(
                    Icons.gps_fixed,
                    color: _isNavigationActive ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // End Navigation
                FloatingActionButton(
                  heroTag: 'close_nav',
                  backgroundColor: Colors.redAccent,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // Recalculating Overlay
          if (_isRecalculating)
             Container(
                 color: Colors.black.withOpacity(0.5),
                 child: const Center(
                     child: CircularProgressIndicator(color: Colors.white),
                 ),
             ),
        ],
      ),
    );
  }
}
