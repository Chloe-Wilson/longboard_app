import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
// import 'package:bezier/bezier.dart';
// import 'package:vector_math/vector_math_64.dart' as vector;

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
  for (int i = 0; i < original.length; i++) {
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
    final timeDeltaSeconds = i > 0 ? original[i].timestamp.inSeconds - original[i - 1].timestamp.inSeconds : 0;
    final speed = original[i].speed > 1 ? original[i].speed : (filteredPositions.isNotEmpty ? Geolocator.distanceBetween(
      filteredPositions[filteredPositions.length - 1].location.latitude,
      filteredPositions[filteredPositions.length - 1].location.longitude,
      original[i].location.latitude,
      original[i].location.longitude,
    ) / timeDeltaSeconds : 0.0);
    filteredPositions.add(LoggedPosition(
        timestamp: original[i].timestamp,
        location: original[i].location,
        accuracy: original[i].accuracy,
        speed: 1 > original[i].speed ? speed : original[i].speed,
      )
    );
  }
  
  List<LoggedPosition> smoothed = [];

  const double alpha = 0.5;

  for (int i = 0; i < filteredPositions.length - 1; i++) {
    var p0 = i == 0 ? filteredPositions[i] : filteredPositions[i - 1];
    var p1 = filteredPositions[i];
    var p2 = filteredPositions[i + 1];
    var p3 = (i + 2 < filteredPositions.length) ? filteredPositions[i + 2] : p2;

    double d01 = Geolocator.distanceBetween(p0.location.latitude, p0.location.longitude, p1.location.latitude, p1.location.longitude);
    double d12 = Geolocator.distanceBetween(p1.location.latitude, p1.location.longitude, p2.location.latitude, p2.location.longitude);
    double d23 = Geolocator.distanceBetween(p2.location.latitude, p2.location.longitude, p3.location.latitude, p3.location.longitude);

    double t0 = 0.0;
    double t1 = t0 + (d01 > 0 ? math.pow(d01, alpha) : 1.0);
    double t2 = t1 + (d12 > 0 ? math.pow(d12, alpha) : 1.0);
    double t3 = t2 + (d23 > 0 ? math.pow(d23, alpha) : 1.0);

    for (int j = 0; j < segments; j++) {
      double weight = j / segments;

      double t = t1 + weight * (t2 - t1);

      double a1Lat = (t1 - t) / (t1 - t0) * p0.location.latitude + (t - t0) / (t1 - t0) * p1.location.latitude;
      double a1Lng = (t1 - t) / (t1 - t0) * p0.location.longitude + (t - t0) / (t1 - t0) * p1.location.longitude;
      
      double a2Lat = (t2 - t) / (t2 - t1) * p1.location.latitude + (t - t1) / (t2 - t1) * p2.location.latitude;
      double a2Lng = (t2 - t) / (t2 - t1) * p1.location.longitude + (t - t1) / (t2 - t1) * p2.location.longitude;
      
      double a3Lat = (t3 - t) / (t3 - t2) * p2.location.latitude + (t - t2) / (t3 - t2) * p3.location.latitude;
      double a3Lng = (t3 - t) / (t3 - t2) * p2.location.longitude + (t - t2) / (t3 - t2) * p3.location.longitude;

      double b1Lat = (t2 - t) / (t2 - t0) * a1Lat + (t - t0) / (t2 - t0) * a2Lat;
      double b1Lng = (t2 - t) / (t2 - t0) * a1Lng + (t - t0) / (t2 - t0) * a2Lng;
      
      double b2Lat = (t3 - t) / (t3 - t1) * a2Lat + (t - t1) / (t3 - t1) * a3Lat;
      double b2Lng = (t3 - t) / (t3 - t1) * a2Lng + (t - t1) / (t3 - t1) * a3Lng;

      double lat = (t2 - t) / (t2 - t1) * b1Lat + (t - t1) / (t2 - t1) * b2Lat;
      double lng = (t2 - t) / (t2 - t1) * b1Lng + (t - t1) / (t2 - t1) * b2Lng;

      double mixedSpeed = p1.speed + (p2.speed - p1.speed) * weight;
      // double mixedSpeed = Geolocator.distanceBetween(p1.location.latitude, p1.location.longitude, p2.location.latitude, p2.location.longitude) / (p2.timestamp.inSeconds - p1.timestamp.inSeconds);

      int p1Ms = p1.timestamp.inMilliseconds;
      int p2Ms = p2.timestamp.inMilliseconds;
      int mixedMs = p1Ms + ((p2Ms - p1Ms) * weight).round();

      smoothed.add(LoggedPosition(
        timestamp: Duration(milliseconds: mixedMs),
        location: LatLng(lat, lng),
        accuracy: 0,
        speed: mixedSpeed,
      ));
    }
  }
  
  smoothed.add(original.last);
  return smoothed;
}
