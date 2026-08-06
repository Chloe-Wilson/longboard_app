import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../helpers/search_helpers.dart' as search_helpers;

typedef StateUpdater = void Function(void Function());

class HomeSearchController {
  HomeSearchController({required this.setState});

  final StateUpdater setState;

  bool isSearchingLocation = false;
  List<search_helpers.SearchSuggestion> searchSuggestions = [];
  Timer? _debounce;

  void dispose() {
    _debounce?.cancel();
  }

  void onSearchTextChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        searchSuggestions = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      fetchSearchSuggestions(query);
    });
  }

  Future<void> fetchSearchSuggestions(String query) async {
    setState(() {
      isSearchingLocation = true;
    });

    try {
      final suggestions = await search_helpers.fetchSearchSuggestions(query);
      setState(() {
        searchSuggestions = suggestions;
      });
    } catch (_) {
      setState(() {
        searchSuggestions = [];
      });
    } finally {
      setState(() {
        isSearchingLocation = false;
      });
    }
  }

  Future<search_helpers.SearchLocationResult?> searchLocation(String query, LatLng? currentLocation) async {
    setState(() {
      isSearchingLocation = true;
    });
    try {
      return await search_helpers.geocodeLocation(query, currentLocation: currentLocation);
    } finally {
      setState(() {
        isSearchingLocation = false;
      });
    }
  }
}
