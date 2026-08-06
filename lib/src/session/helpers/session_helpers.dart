import 'dart:io';

import 'package:geolocator/geolocator.dart';

Future<void> writeSessionHeader(File file, String sessionName) async {
  final header = '# SessionName: $sessionName\n';
  final contents = await file.readAsString();
  if (contents.startsWith('# SessionName:')) {
    final remaining = contents.split('\n').skip(1).join('\n');
    await file.writeAsString('$header$remaining');
  } else {
    await file.writeAsString('$header$contents');
  }
}

Future<void> appendLocationToLog(File sessionFile, Position position, Duration sessionDuration) async {
  final logLine = '$sessionDuration,${position.latitude},${position.longitude},${position.accuracy},${position.speed}\n';

  try {
    await sessionFile.writeAsString(logLine, mode: FileMode.append, flush: true);
  } catch (e) {
    // Preserve the original behavior of logging failures without throwing.
    // This is safe for session logging because location updates can continue.
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
  // Regex matches: hours:minutes:seconds.microseconds
  final regExp = RegExp(r'^(\d+):(\d+):(\d+)\.(\d+)$');
  final match = regExp.firstMatch(input.trim());
  
  if (match == null) throw FormatException('Invalid duration format');

  return Duration(
    hours: int.parse(match[1]!),
    minutes: int.parse(match[2]!),
    seconds: int.parse(match[3]!),
    // Truncate or pad microseconds to ensure it fits safely
    microseconds: int.parse(match[4]!.padRight(6, '0').substring(0, 6)),
  );
}
