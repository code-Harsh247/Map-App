class PlaceModel {
  final String fullAddress;
  final double latitude;
  final double longitude;
  final String placeId;

  PlaceModel({
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    required this.placeId,
  });

  Map<String, dynamic> toJson() {
    return {
      'fullAddress': fullAddress,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
    };
  }

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      fullAddress: json['fullAddress'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      placeId: json['placeId'] ?? '',
    );
  }

  // Convert to coordinate map
  Map<String, double> toCoordinate() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
