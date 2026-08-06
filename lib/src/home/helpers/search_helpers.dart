import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class SearchSuggestion {
  final String label;
  final LatLng location;
  final double zoom;

  SearchSuggestion(this.label, this.location, {required this.zoom});
}

class SearchLocationResult {
  final LatLng center;
  final double zoom;

  SearchLocationResult(this.center, this.zoom);
}

Future<SearchLocationResult?> geocodeLocation(
  String query, {
  LatLng? currentLocation,
}) async {
  if (query.trim().isEmpty) return null;

  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': query.trim(),
    'format': 'json',
    'limit': '5',
  });

  final response = await http.get(uri, headers: {
    'User-Agent': 'longboard_app/1.0',
  });
  if (response.statusCode != 200) return null;
  final data = jsonDecode(response.body);
  if (data is! List || data.isEmpty) return null;

  final locations = <SearchLocationResult>[];
  for (final item in data) {
    if (item is! Map<String, dynamic>) continue;
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat == null || lon == null) continue;

    double zoom = 15.0;
    if (item['boundingbox'] is List && (item['boundingbox'] as List).length == 4) {
      final bbox = item['boundingbox'] as List;
      final south = double.tryParse(bbox[0]?.toString() ?? '');
      final north = double.tryParse(bbox[1]?.toString() ?? '');
      final west = double.tryParse(bbox[2]?.toString() ?? '');
      final east = double.tryParse(bbox[3]?.toString() ?? '');
      if (south != null && north != null && west != null && east != null) {
        zoom = _zoomForBoundingBox(south, north, west, east);
      }
    }

    locations.add(SearchLocationResult(LatLng(lat, lon), zoom));
  }

  if (locations.isEmpty) return null;
  if (currentLocation == null) return locations.first;

  locations.sort((a, b) {
    final distA = const Distance().distance(currentLocation, a.center);
    final distB = const Distance().distance(currentLocation, b.center);
    return distA.compareTo(distB);
  });
  return locations.first;
}

Future<List<SearchSuggestion>> fetchSearchSuggestions(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return [];

  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': trimmed,
    'format': 'json',
    'limit': '5',
  });

  final response = await http.get(uri, headers: {
    'User-Agent': 'longboard_app/1.0',
  });
  if (response.statusCode != 200) return [];

  final data = jsonDecode(response.body);
  if (data is! List) return [];

  return data
      .map<SearchSuggestion?>((item) {
        final fullLabel = item['display_name']?.toString();
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        if (fullLabel == null || lat == null || lon == null) return null;

        final label = simplifySuggestionLabel(fullLabel);
        double zoom = 15.0;
        if (item['boundingbox'] is List && (item['boundingbox'] as List).length == 4) {
          final bbox = item['boundingbox'] as List;
          final south = double.tryParse(bbox[0]?.toString() ?? '');
          final north = double.tryParse(bbox[1]?.toString() ?? '');
          final west = double.tryParse(bbox[2]?.toString() ?? '');
          final east = double.tryParse(bbox[3]?.toString() ?? '');
          if (south != null && north != null && west != null && east != null) {
            zoom = _zoomForBoundingBox(south, north, west, east);
          }
        }

        return SearchSuggestion(label, LatLng(lat, lon), zoom: zoom);
      })
      .whereType<SearchSuggestion>()
      .toList();
}

double _zoomForBoundingBox(
  double south,
  double north,
  double west,
  double east,
) {
  final latDiff = (north - south).abs();
  final lngDiff = (east - west).abs();
  final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

  if (maxDiff < 0.001) return 18.5;
  if (maxDiff < 0.005) return 17.0;
  if (maxDiff < 0.02) return 15.5;
  if (maxDiff < 0.05) return 14.0;
  if (maxDiff < 0.15) return 12.0;
  if (maxDiff < 0.5) return 10.5;
  if (maxDiff < 1.5) return 9.0;
  if (maxDiff < 3.0) return 8.0;
  return 6.5;
}

String simplifySuggestionLabel(String fullLabel) {
  final parts = fullLabel
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length <= 2) return fullLabel;
  return parts.take(2).join(', ');
}
