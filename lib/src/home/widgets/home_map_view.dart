import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeMapView extends StatelessWidget {
  const HomeMapView({
    super.key,
    required this.mapController,
    required this.currentLocation,
    required this.onCenterLocation,
  });

  final MapController mapController;
  final LatLng? currentLocation;
  final VoidCallback onCenterLocation;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => FocusScope.of(context).unfocus(),
          child: FlutterMap(
            mapController: mapController,
            options: const MapOptions(
              initialCenter: LatLng(0.0, 0.0),
              initialZoom: 1.5,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cambion.longboard_app',
              ),
              if (currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.purple.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.location_history,
                            color: Colors.purple,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          right: 16.0,
          top: 152.0,
          child: FloatingActionButton(
            onPressed: onCenterLocation,
            backgroundColor: Colors.white,
            foregroundColor: Colors.purple,
            tooltip: 'Center on location',
            shape: const CircleBorder(),
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}
