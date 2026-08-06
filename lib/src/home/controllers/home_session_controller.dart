import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

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
  Duration sessionAccumulatedDuration = Duration.zero;
  DateTime? sessionResumeTime;
  Timer? _sessionTimer;

  void dispose() {
    _sessionTimer?.cancel();
    sessionDurationNotifier.dispose();
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
    _startSessionTimer();

    unawaited(_createSessionFile(sessionName));
  }

  Future<void> _createSessionFile(String sessionName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$sessionName');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    if (isSessionActive && currentSessionName == sessionName) {
      sessionFile = file;
    }
  }

  void pauseResumeSession() {
    if (!isSessionActive) return;

    if (isPaused) {
      sessionResumeTime = DateTime.now();
      _startSessionTimer();
    } else {
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

  Future<void> appendLocationToLog(Position position) async {
    if (sessionFile == null) return;
    await session_helpers.appendLocationToLog(sessionFile!, position, sessionDuration);
  }
}
