import 'dart:async';

import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'local_storage_service.dart';

class TranslationService extends ChangeNotifier {
  final ApiService _apiService;

  // ✅ Completer pour signaler la fin de l'initialisation
  final Completer<void> _initializationCompleter = Completer<void>();
  
  String _currentLanguage = 'fr';
  Map<String, String> _translations = {};
  bool _isLoading = false;
  bool _isInitialized = false;

  // ✅ Future pour que l'UI puisse attendre la fin de l'initialisation
  Future<void> get initializationComplete => _initializationCompleter.future;

  TranslationService(this._apiService) {
    // ✅ Initialiser automatiquement les traductions au démarrage
    _initializeTranslations();
  }
  
  /// Initialiser les traductions au démarrage de l'application depuis le backend
  Future<void> _initializeTranslations() async {
    if (_isInitialized) {
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
      return;
    }
    
    try {
      // Récupérer la langue depuis le localStorage ou utiliser 'fr' par défaut
      final profile = await LocalStorageService.getProfile();
      String languageCode = 'fr';
      
      if (profile != null && profile['sPaysLangue'] != null) {
        final sPaysLangue = profile['sPaysLangue']!;
        languageCode = extractLanguageCode(sPaysLangue);
      }
      
      print('🌍 TRANSLATION SERVICE: Initialisation avec langue $languageCode depuis le backend SNAL');
      await loadTranslations(languageCode, forceReload: true);
      _isInitialized = true;
      
      // ✅ Vérifier que les traductions ont bien été chargées
      if (_translations.isEmpty) {
        print('⚠️ TRANSLATION SERVICE: Aucune traduction chargée après initialisation, nouvelle tentative...');
        // Nouvelle tentative après un court délai
        await Future.delayed(Duration(milliseconds: 1000));
        await loadTranslations(languageCode, forceReload: true);
      }
    } catch (e) {
      print('❌ TRANSLATION SERVICE: Erreur initialisation: $e');
      // En cas d'erreur, initialiser avec un dictionnaire vide
      _translations = {};
      _isInitialized = true;
      notifyListeners();
    } finally {
      // ✅ Signaler que l'initialisation est terminée, quoi qu'il arrive
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
    }
  }

  String get currentLanguage => _currentLanguage;
  Map<String, String> get translations => _translations;
  bool get isLoading => _isLoading;

  /// Charger les traductions pour une langue depuis le backend SNAL
  /// Avec retry automatique en cas d'échec
  Future<void> loadTranslations(String language, {bool forceReload = false}) async {
    // ✅ Forcer le rechargement si les traductions sont vides, même si la langue correspond
    if (!forceReload && _currentLanguage == language && _translations.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _currentLanguage = language;

    await _saveLanguageToProfileIfDifferent(language);

    // ✅ Tentative de chargement avec retry (max 2 tentatives)
    int maxRetries = 2;
    int attempt = 0;
    bool success = false;

    while (attempt < maxRetries && !success) {
      try {
        attempt++;
        if (attempt > 1) {
          print('🔄 TRANSLATION SERVICE: Tentative $attempt/$maxRetries...');
          // Attendre un peu avant de réessayer
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }

        // ✅ Charger les traductions directement depuis le backend SNAL
        final apiTranslations = await _apiService.getTranslations(language);

        if (apiTranslations.isNotEmpty) {
          // ✅ Utiliser uniquement les traductions du backend
          // Convertir les valeurs en String pour garantir le bon type
          _translations = Map<String, String>.from(
            apiTranslations.map((key, value) {
              final strValue = value?.toString() ?? '';
              // Filtrer les valeurs vides ou identiques à la clé
              if (strValue.trim().isEmpty || 
                  strValue.trim().toLowerCase() == key.toString().toLowerCase()) {
                return MapEntry(key.toString(), '');
              }
              return MapEntry(key.toString(), strValue);
            }),
          );

          print('✅ TRANSLATION SERVICE: Traductions chargées depuis le backend SNAL (${_translations.length} clés)');
          success = true;
        } else {
          print('⚠️ TRANSLATION SERVICE: Backend retourne un objet vide (tentative $attempt/$maxRetries)');
          if (attempt >= maxRetries) {
            _translations = {};
            print('⚠️ TRANSLATION SERVICE: Traductions initialisées à vide après $maxRetries tentatives');
          }
        }
      } catch (e) {
        print('❌ TRANSLATION SERVICE: Erreur API (tentative $attempt/$maxRetries): $e');
        if (attempt >= maxRetries) {
          // En cas d'erreur finale, conserver les traductions existantes si disponibles
          // ou initialiser avec un dictionnaire vide
          if (_translations.isEmpty) {
            _translations = {};
            print('⚠️ TRANSLATION SERVICE: Traductions initialisées à vide après échec');
          } else {
            print('⚠️ TRANSLATION SERVICE: Conservation des traductions existantes après échec');
          }
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Obtenir une traduction depuis le backend uniquement
  /// Retourne la traduction du backend ou la clé elle-même si non trouvée
  String translate(String key) {
    // ✅ Utiliser uniquement les traductions du backend
    if (_translations.containsKey(key)) {
      final value = _translations[key];
      if (value != null && value.isNotEmpty) {
        final normalizedValue = value.trim();
        // ✅ Vérifier que la valeur n'est pas vide et n'est pas identique à la clé
        if (normalizedValue.isNotEmpty &&
            normalizedValue.toLowerCase() != key.toLowerCase()) {
          return normalizedValue;
        }
      }
    }

    // ✅ Si les traductions sont vides, essayer de recharger
    if (_translations.isEmpty && !_isLoading && _isInitialized) {
      print('⚠️ TRANSLATION SERVICE: Traductions vides pour "$key", tentative de rechargement...');
      // Recharger en arrière-plan sans bloquer
      loadTranslations(_currentLanguage, forceReload: true);
    }

    // ✅ Si la clé n'existe pas, retourner la clé elle-même
    return key;
  }

  /// Obtenir une traduction depuis le backend uniquement
  /// Identique à translate() - conservé pour compatibilité
  String translateFromBackend(String key) {
    // ✅ Utiliser uniquement les traductions du backend
    if (_translations.containsKey(key)) {
      final value = _translations[key];
      if (value != null && value.isNotEmpty) {
        final normalizedValue = value.trim();
        // ✅ Vérifier que la valeur n'est pas vide et n'est pas identique à la clé
        if (normalizedValue.isNotEmpty &&
            normalizedValue.toLowerCase() != key.toLowerCase()) {
          return normalizedValue;
        }
      }
    }

    // ✅ Si les traductions sont vides, essayer de recharger
    if (_translations.isEmpty && !_isLoading && _isInitialized) {
      print('⚠️ TRANSLATION SERVICE: Traductions vides pour "$key", tentative de rechargement...');
      // Recharger en arrière-plan sans bloquer
      loadTranslations(_currentLanguage, forceReload: true);
    }

    // ✅ Retourner la clé elle-même si non trouvée
    return key;
  }

  /// Extraire le code langue depuis sPaysLangue (ex: "FR/FR" -> "fr")
  static String extractLanguageCode(String sPaysLangue) {
    try {
      final parts = sPaysLangue.split('/');
      if (parts.length >= 2) {
        return parts[1].toLowerCase();
      }
    } catch (e) {
      print('Erreur extraction code langue: $e');
    }
    return 'fr'; // Fallback
  }

  /// Changer la langue et recharger les traductions
  Future<void> changeLanguage(String sPaysLangue) async {
    final languageCode = extractLanguageCode(sPaysLangue);
    // ✅ Forcer le rechargement lors du changement de langue
    await loadTranslations(languageCode, forceReload: true);
    
    // ✅ Sauvegarder la langue dans le profil
    await _saveLanguageToProfile(sPaysLangue);
  }
  
  /// Sauvegarder la langue dans le profil utilisateur
  Future<void> _saveLanguageToProfile(String sPaysLangue) async {
    try {
      // Récupérer le profil actuel
      final currentProfile = await LocalStorageService.getProfile();
      
      if (currentProfile != null) {
        // Mettre à jour sPaysLangue
        final updatedProfile = Map<String, dynamic>.from(currentProfile);
        updatedProfile['sPaysLangue'] = sPaysLangue;
        
        // Sauvegarder le profil mis à jour
        await LocalStorageService.saveProfile(updatedProfile);
        print('🌍 TRANSLATION SERVICE: Langue sauvegardée: $sPaysLangue');
      } else {
        print('⚠️ TRANSLATION SERVICE: Aucun profil trouvé pour sauvegarder la langue');
      }
    } catch (e) {
      print('❌ TRANSLATION SERVICE: Erreur sauvegarde langue: $e');
    }
  }
  
  /// Sauvegarder la langue dans le profil si elle est différente de celle actuellement sauvegardée
  Future<void> _saveLanguageToProfileIfDifferent(String languageCode) async {
    try {
      // Récupérer le profil actuel
      final currentProfile = await LocalStorageService.getProfile();
      
      if (currentProfile != null) {
        final currentLanguage = currentProfile['sPaysLangue'];
        final newLanguage = '${languageCode.toUpperCase()}/${languageCode.toUpperCase()}';
        
        // Vérifier si la langue a changé
        if (currentLanguage != newLanguage) {
          // Mettre à jour sPaysLangue
          final updatedProfile = Map<String, dynamic>.from(currentProfile);
          updatedProfile['sPaysLangue'] = newLanguage;
          
          // Sauvegarder le profil mis à jour
          await LocalStorageService.saveProfile(updatedProfile);
          print('🌍 TRANSLATION SERVICE: Langue mise à jour: $currentLanguage → $newLanguage');
        } else {
          print('🌍 TRANSLATION SERVICE: Langue déjà à jour: $newLanguage');
        }
      } else {
        print('⚠️ TRANSLATION SERVICE: Aucun profil trouvé pour sauvegarder la langue');
      }
    } catch (e) {
      print('❌ TRANSLATION SERVICE: Erreur sauvegarde langue: $e');
    }
  }
}
