import 'dart:async';
import 'api_service.dart';

/// Service de recherche avec debounce pour l'auto-complétion
/// Conforme à l'implémentation SNAL-Project
class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  // Utiliser le singleton ApiService (déjà initialisé dans app.dart)
  ApiService get _apiService => ApiService();
  
  // Stockage du profil utilisateur pour mobile-first
  String? _userProfile;
  String? _userBasket;
  
  // Timer pour le debounce
  Timer? _debounceTimer;
  
  // Contrôleur pour les streams de recherche
  final StreamController<List<dynamic>> _searchController = StreamController<List<dynamic>>.broadcast();
  
  /// Stream pour écouter les résultats de recherche
  Stream<List<dynamic>> get searchResults => _searchController.stream;
  
  /// Définir le profil utilisateur (mobile-first)
  void setUserProfile(String? iProfile, String? iBasket) {
    _userProfile = iProfile;
    _userBasket = iBasket;
    print('🔧 SearchService: Profil défini - iProfile: $_userProfile, iBasket: $_userBasket');
  }
  
  /// Recherche avec debounce (300ms comme dans SNAL-Project)
  void searchWithDebounce(String query, {String? token, int limit = 10}) {
    // Annuler le timer précédent
    _debounceTimer?.cancel();
    
    // Si la requête est vide, retourner une liste vide immédiatement
    if (query.isEmpty) {
      if (!_searchController.isClosed) {
        _searchController.add([]);
      }
      return;
    }
    
    // Délai de 300ms comme dans SNAL-Project
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        // Utiliser le token fourni ou le profil utilisateur stocké (mobile-first)
        final validToken = token ?? _userProfile ?? '';
        
        final results = await _apiService.searchArticle(query, token: validToken, limit: limit);
        
        if (!_searchController.isClosed) {
          _searchController.add(results);
        }
      } on SearchArticleException catch (e) {
        // ✅ Gérer les erreurs spécifiques du backend
        print('⚠️ Erreur backend dans searchWithDebounce:');
        print('   errorCode: ${e.errorCode}');
        print('   message: ${e.message}');
        // Retourner une liste vide en cas d'erreur backend
        if (!_searchController.isClosed) {
          _searchController.add([]);
        }
      } catch (e) {
        print('❌ Erreur générique dans searchWithDebounce: $e');
        if (!_searchController.isClosed) {
          _searchController.add([]);
        }
      }
    });
  }
  
  /// Recherche immédiate (sans debounce)
  Future<List<dynamic>> searchImmediate(String query, {String? token, int limit = 10}) async {
    try {
      // Utiliser le token fourni ou le profil utilisateur stocké (mobile-first)
      final validToken = token ?? _userProfile ?? '';
      
      return await _apiService.searchArticle(query, token: validToken, limit: limit);
    } on SearchArticleException catch (e) {
      // ✅ Gérer les erreurs spécifiques du backend
      print('⚠️ Erreur backend dans searchImmediate:');
      print('   errorCode: ${e.errorCode}');
      print('   message: ${e.message}');
      return [];
    } catch (e) {
      print('❌ Erreur générique dans searchImmediate: $e');
      return [];
    }
  }
  
  /// Annuler la recherche en cours
  void cancelSearch() {
    _debounceTimer?.cancel();
  }
  
  /// Nettoyer les ressources
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.close();
  }
}
