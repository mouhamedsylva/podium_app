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
  
  /// Initialiser les traductions au démarrage de l'application
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
      
      print('🌍 TRANSLATION SERVICE: Initialisation avec langue $languageCode');
      await loadTranslations(languageCode);
      _isInitialized = true;
    } catch (e) {
      print('❌ TRANSLATION SERVICE: Erreur initialisation: $e');
      // Charger les traductions par défaut en cas d'erreur
      final defaultFr = _defaultTranslations['fr'];
      _translations = defaultFr != null ? Map<String, String>.from(defaultFr) : {};
      _isInitialized = true;
      notifyListeners();
    }
  }

  String get currentLanguage => _currentLanguage;
  Map<String, String> get translations => _translations;
  bool get isLoading => _isLoading;

  // Traductions par défaut basées sur l'API
  static const Map<String, Map<String, String>> _defaultTranslations = {
    'fr': {
      // Clés de l'API pour la page de sélection de pays
      'FRONTPAGE_Msg01': 'Accueil Wishlist Projet Newsletter Abonnement Connexion',
      'FRONTPAGE_Msg02': 'Comparez les prix IKEA dans plusieurs pays en un clic',
      'FRONTPAGE_Msg03': 'JIRIG vous aide à économiser sur vos achats IKEA à l\'international',
      // Clés pour le titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Trouvez vos articles ',
      'SELECT_COUNTRY_TITLE_PART2': ' moins chers avec ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Votre pays d\'origine',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Rechercher votre pays...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'J\'accepte les conditions d\'utilisation',
      'SELECT_COUNTRY_VIEW_TERMS': 'Voir les conditions',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Terminer',
      'SELECT_COUNTRY_FOOTER_TEXT': 'En cliquant sur Terminer, vous acceptez nos conditions d\'utilisation. ',
      'SELECT_COUNTRY_TERMS_LINK': 'Conditions d\'utilisation',
      // Clés pour la page d'accueil
      'FRONTPAGE_Msg77': 'Trouvez vos articles',
      'FRONTPAGE_Msg78': 'moins chers avec Jirig',
      'FRONTPAGE_Msg88': 'Abonnement Premium',
      'FRONTPAGE_Msg89': 'Accédez à toutes les fonctionnalités avancées de JIRIG',
      'FRONTPAGE_Msg90': 'S\'abonner maintenant',
      'COMPARE_Msg03': 'Comparaison par email',
      'COMPARE_TEXT_PART1': 'Envoyez-nous votre liste IKEA par email pour une comparaison personnalisée',
      'COMPARE_Msg05': 'Envoyer par email',
      // Clés pour les modules de la page d'accueil
      'HOME_MODULE_SEARCH': 'Rechercher',
      'HOME_MODULE_SCANNER': 'Scanner',
      // Clés pour le titre de la page d'accueil
      'HOME_TITLE_PART1': 'Comparez les prix ',
      'HOME_TITLE_PART2': ' dans plusieurs pays en un clic',
      // Clés pour les boutons
      'BUTTON_LOGIN': 'Connexion',
      // Bannière accueil
      'BANNER_FREE_100': '100% gratuite',
      'BANNER_FREE_DESC': 'Pas de formule, pas de contrainte : connectez-vous, explorez et profitez librement de tous nos services.',
      'BANNER_FREE_INTRO': 'Pour vous remercier de faire partie de notre lancement, nous avons décidé de rendre la plateforme',
    },
    'en': {
      // Clés de l'API pour la page de sélection de pays
      'FRONTPAGE_Msg01': 'Home Wishlist Project Newsletter Subscription Login',
      'FRONTPAGE_Msg02': 'Compare IKEA prices in multiple countries with one click',
      'FRONTPAGE_Msg03': 'JIRIG helps you save on your international IKEA purchases',
      // Clés pour le titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Find your articles ',
      'SELECT_COUNTRY_TITLE_PART2': ' cheaper with ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Your country of origin',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Search your country...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'I accept the terms of use',
      'SELECT_COUNTRY_VIEW_TERMS': 'View conditions',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Finish',
      'SELECT_COUNTRY_FOOTER_TEXT': 'By clicking Finish, you accept our terms of use. ',
      'SELECT_COUNTRY_TERMS_LINK': 'Terms of use',
      // Clés pour la page d'accueil
      'FRONTPAGE_Msg77': 'Find your articles',
      'FRONTPAGE_Msg78': 'cheaper with Jirig',
      'FRONTPAGE_Msg88': 'Premium Subscription',
      'FRONTPAGE_Msg89': 'Access all advanced JIRIG features',
      'FRONTPAGE_Msg90': 'Subscribe now',
      'COMPARE_Msg03': 'Email comparison',
      'COMPARE_TEXT_PART1': 'Send us your IKEA list by email for a personalized comparison',
      'COMPARE_Msg05': 'Send by email',
      // Clés pour les modules de la page d'accueil
      'HOME_MODULE_SEARCH': 'Search',
      'HOME_MODULE_SCANNER': 'Scanner',
      // Clés pour le titre de la page d'accueil
      'HOME_TITLE_PART1': 'Compare IKEA prices ',
      'HOME_TITLE_PART2': ' in multiple countries with one click',
      // Clés pour les boutons
      'BUTTON_LOGIN': 'Login',
      // Banner home
      'BANNER_FREE_100': '100% free',
      'BANNER_FREE_DESC': 'No plan, no constraint: sign in, explore, and enjoy all our services freely.',
      'BANNER_FREE_INTRO': 'As a thank you for being part of our launch, we have decided to make the platform',
    },
    'de': {
      // Clés de l'API pour la page de sélection de pays (basées sur vos données)
      'FRONTPAGE_Msg01': 'Startseite Wunschliste Projekt Newsletter Abonnement Anmeldung',
      'FRONTPAGE_Msg02': 'Vergleichen Sie IKEA-Preise in mehreren Ländern mit einem Klick',
      'FRONTPAGE_Msg03': 'JIRIG hilft Ihnen bei Ihren internationalen IKEA-Einkäufen zu sparen',
      // Clés pour le titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Finden Sie Ihre Artikel ',
      'SELECT_COUNTRY_TITLE_PART2': ' günstiger mit ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Ihr Herkunftsland',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Ihr Land suchen...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'Ich akzeptiere die Nutzungsbedingungen',
      'SELECT_COUNTRY_VIEW_TERMS': 'Bedingungen anzeigen',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Beenden',
      'SELECT_COUNTRY_FOOTER_TEXT': 'Durch Klicken auf Beenden akzeptieren Sie unsere Nutzungsbedingungen. ',
      'SELECT_COUNTRY_TERMS_LINK': 'Nutzungsbedingungen',
      // Clés pour la page d'accueil
      'FRONTPAGE_Msg77': 'Finden Sie Ihre Artikel',
      'FRONTPAGE_Msg78': 'günstiger mit Jirig',
      'FRONTPAGE_Msg88': 'Premium-Abonnement',
      'FRONTPAGE_Msg89': 'Zugang zu allen erweiterten JIRIG-Funktionen',
      'FRONTPAGE_Msg90': 'Jetzt abonnieren',
      'COMPARE_Msg03': 'E-Mail-Vergleich',
      'COMPARE_TEXT_PART1': 'Senden Sie uns Ihre IKEA-Liste per E-Mail für einen personalisierten Vergleich',
      'COMPARE_Msg05': 'Per E-Mail senden',
    },
    'es': {
      // Clés de l'API pour la page de sélection de pays
      'FRONTPAGE_Msg01': 'Inicio Lista de deseos Proyecto Newsletter Suscripción Iniciar sesión',
      'FRONTPAGE_Msg02': 'Compara los precios de IKEA en varios países con un clic',
      'FRONTPAGE_Msg03': 'JIRIG te ayuda a ahorrar en tus compras internacionales de IKEA',
      // Clés pour le titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Encuentra tus artículos ',
      'SELECT_COUNTRY_TITLE_PART2': ' más baratos con ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Tu país de origen',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Buscar tu país...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'Acepto los términos de uso',
      'SELECT_COUNTRY_VIEW_TERMS': 'Ver condiciones',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Terminar',
      'SELECT_COUNTRY_FOOTER_TEXT': 'Al hacer clic en Terminar, aceptas nuestros términos de uso. ',
      'SELECT_COUNTRY_TERMS_LINK': 'Términos de uso',
      // Clés pour la page d'accueil
      'FRONTPAGE_Msg77': 'Encuentra tus artículos',
      'FRONTPAGE_Msg78': 'más baratos con Jirig',
      'FRONTPAGE_Msg88': 'Suscripción Premium',
      'FRONTPAGE_Msg89': 'Accede a todas las funciones avanzadas de JIRIG',
      'FRONTPAGE_Msg90': 'Suscribirse ahora',
      'COMPARE_Msg03': 'Comparación por email',
      'COMPARE_TEXT_PART1': 'Envíanos tu lista de IKEA por email para una comparación personalizada',
      'COMPARE_Msg05': 'Enviar por email',
    },
    'it': {
      // Clés de l'API pour la page de sélection de pays
      'FRONTPAGE_Msg01': 'Home Lista desideri Progetto Newsletter Abbonamento Accedi',
      'FRONTPAGE_Msg02': 'Confronta i prezzi IKEA in diversi paesi con un clic',
      'FRONTPAGE_Msg03': 'JIRIG ti aiuta a risparmiare sui tuoi acquisti internazionali IKEA',
      // Clés pour le titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Trova i tuoi articoli ',
      'SELECT_COUNTRY_TITLE_PART2': ' più economici con ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Il tuo paese di origine',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Cerca il tuo paese...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'Accetto i termini di utilizzo',
      'SELECT_COUNTRY_VIEW_TERMS': 'Visualizza condizioni',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Termina',
      'SELECT_COUNTRY_FOOTER_TEXT': 'Cliccando su Termina, accetti i nostri termini di utilizzo. ',
      'SELECT_COUNTRY_TERMS_LINK': 'Termini di utilizzo',
      // Clés pour la page d'accueil
      'FRONTPAGE_Msg77': 'Trova i tuoi articoli',
      'FRONTPAGE_Msg78': 'più economici con Jirig',
      'FRONTPAGE_Msg88': 'Abbonamento Premium',
      'FRONTPAGE_Msg89': 'Accedi a tutte le funzionalità avanzate di JIRIG',
      'FRONTPAGE_Msg90': 'Abbonati ora',
      'COMPARE_Msg03': 'Confronto via email',
      'COMPARE_TEXT_PART1': 'Inviaci la tua lista IKEA via email per un confronto personalizzato',
      'COMPARE_Msg05': 'Invia via email',
    },
    'pt': {
      // Clés de l'API pour la page de sélection de pays
      'FRONTPAGE_Msg01': 'Início Lista de desejos Projeto Newsletter Assinatura Login',
      'FRONTPAGE_Msg02': 'Compare preços IKEA em vários países com um clique',
      'FRONTPAGE_Msg03': 'JIRIG te ajuda a economizar em suas compras internacionais IKEA',
      // Clés pour le titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Encontre seus artigos ',
      'SELECT_COUNTRY_TITLE_PART2': ' mais baratos com ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Seu país de origem',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Pesquisar seu país...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'Aceito os termos de uso',
      'SELECT_COUNTRY_VIEW_TERMS': 'Ver condições',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Finalizar',
      'SELECT_COUNTRY_FOOTER_TEXT': 'Ao clicar em Finalizar, você aceita nossos termos de uso. ',
      'SELECT_COUNTRY_TERMS_LINK': 'Termos de uso',
      // Clés pour la page d'accueil
      'FRONTPAGE_Msg77': 'Encontre seus artigos',
      'FRONTPAGE_Msg78': 'mais baratos com Jirig',
      'FRONTPAGE_Msg88': 'Assinatura Premium',
      'FRONTPAGE_Msg89': 'Acesse todos os recursos avançados do JIRIG',
      'FRONTPAGE_Msg90': 'Assinar agora',
      'COMPARE_Msg03': 'Comparação por email',
      'COMPARE_TEXT_PART1': 'Envie-nos sua lista IKEA por email para uma comparação personalizada',
      'COMPARE_Msg05': 'Enviar por email',
    },
    'nl': {
      // Clés de l'API pour la page de sélection de pays
      'FRONTPAGE_Msg01': 'Home Verlanglijst Project Nieuwsbrief Abonnement Inloggen',
      'FRONTPAGE_Msg02': 'Vergelijk IKEA-prijzen in meerdere landen met één klik',
      'FRONTPAGE_Msg03': 'JIRIG helpt je besparen op je internationale IKEA-aankopen',
      // Clés pour le titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Vind je artikelen ',
      'SELECT_COUNTRY_TITLE_PART2': ' goedkoper met ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Uw land van herkomst',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Zoek uw land...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'Ik accepteer de gebruiksvoorwaarden',
      'SELECT_COUNTRY_VIEW_TERMS': 'Bekijk voorwaarden',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Voltooien',
      'SELECT_COUNTRY_FOOTER_TEXT': 'Door op Voltooien te klikken, accepteert u onze gebruiksvoorwaarden. ',
      'SELECT_COUNTRY_TERMS_LINK': 'Gebruiksvoorwaarden',
      // Clés pour la page d'accueil
      'FRONTPAGE_Msg77': 'Vind je artikelen',
      'FRONTPAGE_Msg78': 'goedkoper met Jirig',
      'FRONTPAGE_Msg88': 'Premium Abonnement',
      'FRONTPAGE_Msg89': 'Toegang tot alle geavanceerde JIRIG-functies',
      'FRONTPAGE_Msg90': 'Nu abonneren',
      'COMPARE_Msg03': 'E-mail vergelijking',
      'COMPARE_TEXT_PART1': 'Stuur ons je IKEA-lijst per e-mail voor een gepersonaliseerde vergelijking',
      'COMPARE_Msg05': 'Verzenden per e-mail',
    },
  };

  /// Charger les traductions pour une langue
  Future<void> loadTranslations(String language) async {
    if (_currentLanguage == language && _translations.isNotEmpty) {
      return; // Déjà chargé
    }

    _isLoading = true;
    _currentLanguage = language;
    
    // Notifier immédiatement le changement de langue
    notifyListeners();
    print('🌍 TRANSLATION SERVICE: Changement de langue vers $language');
    
    // ✅ Sauvegarder la langue dans le profil si elle est différente
    await _saveLanguageToProfileIfDifferent(language);

    try {
      print('🌍 TRANSLATION SERVICE: Chargement des traductions pour $language');
      
      // Utiliser uniquement l'API
      final apiTranslations = await _apiService.getTranslations(language);
      
      if (apiTranslations.isNotEmpty) {
        // Convertir les traductions de l'API
        _translations = Map<String, String>.from(apiTranslations);
        
        // Notifier immédiatement après le chargement
        notifyListeners();
        print('✅ TRANSLATION SERVICE: Traductions chargées depuis l\'API');
      } else {
        throw Exception('Aucune traduction reçue de l\'API');
      }
    } catch (e) {
      print('❌ TRANSLATION SERVICE: Erreur API - aucune traduction disponible: $e');
      // Pas de fallback - laisser les traductions vides
      _translations = {};
      rethrow; // Relancer l'erreur pour que l'utilisateur soit informé
    }

    _isLoading = false;
    // Notifier une dernière fois pour indiquer que le chargement est terminé
    notifyListeners();
    print('✅ TRANSLATION SERVICE: Traductions chargées pour $language');
  }

  /// Obtenir une traduction
  String translate(String key) {
    // D'abord essayer les traductions de l'API
    if (_translations.containsKey(key)) {
      return _translations[key]!;
    }
    
    // Sinon, essayer les traductions par défaut
    final defaultTranslations = _defaultTranslations[_currentLanguage];
    if (defaultTranslations != null && defaultTranslations.containsKey(key)) {
      return defaultTranslations[key]!;
    }
    
    // En dernier recours, retourner la clé
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
