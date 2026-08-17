import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../helpers/color_scheme.dart';
import 'settings_provider.dart';

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
                alignment: AttributionAlignment.bottomLeft,
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
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 24.0, top: 50.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'settings',
                  onPressed: () {
                    final settingsNotifier = context.read<SettingsNotifier>();
                    final settings = settingsNotifier.settings;

                    // Create controllers pre-filled with current values
                    final controllers = <String, TextEditingController>{};
                    settings.forEach((key, value) {
                      controllers[key] = TextEditingController(text: value.toString());
                    });

                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('Settings'),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 4.0,
                            ),
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: settings.keys.map((key) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: TextField(
                                    controller: controllers[key],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: key,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                // Save updated values to file & state
                                for (var key in controllers.keys) {
                                  final newValue = int.tryParse(controllers[key]!.text);
                                  if (newValue != null) {
                                    await settingsNotifier.updateSetting(key, newValue);
                                  }
                                }
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  backgroundColor: myColorScheme.primary,
                  foregroundColor: myColorScheme.onPrimary,
                  tooltip: 'Settings',
                  shape: const CircleBorder(),
                  child: const Icon(Icons.settings),
                ),
                const SizedBox(height: 16.0),
                FloatingActionButton(
                  heroTag: 'center_location',
                  onPressed: onCenterLocation,
                  backgroundColor: myColorScheme.primary,
                  foregroundColor: myColorScheme.onPrimary,
                  tooltip: 'Center on location',
                  shape: const CircleBorder(),
                  child: const Icon(Icons.my_location),
                ),
              ]
            ),
          ),
        ),
      ],
    );
  }
}
