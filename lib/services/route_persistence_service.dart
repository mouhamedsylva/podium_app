import 'package:shared_preferences/shared_preferences.dart';

/// Service de persistance des routes cross-platform
/// Mobile-first : utilise SharedPreferences (qui fonctionne aussi sur web)
class RoutePersistenceService {
  static const String _currentRouteKey = 'current_route';
  static const String _routeHistoryKey = 'route_history';
  static const int _maxHistorySize = 10;

  /// ✅ Sauvegarder la route actuelle
  static Future<void> saveCurrentRoute(String route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Sauvegarder la route actuelle
      await prefs.setString(_currentRouteKey, route);
      
      // Ajouter à l'historique
      await _addToHistory(route);
      
      print('💾 Route sauvegardée: $route');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde de la route: $e');
    }
  }

  /// ✅ Récupérer la route actuelle
  static Future<String?> getCurrentRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final route = prefs.getString(_currentRouteKey);
      print('📖 Route récupérée: $route');
      return route;
    } catch (e) {
      print('❌ Erreur lors de la récupération de la route: $e');
      return null;
    }
  }

  /// ✅ Effacer la route actuelle
  static Future<void> clearCurrentRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentRouteKey);
      print('🗑️ Route effacée');
    } catch (e) {
      print('❌ Erreur lors de l\'effacement de la route: $e');
    }
  }

  /// ✅ Récupérer la route de démarrage (avec fallback intelligent)
  static Future<String> getStartupRoute() async {
    try {
      final currentRoute = await getCurrentRoute();

      if (currentRoute != null &&
          currentRoute.isNotEmpty &&
          currentRoute != '/' &&
          currentRoute != '/splash' &&
          isValidRoute(currentRoute)) {
        print('🚀 Route de démarrage depuis SharedPreferences: $currentRoute');
        return currentRoute;
      }

      print('🚀 Route de démarrage par défaut: /country-selection');
      return '/country-selection';
    } catch (e) {
      print('❌ Erreur lors de la récupération de la route de démarrage: $e');
      return '/country-selection';
    }
  }

  /// ✅ Ajouter une route à l'historique
  static Future<void> _addToHistory(String route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString(_routeHistoryKey) ?? '';
      
      // Parser l'historique (format: route1|route2|route3)
      final history = historyString.isEmpty ? <String>[] : historyString.split('|');
      
      // Enlever la route si elle existe déjà (éviter les doublons)
      history.remove(route);
      
      // Ajouter la route au début
      history.insert(0, route);
      
      // Limiter la taille de l'historique
      if (history.length > _maxHistorySize) {
        history.removeRange(_maxHistorySize, history.length);
      }
      
      // Sauvegarder l'historique
      await prefs.setString(_routeHistoryKey, history.join('|'));
      
      print('📚 Historique mis à jour: ${history.take(3).join(' → ')}...');
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de l\'historique: $e');
    }
  }

  /// ✅ Récupérer l'historique des routes
  static Future<List<String>> getRouteHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString(_routeHistoryKey) ?? '';
      
      if (historyString.isEmpty) {
        return [];
      }
      
      return historyString.split('|');
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'historique: $e');
      return [];
    }
  }

  /// ✅ Effacer tout l'historique
  static Future<void> clearRouteHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_routeHistoryKey);
      await prefs.remove(_currentRouteKey);
      print('🗑️ Historique des routes effacé');
    } catch (e) {
      print('❌ Erreur lors de l\'effacement de l\'historique: $e');
    }
  }

  /// ✅ Vérifier si une route est valide pour la restauration
  static bool isValidRoute(String route) {
    const validRoutes = [
      '/',
      '/country-selection',
      '/home',
      '/product-search',
      '/wishlist',
      '/profile',
      '/login',
    ];
    
    // Vérifier si c'est une route de podium (format: /podium/:code)
    if (route.startsWith('/podium/')) {
      return true;
    }
    
    // Vérifier si c'est une route valide
    return validRoutes.contains(route);
  }
}
