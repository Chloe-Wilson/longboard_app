import 'dart:async';


import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background/flutter_background.dart' as flutter_background hide AndroidResource;
import 'package:permission_handler/permission_handler.dart';


import '../controllers/home_page_controller.dart';
import '../helpers/location_helpers.dart';
import '../widgets/home_map_view.dart';
import '../widgets/home_session_controls.dart';
import '../../session/pages/session_history_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _hasFocusedOnLocation = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final HomePageController homePageController;

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _gpsLogTimer;
  Position? _latestPosition;

  @override
  void initState() {
    super.initState();
    homePageController = HomePageController(setState: setState);
    _startLocationTracking();
  }

  Future<void> _startNewSession() async {
    homePageController.sessionController.clearPath();
    await _initBackgroundExecution();
    await homePageController.startNewSession();
    _logGps();
  }

  void _pauseResumeSession() => homePageController.pauseResumeSession();

  Future<void> _stopSession() async {
    _logGps(true);
    await homePageController.stopSession(context);
    await flutter_background.FlutterBackground.disableBackgroundExecution();
  }

  void _openSessionHistoryPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SessionHistoryPage()),
    );
  }

  Future<void> _initBackgroundExecution() async {
    final locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) {
      return Future.error('Foreground location permission denied');
    }

    final backgroundLocationStatus = await Permission.locationAlways.request();
    if (!backgroundLocationStatus.isGranted) {
      return Future.error('Background location permissions are denied');
    }

    final androidConfig = flutter_background.FlutterBackgroundAndroidConfig(
      notificationTitle: "GPS Logging Active",
      notificationText: "Your session is recording in the background.",
      enableWifiLock: true,
    );
    
    bool initialized = await flutter_background.FlutterBackground.initialize(androidConfig: androidConfig);
    if (initialized) {
      await flutter_background.FlutterBackground.enableBackgroundExecution();
    }
  }


  void _logGps([bool last = false]) {
    final position = _latestPosition;
    if (position == null) return;
    if (!homePageController.sessionController.isSessionActive) return;
    if (homePageController.sessionController.isPaused) return;

    homePageController.appendLocationToLog(position, last);
    
    homePageController.sessionController.addPoint(position);
  }

  void _startLocationTracking() async {
  try {
    await checkLocationPermissions(); 
    
    final LocationSettings locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      forceLocationManager: false,
      intervalDuration: const Duration(seconds: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: "Location Tracking Active",
        notificationText: "Your app is tracking location in the background.",
        notificationChannelName: 'Location Tracking',
        enableWakeLock: true,
      ),
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _latestPosition = position;
      final newLocation = LatLng(position.latitude, position.longitude);
      _logGps();
      
      setState(() {
        _currentLocation = newLocation;
      });

      if (!_hasFocusedOnLocation) {
        _hasFocusedOnLocation = true;
        _mapController.move(newLocation, 15.0);
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
    _positionStreamSubscription?.cancel();
    _gpsLogTimer?.cancel();
    homePageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
        ValueListenableBuilder<List<LatLng>>(
          valueListenable: homePageController.sessionController.sessionPathNotifier,
          builder: (context, sessionPoints, child) {
            return HomeMapView(
              mapController: _mapController,
              currentLocation: _currentLocation,
              currentSessionPoints: sessionPoints, // Pass the live list here
              onCenterLocation: () {
                setState(() {
                  _searchController.clear();
                  homePageController.searchController.searchSuggestions = [];
                });
                FocusScope.of(context).unfocus();
                if (_currentLocation != null) {
                  _mapController.move(_currentLocation!, 15.0);
                }
              },
            );
          },
        ),
        HomeSessionControls(
          isSessionActive: homePageController.sessionController.isSessionActive,
          isPaused: homePageController.sessionController.isPaused,
          sessionDurationListenable: homePageController.sessionController.sessionDurationNotifier,
          sessionDistanceListenable: homePageController.sessionController.sessionDistanceNotifier,
          onStartSession: _startNewSession,
          onStopSession: _stopSession,
          onPauseResumeSession: _pauseResumeSession,
          onOpenSessionHistory: _openSessionHistoryPage,
        ),
      ],
    );
  }
}
