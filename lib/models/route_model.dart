class RouteModel {
  final List<List<double>> orderedCoordinates;
  final List<List<double>> path;
  final double distance; // in meters

  RouteModel({
    required this.orderedCoordinates,
    required this.path,
    required this.distance,
  });

  // Convert distance from meters to kilometers
  double get distanceInKm => distance / 1000;

  /// Estimated travel time in minutes (assuming ~30 km/h average city driving)
  double get estimatedMinutes => (distanceInKm / 30.0) * 60.0;

  /// Human-readable ETA string (e.g. "12 min", "1 hr 5 min")
  String get etaLabel {
    final mins = estimatedMinutes.round();
    if (mins < 1) return '< 1 min';
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return rem == 0 ? '$hrs hr' : '$hrs hr $rem min';
  }

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    // Parse [[lat, lng], [lat, lng], ...] format
    List<List<double>> parseCoordArray(dynamic coords) {
      if (coords == null || coords is! List) return [];
      return coords.map<List<double>>((coord) {
        if (coord is List && coord.length >= 2) {
          return [
            (coord[0] as num).toDouble(),
            (coord[1] as num).toDouble(),
          ];
        }
        return [0.0, 0.0];
      }).toList();
    }

    return RouteModel(
      orderedCoordinates: parseCoordArray(json['ordered_coordinates']),
      path: parseCoordArray(json['path']),
      distance: (json['distance'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ordered_coordinates': orderedCoordinates,
      'path': path,
      'distance': distance,
    };
  }
}
