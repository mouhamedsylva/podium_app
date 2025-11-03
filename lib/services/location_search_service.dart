import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Service de recherche de localisation avec debounce
/// Conforme à l'architecture SNAL-Project (comme useSearchArticle.ts)
class LocationSearchService {
  static final LocationSearchService _instance = LocationSearchService._internal();
  factory LocationSearchService() => _instance;
  LocationSearchService._internal();

  // Timer pour le debounce (300ms comme dans SNAL-Project)
  Timer? _debounceTimer;

  /// Recherche de localisation avec debounce (300ms)
  /// Validation: minimum 3 caractères
  Future<List<Map<String, dynamic>>> searchLocations(
    String query, {
    int limit = 5,
    Duration debounceDelay = const Duration(milliseconds: 300),
  }) async {
    // Annuler le timer précédent
    _debounceTimer?.cancel();

    // Validation: minimum 3 caractères (comme SNAL-Project)
    final cleanQuery = query.trim();
    if (cleanQuery.length < 3) {
      return [];
    }

    // Debounce: attendre avant de lancer la recherche
    final completer = Completer<List<Map<String, dynamic>>>();
    
    _debounceTimer = Timer(debounceDelay, () async {
      try {
        final results = await _performLocationSearch(cleanQuery, limit: limit);
        if (!completer.isCompleted) {
          completer.complete(results);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });

    return completer.future;
  }

  /// Effectuer la recherche de localisation (appelée après le debounce)
  Future<List<Map<String, dynamic>>> _performLocationSearch(
    String query, {
    int limit = 5,
  }) async {
    try {
      print('🔍 LocationSearchService: Recherche de lieu: $query');
      final encodedQuery = Uri.encodeComponent(query);

      // Utiliser le proxy côté web pour éviter CORS, appel direct sur mobile
      final String url = kIsWeb
          ? '/api/nominatim/search?q=' + encodedQuery + '&limit=$limit'
          : 'https://nominatim.openstreetmap.org/search?q=' +
              encodedQuery +
              '&format=json&limit=$limit&addressdetails=1';

      final uri = Uri.parse(url);
      final headers = kIsWeb
          ? <String, String>{'Accept': 'application/json'}
          : <String, String>{'User-Agent': 'JIRIG-Flutter-App/1.0'};

      final httpResponse = await http.get(uri, headers: headers);

      print('📡 LocationSearchService: Status code: ${httpResponse.statusCode}');

      if (httpResponse.statusCode == 200) {
        final List<dynamic> data = json.decode(httpResponse.body);
        print('📊 LocationSearchService: ${data.length} résultats trouvés');

        // Formater les résultats (comme dans SNAL-Project)
        final results = data.map((item) {
          return {
            'display_name': item['display_name'] ?? '',
            'lat': double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0,
            'lon': double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0,
            'type': item['type'] ?? '',
            'address': item['address'] ?? {},
          };
        }).toList();

        // Filtrage côté client pour les recherches textuelles (comme SNAL-Project)
        return _filterLocationResults(results, query);
      } else {
        print('❌ LocationSearchService: Erreur HTTP: ${httpResponse.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ LocationSearchService: Erreur lors de la recherche: $e');
      return [];
    }
  }

  /// Filtrer les résultats de recherche (comme dans useSearchArticle.ts)
  List<Map<String, dynamic>> _filterLocationResults(
    List<Map<String, dynamic>> results,
    String query,
  ) {
    final cleanQuery = query.toLowerCase();

    // Pour les recherches textuelles, filtrer par display_name
    return results.where((item) {
      final displayName = (item['display_name'] ?? '').toString().toLowerCase();
      return displayName.contains(cleanQuery);
    }).toList();
  }

  /// Recherche immédiate (sans debounce)
  Future<List<Map<String, dynamic>>> searchLocationsImmediate(
    String query, {
    int limit = 5,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 3) {
      return [];
    }

    return await _performLocationSearch(cleanQuery, limit: limit);
  }

  /// Annuler la recherche en cours
  void cancelSearch() {
    _debounceTimer?.cancel();
  }

  /// Nettoyer les ressources
  void dispose() {
    _debounceTimer?.cancel();
  }
}

