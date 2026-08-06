import 'package:flutter/material.dart';

class HomeSessionControls extends StatelessWidget {
  const HomeSessionControls({
    super.key,
    required this.isSessionActive,
    required this.isPaused,
    required this.sessionDuration,
    required this.onStartSession,
    required this.onStopSession,
    required this.onPauseResumeSession,
    required this.onOpenSessionHistory,
  });

  final bool isSessionActive;
  final bool isPaused;
  final String sessionDuration;
  final VoidCallback onStartSession;
  final VoidCallback onStopSession;
  final VoidCallback onPauseResumeSession;
  final VoidCallback onOpenSessionHistory;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 100.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSessionActive)
                Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(31),
                        blurRadius: 8.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Session time: $sessionDuration',
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSessionActive)
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(18.0),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          elevation: 6,
                        ),
                        onPressed: onPauseResumeSession,
                        child: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                      ),
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20.0),
                      backgroundColor: isSessionActive ? Colors.redAccent : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 8,
                    ),
                    onPressed: isSessionActive ? onStopSession : onStartSession,
                    child: Icon(isSessionActive ? Icons.stop : Icons.play_arrow),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isSessionActive)
          Positioned(
            bottom: 24.0,
            right: 24.0,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                elevation: 6,
              ),
              onPressed: onOpenSessionHistory,
              child: const Icon(Icons.history),
            ),
          ),
      ],
    );
  }
}
