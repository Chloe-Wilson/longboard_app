import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

Future<void> checkLocationPermissions() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }
  
  if (permission == LocationPermission.deniedForever) {
    return Future.error(
      'Location permissions are permanently denied, we cannot request permissions.'
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Chloe Longboard App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Controller to programmatically move the map camera
  final MapController _mapController = MapController();

  LatLng? _currentLocation;

  // Stream subscription to track location continuously
  StreamSubscription<Position>? _positionStreamSubscription;

  bool _isSessionActive = false;
  bool _isPaused = false;
  File? _sessionFile;
  String? _currentSessionName;

  @override
  void initState() {
    super.initState();
    // Start tracking when the screen loads
    _startLocationTracking();
  }

  Future<void> _startNewSession() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final sessionName = 'longboard_session_$timestamp.txt';
    final file = File('${directory.path}/$sessionName');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    setState(() {
      _sessionFile = file;
      _currentSessionName = sessionName;
      _isSessionActive = true;
      _isPaused = false;
    });
  }

  void _pauseResumeSession() {
    if (!_isSessionActive) return;

    setState(() {
      _isPaused = !_isPaused;
    });
  }

  Future<void> _stopSession() async {
    if (!_isSessionActive) return;

    final file = _sessionFile;
    final defaultSessionName = await _nextSessionDefaultName();
    final enteredName = await _promptSessionName(defaultSessionName);
    final sessionName = enteredName.isNotEmpty ? enteredName : defaultSessionName;

    if (file != null) {
      await _writeSessionHeader(file, sessionName);
    }

    setState(() {
      _isSessionActive = false;
      _isPaused = false;
      _sessionFile = null;
      _currentSessionName = null;
    });
  }

  Future<String> _promptSessionName(String fallbackName) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Name your session'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Session name',
              hintText: fallbackName,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Skip'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    return result?.trim() ?? '';
  }

  Future<String> _nextSessionDefaultName() async {
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

  Future<void> _writeSessionHeader(File file, String sessionName) async {
    final header = '# SessionName: $sessionName\n';
    final contents = await file.readAsString();
    if (contents.startsWith('# SessionName:')) {
      final remaining = contents.split('\n').skip(1).join('\n');
      await file.writeAsString('$header$remaining');
    } else {
      await file.writeAsString('$header$contents');
    }
  }

  void _openSessionHistoryPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SessionHistoryPage()),
    );
  }

  Future<void> _appendLocationToLog(Position position) async {
    if (_sessionFile == null) return;

    final timestamp = DateTime.now().toIso8601String();
    final logLine = '$timestamp,${position.latitude},${position.longitude},${position.accuracy}\n';

    try {
      await _sessionFile!.writeAsString(logLine, mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('Failed to write log entry: $e');
    }
  }

  void _startLocationTracking() async {
    try {
      // 1. Ensure permissions are granted before starting the stream
      await checkLocationPermissions();

      // 2. Configure settings for steady updates
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high, // Accurate GPS reading
        distanceFilter: 0,               // Notify even if the user hasn't moved far
      );

      // 3. Listen to the stream
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });

        if (_isSessionActive && !_isPaused) {
          _appendLocationToLog(position);
        }
      }, onError: (error) {
        debugPrint('Location stream error: $error');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    // Crucial: Cancel the stream subscription to prevent memory leaks when widget is destroyed
    _positionStreamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: content(),
    );
  }

  Widget content() {
    return Stack(
      children: [
        // 1. Map Layer
        FlutterMap(
          mapController: _mapController, // Linked controller
          options: const MapOptions(
            initialCenter: LatLng(43.14795, -79.22791),
            initialZoom: 9.2,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.cambion.longboard_app',
            ),
            if (_currentLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation!,
                    width: 40,
                    height: 40, 
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.location_history, // Visual indicator icon
                          color: Colors.purple,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ]
              ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')), // (external)
                ),
              ],
            ),
          ],
        ),

        // 2. Bottom session control buttons
        Positioned(
          left: 0,
          right: 0,
          bottom: 100.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentSessionName != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24.0),
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    'Session: $_currentSessionName${_isPaused ? ' (paused)' : ''}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_currentSessionName != null)
                const SizedBox(height: 10.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSessionActive)
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
                        onPressed: _pauseResumeSession,
                        child: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                      ),
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20.0),
                      backgroundColor: _isSessionActive ? Colors.redAccent : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 8,
                    ),
                    onPressed: _isSessionActive ? _stopSession : _startNewSession,
                    child: Icon(_isSessionActive ? Icons.stop : Icons.play_arrow),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 3. Overlay Floating GPS Button in top right
        Positioned(
          top: 24.0,
          right: 24.0,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(), // Makes the button perfectly round
              padding: const EdgeInsets.all(16), // Padding around the icon
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 6,
            ),
            onPressed: () {
              if (_currentLocation != null) {
                _mapController.move(_currentLocation!, 15.0);
              }
            },
            child: const Icon(Icons.my_location),
          ),
        ),

        // 4. Session history button at bottom right when no active session
        if (!_isSessionActive)
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
              onPressed: _openSessionHistoryPage,
              child: const Icon(Icons.history),
            ),
          ),
      ],
    );
  }
}

class SessionHistoryPage extends StatefulWidget {
  const SessionHistoryPage({super.key});

  @override
  State<SessionHistoryPage> createState() => _SessionHistoryPageState();
}

class _SessionHistoryPageState extends State<SessionHistoryPage> {
  late Future<List<_SessionSummary>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _loadSessionSummaries();
  }

  Future<List<_SessionSummary>> _loadSessionSummaries() async {
    final directory = await getApplicationDocumentsDirectory();
    final entities = await directory.list().toList();
    final sessionFiles = entities
        .whereType<File>()
        .where((file) =>
            file.path.split(Platform.pathSeparator).last.startsWith('longboard_session_'))
        .toList();
    sessionFiles.sort((a, b) => b.path.compareTo(a.path));

    final summaries = <_SessionSummary>[];
    for (final file in sessionFiles) {
      final summary = await _parseSessionFile(file);
      summaries.add(summary);
    }
    return summaries;
  }

  Future<_SessionSummary> _parseSessionFile(File file) async {
    final lines = await file.readAsLines();
    final positions = <_LoggedPosition>[];
    final rawLines = lines.where((line) => line.trim().isNotEmpty).toList();
    for (var index = 0; index < rawLines.length; index++) {
      final line = rawLines[index].trim();
      if (index == 0 && line.startsWith('# SessionName:')) {
        continue;
      }
      final parts = line.split(',');
      if (parts.length < 3) continue;
      try {
        final timestamp = DateTime.parse(parts[0]);
        final latitude = double.parse(parts[1]);
        final longitude = double.parse(parts[2]);
        positions.add(_LoggedPosition(
          timestamp: timestamp,
          location: LatLng(latitude, longitude),
        ));
      } catch (_) {
        continue;
      }
    }

    final duration = positions.length >= 2
        ? positions.last.timestamp.difference(positions.first.timestamp)
        : Duration.zero;

    double totalDistance = 0.0;
    double maxSpeedMps = 0.0;

    for (var i = 1; i < positions.length; i++) {
      final previous = positions[i - 1];
      final current = positions[i];
      final segmentDistance = const Distance().distance(
        previous.location,
        current.location,
      );
      final seconds = current.timestamp.difference(previous.timestamp).inMilliseconds / 1000.0;
      totalDistance += segmentDistance;
      if (seconds > 0) {
        final speedMps = segmentDistance / seconds;
        if (speedMps > maxSpeedMps) {
          maxSpeedMps = speedMps;
        }
      }
    }

    final averageSpeedKmh = duration.inSeconds > 0
        ? (totalDistance / duration.inSeconds) * 3.6
        : 0.0;
    final maxSpeedKmh = maxSpeedMps * 3.6;

    var sessionName = file.path.split(Platform.pathSeparator).last;
    if (lines.isNotEmpty && lines.first.trim().startsWith('# SessionName:')) {
      final headerName = lines.first.trim().replaceFirst('# SessionName:', '').trim();
      if (headerName.isNotEmpty) {
        sessionName = headerName;
      }
    }

    return _SessionSummary(
      file: file,
      sessionName: sessionName,
      duration: duration,
      distanceMeters: totalDistance,
      averageSpeedKmh: averageSpeedKmh,
      maxSpeedKmh: maxSpeedKmh,
    );
  }

  Future<void> _deleteSession(File file) async {
    await file.delete();
    setState(() {
      _sessionsFuture = _loadSessionSummaries();
    });
  }

  Future<bool> _confirmDelete(BuildContext context, String sessionName) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Session'),
          content: Text('Delete "$sessionName"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  String _formatDistance(double meters) {
    final kilometers = meters / 1000.0;
    return '${kilometers.toStringAsFixed(2)} km';
  }

  String _formatSpeed(double kmh) {
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Past Sessions')),
      body: FutureBuilder<List<_SessionSummary>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return const Center(child: Text('No past sessions found.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12.0),
            itemBuilder: (context, index) {
              final summary = sessions[index];
              final details =
                  '${_formatDuration(summary.duration)} • ${_formatDistance(summary.distanceMeters)}';
              final stats =
                  'Avg ${_formatSpeed(summary.averageSpeedKmh)}, max ${_formatSpeed(summary.maxSpeedKmh)}';
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                tileColor: Theme.of(context).colorScheme.surfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                title: Text(summary.sessionName),
                subtitle: Text('$details\n$stats'),
                isThreeLine: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SessionDetailPage(
                        sessionFile: summary.file,
                        sessionName: summary.sessionName,
                      ),
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirmed = await _confirmDelete(context, summary.sessionName);
                    if (confirmed) {
                      await _deleteSession(summary.file);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({
    super.key,
    required this.sessionFile,
    required this.sessionName,
  });

  final File sessionFile;
  final String sessionName;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  final MapController _mapController = MapController();
  late Future<List<_LoggedPosition>> _positionsFuture;

  @override
  void initState() {
    super.initState();
    _positionsFuture = _loadPositions();
  }

  Future<List<_LoggedPosition>> _loadPositions() async {
    final lines = await widget.sessionFile.readAsLines();
    final positions = <_LoggedPosition>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 3) continue;
      try {
        final timestamp = DateTime.parse(parts[0]);
        final latitude = double.parse(parts[1]);
        final longitude = double.parse(parts[2]);
        positions.add(_LoggedPosition(
          timestamp: timestamp,
          location: LatLng(latitude, longitude),
        ));
      } catch (_) {
        continue;
      }
    }
    return positions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionName),
      ),
      body: FutureBuilder<List<_LoggedPosition>>(
        future: _positionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final positions = snapshot.data ?? [];
          if (positions.isEmpty) {
            return const Center(child: Text('No GPS points available.'));
          }

          final polylinePoints = positions.map((p) => p.location).toList();
          final center = polylinePoints.first;

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cambion.longboard_app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    color: Colors.blueAccent,
                    strokeWidth: 4.0,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: polylinePoints.first,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.green,
                      size: 32,
                    ),
                  ),
                  Marker(
                    point: polylinePoints.last,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.stop,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoggedPosition {
  _LoggedPosition({required this.timestamp, required this.location});

  final DateTime timestamp;
  final LatLng location;
}

class _SessionSummary {
  _SessionSummary({
    required this.file,
    required this.sessionName,
    required this.duration,
    required this.distanceMeters,
    required this.averageSpeedKmh,
    required this.maxSpeedKmh,
  });

  final File file;
  final String sessionName;
  final Duration duration;
  final double distanceMeters;
  final double averageSpeedKmh;
  final double maxSpeedKmh;
}
