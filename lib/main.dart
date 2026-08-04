import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
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

  @override
  void initState() {
    super.initState();
    // Start tracking when the screen loads
    _startLocationTracking();
  }

 void _startLocationTracking() async {
    try {
      // 1. Ensure permissions are granted before starting the stream
      await checkLocationPermissions();

      // 2. Configure settings for 1-second update intervals
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high, // Accurate GPS reading
        distanceFilter: 0,               // Notify even if the user hasn't moved far
        timeLimit: Duration(seconds: 10), // Optional timeout safety
      );

      // 3. Listen to the stream
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
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
      // appBar: AppBar(
      //   backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      //   title: Text(widget.title),
      // ),
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
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [
                    LatLng(43.171211, -79.196534),
                    LatLng(43.177982, -79.197328),
                  ],
                  color: Colors.purple,
                  strokeWidth: 4.0,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
              ],
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

        // 2. Overlay Floating GPS Button
        Positioned(
          bottom: 24.0,
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
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Waiting for GPS signal...')),
                );
              }
            },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}