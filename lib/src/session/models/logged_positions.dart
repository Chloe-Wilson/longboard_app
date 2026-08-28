import 'package:latlong2/latlong.dart';

class LoggedPosition {
  LoggedPosition({
    required this.timestamp, 
    required this.location, 
    required this.accuracy, 
    required this.speed, 
    required this.speedAccuracy, 
    required this.altitude, 
    required this.altitudeAccuracy
  });

  final Duration timestamp;
  final LatLng location;
  final double accuracy;
  final double speed;
  final double speedAccuracy;
  final double altitude;
  final double altitudeAccuracy;
}