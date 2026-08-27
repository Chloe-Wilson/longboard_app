import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../session/helpers/session_helpers.dart' as session_helpers;
import '../../session/models/logged_positions.dart';
import '../../home/helpers/color_scheme.dart';
import '../../home/widgets/settings_provider.dart';
import '../widgets/vertical_range_slider.dart';

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

  // Option 2: Isolated slider state using ValueNotifier
  final ValueNotifier<RangeValues> _rangeNotifier = ValueNotifier(const RangeValues(0.0, 1.0));

  // Cached positions stored at the State level, NOT inside the build method
  List<LoggedPosition>? _cachedSmoothedPositions;

  @override
  void initState() {
    super.initState();
    _positionsFuture = _loadPositions();
  }

  @override
  void dispose() {
    _rangeNotifier.dispose();
    super.dispose();
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
    // Extract settings ONCE at the top level
    final settings = context.watch<SettingsNotifier>().settings;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionName),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export Session',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final exportedFile = await session_helpers.exportSession(widget.sessionFile);
              
              if (exportedFile != null) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Session exported to ${exportedFile.path}'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        ],
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

          if (_cachedSmoothedPositions == null) {
            final rawSmoothed = session_helpers.smoothPositions(positions, segments: 2);
            _cachedSmoothedPositions = [];
            for (var i = 0; i < rawSmoothed.length; ) {
              final j = i;
              i++;
              double maxSpeed = rawSmoothed[j].speed;
              for ( ; i < rawSmoothed.length; i++) {
                final dist = Geolocator.distanceBetween(
                  rawSmoothed[j].location.latitude, 
                  rawSmoothed[j].location.longitude, 
                  rawSmoothed[i].location.latitude, 
                  rawSmoothed[i].location.longitude
                  );
                if (dist > 5) break;
                maxSpeed = max(maxSpeed, rawSmoothed[i].speed);
              }
              _cachedSmoothedPositions!.add(LoggedPosition(
                timestamp: rawSmoothed[j].timestamp, 
                location: rawSmoothed[j].location, 
                accuracy: rawSmoothed[j].accuracy, 
                speed: maxSpeed)
                );
            }
            if (rawSmoothed.isNotEmpty && _cachedSmoothedPositions!.last != rawSmoothed.last) {
              _cachedSmoothedPositions!.add(rawSmoothed.last);
            }
          }

          final smoothedPositions = _cachedSmoothedPositions!;
          final totalCount = smoothedPositions.length;

          return Stack(
            children: [
              // RepaintBoundary prevents map canvas repaints during non-map gestures
              RepaintBoundary(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    backgroundColor: myColorScheme.surface,
                    initialCameraFit: CameraFit.coordinates(
                      coordinates: smoothedPositions.map((p) => p.location).toList(),
                      padding: const EdgeInsets.only(left: 40, top: 40, right: 40, bottom: 80),
                    ),
                    interactionOptions: const InteractionOptions(
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
                      userAgentPackageName: 'com.CambionStudios.carve',
                    ),
                    
                    // ValueListenableBuilder targets ONLY the polyline updates
                    ValueListenableBuilder<RangeValues>(
                      valueListenable: _rangeNotifier,
                      builder: (context, currentRange, _) {
                        final startIdx = (totalCount * currentRange.start).toInt().clamp(0, totalCount);
                        final endIdx = (totalCount * currentRange.end).toInt().clamp(0, totalCount);

                        final activePositions = (endIdx > startIdx)
                            ? smoothedPositions.sublist(startIdx, endIdx)
                            : <LoggedPosition>[];

                        final batchedColoredSegments = session_helpers.batchPositionsByColor(activePositions, settings);
                        final activeLocations = activePositions.map((p) => p.location).toList();

                        return Stack(
                          children: [
                            PolylineLayer(
                              polylines: [
                                if (activeLocations.length > 1)
                                  Polyline(
                                    points: activeLocations,
                                    color: myColorScheme.primary,
                                    strokeWidth: 6.0,
                                    strokeCap: StrokeCap.round,
                                    strokeJoin: StrokeJoin.round,
                                  ),
                              ],
                            ),
                            PolylineLayer(
                              polylines: batchedColoredSegments,
                            ),
                          ],
                        );
                      },
                    ),

                    MarkerLayer(
                      markers: [
                        Marker(
                          point: positions.first.location,
                          width: 30,
                          height: 30,
                          child: const Icon(Icons.play_arrow, color: Colors.green, size: 20),
                        ),
                        Marker(
                          point: positions.last.location,
                          width: 30,
                          height: 30,
                          child: const Icon(Icons.stop, color: Colors.red, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Slider listens directly to ValueNotifier without triggering setState
              Positioned(
                bottom: 10,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: ValueListenableBuilder<RangeValues>(
                    valueListenable: _rangeNotifier,
                    builder: (context, currentRange, _) {
                      return VerticalScrubRangeSlider(
                        totalPoints: totalCount,
                        currentRange: currentRange,
                        onChanged: (newRange) {
                          _rangeNotifier.value = newRange;
                        },
                      );
                    },
                  ),
                ),
              ),

              Positioned(
                top: 10,
                right: 16,
                child: FloatingActionButton(
                  heroTag: 'info',
                  onPressed: smoothedPositions.isEmpty
                      ? null
                      : () async {
                          final startIdx = (totalCount * _rangeNotifier.value.start).toInt().clamp(0, totalCount);
                          final endIdx = (totalCount * _rangeNotifier.value.end).toInt().clamp(0, totalCount);

                          final activePositions = (endIdx > startIdx)
                              ? smoothedPositions.sublist(startIdx, endIdx)
                              : <LoggedPosition>[];
                          await session_helpers.showSelectionStatsDialog(
                            context: context,
                            smoothedPositions: activePositions,
                          );
                        },
                  backgroundColor: myColorScheme.primary,
                  foregroundColor: myColorScheme.onPrimary,
                  tooltip: 'info',
                  shape: const CircleBorder(),
                  child: const Icon(Icons.info),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
