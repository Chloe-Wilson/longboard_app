import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_background/flutter_background.dart' as flutter_background hide AndroidResource;

import '../../session/helpers/session_helpers.dart' as session_helpers;

typedef StateUpdater = void Function(void Function());

class HomeSessionController {
  HomeSessionController({required this.setState});

  final StateUpdater setState;

  bool isSessionActive = false;
  bool isPaused = false;
  File? sessionFile;
  String? currentSessionName;
  Duration sessionDuration = Duration.zero;
  final ValueNotifier<Duration> sessionDurationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<double> sessionDistanceNotifier = ValueNotifier(0.0);
  Duration sessionAccumulatedDuration = Duration.zero;
  DateTime? sessionResumeTime;
  Timer? _sessionTimer;

  void dispose() {
    _sessionTimer?.cancel();
    sessionDurationNotifier.dispose();
    sessionDistanceNotifier.dispose();
  }

  Future<void> startNewSession() async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final sessionName = 'longboard_session_$timestamp.txt';

    setState(() {
      sessionFile = null;
      currentSessionName = sessionName;
      isSessionActive = true;
      isPaused = false;
      sessionDuration = Duration.zero;
      sessionAccumulatedDuration = Duration.zero;
      sessionResumeTime = DateTime.now();
    });
    sessionDurationNotifier.value = Duration.zero;
    sessionDistanceNotifier.value = 0.0;
    _startSessionTimer();

    final file = await _createSessionFile(sessionName);
    if (isSessionActive && currentSessionName == sessionName) {
      sessionFile = file;
    }
  }

  Future<File> _createSessionFile(String sessionName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$sessionName');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    return file;
  }

  Future<void> pauseResumeSession() async {
    if (!isSessionActive) return;

    if (isPaused) {
      await flutter_background.FlutterBackground.enableBackgroundExecution();
      sessionResumeTime = DateTime.now();
      _startSessionTimer();
    } else {
      await flutter_background.FlutterBackground.disableBackgroundExecution();
      if (sessionResumeTime != null) {
        sessionAccumulatedDuration += DateTime.now().difference(sessionResumeTime!);
        sessionResumeTime = null;
      }
      _stopSessionTimer();
    }

    setState(() {
      isPaused = !isPaused;
    });
  }

  Future<void> stopSession() async {
    if (!isSessionActive) return;

    _stopSessionTimer();
    setState(() {
      isSessionActive = false;
      isPaused = false;
      sessionDuration = Duration.zero;
      sessionAccumulatedDuration = Duration.zero;
      sessionResumeTime = null;
    });
    sessionDurationNotifier.value = Duration.zero;
    sessionDistanceNotifier.value = 0.0;
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _updateSessionDuration();
    });
    _updateSessionDuration();
  }

  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  void _updateSessionDuration() {
    if (!isSessionActive || sessionResumeTime == null) return;
    final elapsedSinceResume = DateTime.now().difference(sessionResumeTime!);
    final updatedDuration = sessionAccumulatedDuration + elapsedSinceResume;
    sessionDuration = updatedDuration;
    sessionDurationNotifier.value = updatedDuration;
  }

  Future<void> appendLocationToLog(Position position, [bool last = false]) async {
    if (sessionFile == null) return;
    sessionDistanceNotifier.value += session_helpers.calculateDistanceFromLastPoint(sessionFile!, position);
    await session_helpers.appendLocationToLog(sessionFile!, position, sessionDuration, last);
  }

  final ValueNotifier<List<LatLng>> sessionPathNotifier = ValueNotifier([]);

  void addPoint(Position position) {
    final latLng = LatLng(position.latitude, position.longitude);
    // Update the list and notify listeners
    sessionPathNotifier.value = [...sessionPathNotifier.value, latLng];
  }

  // Clear path when session stops/starts fresh
  void clearPath() {
    sessionPathNotifier.value = [];
  }
}
