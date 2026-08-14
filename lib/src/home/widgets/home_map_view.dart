import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/color_scheme.dart';

class HomeMapView extends StatelessWidget {
  const HomeMapView({
    super.key,
    required this.mapController,
    required this.currentLocation,
    required this.onCenterLocation,
    required this.currentSessionPoints,
  });

  final MapController mapController;
  final LatLng? currentLocation;
  final VoidCallback onCenterLocation;
  final List<LatLng> currentSessionPoints;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => FocusScope.of(context).unfocus(),
          child: FlutterMap(
            mapController: mapController,
            options: MapOptions(
              backgroundColor: myColorScheme.surface,
              initialCenter: LatLng(0.0, 0.0),
              initialZoom: 1.5,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileBuilder: (context, tileWidget, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      0,       0,       0,       1, 0,
                    ]),
                    child: tileWidget,
                  );
                },
                userAgentPackageName: 'com.cambion.longboard_app',
              ),
              if (currentSessionPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: currentSessionPoints,
                      color: myColorScheme.onPrimary,
                      strokeWidth: 4.0,
                      borderColor: myColorScheme.primary,
                      borderStrokeWidth: 2.0,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
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
                          color: myColorScheme.primary.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.location_history,
                            color: myColorScheme.primary,
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
            backgroundColor: myColorScheme.primary,
            foregroundColor: myColorScheme.onPrimary,
            tooltip: 'Center on location',
            shape: const CircleBorder(),
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}
