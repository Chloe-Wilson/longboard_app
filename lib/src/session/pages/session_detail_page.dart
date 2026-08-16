import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../session/helpers/session_helpers.dart' as session_helpers;
import '../../session/models/logged_positions.dart';
import '../../home/helpers/color_scheme.dart';

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
  late Future<List<LoggedPosition>> _positionsFuture;

  @override
  void initState() {
    super.initState();
    _positionsFuture = _loadPositions();
  }

  Future<List<LoggedPosition>> _loadPositions() async {
    final lines = await widget.sessionFile.readAsLines();
    final positions = <LoggedPosition>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) continue;
      final parts = line.split(',');
      if (parts.length < 3) continue;
      try {
        final timestamp = session_helpers.parseLogDuration(parts[0]);
        final latitude = double.parse(parts[1]);
        final longitude = double.parse(parts[2]);
        final accuracy = double.parse(parts[3]);
        final speed = double.parse(parts[4]);
        positions.add(LoggedPosition(
          timestamp: timestamp,
          location: LatLng(latitude, longitude),
          accuracy: accuracy,
          speed: speed,
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
      body: FutureBuilder<List<LoggedPosition>>(
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

          final center = positions.first.location;
          final smoothedPositions = session_helpers.smoothPositions(positions, segments: 2);

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              backgroundColor: myColorScheme.surface,
              initialCenter: center,
              initialZoom: 15.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileBuilder: (context, tileWidget, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      0,       0,       0,       1, 0,
                    ]),
                    child: tileWidget,
                  );
                },
                userAgentPackageName: 'com.cambion.longboard_app',
              ),
              PolylineLayer(
                polylines: [
                  for (var i = 1; i < smoothedPositions.length; i++)
                    Polyline(
                      points: [smoothedPositions[i - 1].location, smoothedPositions[i].location],
                      color: myColorScheme.primary,
                      strokeWidth: 6.0,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                ],
              ),
              PolylineLayer(
                polylines: [
                  for (var i = 1; i < smoothedPositions.length; i++)
                    Polyline(
                      points: [smoothedPositions[i - 1].location, smoothedPositions[i].location],
                      gradientColors: [
                        session_helpers.getSpeedColor(smoothedPositions[i - 1].speed),
                        session_helpers.getSpeedColor(smoothedPositions[i].speed),
                      ],
                      strokeWidth: 4.0,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: positions.first.location,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  Marker(
                    point: positions.last.location,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.stop,
                      color: Colors.red,
                      size: 20,
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
