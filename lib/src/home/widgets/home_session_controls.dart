import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helpers/color_scheme.dart';

class HomeSessionControls extends StatelessWidget {
  const HomeSessionControls({
    super.key,
    required this.isSessionActive,
    required this.isPaused,
    required this.sessionDurationListenable,
    required this.onStartSession,
    required this.onStopSession,
    required this.onPauseResumeSession,
    required this.onOpenSessionHistory,
  });

  final bool isSessionActive;
  final bool isPaused;
  final ValueListenable<Duration> sessionDurationListenable;
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
                ValueListenableBuilder<Duration>(
                  valueListenable: sessionDurationListenable,
                  builder: (context, sessionDuration, child) {
                    final hours = sessionDuration.inHours;
                    final minutes = sessionDuration.inMinutes.remainder(60);
                    final seconds = sessionDuration.inSeconds.remainder(60);
                    final hoursPart = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
                    final minutesPart = '${minutes.toString().padLeft(2, '0')}:';
                    final secondsPart = seconds.toString().padLeft(2, '0');
                    final durationText = '$hoursPart$minutesPart$secondsPart';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14.0),
                      decoration: BoxDecoration(
                        color: myColorScheme.primary,
                        borderRadius: BorderRadius.circular(20.0),
                        boxShadow: [
                          BoxShadow(
                            color: myColorScheme.surface.withAlpha(31),
                            blurRadius: 8.0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'Session time: $durationText',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                          color: myColorScheme.onSurface,
                        ),
                      ),
                    );
                  },
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
                          foregroundColor: myColorScheme.onPrimary,
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
                      backgroundColor: isSessionActive ? Colors.redAccent : myColorScheme.primary,
                      foregroundColor: myColorScheme.onPrimary,
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
                backgroundColor: myColorScheme.primary,
                foregroundColor: myColorScheme.onPrimary,
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
