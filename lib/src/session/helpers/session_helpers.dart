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

Future<void> appendLocationToLog(File sessionFile, Position position) async {
  final timestamp = DateTime.now().toIso8601String();
  final logLine = '$timestamp,${position.latitude},${position.longitude},${position.accuracy}\n';

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
