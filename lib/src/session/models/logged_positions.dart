import 'package:latlong2/latlong.dart';

class LoggedPosition {
  LoggedPosition({required this.timestamp, required this.location, required this.accuracy, required this.speed});

  final Duration timestamp;
  final LatLng location;
  final double accuracy;
  final double speed;
}