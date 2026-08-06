import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({
    super.key,
    required this.sessionFile,
    required this.sessionName,
  });

  final File sessionFile;
  final String sessionName;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  final MapController _mapController = MapController();
  late Future<List<_LoggedPosition>> _positionsFuture;

  @override
  void initState() {
    super.initState();
    _positionsFuture = _loadPositions();
  }

  Future<List<_LoggedPosition>> _loadPositions() async {
    final lines = await widget.sessionFile.readAsLines();
    final positions = <_LoggedPosition>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 3) continue;
      try {
        final timestamp = DateTime.parse(parts[0]);
        final latitude = double.parse(parts[1]);
        final longitude = double.parse(parts[2]);
        positions.add(_LoggedPosition(
          timestamp: timestamp,
          location: LatLng(latitude, longitude),
        ));
      } catch (_) {
        continue;
      }
    }
    return positions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionName),
      ),
      body: FutureBuilder<List<_LoggedPosition>>(
        future: _positionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final positions = snapshot.data ?? [];
          if (positions.isEmpty) {
            return const Center(child: Text('No GPS points available.'));
          }

          final polylinePoints = positions.map((p) => p.location).toList();
          final center = polylinePoints.first;

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cambion.longboard_app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    color: Colors.blueAccent,
                    strokeWidth: 4.0,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: polylinePoints.first,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.green,
                      size: 32,
                    ),
                  ),
                  Marker(
                    point: polylinePoints.last,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.stop,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoggedPosition {
  _LoggedPosition({required this.timestamp, required this.location});

  final DateTime timestamp;
  final LatLng location;
}
