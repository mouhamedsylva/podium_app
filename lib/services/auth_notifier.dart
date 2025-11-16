import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';
import 'api_service.dart';

/// Service pour notifier les changements d'état d'authentification
class AuthNotifier extends ChangeNotifier {
  bool _isLoggedIn = false;
  Map<String, String>? _userInfo;

  bool get isLoggedIn => _isLoggedIn;
  Map<String, String>? get userInfo => _userInfo;

  /// Initialiser l'état d'authentification
  Future<void> initialize() async {
    print('🔐 AuthNotifier: Initialisation...');
    
    // D'abord vérifier le localStorage
    _isLoggedIn = await LocalStorageService.isLoggedIn();
    _userInfo = await LocalStorageService.getUserInfo();
    
    // Si on a un email dans localStorage, vérifier la session avec l'API
    if (_isLoggedIn) {
      print('🔐 Session trouvée dans localStorage, vérification avec l\'API...');
      await _syncWithApi();
    } else {
      // ✅ CORRECTION: Même si user_email n'existe pas dans localStorage,
      // vérifier l'API au cas où les cookies seraient valides
      print('🔐 Aucune session dans localStorage, vérification de l\'API...');
      await _syncWithApi();
    }
    
    notifyListeners();
  }

  /// Synchroniser avec l'API pour récupérer le profil utilisateur
  Future<void> _syncWithApi() async {
    try {
      print('🔄 AuthNotifier._syncWithApi() - Début synchronisation');
      final apiService = ApiService();
      final profile = await apiService.getProfile();
      
      print('📦 Profil reçu de l\'API: ${profile.keys.join(', ')}');
      print('📧 Email dans le profil: ${profile['sEmail']}');
      print('👤 Nom dans le profil: ${profile['sNom']}');
      print('👤 Prénom dans le profil: ${profile['sPrenom']}');
      
      // ✅ CORRECTION: Vérifier si le profil contient un email (utilisateur connecté)
      // Un profil vide ou sans email signifie utilisateur guest
      final hasEmail = profile['sEmail'] != null && profile['sEmail'].toString().isNotEmpty;
      
      if (profile.isNotEmpty && hasEmail) {
        print('✅ Session valide, utilisateur connecté - mise à jour du profil depuis l\'API');
        
        // Sauvegarder le profil complet dans SharedPreferences
        await LocalStorageService.saveProfile({
          'iProfile': profile['iProfile']?.toString() ?? '',
          'iBasket': profile['iBasket']?.toString() ?? '',
          'sPaysFav': profile['sPaysFav']?.toString() ?? '',
          'sPaysLangue': profile['sPaysLangue']?.toString() ?? '',
          'sEmail': profile['sEmail']?.toString() ?? '',
          'sNom': profile['sNom']?.toString() ?? '',
          'sPrenom': profile['sPrenom']?.toString() ?? '',
          'sPhoto': profile['sPhoto']?.toString() ?? '',
        });
        
        print('💾 Profil sauvegardé dans SharedPreferences');
        
        // Mettre à jour l'état local
        _isLoggedIn = true;
        _userInfo = await LocalStorageService.getUserInfo();
        print('👤 UserInfo après sync: $_userInfo');
      } else if (profile.isNotEmpty && !hasEmail) {
        // Profil existe mais pas d'email = utilisateur guest
        print('ℹ️ Profil guest détecté - pas d\'email dans le profil');
        _isLoggedIn = false;
        _userInfo = null;
      } else {
        print('⚠️ Session expirée ou invalide, déconnexion');
        _isLoggedIn = false;
        _userInfo = null;
      }
    } catch (e) {
      print('❌ Erreur lors de la synchronisation avec l\'API: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      // En cas d'erreur réseau, garder la session locale si elle existe
      if (!_isLoggedIn) {
        _isLoggedIn = false;
        _userInfo = null;
      }
    }
  }

  /// Mettre à jour l'état après connexion
  Future<void> onLogin() async {
    print('🔐 AuthNotifier: onLogin appelé');
    await _syncWithApi();
    notifyListeners();
  }

  /// Mettre à jour l'état après déconnexion (nettoyage local uniquement, sans endpoint backend)
  Future<void> onLogout() async {
    print('🔐 AuthNotifier: onLogout appelé');
    
    try {
      // Nettoyer le profil local (supprime email et infos utilisateur)
      await LocalStorageService.clearProfile();
      
      // Mettre à jour l'état local
      _isLoggedIn = false;
      _userInfo = null;
      
      print('✅ Déconnexion réussie - Profil local nettoyé');
    } catch (e) {
      print('❌ Erreur lors de la déconnexion: $e');
      // En cas d'erreur, forcer quand même la déconnexion
      _isLoggedIn = false;
      _userInfo = null;
    }
    
    notifyListeners();
  }

  /// Recharger les informations utilisateur
  Future<void> refresh() async {
    print('🔐 AuthNotifier: refresh appelé');
    
    // Vérifier d'abord le localStorage
    _isLoggedIn = await LocalStorageService.isLoggedIn();
    
    if (_isLoggedIn) {
      // Synchroniser avec l'API pour obtenir les dernières infos
      await _syncWithApi();
    } else {
      _userInfo = null;
    }
    
    notifyListeners();
  }
}

