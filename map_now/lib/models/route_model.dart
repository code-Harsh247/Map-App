class RouteModel {
  final List<Map<String, double>> orderedCoordinates;
  final List<Map<String, double>> path;
  final double distance; // in meters

  RouteModel({
    required this.orderedCoordinates,
    required this.path,
    required this.distance,
  });

  // Convert distance from meters to kilometers
  double get distanceInKm => distance / 1000;

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, double>> parseCoordinates(List<dynamic>? coords) {
      if (coords == null) return [];
      return coords.map((coord) {
        return <String, double>{
          'latitude': (coord['latitude'] ?? 0.0).toDouble(),
          'longitude': (coord['longitude'] ?? 0.0).toDouble(),
        };
      }).toList();
    }

    return RouteModel(
      orderedCoordinates: parseCoordinates(json['ordered_coordinates']),
      path: parseCoordinates(json['path']),
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
