import 'dart:async';
import 'dart:io';

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
  Duration sessionAccumulatedDuration = Duration.zero;
  DateTime? sessionResumeTime;
  Timer? _sessionTimer;

  void dispose() {
    _sessionTimer?.cancel();
  }

  Future<void> startNewSession() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final sessionName = 'longboard_session_$timestamp.txt';
    final file = File('${directory.path}/$sessionName');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    setState(() {
      sessionFile = file;
      currentSessionName = sessionName;
      isSessionActive = true;
      isPaused = false;
      sessionDuration = Duration.zero;
      sessionAccumulatedDuration = Duration.zero;
      sessionResumeTime = DateTime.now();
    });
    _startSessionTimer();
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

    setState(() {
      isSessionActive = false;
      isPaused = false;
      sessionFile = null;
      currentSessionName = null;
      sessionDuration = Duration.zero;
      sessionAccumulatedDuration = Duration.zero;
      sessionResumeTime = null;
    });

    _stopSessionTimer();
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
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
    setState(() {
      sessionDuration = sessionAccumulatedDuration + elapsedSinceResume;
    });
  }

  Future<void> appendLocationToLog(Position position) async {
    if (sessionFile == null) return;
    await session_helpers.appendLocationToLog(sessionFile!, position);
  }
}
