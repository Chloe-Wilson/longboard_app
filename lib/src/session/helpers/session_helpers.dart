import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:longboard_app/src/home/helpers/color_scheme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_map/flutter_map.dart';

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
  final logLine = '$sessionDuration,${position.latitude},${position.longitude},${position.accuracy},${position.speed},${position.speedAccuracy},${position.altitude},${position.altitudeAccuracy}\n';

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
  List<Duration> stopTime = [];
  int stopped = 0;
  LoggedPosition stoppedSpot = original.first;
  filteredPositions.add(original.first);
  for (int i = 1; i < original.length - 1; i++) {
    if (original[i].accuracy >= 15) continue;
    if (filteredPositions.isNotEmpty) {
      final dist = Geolocator.distanceBetween(
        original[i].location.latitude,
        original[i].location.longitude,
        stoppedSpot.location.latitude,
        stoppedSpot.location.longitude,
      );
      if (dist < 5) {
        stopped += 1;
      } else {
        if (stopped >= 10) {
          while (filteredPositions.last.location != stoppedSpot.location) {
            stopTime.add(filteredPositions.last.timestamp);
            filteredPositions.removeLast();
          }
          stopTime.sort();
        }
        stopped = 0;
        stoppedSpot = original[i];
      }
    }

    if (stopTime.isEmpty) {
      filteredPositions.add(LoggedPosition(
          timestamp: original[i].timestamp,
          location: original[i].location,
          accuracy: original[i].accuracy,
          speed: original[i].speed,
          speedAccuracy: original[i].speedAccuracy,
          altitude: original[i].altitude,
          altitudeAccuracy: original[i].altitudeAccuracy
        )
      );
    } else {
      stopTime.add(original[i].timestamp);
      filteredPositions.add(LoggedPosition(
          timestamp: stopTime.first,
          location: original[i].location,
          accuracy: original[i].accuracy,
          speed: original[i].speed,
          speedAccuracy: original[i].speedAccuracy,
          altitude: original[i].altitude,
          altitudeAccuracy: original[i].altitudeAccuracy
        )
      );
      stopTime.removeAt(0);
    }
  }
  if (stopped >= 10) {
    while (filteredPositions.last.location != stoppedSpot.location) {
      stopTime.add(filteredPositions.last.timestamp);
      filteredPositions.removeLast();
    }
    stopTime.sort();
  }
  if (stopTime.isEmpty) {
    filteredPositions.add(original.last);
    }
  else {
    filteredPositions.add(LoggedPosition(
          timestamp: stopTime.first,
          location: original.last.location,
          accuracy: original.last.accuracy,
          speed: original.last.speed,
          speedAccuracy: original.last.speedAccuracy,
          altitude: original.last.altitude,
          altitudeAccuracy: original.last.altitudeAccuracy
        )
      );
  }

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
    final speed = curr.speedAccuracy > 2 ? weightedPoints.last.speed : curr.speed;

    weightedPoints.add(LoggedPosition(
      timestamp: curr.timestamp,
      location: LatLng(latitude, longitude),
      accuracy: curr.accuracy,
      speed: speed,
      speedAccuracy: curr.speedAccuracy,
      altitude: curr.altitude,
      altitudeAccuracy: curr.altitudeAccuracy
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

Future<File?> uploadSession() async {
  try {
    // Call FilePicker directly (no .platform instance required)
    PlatformFile? pickedFile = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (pickedFile == null || pickedFile.path == null) {
      // User canceled the picker
      return null;
    }

    // Read the source file chosen by the user
    File sourceFile = File(pickedFile.path!);
    String content = await sourceFile.readAsString();

    // Get the app's internal documents directory
    Directory appDocDir = await getApplicationDocumentsDirectory();

    // Save using the original file name
    String newPath = '${appDocDir.path}/${pickedFile.name}';
    File newFile = File(newPath);

    return await newFile.writeAsString(content);
  } catch (e) {
    debugPrint('Error picking or saving file: $e');
    return null;
  }
}

Future<void> showSelectionStatsDialog({
  required BuildContext context,
  required List<LoggedPosition> smoothedPositions,
}) async {
  if (smoothedPositions.isEmpty) return;

  double distance = 0;
  double topSpeed = 0;
  final duration = smoothedPositions.last.timestamp - smoothedPositions.first.timestamp;

  for (var i = 1; i < smoothedPositions.length; i++) {
    topSpeed = topSpeed > smoothedPositions[i].speed ? topSpeed : smoothedPositions[i].speed;
    distance += Geolocator.distanceBetween(
      smoothedPositions[i - 1].location.latitude,
      smoothedPositions[i - 1].location.longitude,
      smoothedPositions[i].location.latitude,
      smoothedPositions[i].location.longitude,
    );
  }

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final hoursPart = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
  final minutesPart = '${minutes.toString().padLeft(2, '0')}:';
  final secondsPart = seconds.toString().padLeft(2, '0');
  final durationText = '$hoursPart$minutesPart$secondsPart';

  final distanceText = '${(distance / 1000).toStringAsFixed(2)} km';
  final topSpeedText = '${(topSpeed * 3.6).toStringAsFixed(2)} km/h';

  final averageSpeedText = duration.inSeconds > 0
      ? '${(distance / duration.inSeconds * 3.6).toStringAsFixed(2)} km/h'
      : '0.00 km/h';

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Selection Info'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: myColorScheme.primary,
            width: 4.0,
          ),
        ),
        content: Text(
          '$durationText\n$distanceText\nAvg $averageSpeedText\nMax $topSpeedText',
          textAlign: TextAlign.center,
          maxLines: 4,
        ),
      );
    },
  );
}

List<Polyline> batchPositionsByColor(
  List<LoggedPosition> positions, 
   Map<String, dynamic> settings,
) {
  if (positions.length < 2) return [];

  final List<Polyline> polylines = [];
  List<LatLng> currentBatch = [positions.first.location];
  Color currentColor = getSpeedColor(positions.first.speed, settings);

  for (var i = 1; i < positions.length; i++) {
    final pointColor = getSpeedColor(positions[i].speed, settings);

    if (pointColor == currentColor) {
      currentBatch.add(positions[i].location);
    } else {
      currentBatch.add(positions[i].location); // Include transition point to connect lines seamlessly
      polylines.add(
        Polyline(
          points: currentBatch,
          color: currentColor,
          strokeWidth: 4.0,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
      
      // Start new batch
      currentBatch = [positions[i].location];
      currentColor = pointColor;
    }
  }

  if (currentBatch.length > 1) {
    polylines.add(
      Polyline(
        points: currentBatch,
        color: currentColor,
        strokeWidth: 4.0,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ),
    );
  }

  return polylines;
}