import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../controllers/home_page_controller.dart';
import '../helpers/location_helpers.dart';
import '../helpers/search_helpers.dart';
import '../widgets/home_map_view.dart';
import '../widgets/home_search_bar.dart';
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

  final homePageController = HomePageController(setState: (fn) => fn());

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _positionPollTimer;
  bool _isFetchingPosition = false;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  Future<void> _startNewSession() => homePageController.startNewSession();

  void _pauseResumeSession() => homePageController.pauseResumeSession();

  Future<void> _stopSession() async {
    await homePageController.stopSession(context);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final hoursPart = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    final minutesPart = '${minutes.toString().padLeft(2, '0')}:';
    final secondsPart = seconds.toString().padLeft(2, '0');
    return '$hoursPart$minutesPart$secondsPart';
  }

  void _openSessionHistoryPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SessionHistoryPage()),
    );
  }

  Future<void> _searchAndMoveToLocation() async {
    await homePageController.searchAndMoveToLocation(
      _searchController.text,
      _currentLocation,
      _mapController,
    );
  }

  void _onSearchTextChanged(String query) {
    homePageController.onSearchTextChanged(query);
  }

  void _selectSuggestion(SearchSuggestion suggestion) {
    homePageController.selectSuggestion(
      suggestion,
      _searchController,
      _searchFocusNode,
      _mapController,
    );
  }


  Future<void> _appendLocationToLog(Position position) async {
    await homePageController.appendLocationToLog(position);
  }

  void _startPositionPolling() {
    _positionPollTimer?.cancel();
    _positionPollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_isFetchingPosition) return;

      _isFetchingPosition = true;
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final newLocation = LatLng(position.latitude, position.longitude);
        if (mounted) {
          setState(() {
            _currentLocation = newLocation;
          });
        }

        if (homePageController.sessionController.isSessionActive && !homePageController.sessionController.isPaused) {
          await _appendLocationToLog(position);
        }
      } catch (e) {
        debugPrint('Position polling error: $e');
      } finally {
        _isFetchingPosition = false;
      }
    });
  }

  void _startLocationTracking() async {
    try {
      await checkLocationPermissions();

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        final newLocation = LatLng(position.latitude, position.longitude);
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

      _startPositionPolling();
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
    _positionPollTimer?.cancel();
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
        HomeMapView(
          mapController: _mapController,
          currentLocation: _currentLocation,
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
        ),
        Positioned(
          top: 80.0,
          left: 16.0,
          right: 16.0,
          child: HomeSearchBar(
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
            isSearchingLocation: homePageController.searchController.isSearchingLocation,
            searchSuggestions: homePageController.searchController.searchSuggestions,
            onSearchTextChanged: _onSearchTextChanged,
            onSearchSubmitted: _searchAndMoveToLocation,
            onSuggestionSelected: _selectSuggestion,
          ),
        ),
        HomeSessionControls(
          isSessionActive: homePageController.sessionController.isSessionActive,
          isPaused: homePageController.sessionController.isPaused,
          sessionDuration: _formatDuration(homePageController.sessionController.sessionDuration),
          onStartSession: _startNewSession,
          onStopSession: _stopSession,
          onPauseResumeSession: _pauseResumeSession,
          onOpenSessionHistory: _openSessionHistoryPage,
        ),
      ],
    );
  }
}
