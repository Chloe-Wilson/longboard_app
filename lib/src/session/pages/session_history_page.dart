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
        hasSummary = true;
        break;
      }
      final parts = line.split(',');
      if (parts.length < 3) continue;
      try {
        final timestamp = session_helpers.parseLogDuration(parts[0]);
        final latitude = double.parse(parts[1]);
        final longitude = double.parse(parts[2]);
        final accuracy = double.parse(parts[3]);
        final speed = double.parse(parts[4]);
        if (accuracy >= 15) continue;
        if (positions.isNotEmpty) {
          if (Geolocator.distanceBetween(
                latitude,
                longitude,
                positions.last.location.latitude,
                positions.last.location.longitude,
              ) < 5) {
            continue;
          }
        }
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
        distanceMeters: double.parse(summary[1]),
        averageSpeedKmh: double.parse(summary[2]),
        maxSpeedKmh: double.parse(summary[3]),
      );
    } else {
      final duration = positions.length >= 2
        ? positions.last.timestamp
        : Duration.zero;

      double totalDistance = 0.0;
      double maxSpeedMps = 0.0;

      for (var i = 1; i < positions.length; i++) {
        final timeDeltaSeconds = positions[i].timestamp.inSeconds - positions[i - 1].timestamp.inSeconds;
        if (timeDeltaSeconds <= 0) continue;
        
        final distance = Geolocator.distanceBetween(
          positions[i - 1].location.latitude,
          positions[i - 1].location.longitude,
          positions[i].location.latitude,
          positions[i].location.longitude,
        );
        distance > 0 ? totalDistance += distance : null;
        maxSpeedMps = positions[i].speed > maxSpeedMps ? positions[i].speed : maxSpeedMps;
      }

      final averageSpeedKmh = duration.inSeconds > 0
          ? (totalDistance / duration.inSeconds) * 3.6
          : 0.0;
      final maxSpeedKmh = maxSpeedMps * 3.6;

      session_helpers.writeSessionHeader(file, sessionName, '$duration,$totalDistance,$averageSpeedKmh,$maxSpeedKmh');

      return _SessionSummary(
        file: file,
        sessionName: sessionName,
        totalDuration: duration,
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
      appBar: AppBar(title: const Text('Past Sessions')),
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
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12.0),
            itemBuilder: (context, index) {
              final summary = sessions[index];
              final details =
                  '${_formatDuration(summary.totalDuration)} • ${_formatDistance(summary.distanceMeters)}';
              final stats =
                  'Avg ${_formatSpeed(summary.averageSpeedKmh)}, max ${_formatSpeed(summary.maxSpeedKmh)}';
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
    required this.distanceMeters,
    required this.averageSpeedKmh,
    required this.maxSpeedKmh,
  });

  final File file;
  final String sessionName;
  final Duration totalDuration;
  final double distanceMeters;
  final double averageSpeedKmh;
  final double maxSpeedKmh;
}
