import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'home_search_controller.dart';
import 'home_session_controller.dart';
import '../../session/helpers/session_helpers.dart' as session_helpers;
import '../helpers/search_helpers.dart' as search_helpers;
import '../helpers/color_scheme.dart';

typedef StateUpdater = void Function(void Function());

class HomePageController {
  HomePageController({required this.setState})
      : searchController = HomeSearchController(setState: setState),
        sessionController = HomeSessionController(setState: setState);

  final StateUpdater setState;
  final HomeSearchController searchController;
  final HomeSessionController sessionController;

  void dispose() {
    searchController.dispose();
    sessionController.dispose();
  }

  Future<void> startNewSession() => sessionController.startNewSession();

  void pauseResumeSession() => sessionController.pauseResumeSession();

  Future<void> stopSession(BuildContext context) async {
    if (!sessionController.isSessionActive) return;

    final sessionFile = sessionController.sessionFile;
    sessionController.stopSession();

    final defaultSessionName = _defaultSessionName();
    final enteredName = await _promptSessionName(context, defaultSessionName);
    final sessionName = enteredName.isNotEmpty ? enteredName : defaultSessionName;

    if (sessionFile != null) {
      session_helpers.writeSessionHeader(sessionFile, sessionName);
    }
  }

  String _defaultSessionName() {
    final date = DateTime.now();
    return 'Session ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}_${date.hour.toString().padLeft(2, '0')}.${date.minute.toString().padLeft(2, '0')}';
  }

  Future<String> _promptSessionName(BuildContext context, String fallbackName) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Name your session'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(
              color: myColorScheme.primary,
              width: 4.0,
            ),
          ),
          content: TextField(
            controller: controller,
            style: TextStyle(
              color: myColorScheme.onSurface,
              fontSize: 16.0,
            ),
            decoration: InputDecoration(
              labelText: 'Session name',
              hintText: fallbackName,
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: myColorScheme.primary,
              ),
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Skip'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: myColorScheme.primary,
              ),
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    return result?.trim() ?? '';
  }

  Future<void> searchAndMoveToLocation(
    String query,
    LatLng? currentLocation,
    MapController mapController,
  ) async {
    if (query.trim().isEmpty) return;

    final result = await searchController.searchLocation(query, currentLocation);
    if (result != null) {
      mapController.move(result.center, result.zoom);
    }

    setState(() {
      searchController.searchSuggestions = [];
    });
  }

  void onSearchTextChanged(String query) {
    searchController.onSearchTextChanged(query);
  }

  void selectSuggestion(
    search_helpers.SearchSuggestion suggestion,
    TextEditingController searchTextController,
    FocusNode focusNode,
    MapController mapController,
  ) {
    searchTextController.text = suggestion.label;
    searchController.searchSuggestions = [];
    focusNode.unfocus();
    mapController.move(suggestion.location, suggestion.zoom);
  }

  Future<void> appendLocationToLog(Position position, [bool last = false]) async {
    await sessionController.appendLocationToLog(position, last);
  }
}
