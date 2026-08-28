import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

import 'session_detail_page.dart';
import '../../session/helpers/session_helpers.dart' as session_helpers;
import '../../session/models/logged_positions.dart';

class SessionHistoryPage extends StatefulWidget {
  const SessionHistoryPage({super.key});

  @override
  State<SessionHistoryPage> createState() => _SessionHistoryPageState();
}

class _SessionHistoryPageState extends State<SessionHistoryPage> {
  late Future<List<_SessionSummary>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _loadSessionSummaries();
  }

  Future<List<_SessionSummary>> _loadSessionSummaries() async {
    final directory = await getApplicationDocumentsDirectory();
    final entities = await directory.list().toList();
    final sessionFiles = entities
        .whereType<File>()
        .where((file) =>
            file.path.split(Platform.pathSeparator).last.startsWith('longboard_session_'))
        .toList();
    sessionFiles.sort((a, b) => b.path.compareTo(a.path));

    final summaries = <_SessionSummary>[];
    for (final file in sessionFiles) {
      final summary = await _parseSessionFile(file);
      summaries.add(summary);
    }
    return summaries;
  }

  Future<_SessionSummary> _parseSessionFile(File file) async {
    final lines = await file.readAsLines();
    final positions = <LoggedPosition>[];
    final rawLines = lines.where((line) => line.trim().isNotEmpty).toList();
    bool hasSummary = false;
    for (var index = 0; index < rawLines.length; index++) {
      final line = rawLines[index].trim();
      if (index == 0 && line.startsWith('# SessionName:')) {
        continue;
      }
      if (index == 1 && line.startsWith('# Summary:')) {
        if (line.split(',').length == 6) {
          hasSummary = true;
          break;
        }
      }
      if (line.startsWith("#")) continue;
      final parts = line.split(',');
      try {
        final timestamp = session_helpers.parseLogDuration(parts[0]);
        final latitude = double.parse(parts[1]);
        final longitude = double.parse(parts[2]);
        final accuracy = double.parse(parts[3]);
        final speed = double.parse(parts[4]);
        final speedAccuracy = parts.length == 8 ? double.parse(parts[5]) : 0.0;
        final altitude = parts.length == 8 ? double.parse(parts[6]) : 0.0;
        final altitudeAccuracy = parts.length == 8 ? double.parse(parts[7]) : 0.0;

        if (accuracy >= 15) continue;
        positions.add(LoggedPosition(
          timestamp: timestamp,
          location: LatLng(latitude, longitude),
          accuracy: accuracy,
          speed: speed,
          speedAccuracy: speedAccuracy,
          altitude: altitude,
          altitudeAccuracy: altitudeAccuracy
        ));
      } catch (_) {
        continue;
      }
    }

    final smoothed = session_helpers.smoothPositions(positions);

    var sessionName = file.path.split(Platform.pathSeparator).last;
    if (lines.isNotEmpty && lines.first.trim().startsWith('# SessionName:')) {
      final headerName = lines.first.trim().replaceFirst('# SessionName:', '').trim();
      if (headerName.isNotEmpty) {
        sessionName = headerName;
      }
    }

    if (hasSummary) {
      final summary = lines[1].trim().replaceFirst('# Summary:', '').trim().split(',');
      return _SessionSummary(
        file: file,
        sessionName: sessionName,
        totalDuration: session_helpers.parseLogDuration(summary[0]),
        activeDuration: session_helpers.parseLogDuration(summary[1]),
        breakDuration: session_helpers.parseLogDuration(summary[2]),
        distanceMeters: double.parse(summary[3]),
        averageSpeedKmh: double.parse(summary[4]),
        maxSpeedKmh: double.parse(summary[5]),
      );
    } else {
      final totalDuration = positions.length >= 2
        ? positions.last.timestamp
        : Duration.zero;
      final activeDuration = smoothed.length >= 2
        ? smoothed.last.timestamp
        : Duration.zero;
      final breakDuration = totalDuration - activeDuration;
      double totalDistance = 0.0;
      double maxSpeedMps = 0.0;

      for (var i = 1; i < smoothed.length; i++) {
        final timeDeltaSeconds = smoothed[i].timestamp.inSeconds - smoothed[i - 1].timestamp.inSeconds;
        if (timeDeltaSeconds <= 0) continue;
        
        final distance = Geolocator.distanceBetween(
          smoothed[i - 1].location.latitude,
          smoothed[i - 1].location.longitude,
          smoothed[i].location.latitude,
          smoothed[i].location.longitude,
        );
        distance > 0 ? totalDistance += distance : null;
        maxSpeedMps = smoothed[i].speed > maxSpeedMps ? smoothed[i].speed : maxSpeedMps;
      }

      final averageSpeedKmh = activeDuration.inSeconds > 0
          ? (totalDistance / activeDuration.inSeconds) * 3.6
          : 0.0;
      final maxSpeedKmh = maxSpeedMps * 3.6;

      session_helpers.writeSessionHeader(file, sessionName, '$totalDuration,$activeDuration,$breakDuration,$totalDistance,$averageSpeedKmh,$maxSpeedKmh');

      return _SessionSummary(
        file: file,
        sessionName: sessionName,
        totalDuration: totalDuration,
        activeDuration: activeDuration,
        breakDuration: breakDuration,
        distanceMeters: totalDistance,
        averageSpeedKmh: averageSpeedKmh,
        maxSpeedKmh: maxSpeedKmh,
      );
    }
  }

  Future<void> _deleteSession(File file) async {
    await file.delete();
    setState(() {
      _sessionsFuture = _loadSessionSummaries();
    });
  }

  Future<bool> _confirmDelete(BuildContext context, String sessionName) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Session'),
          content: Text('Delete "$sessionName"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  String _formatDistance(double meters) {
    final kilometers = meters / 1000.0;
    return '${kilometers.toStringAsFixed(2)} km';
  }

  String _formatSpeed(double kmh) {
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Sessions'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.upload),
            tooltip: 'Upload Session',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final uploadFile = await session_helpers.uploadSession();
              
              if (uploadFile != null) {
                setState(() {
                  _sessionsFuture = _loadSessionSummaries();
                });
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('${uploadFile.path} uploaded'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<_SessionSummary>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return const Center(child: Text('No past sessions found.'));
          }
          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12.0),
            itemBuilder: (context, index) {
              final summary = sessions[index];
              final details =
                  '${_formatDuration(summary.totalDuration)} • ${_formatDistance(summary.distanceMeters)}';
              final stats =
                  'Active ${_formatDuration(summary.activeDuration)}\nAvg ${_formatSpeed(summary.averageSpeedKmh)}, max ${_formatSpeed(summary.maxSpeedKmh)}';
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                title: Text(summary.sessionName),
                subtitle: Text('$details\n$stats'),
                isThreeLine: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SessionDetailPage(
                        sessionFile: summary.file,
                        sessionName: summary.sessionName,
                      ),
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirmed = await _confirmDelete(context, summary.sessionName);
                    if (confirmed) {
                      await _deleteSession(summary.file);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SessionSummary {
  _SessionSummary({
    required this.file,
    required this.sessionName,
    required this.totalDuration,
    required this.activeDuration,
    required this.breakDuration,
    required this.distanceMeters,
    required this.averageSpeedKmh,
    required this.maxSpeedKmh,
  });

  final File file;
  final String sessionName;
  final Duration totalDuration;
  final Duration activeDuration;
  final Duration breakDuration;
  final double distanceMeters;
  final double averageSpeedKmh;
  final double maxSpeedKmh;
}
