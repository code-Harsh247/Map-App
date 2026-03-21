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
