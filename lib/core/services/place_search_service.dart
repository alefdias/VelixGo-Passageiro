import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceSuggestion {
  final String title;
  final String subtitle;
  final LatLng location;
  final String? type;

  const PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.location,
    this.type,
  });
}

class PlaceSearchService {
  /// Busca sugestões de endereços reais usando o Photon (OpenStreetMap)
  /// com priorização pela proximidade das coordenadas do usuário.
  static Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? userLocation,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    try {
      // 1. Tentar Photon Geocoding (super rápido e ordenado por proximidade)
      String photonUrl = 'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}&limit=8&lang=pt';
      if (userLocation != null) {
        photonUrl += '&lat=${userLocation.latitude}&lon=${userLocation.longitude}';
      }

      final response = await http.get(Uri.parse(photonUrl)).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final List<PlaceSuggestion> results = [];

          for (final f in features) {
            final props = f['properties'] as Map<String, dynamic>? ?? {};
            final geom = f['geometry'] as Map<String, dynamic>? ?? {};
            final coords = geom['coordinates'] as List?;

            if (coords != null && coords.length >= 2) {
              final double lng = (coords[0] as num).toDouble();
              final double lat = (coords[1] as num).toDouble();

              final name = (props['name'] as String?)?.trim() ?? '';
              final street = (props['street'] as String?)?.trim();
              final houseNumber = (props['housenumber'] as String?)?.trim();
              final district = (props['district'] ?? props['suburb'] ?? props['locality'] as String?)?.toString().trim();
              final city = (props['city'] ?? props['town'] as String?)?.toString().trim();
              final state = (props['state'] as String?)?.toString().trim();
              final postcode = (props['postcode'] as String?)?.toString().trim();

              // Construir título limpo
              String title = name;
              if (street != null && street.isNotEmpty && street != name) {
                title = '$street, $name';
              }
              if (houseNumber != null && houseNumber.isNotEmpty) {
                title = '$title, $houseNumber';
              }
              if (title.isEmpty) continue;

              // Construir subtítulo
              final subParts = <String>[];
              if (district != null && district.isNotEmpty) subParts.add(district);
              if (city != null && city.isNotEmpty) {
                if (state != null && state.isNotEmpty) {
                  subParts.add('$city - $state');
                } else {
                  subParts.add(city);
                }
              }
              if (postcode != null && postcode.isNotEmpty) {
                subParts.add('CEP: $postcode');
              }

              results.add(
                PlaceSuggestion(
                  title: title,
                  subtitle: subParts.isNotEmpty ? subParts.join(', ') : 'Brasil',
                  location: LatLng(lat, lng),
                  type: props['type']?.toString(),
                ),
              );
            }
          }

          if (results.isNotEmpty) {
            return results;
          }
        }
      }
    } catch (_) {
      // Falha silenciosa para fallback Nominatim
    }

    // 2. Fallback: Nominatim OpenStreetMap
    try {
      final nominatimUrl = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&addressdetails=1&countrycodes=br&limit=6';
      final nomResponse = await http.get(
        Uri.parse(nominatimUrl),
        headers: {'User-Agent': 'VelixGoPassageiroApp/1.0'},
      ).timeout(const Duration(seconds: 4));

      if (nomResponse.statusCode == 200) {
        final List data = json.decode(nomResponse.body);
        final List<PlaceSuggestion> fallbackResults = [];

        for (final item in data) {
          final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
          if (lat == 0.0 || lon == 0.0) continue;

          final address = item['address'] as Map<String, dynamic>? ?? {};
          final road = (address['road'] ?? address['pedestrian'] ?? address['suburb'] ?? item['name'])?.toString() ?? '';
          final houseNumber = address['house_number']?.toString();
          final city = (address['city'] ?? address['town'] ?? address['municipality'])?.toString() ?? '';
          final state = address['state']?.toString() ?? '';

          String title = road.isNotEmpty ? road : (item['display_name'] ?? '');
          if (houseNumber != null && !title.contains(houseNumber)) {
            title = '$title, $houseNumber';
          }

          fallbackResults.add(
            PlaceSuggestion(
              title: title,
              subtitle: city.isNotEmpty ? '$city${state.isNotEmpty ? ' - $state' : ''}' : item['display_name'] ?? '',
              location: LatLng(lat, lon),
            ),
          );
        }

        if (fallbackResults.isNotEmpty) {
          return fallbackResults;
        }
      }
    } catch (_) {}

    return [];
  }
}
