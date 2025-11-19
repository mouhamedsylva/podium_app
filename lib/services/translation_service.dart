import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'local_storage_service.dart';

class TranslationService extends ChangeNotifier {
  final ApiService _apiService;
  
  String _currentLanguage = 'fr';
  Map<String, String> _translations = {};
  bool _isLoading = false;
  bool _isInitialized = false;

  TranslationService(this._apiService) {
    // ✅ Initialiser automatiquement les traductions au démarrage
    _initializeTranslations();
  }
  
  /// Initialiser les traductions au démarrage de l'application depuis le backend
  Future<void> _initializeTranslations() async {
    if (_isInitialized) return;
    
    try {
      // Récupérer la langue depuis le localStorage ou utiliser 'fr' par défaut
      final profile = await LocalStorageService.getProfile();
      String languageCode = 'fr';
      
      if (profile != null && profile['sPaysLangue'] != null) {
        final sPaysLangue = profile['sPaysLangue']!;
        languageCode = extractLanguageCode(sPaysLangue);
      }
      
      print('🌍 TRANSLATION SERVICE: Initialisation avec langue $languageCode depuis le backend SNAL');
      await loadTranslations(languageCode);
      _isInitialized = true;
    } catch (e) {
      print('❌ TRANSLATION SERVICE: Erreur initialisation: $e');
      // En cas d'erreur, initialiser avec un dictionnaire vide
      _translations = {};
      _isInitialized = true;
      notifyListeners();
    }
  }

  String get currentLanguage => _currentLanguage;
  Map<String, String> get translations => _translations;
  bool get isLoading => _isLoading;

  /// Charger les traductions pour une langue depuis le backend SNAL
  Future<void> loadTranslations(String language) async {
    if (_currentLanguage == language && _translations.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _currentLanguage = language;

    await _saveLanguageToProfileIfDifferent(language);

    try {
      // ✅ Charger les traductions directement depuis le backend SNAL
      final apiTranslations = await _apiService.getTranslations(language);

      if (apiTranslations.isNotEmpty) {
        // ✅ Utiliser uniquement les traductions du backend
        // Convertir les valeurs en String pour garantir le bon type
        _translations = Map<String, String>.from(
          apiTranslations.map((key, value) => MapEntry(
            key.toString(),
            value?.toString() ?? '',
          )),
        );

        print('✅ TRANSLATION SERVICE: Traductions chargées depuis le backend SNAL (${_translations.length} clés)');
      } else {
        // Si le backend retourne un objet vide, initialiser avec un dictionnaire vide
        print('⚠️ TRANSLATION SERVICE: Backend retourne un objet vide');
        _translations = {};
        print('✅ TRANSLATION SERVICE: Traductions initialisées à vide');
      }
    } catch (e) {
      print('❌ TRANSLATION SERVICE: Erreur API: $e');
      // En cas d'erreur, initialiser avec un dictionnaire vide
      _translations = {};
      print('✅ TRANSLATION SERVICE: Traductions initialisées à vide en cas d\'erreur');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Traductions locales de fallback (pour certaines clés spécifiques)
  /// Format: { 'clé': { 'langue': 'traduction' } }
  static const Map<String, Map<String, String>> _localFallbacks = {
    'SELECT_COUNTRY_SEARCH_PLACEHOLDER': {
      'fr': 'Rechercher votre pays...',
      'en': 'Search your country...',
      'de': 'Ihr Land suchen...',
      'es': 'Buscar tu país...',
      'it': 'Cerca il tuo paese...',
      'pt': 'Pesquisar seu país...',
      'nl': 'Zoek uw land...',
    },
    'ONBOARDING_Msg07': {
      'fr': 'Valider',
      'en': 'Validate',
      'de': 'Bestätigen',
      'es': 'Validar',
      'it': 'Convalidare',
      'pt': 'Validar',
      'nl': 'Valideren',
    },
    'FRONTPAGE_Msg05': {
      'fr': 'Trouvez Votre Produit',
      'en': 'Find Your Product',
      'de': 'Finden Sie Ihr Produkt',
      'es': 'Encuentra Tu Producto',
      'it': 'Trova Il Tuo Prodotto',
      'pt': 'Encontre Seu Produto',
      'nl': 'Vind Uw Product',
    },
    'CONFIRM_TITLE': {
      'fr': 'Confirmation',
      'en': 'Confirmation',
      'de': 'Bestätigung',
      'es': 'Confirmación',
      'it': 'Conferma',
      'pt': 'Confirmação',
      'nl': 'Bevestiging',
    },
    'BUTTON_YES': {
      'fr': 'Oui',
      'en': 'Yes',
      'de': 'Ja',
      'es': 'Sí',
      'it': 'Sì',
      'pt': 'Sim',
      'nl': 'Ja',
    },
    'BUTTON_NO': {
      'fr': 'Non',
      'en': 'No',
      'de': 'Nein',
      'es': 'No',
      'it': 'No',
      'pt': 'Não',
      'nl': 'Nee',
    },
    'LOGIN_EMAIL_PLACEHOLDER': {
      'fr': 'votre@email.com',
      'en': 'your@email.com',
      'de': 'ihre@email.com',
      'es': 'tu@email.com',
      'it': 'tua@email.com',
      'pt': 'seu@email.com',
      'nl': 'uw@email.com',
    },
    // ===== Fallbacks locaux pour l'écran de connexion =====
    'LOGIN_SEND_LINK': {
      'fr': 'Envoyer le code',
      'en': 'Send code',
      'de': 'Code senden',
      'es': 'Enviar código',
      'it': 'Invia codice',
      'pt': 'Enviar código',
      'nl': 'Code verzenden',
    },
    'LOGIN_LOADING_SENDING_CODE': {
      'fr': 'Envoi du lien...',
      'en': 'Sending link...',
      'de': 'Link wird gesendet...',
      'es': 'Enviando enlace...',
      'it': 'Invio del link...',
      'pt': 'Enviando link...',
      'nl': 'Link verzenden...',
    },
    'LOGIN_LOADING_CONNECTING': {
      'fr': 'Connexion...',
      'en': 'Connecting...',
      'de': 'Verbindung...',
      'es': 'Conectando...',
      'it': 'Connessione...',
      'pt': 'Conectando...',
      'nl': 'Verbinden...',
    },
    'LOGIN_CODE_LABEL': {
      'fr': 'Code de connexion',
      'en': 'Login code',
      'de': 'Anmeldecode',
      'es': 'Código de acceso',
      'it': 'Codice di accesso',
      'pt': 'Código de acesso',
      'nl': 'Inlogcode',
    },
    'LOGIN_ACTION_VALIDATE_CODE': {
      'fr': 'Valider le code',
      'en': 'Validate code',
      'de': 'Code bestätigen',
      'es': 'Validar código',
      'it': 'Convalidare il codice',
      'pt': 'Validar código',
      'nl': 'Code valideren',
    },
    'LOGIN_CODE_SENT_PLACEHOLDER': {
      'fr': 'Votre code de connexion',
      'en': 'Your login code',
      'de': 'Ihr Anmeldecode',
      'es': 'Tu código de acceso',
      'it': 'Il tuo codice di accesso',
      'pt': 'Seu código de acesso',
      'nl': 'Uw inlogcode',
    },
    'LOGIN_CODE_SENT_FOOTER': {
      'fr': 'Si vous ne voyez pas l’e‑mail, vérifiez vos spams.',
      'en': 'If you don’t see the email, check your spam folder.',
      'de': 'Wenn Sie die E‑Mail nicht sehen, prüfen Sie den Spam‑Ordner.',
      'es': 'Si no ves el correo, revisa tu carpeta de spam.',
      'it': 'Se non vedi l’email, controlla la posta indesiderata.',
      'pt': 'Se não vir o e‑mail, verifique a pasta de spam.',
      'nl': 'Als u de e‑mail niet ziet, kijk in uw spammap.',
    },
    'LOGIN_OPEN_MAIL': {
      'fr': 'Ouvrir ma messagerie',
      'en': 'Open my mailbox',
      'de': 'Postfach öffnen',
      'es': 'Abrir mi correo',
      'it': 'Apri la mia posta',
      'pt': 'Abrir minha caixa de e‑mail',
      'nl': 'Mijn mailbox openen',
    },
    'LOGIN_CODE_COPIED_BUTTON': {
      'fr': 'J’ai copié le code',
      'en': 'I’ve copied the code',
      'de': 'Ich habe den Code kopiert',
      'es': 'He copiado el código',
      'it': 'Ho copiato il codice',
      'pt': 'Copiei o código',
      'nl': 'Ik heb de code gekopieerd',
    },
    'LOGIN_SUCCESS_TITLE': {
      'fr': 'Connexion réussie',
      'en': 'Login successful',
      'de': 'Erfolgreich angemeldet',
      'es': 'Inicio de sesión correcto',
      'it': 'Accesso riuscito',
      'pt': 'Sessão iniciada com sucesso',
      'nl': 'Succesvol ingelogd',
    },
    'LOGIN_SUCCESS_MESSAGE': {
      'fr': 'Vous êtes connecté. Redirection en cours...',
      'en': 'You are logged in. Redirecting...',
      'de': 'Sie sind angemeldet. Weiterleitung...',
      'es': 'Has iniciado sesión. Redirigiendo...',
      'it': 'Sei connesso. Reindirizzamento...',
      'pt': 'Você está conectado. Redirecionando...',
      'nl': 'U bent ingelogd. Doorsturen...',
    },
    'PODIUM_ENLARGE': {
      'fr': 'Agrandir',
      'en': 'Enlarge',
      'de': 'Vergrößern',
      'es': 'Ampliar',
      'it': 'Ingrandisci',
      'pt': 'Ampliar',
      'nl': 'Vergroten',
    },

    // ===== Fallbacks locaux pour les écrans de profil =====
    'PROFILE_LOGOUT': {
      'fr': 'Déconnexion',
      'en': 'Logout',
      'de': 'Abmelden',
      'es': 'Cerrar sesión',
      'it': 'Disconnetti',
      'pt': 'Sair',
      'nl': 'Uitloggen',
    },
    'PROFILE_LOGOUT_CONFIRM': {
      'fr': 'Êtes-vous sûr de vouloir vous déconnecter ?',
      'en': 'Are you sure you want to logout?',
      'de': 'Sind Sie sicher, dass Sie sich abmelden möchten?',
      'es': '¿Estás seguro de que quieres cerrar sesión?',
      'it': 'Sei sicuro di voler disconnetter?',
      'pt': 'Tem certeza de que deseja sair?',
      'nl': 'Weet u zeker dat u wilt uitloggen?',
    },
  };

  /// Obtenir une traduction depuis le backend
  /// Pour les clés dans _localFallbacks, le fallback local a la priorité absolue
  /// Sinon, utilise le backend, puis retourne la clé elle-même
  String translate(String key) {
    // ✅ Priorité 1: Fallback local pour certaines clés spécifiques (priorité absolue)
    // Ces clés sont toujours gérées localement, même si le backend les fournit
    if (_localFallbacks.containsKey(key)) {
      final languageFallbacks = _localFallbacks[key]!;
      // Utiliser la langue courante, ou 'fr' par défaut
      final fallback = languageFallbacks[_currentLanguage] ?? languageFallbacks['fr'];
      if (fallback != null) {
        return fallback;
      }
    }

    // ✅ Priorité 2: Traductions du backend (pour les autres clés)
    if (_translations.containsKey(key)) {
      final value = _translations[key];
      if (value != null) {
        final normalizedValue = value.trim();
        if (normalizedValue.isNotEmpty &&
            normalizedValue.toLowerCase() != key.toLowerCase()) {
          return normalizedValue;
        }
      }
    }

    // ✅ Priorité 3: Si la clé n'existe pas, retourner la clé elle-même
    return key;
  }

  /// Obtenir une traduction en privilégiant toujours le backend
  /// Cette méthode ignore les fallbacks locaux et utilise uniquement le backend
  /// Utile pour les écrans qui doivent toujours utiliser les traductions du backend
  String translateFromBackend(String key) {
    // ✅ Priorité 1: Traductions du backend (priorité absolue)
    if (_translations.containsKey(key)) {
      final value = _translations[key];
      if (value != null) {
        final normalizedValue = value.trim();
        if (normalizedValue.isNotEmpty &&
            normalizedValue.toLowerCase() != key.toLowerCase()) {
          return normalizedValue;
        }
      }
    }

    // ✅ Priorité 2: Fallback local uniquement si le backend ne fournit pas la clé
    if (_localFallbacks.containsKey(key)) {
      final languageFallbacks = _localFallbacks[key]!;
      final fallback = languageFallbacks[_currentLanguage] ?? languageFallbacks['fr'];
      if (fallback != null) {
        return fallback;
      }
    }

    // ✅ Priorité 3: Si la clé n'existe pas, retourner la clé elle-même
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
    await loadTranslations(languageCode);
    
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
