import 'package:latlong2/latlong.dart';

/// Records GPS points during active navigation for later upload.
class RouteRecorderService {
  final List<RecordedPoint> _points = [];
  DateTime? _startTime;
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  List<RecordedPoint> get points => List.unmodifiable(_points);
  DateTime? get startTime => _startTime;

  void start() {
    _points.clear();
    _startTime = DateTime.now();
    _isRecording = true;
  }

  void addPoint(LatLng position, double heading, double speed) {
    if (!_isRecording) return;
    _points.add(RecordedPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      heading: heading,
      speed: speed,
      timestamp: DateTime.now(),
    ));
  }

  void stop() {
    _isRecording = false;
  }

  /// Build the JSON payload for S3 upload.
  Map<String, dynamic> toJson({
    required String userId,
    required Map<String, dynamic> routeInfo,
  }) {
    return {
      'userId': userId,
      'startTime': _startTime?.toUtc().toIso8601String(),
      'endTime': DateTime.now().toUtc().toIso8601String(),
      'pointCount': _points.length,
      'route': routeInfo,
      'track': _points.map((p) => p.toJson()).toList(),
    };
  }

  void reset() {
    _points.clear();
    _startTime = null;
    _isRecording = false;
  }
}

class RecordedPoint {
  final double latitude;
  final double longitude;
  final double heading;
  final double speed;
  final DateTime timestamp;

  const RecordedPoint({
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.speed,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'heading': heading,
        'speed': speed,
        'ts': timestamp.toUtc().toIso8601String(),
      };
}
