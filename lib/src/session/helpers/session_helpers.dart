import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import 'package:longboard_app/src/session/models/logged_positions.dart';

Future<void> writeSessionHeader(File file, String sessionName, [String summary = '']) async {
  final header = '# SessionName: $sessionName';
  
  final formattedSummary = summary.isNotEmpty ? '\n# Summary: $summary' : '';
  final newHeaderBlock = '$header$formattedSummary\n';

  final contents = await file.readAsString();

  if (contents.startsWith('# SessionName:')) {
    final firstNewlineIndex = contents.indexOf('\n');
    final remaining = firstNewlineIndex != -1 
        ? contents.substring(firstNewlineIndex + 1) 
        : '';
    await file.writeAsString('$newHeaderBlock$remaining');
  } else {
    await file.writeAsString('$newHeaderBlock$contents');
  }
}

Future<void> appendLocationToLog(File sessionFile, Position position, Duration sessionDuration, [bool last = false]) async {
  final logLine = '$sessionDuration,${position.latitude},${position.longitude},${position.accuracy},${position.speed}\n';

  try {
    if (await sessionFile.exists()) {
      final lines = await sessionFile.readAsLines();
      if (last && lines.length < 3) {
        debugPrint('Not enough lines to remove the last one. Lines count: ${lines.length}');
        await sessionFile.writeAsString(logLine, mode: FileMode.append, flush: true);
        return;
      }

      if (lines.isNotEmpty) {
        final segments = lines.last.split(',');

        if (segments.length >= 3) {
          final lastLatitude = segments[1];
          final lastLongitude = segments[2];

          if (lastLatitude == position.latitude.toString() && 
              lastLongitude == position.longitude.toString()) {
            
            lines.removeLast();
            
            final updatedContent = lines.isEmpty 
                ? logLine 
                : '${lines.join('\n')}\n$logLine';
                
            await sessionFile.writeAsString(updatedContent, mode: FileMode.write, flush: true);
            return;
          }
        }
      }
    }

    await sessionFile.writeAsString(logLine, mode: FileMode.append, flush: true);
  } catch (e) {
    debugPrint('Error writing to session log: $e');
  }
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  final hoursPart = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
  final minutesPart = '${minutes.toString().padLeft(2, '0')}:';
  final secondsPart = seconds.toString().padLeft(2, '0');

  return '$hoursPart$minutesPart$secondsPart';
}

Duration parseLogDuration(String input) {
  final regExp = RegExp(r'^(\d+):(\d+):(\d+)\.(\d+)$');
  final match = regExp.firstMatch(input.trim());
  
  if (match == null) throw FormatException('Invalid duration format');

  return Duration(
    hours: int.parse(match[1]!),
    minutes: int.parse(match[2]!),
    seconds: int.parse(match[3]!),
    microseconds: int.parse(match[4]!.padRight(6, '0').substring(0, 6)),
  );
}

Color getSpeedColor(double speed, Map<String, dynamic> settings) {
  final green = (settings['Green'] ?? 10).toDouble()/3.6;
  final yellow = (settings['Yellow'] ?? 15).toDouble()/3.6;
  final orange = (settings['Orange'] ?? 20).toDouble()/3.6;
  final red = (settings['Red'] ?? 25).toDouble()/3.6;
  final blue = (settings['Blue'] ?? 30).toDouble()/3.6;
  final purple = (settings['Purple'] ?? 35).toDouble()/3.6;

  if (speed < green) {
    return Color.fromRGBO(0, 255, 0, 1.0);
  } else if (speed < yellow) {
    return Color.fromRGBO((255*(speed-green)/(yellow-green)).toInt().clamp(0, 255), 255, 0, 1.0);
  } else if (speed < orange) {
    return Color.fromRGBO(255, (255-90*(speed-yellow)/(orange-yellow)).toInt().clamp(165, 255), 0, 1.0);
  } else if (speed < red) {
    return Color.fromRGBO(255, (165-165*(speed-orange)/(red-orange)).toInt().clamp(0, 165), 0, 1.0);
  } else if (speed < blue) {
    return Color.fromRGBO((255-255*(speed-red)/(blue-red)).toInt().clamp(0, 255), 0, (255*(speed-red)/(blue-red)).toInt().clamp(0, 255), 1.0);
  } else {
    return Color.fromRGBO((153*(speed-blue)/(purple-blue)).toInt().clamp(0, 153), (51*(speed-blue)/(purple-blue)).toInt().clamp(0, 51), 255, 1.0);
  }
}

List<LoggedPosition> smoothPositions(List<LoggedPosition> original, {int segments = 8}) {
  if (original.length < 4) return original;

  List<LoggedPosition> filteredPositions = [];
  filteredPositions.add(original.first);
  for (int i = 1; i < original.length - 1; i++) {
    if (original[i].accuracy >= 15) continue;
    if (filteredPositions.isNotEmpty) {
      final dist = Geolocator.distanceBetween(
        original[i].location.latitude,
        original[i].location.longitude,
        filteredPositions[filteredPositions.length - 1].location.latitude,
        filteredPositions[filteredPositions.length - 1].location.longitude,
      );
      if (dist < 5) continue;
    }

    filteredPositions.add(LoggedPosition(
        timestamp: original[i].timestamp,
        location: original[i].location,
        accuracy: original[i].accuracy,
        speed: original[i].speed,
      )
    );
  }
  filteredPositions.add(original.last);

  List<LoggedPosition> weightedPoints = [];
  weightedPoints.add(filteredPositions.first);
  for (int i = 3; i < filteredPositions.length - 3; i++) {
    final prev3 = filteredPositions[i - 3];
    final prev2 = filteredPositions[i - 2];
    final prev = filteredPositions[i - 1];
    final curr = filteredPositions[i];
    final next = filteredPositions[i + 1];
    final next2 = filteredPositions[i + 2];
    final next3 = filteredPositions[i + 3];
    final prev3Weight = (15 - prev3.accuracy) / (105 - prev3.accuracy + prev2.accuracy + prev.accuracy + curr.accuracy + next.accuracy + next2.accuracy + next3.accuracy);
    final prev2Weight = (15 - prev2.accuracy) / (105 - prev3.accuracy + prev2.accuracy + prev.accuracy + curr.accuracy + next.accuracy + next2.accuracy + next3.accuracy);
    final prevWeight = (15 - prev.accuracy) / (105 - prev3.accuracy + prev2.accuracy + prev.accuracy + curr.accuracy + next.accuracy + next2.accuracy + next3.accuracy);
    final currWeight = (15 - curr.accuracy) / (105 - prev3.accuracy + prev2.accuracy + prev.accuracy + curr.accuracy + next.accuracy + next2.accuracy + next3.accuracy);
    final nextWeight = (15 - next.accuracy) / (105 - prev3.accuracy + prev2.accuracy + prev.accuracy + curr.accuracy + next.accuracy + next2.accuracy + next3.accuracy);
    final next2Weight = (15 - next2.accuracy) / (105 - prev3.accuracy + prev2.accuracy + prev.accuracy + curr.accuracy + next.accuracy + next2.accuracy + next3.accuracy);
    final next3Weight = (15 - next3.accuracy) / (105 - prev3.accuracy + prev2.accuracy + prev.accuracy + curr.accuracy + next.accuracy + next2.accuracy + next3.accuracy);
    final totalWeight = prev3Weight + prev2Weight + prevWeight + currWeight + nextWeight + next2Weight + next3Weight;
    final longitude = ((prev3.location.longitude * prev3Weight) + (prev2.location.longitude * prev2Weight) + (prev.location.longitude * prevWeight) + (curr.location.longitude * currWeight) + (next.location.longitude * nextWeight) + (next2.location.longitude * next2Weight) + (next3.location.longitude * next3Weight)) / totalWeight;
    final latitude = ((prev3.location.latitude * prev3Weight) + (prev2.location.latitude * prev2Weight) + (prev.location.latitude * prevWeight) + (curr.location.latitude * currWeight) + (next.location.latitude * nextWeight) + (next2.location.latitude * next2Weight) + (next3.location.latitude * next3Weight)) / totalWeight;
    

    weightedPoints.add(LoggedPosition(
      timestamp: curr.timestamp,
      location: LatLng(latitude, longitude),
      accuracy: curr.accuracy,
      speed: curr.speed,
    ));
  }
  weightedPoints.add(filteredPositions.last);
  return weightedPoints;
}

double calculateDistanceFromLastPoint(File sessionFile, Position position) {
  try {
    if (!sessionFile.existsSync()) return 0.0;

    final lines = sessionFile.readAsLinesSync();
    if (lines.isEmpty) return 0.0;

    final lastLine = lines.last;
    if (lastLine.startsWith("#")) return 0.0;
    final segments = lastLine.split(',');

    if (segments.length < 3) return 0.0;

    final accuracy = double.tryParse(segments[3]);
    if (accuracy! >= 15) return 0.0;

    final lastLatitude = double.tryParse(segments[1]);
    final lastLongitude = double.tryParse(segments[2]);

    if (lastLatitude == null || lastLongitude == null) return 0.0;

    final distance = Geolocator.distanceBetween(
      lastLatitude,
      lastLongitude,
      position.latitude,
      position.longitude,
    );

    return distance;
  } catch (e) {
    debugPrint('Error calculating distance from last point: $e');
    return 0.0;
  }
}

Future<XFile?> exportSession(File sessionFile) async {
  final xFile = XFile(sessionFile.path);
  final result = await Share.shareXFiles([xFile], text: 'Exported Session');
  
  if (result.status == ShareResultStatus.success) {
    return xFile;
  }
  return null;
}

