import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

Future<String> nextSessionDefaultName() async {
  final directory = await getApplicationDocumentsDirectory();
  final entities = await directory.list().toList();
  int maxNumber = 0;

  for (final entity in entities.whereType<File>()) {
    final content = await entity.readAsLines();
    if (content.isEmpty) continue;
    final firstLine = content.first.trim();
    if (!firstLine.startsWith('# SessionName:')) continue;
    final name = firstLine.replaceFirst('# SessionName:', '').trim();
    final match = RegExp(r'^Session #(\d+)$').firstMatch(name);
    if (match != null) {
      final number = int.tryParse(match.group(1) ?? '') ?? 0;
      maxNumber = number > maxNumber ? number : maxNumber;
    }
  }

  return 'Session #${maxNumber + 1}';
}

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
