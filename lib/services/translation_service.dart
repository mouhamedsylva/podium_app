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
      'PODIUM_ENLARGE': 'Agrandir',
      'LOGIN_WELCOME_TITLE': 'Bienvenue sur Jirig',
      'LOGIN_WELCOME_SUBTITLE':
          'Connectez-vous et explorez toutes les fonctionnalités de notre plateforme',
      'LOGIN_TITLE': 'Connexion',
      'LOGIN_SUBTITLE': 'Accédez à votre compte',
      'LOGIN_EMAIL_LABEL': 'Adresse email',
      'LOGIN_EMAIL_PLACEHOLDER': 'votre@email.com',
      'LOGIN_CODE_LABEL': 'Code de vérification',
      'LOGIN_CODE_PLACEHOLDER': 'Entrez le code reçu par e-mail',
      'LOGIN_ACTION_SEND_CODE': 'Envoi du code',
      'LOGIN_ACTION_VALIDATE_CODE': 'Valider le code',
      'LOGIN_LOADING_SENDING_CODE': 'Envoi du code...',
      'LOGIN_LOADING_CONNECTING': 'Connexion...',
      'LOGIN_SEPARATOR_TEXT': 'Ou continuer avec',
      'LOGIN_CONTINUE_WITH_GOOGLE': 'Continuer avec Google',
      'LOGIN_CONTINUE_WITH_FACEBOOK': 'Continuer avec Facebook',
      'LOGIN_TERMS_PREFIX': 'En vous connectant, vous acceptez nos',
      'LOGIN_TERMS_LINK': 'Conditions d\'utilisation',
      'LOGIN_AND_OUR': 'et notre',
      'LOGIN_PRIVACY_LINK': 'Politique de confidentialité',
      'LOGIN_CODE_SENT_TITLE': 'Code envoyé',
      'LOGIN_CODE_SENT_MESSAGE':
          'Copiez ce code ou ouvrez votre boîte mail pour le récupérer.',
      'LOGIN_CODE_SENT_PLACEHOLDER': 'Code envoyé par email',
      'LOGIN_CODE_SENT_TOOLTIP': 'Copier',
      'LOGIN_CODE_SENT_FOOTER':
          'Vous pouvez aussi ouvrir votre messagerie pour retrouver ce message.',
      'LOGIN_OPEN_MAIL': 'Ouvrir ma boîte mail',
      'LOGIN_CODE_COPIED_BUTTON': 'J\'ai copié le code',
      'LOGIN_RESEND_CODE': 'Renvoyer un code',
      'LOGIN_SNACKBAR_COPIED': 'Code copié dans le presse-papiers',
      'LOGIN_ERROR_EMPTY_EMAIL': 'Veuillez entrer votre adresse email',
      'LOGIN_ERROR_INVALID_EMAIL': 'Adresse email invalide',
      'LOGIN_ERROR_EMPTY_CODE': 'Veuillez entrer le code reçu par email',
      'LOGIN_ERROR_GENERIC': 'Erreur lors de la connexion. Veuillez réessayer.',
      'LOGIN_ERROR_INVALID_CODE':
          'Code invalide. Veuillez vérifier le code reçu par email et réessayer.',
      'LOGIN_ERROR_CODE_OR_CONNECTION':
          'Code invalide ou erreur de connexion. Veuillez vérifier le code et réessayer.',
      'LOGIN_MESSAGE_RETURN_APP': 'Après la connexion, revenez dans cette application.',
      'LOGIN_ERROR_GOOGLE': 'Erreur lors de la connexion avec Google',
      'LOGIN_ERROR_FACEBOOK': 'Erreur lors de la connexion avec Facebook',
      'LOGIN_SUCCESS_TITLE': 'Connexion réussie !',
      'LOGIN_SUCCESS_MESSAGE': 'Vous allez être redirigé...',
      // Clés pour le titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Trouvez vos articles ',
      'SELECT_COUNTRY_TITLE_PART2': ' moins chers avec ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Votre pays d\'origine',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Rechercher votre pays...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'J\'accepte les conditions d\'utilisation',
      'SELECT_COUNTRY_VIEW_TERMS': 'Voir les conditions',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Valider',
      'SELECT_COUNTRY_FOOTER_TEXT': 'En cliquant sur Valider, vous acceptez nos conditions d\'utilisation. ',
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
      'BANNER_FREE_TITLE': 'C’est cadeau !.',
      // Product search - état initial
      'PRODUCTSEARCH_ENTER_CODE': 'Saisissez un code article pour commencer la recherche',
      // Product search - champ de saisie
      'PRODUCTSEARCH_HINT_CODE': 'Référence IKEA (ex: 123.456.78)',
      // Product search - erreurs backend
      'HTML_SEARCH_BADREFERENCE': 'La référence ne semble pas être correcte.\nUne référence est une suite de 8 chiffres séparée par 2 points (ex. 123.456.78)',
      // Wishlist labels
      'BEST_PRICE': 'Meilleur prix',
      'OPTIMAL': 'Optimal',
      'CURRENT_PRICE': 'Prix actuel',
      'CURRENT': 'Actuel',
      'PROFIT': 'Bénéfice',
      'ADD_ITEM': 'Ajouter',
      'WISHLIST_COUNTRY_MODAL_TITLE': 'Ajouter des pays',
      'WISHLIST_COUNTRY_MODAL_AVAILABLE': 'Pays disponibles',
      'WISHLIST_COUNTRY_MODAL_HELP':
          'Cliquez pour activer/désactiver les pays dans votre wishlist',
      'WISHLIST_COUNTRY_MODAL_CANCEL': 'Annuler',
      'WISHLIST_COUNTRY_MODAL_SAVE': 'Modifier',
      'WISHLIST_COUNTRY_SIDEBAR_MANAGE_BUTTON': 'Ajouter/Supprimer un pays',
      'WISHLIST_COUNTRY_SIDEBAR_CLOSE': 'Fermer',
      'WISHLIST_COUNTRY_EMPTY': 'Aucun pays disponible',
      'WISHLIST_COUNTRY_PRICE_UNAVAILABLE': 'Indisponible',
      // Wishlist - dialogs
      'CONFIRM_TITLE': 'Confirmation',
      'CONFIRM_DELETE_ITEM': 'Voulez-vous vraiment supprimer cet article ?',
      'BUTTON_NO': 'Non',
      'BUTTON_YES': 'Oui',
      'SUCCESS_TITLE': 'Succès',
      'SUCCESS_DELETE_ARTICLE': "L'article a été supprimé avec succès.",
      'ERROR_TITLE': 'Erreur',
      'DELETE_ERROR': 'Une erreur est survenue lors de la suppression.',
      // Map - boutons
      'BUTTON_STORES': 'Magasins',
      'BUTTON_CLOSE': 'Fermer',
      // Map - magasins
      'STORES_NEARBY': 'Magasins à proximité',
      'SORTED_BY_PROXIMITY': 'Triés par proximité',
      'YOUR_POSITION': 'Votre position',
      'IKEA_STORES': 'Magasins IKEA',
      'IKEA_STORES_NEARBY': 'Magasins IKEA à proximité',
      'SEARCH_STORE_PLACEHOLDER': 'Rechercher un magasin (nom, pays, ville)',
      'SEARCH_LOCATION_PLACEHOLDER': 'Rechercher une ville, adresse ou code postal...',
      // Search modal - titre
      'FRONTPAGE_Msg05': 'Rechercher un article',
      // Search modal - sélection pays
      'FRONTPAGE_Msg04': 'Choisissez les pays à comparer:',
      // Search modal - bouton scanner
      'FRONTPAGE_Msg08': 'Scanner un produit',
      // Wishlist - panier vide
      'EMPTY_CART_TITLE': 'Panier vide',
      'EMPTY_CART_MESSAGE': 'Aucun Article trouvé dans ce panier',
      // Profile detail
      'PROFILE_EDIT_BUTTON': 'Modifier mon profil',
      'PROFILE_MAIN_COUNTRY': 'Pays principal',
      'PROFILE_NOT_SELECTED': 'Non sélectionné',
      'PROFILE_FAVORITE_COUNTRIES': 'Pays favoris',
      'PROFILE_NO_FAVORITE_COUNTRIES': 'Aucun pays favori sélectionné',
    },
    'en': {
      // Clés de l'API pour la page de sélection de pays
      'FRONTPAGE_Msg01': 'Home Wishlist Project Newsletter Subscription Login',
      'FRONTPAGE_Msg02': 'Compare IKEA prices in multiple countries with one click',
      'FRONTPAGE_Msg03': 'JIRIG helps you save on your international IKEA purchases',
      'PODIUM_ENLARGE': 'Enlarge',
      'LOGIN_WELCOME_TITLE': 'Welcome to Jirig',
      'LOGIN_WELCOME_SUBTITLE':
          'Sign in and explore all the features of our platform',
      'LOGIN_TITLE': 'Sign In',
      'LOGIN_SUBTITLE': 'Access your account',
      'LOGIN_EMAIL_LABEL': 'Email address',
      'LOGIN_EMAIL_PLACEHOLDER': 'your@email.com',
      'LOGIN_CODE_LABEL': 'Verification code',
      'LOGIN_CODE_PLACEHOLDER': 'Enter the code received by email',
      'LOGIN_ACTION_SEND_CODE': 'Send the code',
      'LOGIN_ACTION_VALIDATE_CODE': 'Validate the code',
      'LOGIN_LOADING_SENDING_CODE': 'Sending the code...',
      'LOGIN_LOADING_CONNECTING': 'Signing in...',
      'LOGIN_SEPARATOR_TEXT': 'Or continue with',
      'LOGIN_CONTINUE_WITH_GOOGLE': 'Continue with Google',
      'LOGIN_CONTINUE_WITH_FACEBOOK': 'Continue with Facebook',
      'LOGIN_TERMS_PREFIX': 'By signing in, you agree to our',
      'LOGIN_TERMS_LINK': 'Terms of Use',
      'LOGIN_AND_OUR': 'and our',
      'LOGIN_PRIVACY_LINK': 'Privacy Policy',
      'LOGIN_CODE_SENT_TITLE': 'Code sent',
      'LOGIN_CODE_SENT_MESSAGE':
          'Copy this code or open your mailbox to retrieve it.',
      'LOGIN_CODE_SENT_PLACEHOLDER': 'Code sent by email',
      'LOGIN_CODE_SENT_TOOLTIP': 'Copy',
      'LOGIN_CODE_SENT_FOOTER':
          'You can also open your mailbox to find this message.',
      'LOGIN_OPEN_MAIL': 'Open my mailbox',
      'LOGIN_CODE_COPIED_BUTTON': 'I copied the code',
      'LOGIN_RESEND_CODE': 'Send a new code',
      'LOGIN_SNACKBAR_COPIED': 'Code copied to the clipboard',
      'LOGIN_ERROR_EMPTY_EMAIL': 'Please enter your email address',
      'LOGIN_ERROR_INVALID_EMAIL': 'Invalid email address',
      'LOGIN_ERROR_EMPTY_CODE': 'Please enter the code received by email',
      'LOGIN_ERROR_GENERIC':
          'An error occurred while signing in. Please try again.',
      'LOGIN_ERROR_INVALID_CODE':
          'Invalid code. Please check the code received by email and try again.',
      'LOGIN_ERROR_CODE_OR_CONNECTION':
          'Invalid code or connection error. Please check the code and try again.',
      'LOGIN_MESSAGE_RETURN_APP': 'After signing in, return to this app.',
      'LOGIN_ERROR_GOOGLE': 'An error occurred while signing in with Google',
      'LOGIN_ERROR_FACEBOOK': 'An error occurred while signing in with Facebook',
      'LOGIN_SUCCESS_TITLE': 'Sign-in successful!',
      'LOGIN_SUCCESS_MESSAGE': 'You will be redirected shortly...',
      // Clés pour le titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Find your articles ',
      'SELECT_COUNTRY_TITLE_PART2': ' cheaper with ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Your country of origin',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Search your country...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'I accept the terms of use',
      'SELECT_COUNTRY_VIEW_TERMS': 'View conditions',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Validate',
      'SELECT_COUNTRY_FOOTER_TEXT': 'By clicking Validate, you accept our terms of use. ',
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
      'BANNER_FREE_TITLE': 'It’s a gift!.',
      // Product search - initial state
      'PRODUCTSEARCH_ENTER_CODE': 'Enter an article code to start searching',
      // Product search - input field
      'PRODUCTSEARCH_HINT_CODE': 'IKEA Reference (e.g. 123.456.78)',
      // Product search - backend errors
      'HTML_SEARCH_BADREFERENCE': 'The reference does not seem to be correct.\nA reference is a sequence of 8 digits separated by 2 dots (e.g. 123.456.78)',
      // Wishlist labels
      'BEST_PRICE': 'Best price',
      'OPTIMAL': 'Optimal',
      'CURRENT_PRICE': 'Current price',
      'CURRENT': 'Current',
      'PROFIT': 'Profit',
      'ADD_ITEM': 'Add',
      'WISHLIST_COUNTRY_MODAL_TITLE': 'Add countries',
      'WISHLIST_COUNTRY_MODAL_AVAILABLE': 'Available countries',
      'WISHLIST_COUNTRY_MODAL_HELP':
          'Tap to enable or disable countries in your wishlist',
      'WISHLIST_COUNTRY_MODAL_CANCEL': 'Cancel',
      'WISHLIST_COUNTRY_MODAL_SAVE': 'Update',
      'WISHLIST_COUNTRY_SIDEBAR_MANAGE_BUTTON': 'Add/Remove a country',
      'WISHLIST_COUNTRY_SIDEBAR_CLOSE': 'Close',
      'WISHLIST_COUNTRY_EMPTY': 'No countries available',
      'WISHLIST_COUNTRY_PRICE_UNAVAILABLE': 'Unavailable',
      // Wishlist - dialogs
      'CONFIRM_TITLE': 'Confirmation',
      'CONFIRM_DELETE_ITEM': 'Are you sure you want to delete this item?',
      'BUTTON_NO': 'No',
      'BUTTON_YES': 'Yes',
      'SUCCESS_TITLE': 'Success',
      'SUCCESS_DELETE_ARTICLE': 'The item has been deleted successfully.',
      'ERROR_TITLE': 'Error',
      'DELETE_ERROR': 'An error occurred while deleting.',
      // Map - buttons
      'BUTTON_STORES': 'Stores',
      'BUTTON_CLOSE': 'Close',
      // Map - stores
      'STORES_NEARBY': 'Stores nearby',
      'SORTED_BY_PROXIMITY': 'Sorted by proximity',
      'YOUR_POSITION': 'Your position',
      'IKEA_STORES': 'IKEA Stores',
      'IKEA_STORES_NEARBY': 'IKEA Stores nearby',
      'SEARCH_STORE_PLACEHOLDER': 'Search for a store (name, country, city)',
      'SEARCH_LOCATION_PLACEHOLDER': 'Search for a city, address or postal code...',
      // Search modal - title
      'FRONTPAGE_Msg05': 'Search for an article',
      // Search modal - country selection
      'FRONTPAGE_Msg04': 'Choose countries to compare:',
      // Search modal - scanner button
      'FRONTPAGE_Msg08': 'Scan a product',
      // Wishlist - empty cart
      'EMPTY_CART_TITLE': 'Empty cart',
      'EMPTY_CART_MESSAGE': 'No item found in this cart',
      // Profile detail
      'PROFILE_EDIT_BUTTON': 'Edit my profile',
      'PROFILE_MAIN_COUNTRY': 'Main country',
      'PROFILE_NOT_SELECTED': 'Not selected',
      'PROFILE_FAVORITE_COUNTRIES': 'Favorite countries',
      'PROFILE_NO_FAVORITE_COUNTRIES': 'No favorite countries selected',
    },
    'de': {
      // Clés de l'API pour la page de sélection de pays (basées sur vos données)
      'FRONTPAGE_Msg01': 'Startseite Wunschliste Projekt Newsletter Abonnement Anmeldung',
      'FRONTPAGE_Msg02': 'Vergleichen Sie IKEA-Preise in mehreren Ländern mit einem Klick',
      'FRONTPAGE_Msg03': 'JIRIG hilft Ihnen bei Ihren internationalen IKEA-Einkäufen zu sparen',
      'PODIUM_ENLARGE': 'Vergrößern',
      'LOGIN_WELCOME_TITLE': 'Willkommen bei Jirig',
      'LOGIN_WELCOME_SUBTITLE':
          'Melden Sie sich an und entdecken Sie alle Funktionen unserer Plattform',
      'LOGIN_TITLE': 'Anmeldung',
      'LOGIN_SUBTITLE': 'Greifen Sie auf Ihr Konto zu',
      'LOGIN_EMAIL_LABEL': 'E-Mail-Adresse',
      'LOGIN_EMAIL_PLACEHOLDER': 'ihre@email.com',
      'LOGIN_CODE_LABEL': 'Bestätigungscode',
      'LOGIN_CODE_PLACEHOLDER': 'Geben Sie den per E-Mail erhaltenen Code ein',
      'LOGIN_ACTION_SEND_CODE': 'Code senden',
      'LOGIN_ACTION_VALIDATE_CODE': 'Code bestätigen',
      'LOGIN_LOADING_SENDING_CODE': 'Code wird gesendet...',
      'LOGIN_LOADING_CONNECTING': 'Anmeldung läuft...',
      'LOGIN_SEPARATOR_TEXT': 'Oder fortfahren mit',
      'LOGIN_CONTINUE_WITH_GOOGLE': 'Mit Google fortfahren',
      'LOGIN_CONTINUE_WITH_FACEBOOK': 'Mit Facebook fortfahren',
      'LOGIN_TERMS_PREFIX': 'Mit Ihrer Anmeldung akzeptieren Sie unsere',
      'LOGIN_TERMS_LINK': 'Nutzungsbedingungen',
      'LOGIN_AND_OUR': 'und unsere',
      'LOGIN_PRIVACY_LINK': 'Datenschutzerklärung',
      'LOGIN_CODE_SENT_TITLE': 'Code gesendet',
      'LOGIN_CODE_SENT_MESSAGE':
          'Kopieren Sie diesen Code oder öffnen Sie Ihr Postfach, um ihn abzurufen.',
      'LOGIN_CODE_SENT_PLACEHOLDER': 'Per E-Mail gesendeter Code',
      'LOGIN_CODE_SENT_TOOLTIP': 'Kopieren',
      'LOGIN_CODE_SENT_FOOTER':
          'Sie können auch Ihr Postfach öffnen, um diese Nachricht zu finden.',
      'LOGIN_OPEN_MAIL': 'Mein Postfach öffnen',
      'LOGIN_CODE_COPIED_BUTTON': 'Ich habe den Code kopiert',
      'LOGIN_RESEND_CODE': 'Neuen Code senden',
      'LOGIN_SNACKBAR_COPIED': 'Code in die Zwischenablage kopiert',
      'LOGIN_ERROR_EMPTY_EMAIL': 'Bitte geben Sie Ihre E-Mail-Adresse ein',
      'LOGIN_ERROR_INVALID_EMAIL': 'Ungültige E-Mail-Adresse',
      'LOGIN_ERROR_EMPTY_CODE':
          'Bitte geben Sie den per E-Mail erhaltenen Code ein',
      'LOGIN_ERROR_GENERIC':
          'Beim Anmelden ist ein Fehler aufgetreten. Bitte versuchen Sie es erneut.',
      'LOGIN_ERROR_INVALID_CODE':
          'Ungültiger Code. Bitte überprüfen Sie den per E-Mail erhaltenen Code und versuchen Sie es erneut.',
      'LOGIN_ERROR_CODE_OR_CONNECTION':
          'Ungültiger Code oder Verbindungsfehler. Bitte überprüfen Sie den Code und versuchen Sie es erneut.',
      'LOGIN_MESSAGE_RETURN_APP': 'Kehren Sie nach der Anmeldung zu dieser App zurück.',
      'LOGIN_ERROR_GOOGLE':
          'Beim Anmelden mit Google ist ein Fehler aufgetreten',
      'LOGIN_ERROR_FACEBOOK':
          'Beim Anmelden mit Facebook ist ein Fehler aufgetreten',
      'LOGIN_SUCCESS_TITLE': 'Anmeldung erfolgreich!',
      'LOGIN_SUCCESS_MESSAGE': 'Sie werden in Kürze weitergeleitet...',
      // Clés pour le titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Finden Sie Ihre Artikel ',
      'SELECT_COUNTRY_TITLE_PART2': ' günstiger mit ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Ihr Herkunftsland',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Ihr Land suchen...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'Ich akzeptiere die Nutzungsbedingungen',
      'SELECT_COUNTRY_VIEW_TERMS': 'Bedingungen anzeigen',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Validieren',
      'SELECT_COUNTRY_FOOTER_TEXT': 'Durch Anklicken von Validieren akzeptieren Sie unsere Nutzungsbedingungen. ',
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
      // Product search - initial state
      'PRODUCTSEARCH_ENTER_CODE': 'Geben Sie einen Artikelcode ein, um die Suche zu starten',
      // Product search - input field
      'PRODUCTSEARCH_HINT_CODE': 'IKEA-Referenz (z. B. 123.456.78)',
      // Product search - backend errors
      'HTML_SEARCH_BADREFERENCE': 'Die Referenz scheint nicht korrekt zu sein.\nEine Referenz ist eine Folge von 8 Ziffern, getrennt durch 2 Punkte (z.B. 123.456.78)',
      // Wishlist labels
      'BEST_PRICE': 'Bester Preis',
      'OPTIMAL': 'Optimal',
      'CURRENT_PRICE': 'Aktueller Preis',
      'CURRENT': 'Aktuell',
      'PROFIT': 'Gewinn',
      'ADD_ITEM': 'Hinzufügen',
      'WISHLIST_COUNTRY_MODAL_TITLE': 'Länder hinzufügen',
      'WISHLIST_COUNTRY_MODAL_AVAILABLE': 'Verfügbare Länder',
      'WISHLIST_COUNTRY_MODAL_HELP':
          'Tippen Sie, um Länder in Ihrer Wunschliste zu aktivieren oder zu deaktivieren',
      'WISHLIST_COUNTRY_MODAL_CANCEL': 'Abbrechen',
      'WISHLIST_COUNTRY_MODAL_SAVE': 'Speichern',
      'WISHLIST_COUNTRY_SIDEBAR_MANAGE_BUTTON': 'Land hinzufügen/entfernen',
      'WISHLIST_COUNTRY_SIDEBAR_CLOSE': 'Schließen',
      'WISHLIST_COUNTRY_EMPTY': 'Keine Länder verfügbar',
      'WISHLIST_COUNTRY_PRICE_UNAVAILABLE': 'Nicht verfügbar',
      // Wishlist - dialogs
      'CONFIRM_TITLE': 'Bestätigung',
      'CONFIRM_DELETE_ITEM': 'Möchten Sie diesen Artikel wirklich löschen?',
      'BUTTON_NO': 'Nein',
      'BUTTON_YES': 'Ja',
      'SUCCESS_TITLE': 'Erfolg',
      'SUCCESS_DELETE_ARTICLE': 'Der Artikel wurde erfolgreich gelöscht.',
      'ERROR_TITLE': 'Fehler',
      'DELETE_ERROR': 'Beim Löschen ist ein Fehler aufgetreten.',
      // Karte - Schaltflächen
      'BUTTON_STORES': 'Geschäfte',
      'BUTTON_CLOSE': 'Schließen',
      // Karte - Geschäfte
      'STORES_NEARBY': 'Geschäfte in der Nähe',
      'SORTED_BY_PROXIMITY': 'Nach Entfernung sortiert',
      'YOUR_POSITION': 'Ihre Position',
      'IKEA_STORES': 'IKEA Geschäfte',
      'IKEA_STORES_NEARBY': 'IKEA Geschäfte in der Nähe',
      'SEARCH_STORE_PLACEHOLDER': 'Ein Geschäft suchen (Name, Land, Stadt)',
      'SEARCH_LOCATION_PLACEHOLDER': 'Eine Stadt, Adresse oder Postleitzahl suchen...',
      // Suchmodal - Titel
      'FRONTPAGE_Msg05': 'Einen Artikel suchen',
      // Suchmodal - Länderauswahl
      'FRONTPAGE_Msg04': 'Länder zum Vergleichen auswählen:',
      // Suchmodal - Scanner-Button
      'FRONTPAGE_Msg08': 'Ein Produkt scannen',
      // Wunschliste - leerer Warenkorb
      'EMPTY_CART_TITLE': 'Leerer Warenkorb',
      'EMPTY_CART_MESSAGE': 'Kein Artikel in diesem Warenkorb gefunden',
      // Profile detail
      'PROFILE_EDIT_BUTTON': 'Mein Profil bearbeiten',
      'PROFILE_MAIN_COUNTRY': 'Hauptland',
      'PROFILE_NOT_SELECTED': 'Nicht ausgewählt',
      'PROFILE_FAVORITE_COUNTRIES': 'Lieblingsländer',
      'PROFILE_NO_FAVORITE_COUNTRIES': 'Keine Lieblingsländer ausgewählt',
    },
    'es': {
      // Clés de l'API pour la page de sélection de pays
      'FRONTPAGE_Msg01': 'Inicio Lista de deseos Proyecto Newsletter Suscripción Iniciar sesión',
      'FRONTPAGE_Msg02': 'Compara los precios de IKEA en varios países con un clic',
      'FRONTPAGE_Msg03': 'JIRIG te ayuda a ahorrar en tus compras internacionales de IKEA',
      'PODIUM_ENLARGE': 'Ampliar',
      'LOGIN_WELCOME_TITLE': 'Bienvenido a Jirig',
      'LOGIN_WELCOME_SUBTITLE':
          'Inicia sesión y explora todas las funciones de nuestra plataforma',
      'LOGIN_TITLE': 'Iniciar sesión',
      'LOGIN_SUBTITLE': 'Accede a tu cuenta',
      'LOGIN_EMAIL_LABEL': 'Correo electrónico',
      'LOGIN_EMAIL_PLACEHOLDER': 'tu@email.com',
      'LOGIN_CODE_LABEL': 'Código de verificación',
      'LOGIN_CODE_PLACEHOLDER': 'Introduce el código recibido por correo',
      'LOGIN_ACTION_SEND_CODE': 'Enviar el código',
      'LOGIN_ACTION_VALIDATE_CODE': 'Validar el código',
      'LOGIN_LOADING_SENDING_CODE': 'Enviando el código...',
      'LOGIN_LOADING_CONNECTING': 'Conectando...',
      'LOGIN_SEPARATOR_TEXT': 'O continuar con',
      'LOGIN_CONTINUE_WITH_GOOGLE': 'Continuar con Google',
      'LOGIN_CONTINUE_WITH_FACEBOOK': 'Continuar con Facebook',
      'LOGIN_TERMS_PREFIX': 'Al iniciar sesión aceptas nuestros',
      'LOGIN_TERMS_LINK': 'Términos de uso',
      'LOGIN_AND_OUR': 'y nuestra',
      'LOGIN_PRIVACY_LINK': 'Política de privacidad',
      'LOGIN_CODE_SENT_TITLE': 'Código enviado',
      'LOGIN_CODE_SENT_MESSAGE':
          'Copia este código u abre tu buzón para recuperarlo.',
      'LOGIN_CODE_SENT_PLACEHOLDER': 'Código enviado por correo',
      'LOGIN_CODE_SENT_TOOLTIP': 'Copiar',
      'LOGIN_CODE_SENT_FOOTER':
          'También puedes abrir tu buzón para encontrar este mensaje.',
      'LOGIN_OPEN_MAIL': 'Abrir mi buzón',
      'LOGIN_CODE_COPIED_BUTTON': 'He copiado el código',
      'LOGIN_RESEND_CODE': 'Enviar un nuevo código',
      'LOGIN_SNACKBAR_COPIED': 'Código copiado al portapapeles',
      'LOGIN_ERROR_EMPTY_EMAIL': 'Introduce tu correo electrónico',
      'LOGIN_ERROR_INVALID_EMAIL': 'Correo electrónico no válido',
      'LOGIN_ERROR_EMPTY_CODE':
          'Introduce el código recibido por correo electrónico',
      'LOGIN_ERROR_GENERIC':
          'Se produjo un error al iniciar sesión. Inténtalo de nuevo.',
      'LOGIN_ERROR_INVALID_CODE':
          'Código no válido. Verifica el código recibido por correo e inténtalo de nuevo.',
      'LOGIN_ERROR_CODE_OR_CONNECTION':
          'Código no válido o error de conexión. Verifica el código e inténtalo de nuevo.',
      'LOGIN_MESSAGE_RETURN_APP':
          'Después de iniciar sesión, vuelve a esta aplicación.',
      'LOGIN_ERROR_GOOGLE':
          'Se produjo un error al iniciar sesión con Google',
      'LOGIN_ERROR_FACEBOOK':
          'Se produjo un error al iniciar sesión con Facebook',
      'LOGIN_SUCCESS_TITLE': '¡Inicio de sesión exitoso!',
      'LOGIN_SUCCESS_MESSAGE': 'Serás redirigido en unos instantes...',
      // Clés para el titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Encuentra tus artículos ',
      'SELECT_COUNTRY_TITLE_PART2': ' más baratos con ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Tu país de origen',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Buscar tu país...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'Acepto los términos de uso',
      'SELECT_COUNTRY_VIEW_TERMS': 'Ver condiciones',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Validar',
      'SELECT_COUNTRY_FOOTER_TEXT': 'Al hacer clic en Validar, aceptas nuestros términos de uso. ',
      'SELECT_COUNTRY_TERMS_LINK': 'Condiciones de uso',
      // Clés para la page d'accueil
      'FRONTPAGE_Msg77': 'Encuentra tus artículos',
      'FRONTPAGE_Msg78': 'más baratos con Jirig',
      'FRONTPAGE_Msg88': 'Suscripción Premium',
      'FRONTPAGE_Msg89': 'Accede a todas las funciones avanzadas de JIRIG',
      'FRONTPAGE_Msg90': 'Suscribirse ahora',
      'COMPARE_Msg03': 'Comparación por email',
      'COMPARE_TEXT_PART1': 'Envíanos tu lista de IKEA por email para una comparación personalizada',
      'COMPARE_Msg05': 'Enviar por email',
      // Product search - initial state
      'PRODUCTSEARCH_ENTER_CODE': 'Introduce un código de artículo para iniciar la búsqueda',
      // Product search - input field
      'PRODUCTSEARCH_HINT_CODE': 'Referencia IKEA (ej.: 123.456.78)',
      // Product search - backend errors
      'HTML_SEARCH_BADREFERENCE': 'La referencia no parece ser correcta.\nUna referencia es una secuencia de 8 dígitos separados por 2 puntos (ej. 123.456.78)',
      // Wishlist labels
      'BEST_PRICE': 'Mejor precio',
      'OPTIMAL': 'Óptimo',
      'CURRENT_PRICE': 'Precio actual',
      'CURRENT': 'Actual',
      'PROFIT': 'Beneficio',
      'ADD_ITEM': 'Añadir',
      'WISHLIST_COUNTRY_MODAL_TITLE': 'Agregar países',
      'WISHLIST_COUNTRY_MODAL_AVAILABLE': 'Países disponibles',
      'WISHLIST_COUNTRY_MODAL_HELP':
          'Pulsa para activar o desactivar países en tu lista de deseos',
      'WISHLIST_COUNTRY_MODAL_CANCEL': 'Cancelar',
      'WISHLIST_COUNTRY_MODAL_SAVE': 'Actualizar',
      'WISHLIST_COUNTRY_SIDEBAR_MANAGE_BUTTON': 'Agregar/Quitar un país',
      'WISHLIST_COUNTRY_SIDEBAR_CLOSE': 'Cerrar',
      'WISHLIST_COUNTRY_EMPTY': 'No hay países disponibles',
      'WISHLIST_COUNTRY_PRICE_UNAVAILABLE': 'No disponible',
      // Wishlist - dialogs
      'CONFIRM_TITLE': 'Confirmación',
      'CONFIRM_DELETE_ITEM': '¿Seguro que desea eliminar este artículo?',
      'BUTTON_NO': 'No',
      'BUTTON_YES': 'Sí',
      'SUCCESS_TITLE': 'Éxito',
      'SUCCESS_DELETE_ARTICLE': 'El artículo se ha eliminado correctamente.',
      'ERROR_TITLE': 'Error',
      'DELETE_ERROR': 'Se produjo un error al eliminar.',
      // Mapa - botones
      'BUTTON_STORES': 'Tiendas',
      'BUTTON_CLOSE': 'Cerrar',
      // Mapa - tiendas
      'STORES_NEARBY': 'Tiendas cercanas',
      'SORTED_BY_PROXIMITY': 'Ordenadas por proximidad',
      'YOUR_POSITION': 'Su posición',
      'IKEA_STORES': 'Tiendas IKEA',
      'IKEA_STORES_NEARBY': 'Tiendas IKEA cercanas',
      'SEARCH_STORE_PLACEHOLDER': 'Buscar una tienda (nombre, país, ciudad)',
      'SEARCH_LOCATION_PLACEHOLDER': 'Buscar una ciudad, dirección o código postal...',
      // Modal de búsqueda - título
      'FRONTPAGE_Msg05': 'Buscar un artículo',
      // Modal de búsqueda - selección de países
      'FRONTPAGE_Msg04': 'Elige los países a comparar:',
      // Modal de búsqueda - botón escáner
      'FRONTPAGE_Msg08': 'Escanear un producto',
      // Lista de deseos - carrito vacío
      'EMPTY_CART_TITLE': 'Carrito vacío',
      'EMPTY_CART_MESSAGE': 'Ningún artículo encontrado en este carrito',
      // Profile detail
      'PROFILE_EDIT_BUTTON': 'Editar mi perfil',
      'PROFILE_MAIN_COUNTRY': 'País principal',
      'PROFILE_NOT_SELECTED': 'No seleccionado',
      'PROFILE_FAVORITE_COUNTRIES': 'Países favoritos',
      'PROFILE_NO_FAVORITE_COUNTRIES': 'No se han seleccionado países favoritos',
    },
    'it': {
      // Clés de l'API pour la page de sélection de pays
      'FRONTPAGE_Msg01': 'Home Lista desideri Progetto Newsletter Abbonamento Accedi',
      'FRONTPAGE_Msg02': 'Confronta i prezzi IKEA in diversi paesi con un clic',
      'FRONTPAGE_Msg03': 'JIRIG ti aiuta a risparmiare sui tuoi acquisti internazionali IKEA',
      'PODIUM_ENLARGE': 'Ingrandire',
      'LOGIN_WELCOME_TITLE': 'Benvenuto su Jirig',
      'LOGIN_WELCOME_SUBTITLE':
          'Accedi ed esplora tutte le funzionalità della nostra piattaforma',
      'LOGIN_TITLE': 'Accesso',
      'LOGIN_SUBTITLE': 'Accedi al tuo account',
      'LOGIN_EMAIL_LABEL': 'Indirizzo email',
      'LOGIN_EMAIL_PLACEHOLDER': 'tua@email.com',
      'LOGIN_CODE_LABEL': 'Codice di verifica',
      'LOGIN_CODE_PLACEHOLDER': 'Inserisci il codice ricevuto via email',
      'LOGIN_ACTION_SEND_CODE': 'Invia il codice',
      'LOGIN_ACTION_VALIDATE_CODE': 'Convalida il codice',
      'LOGIN_LOADING_SENDING_CODE': 'Invio del codice...',
      'LOGIN_LOADING_CONNECTING': 'Accesso in corso...',
      'LOGIN_SEPARATOR_TEXT': 'Oppure continua con',
      'LOGIN_CONTINUE_WITH_GOOGLE': 'Continua con Google',
      'LOGIN_CONTINUE_WITH_FACEBOOK': 'Continua con Facebook',
      'LOGIN_TERMS_PREFIX': 'Accedendo accetti i nostri',
      'LOGIN_TERMS_LINK': 'Termini di utilizzo',
      'LOGIN_AND_OUR': 'e la nostra',
      'LOGIN_PRIVACY_LINK': 'Informativa sulla privacy',
      'LOGIN_CODE_SENT_TITLE': 'Codice inviato',
      'LOGIN_CODE_SENT_MESSAGE':
          'Copia questo codice o apri la tua casella di posta per recuperarlo.',
      'LOGIN_CODE_SENT_PLACEHOLDER': 'Codice inviato via email',
      'LOGIN_CODE_SENT_TOOLTIP': 'Copia',
      'LOGIN_CODE_SENT_FOOTER':
          'Puoi anche aprire la casella di posta per trovare questo messaggio.',
      'LOGIN_OPEN_MAIL': 'Apri la mia casella di posta',
      'LOGIN_CODE_COPIED_BUTTON': 'Ho copiato il codice',
      'LOGIN_RESEND_CODE': 'Invia un nuovo codice',
      'LOGIN_SNACKBAR_COPIED': 'Codice copiato negli appunti',
      'LOGIN_ERROR_EMPTY_EMAIL': 'Inserisci il tuo indirizzo email',
      'LOGIN_ERROR_INVALID_EMAIL': 'Indirizzo email non valido',
      'LOGIN_ERROR_EMPTY_CODE':
          'Inserisci il codice ricevuto via email',
      'LOGIN_ERROR_GENERIC':
          'Si è verificato un errore durante l\'accesso. Riprova.',
      'LOGIN_ERROR_INVALID_CODE':
          'Codice non valido. Controlla il codice ricevuto via email e riprova.',
      'LOGIN_ERROR_CODE_OR_CONNECTION':
          'Codice non valido o errore di connessione. Controlla il codice e riprova.',
      'LOGIN_MESSAGE_RETURN_APP': 'Dopo l\'accesso, torna a questa applicazione.',
      'LOGIN_ERROR_GOOGLE':
          'Si è verificato un errore durante l\'accesso con Google',
      'LOGIN_ERROR_FACEBOOK':
          'Si è verificato un errore durante l\'accesso con Facebook',
      'LOGIN_SUCCESS_TITLE': 'Accesso riuscito!',
      'LOGIN_SUCCESS_MESSAGE': 'Verrai reindirizzato a breve...',
      // Clés pour le titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Trova i tuoi articoli ',
      'SELECT_COUNTRY_TITLE_PART2': ' più economici con ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Il tuo paese di origine',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Cerca il tuo paese...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'Accetto i termini di utilizzo',
      'SELECT_COUNTRY_VIEW_TERMS': 'Visualizza condizioni',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Convalidare',
      'SELECT_COUNTRY_FOOTER_TEXT': 'Cliccando su Convalidare, accetti i nostri termini di utilizzo. ',
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
      // Product search - initial state
      'PRODUCTSEARCH_ENTER_CODE': 'Inserisci un codice articolo per avviare la ricerca',
      // Product search - input field
      'PRODUCTSEARCH_HINT_CODE': 'Riferimento IKEA (es.: 123.456.78)',
      // Product search - backend errors
      'HTML_SEARCH_BADREFERENCE': 'Il riferimento non sembra essere corretto.\nUn riferimento è una sequenza di 8 cifre separate da 2 punti (es. 123.456.78)',
      // Wishlist labels
      'BEST_PRICE': 'Miglior prezzo',
      'OPTIMAL': 'Ottimale',
      'CURRENT_PRICE': 'Prezzo attuale',
      'CURRENT': 'Attuale',
      'PROFIT': 'Beneficio',
      'ADD_ITEM': 'Aggiungi',
      // Wishlist - dialogs
      'CONFIRM_TITLE': 'Conferma',
      'CONFIRM_DELETE_ITEM': 'Sei sicuro di voler eliminare questo articolo?',
      'BUTTON_NO': 'No',
      'BUTTON_YES': 'Sì',
      'SUCCESS_TITLE': 'Successo',
      'SUCCESS_DELETE_ARTICLE': "L'articolo è stato eliminato con successo.",
      'ERROR_TITLE': 'Errore',
      'DELETE_ERROR': 
          'Si è verificato un errore durante l\'eliminazione.',
      // Mappa - pulsanti
      'BUTTON_STORES': 'Negozi',
      'BUTTON_CLOSE': 'Chiudi',
      // Mappa - negozi
      'STORES_NEARBY': 'Negozi nelle vicinanze',
      'SORTED_BY_PROXIMITY': 'Ordinati per vicinanza',
      'YOUR_POSITION': 'La tua posizione',
      'IKEA_STORES': 'Negozi IKEA',
      'IKEA_STORES_NEARBY': 'Negozi IKEA nelle vicinanze',
      'SEARCH_STORE_PLACEHOLDER': 'Cerca un negozio (nome, paese, stad)',
      'SEARCH_LOCATION_PLACEHOLDER': 'Cerca una città, indirizzo o codice postale...',
      // Modale di ricerca - titolo
      'FRONTPAGE_Msg05': 'Cerca un articolo',
      // Modale di ricerca - selezione paesi
      'FRONTPAGE_Msg04': 'Scegli i paesi da confrontare:',
      // Modale di ricerca - pulsante scanner
      'FRONTPAGE_Msg08': 'Scansiona un prodotto',
      // Lista desideri - carrello vuoto
      'EMPTY_CART_TITLE': 'Carrello vuoto',
      'EMPTY_CART_MESSAGE': 'Nessun articolo trovato in questo carrello',
      // Profile detail
      'PROFILE_EDIT_BUTTON': 'Modifica il mio profilo',
      'PROFILE_MAIN_COUNTRY': 'Paese principale',
      'PROFILE_NOT_SELECTED': 'Non selezionato',
      'PROFILE_FAVORITE_COUNTRIES': 'Paesi preferiti',
      'PROFILE_NO_FAVORITE_COUNTRIES': 'Nessun paese preferito selezionato',
    },
    'pt': {
      // Clés de l'API pour la page de sélection de pays
      'FRONTPAGE_Msg01': 'Início Lista de desejos Projeto Newsletter Assinatura Login',
      'FRONTPAGE_Msg02': 'Compare preços IKEA em vários países com um clique',
      'FRONTPAGE_Msg03': 'JIRIG te ajuda a economizar em suas compras internacionais IKEA',
      'PODIUM_ENLARGE': 'Ampliar',
      'LOGIN_WELCOME_TITLE': 'Bem-vindo ao Jirig',
      'LOGIN_WELCOME_SUBTITLE':
          'Faça login e explore todos os recursos da nossa plataforma',
      'LOGIN_TITLE': 'Entrar',
      'LOGIN_SUBTITLE': 'Acesse sua conta',
      'LOGIN_EMAIL_LABEL': 'Endereço de e-mail',
      'LOGIN_EMAIL_PLACEHOLDER': 'seu@email.com',
      'LOGIN_CODE_LABEL': 'Código de verificação',
      'LOGIN_CODE_PLACEHOLDER': 'Digite o código recebido por e-mail',
      'LOGIN_ACTION_SEND_CODE': 'Enviar código',
      'LOGIN_ACTION_VALIDATE_CODE': 'Validar código',
      'LOGIN_LOADING_SENDING_CODE': 'Enviando o código...',
      'LOGIN_LOADING_CONNECTING': 'Conectando...',
      'LOGIN_SEPARATOR_TEXT': 'Ou continue com',
      'LOGIN_CONTINUE_WITH_GOOGLE': 'Continuar com Google',
      'LOGIN_CONTINUE_WITH_FACEBOOK': 'Continuar com Facebook',
      'LOGIN_TERMS_PREFIX': 'Ao entrar, você aceita nossos',
      'LOGIN_TERMS_LINK': 'Termos de uso',
      'LOGIN_AND_OUR': 'e nossa',
      'LOGIN_PRIVACY_LINK': 'Política de privacidade',
      'LOGIN_CODE_SENT_TITLE': 'Código enviado',
      'LOGIN_CODE_SENT_MESSAGE':
          'Copie este código ou abra sua caixa de entrada para recuperá-lo.',
      'LOGIN_CODE_SENT_PLACEHOLDER': 'Código enviado por e-mail',
      'LOGIN_CODE_SENT_TOOLTIP': 'Copiar',
      'LOGIN_CODE_SENT_FOOTER':
          'Você também pode abrir sua caixa de entrada para encontrar esta mensagem.',
      'LOGIN_OPEN_MAIL': 'Abrir minha caixa de entrada',
      'LOGIN_CODE_COPIED_BUTTON': 'Copiei o código',
      'LOGIN_RESEND_CODE': 'Enviar um novo código',
      'LOGIN_SNACKBAR_COPIED': 'Código copiado para a área de transferência',
      'LOGIN_ERROR_EMPTY_EMAIL': 'Informe seu endereço de e-mail',
      'LOGIN_ERROR_INVALID_EMAIL': 'Endereço de e-mail inválido',
      'LOGIN_ERROR_EMPTY_CODE':
          'Informe o código recebido por e-mail',
      'LOGIN_ERROR_GENERIC':
          'Ocorreu um erro ao fazer login. Tente novamente.',
      'LOGIN_ERROR_INVALID_CODE':
          'Código inválido. Verifique o código recebido por e-mail e tente novamente.',
      'LOGIN_ERROR_CODE_OR_CONNECTION':
          'Código inválido ou erro de conexão. Verifique o código e tente novamente.',
      'LOGIN_MESSAGE_RETURN_APP':
          'Após entrar, volte para este aplicativo.',
      'LOGIN_ERROR_GOOGLE':
          'Ocorreu um erro ao entrar com o Google',
      'LOGIN_ERROR_FACEBOOK':
          'Ocorreu um erro ao entrar com o Facebook',
      'LOGIN_SUCCESS_TITLE': 'Login concluído!',
      'LOGIN_SUCCESS_MESSAGE': 'Você será redirecionado em instantes...',
      // Clés para le titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Encontre seus artigos ',
      'SELECT_COUNTRY_TITLE_PART2': ' mais baratos com ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Seu país de origem',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Pesquisar seu país...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'Aceito os termos de uso',
      'SELECT_COUNTRY_VIEW_TERMS': 'Ver condições',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Validar',
      'SELECT_COUNTRY_FOOTER_TEXT': 'Ao clicar em Validar, você aceita nossos termos de uso. ',
      'SELECT_COUNTRY_TERMS_LINK': 'Termos de uso',
      // Clés para la page d'accueil
      'FRONTPAGE_Msg77': 'Encontre seus artigos',
      'FRONTPAGE_Msg78': 'mais baratos com Jirig',
      'FRONTPAGE_Msg88': 'Assinatura Premium',
      'FRONTPAGE_Msg89': 'Acesse todos os recursos avançados do JIRIG',
      'FRONTPAGE_Msg90': 'Assinar agora',
      'COMPARE_Msg03': 'Comparação por email',
      'COMPARE_TEXT_PART1': 'Envie-nos sua lista IKEA por email para uma comparação personalizada',
      'COMPARE_Msg05': 'Enviar por email',
      // Product search - initial state
      'PRODUCTSEARCH_ENTER_CODE': 'Insira um código de artigo para iniciar a pesquisa',
      // Product search - input field
      'PRODUCTSEARCH_HINT_CODE': 'Referência IKEA (ex.: 123.456.78)',
      // Product search - backend errors
      'HTML_SEARCH_BADREFERENCE': 'A referência não parece estar correta.\nUma referência é uma sequência de 8 dígitos separados por 2 pontos (ex. 123.456.78)',
      // Wishlist labels
      'BEST_PRICE': 'Melhor preço',
      'OPTIMAL': 'Ótimo',
      'CURRENT_PRICE': 'Preço atual',
      'CURRENT': 'Atual',
      'PROFIT': 'Lucro',
      'ADD_ITEM': 'Adicionar',
      // Wishlist - dialogs
      'CONFIRM_TITLE': 'Confirmação',
      'CONFIRM_DELETE_ITEM': 'Tem certeza de que deseja excluir este item?',
      'BUTTON_NO': 'Não',
      'BUTTON_YES': 'Sim',
      'SUCCESS_TITLE': 'Sucesso',
      'SUCCESS_DELETE_ARTICLE': 'O item foi excluído com sucesso.',
      'ERROR_TITLE': 'Erro',
      'DELETE_ERROR': 'Ocorreu um erro ao excluir.',
      // Mapa - botões
      'BUTTON_STORES': 'Lojas',
      'BUTTON_CLOSE': 'Fechar',
      // Mapa - lojas
      'STORES_NEARBY': 'Lojas próximas',
      'SORTED_BY_PROXIMITY': 'Ordenadas por proximidade',
      'YOUR_POSITION': 'Sua posição',
      'IKEA_STORES': 'Lojas IKEA',
      'IKEA_STORES_NEARBY': 'Lojas IKEA próximas',
      'SEARCH_STORE_PLACEHOLDER': 'Pesquisar uma loja (nome, país, cidade)',
      'SEARCH_LOCATION_PLACEHOLDER': 'Pesquisar uma cidade, endereço ou código postal...',
      // Modal de pesquisa - título
      'FRONTPAGE_Msg05': 'Pesquisar um artigo',
      // Modal de pesquisa - seleção de países
      'FRONTPAGE_Msg04': 'Escolha os países para comparar:',
      // Modal de pesquisa - botão scanner
      'FRONTPAGE_Msg08': 'Escanear um produto',
      // Lista de desejos - carrinho vazio
      'EMPTY_CART_TITLE': 'Carrinho vazio',
      'EMPTY_CART_MESSAGE': 'Nenhum artículo encontrado neste carrinho',
      // Profile detail
      'PROFILE_EDIT_BUTTON': 'Editar meu perfil',
      'PROFILE_MAIN_COUNTRY': 'País principal',
      'PROFILE_NOT_SELECTED': 'Não selecionado',
      'PROFILE_FAVORITE_COUNTRIES': 'Países favoritos',
      'PROFILE_NO_FAVORITE_COUNTRIES': 'Nenhum país favorito selecionado',
      'WISHLIST_COUNTRY_MODAL_TITLE': 'Adicionar países',
      'WISHLIST_COUNTRY_MODAL_AVAILABLE': 'Países disponíveis',
      'WISHLIST_COUNTRY_MODAL_HELP':
          'Toque para ativar ou desativar os países na sua lista de desejos',
      'WISHLIST_COUNTRY_MODAL_CANCEL': 'Cancelar',
      'WISHLIST_COUNTRY_MODAL_SAVE': 'Atualizar',
      'WISHLIST_COUNTRY_SIDEBAR_MANAGE_BUTTON': 'Adicionar/Remover um país',
      'WISHLIST_COUNTRY_SIDEBAR_CLOSE': 'Fechar',
      'WISHLIST_COUNTRY_EMPTY': 'Nenhum país disponível',
      'WISHLIST_COUNTRY_PRICE_UNAVAILABLE': 'Indisponível',
    },
    'nl': {
      // Clés de l'API pour la page de sélection de pays
      'FRONTPAGE_Msg01': 'Home Verlanglijst Project Nieuwsbrief Abonnement Inloggen',
      'FRONTPAGE_Msg02': 'Vergelijk IKEA-prijzen in meerdere landen met één klik',
      'FRONTPAGE_Msg03': 'JIRIG helpt je besparen op je internationale IKEA-aankopen',
      'PODIUM_ENLARGE': 'Vergroten',
      'LOGIN_WELCOME_TITLE': 'Welkom bij Jirig',
      'LOGIN_WELCOME_SUBTITLE':
          'Meld je aan en ontdek alle functies van ons platform',
      'LOGIN_TITLE': 'Inloggen',
      'LOGIN_SUBTITLE': 'Toegang tot je account',
      'LOGIN_EMAIL_LABEL': 'E-mailadres',
      'LOGIN_EMAIL_PLACEHOLDER': 'jouw@email.com',
      'LOGIN_CODE_LABEL': 'Verificatiecode',
      'LOGIN_CODE_PLACEHOLDER':
          'Voer de code in die je per e-mail hebt ontvangen',
      'LOGIN_ACTION_SEND_CODE': 'Code verzenden',
      'LOGIN_ACTION_VALIDATE_CODE': 'Code bevestigen',
      'LOGIN_LOADING_SENDING_CODE': 'Code wordt verzonden...',
      'LOGIN_LOADING_CONNECTING': 'Bezig met inloggen...',
      'LOGIN_SEPARATOR_TEXT': 'Of ga verder met',
      'LOGIN_CONTINUE_WITH_GOOGLE': 'Ga verder met Google',
      'LOGIN_CONTINUE_WITH_FACEBOOK': 'Ga verder met Facebook',
      'LOGIN_TERMS_PREFIX': 'Door in te loggen ga je akkoord met onze',
      'LOGIN_TERMS_LINK': 'Gebruiksvoorwaarden',
      'LOGIN_AND_OUR': 'en ons',
      'LOGIN_PRIVACY_LINK': 'Privacybeleid',
      'LOGIN_CODE_SENT_TITLE': 'Code verzonden',
      'LOGIN_CODE_SENT_MESSAGE':
          'Kopieer deze code of open je mailbox om hem op te halen.',
      'LOGIN_CODE_SENT_PLACEHOLDER': 'Code per e-mail verzonden',
      'LOGIN_CODE_SENT_TOOLTIP': 'Kopiëren',
      'LOGIN_CODE_SENT_FOOTER':
          'Je kunt ook je mailbox openen om dit bericht terug te vinden.',
      'LOGIN_OPEN_MAIL': 'Mijn mailbox openen',
      'LOGIN_CODE_COPIED_BUTTON': 'Ik heb de code gekopieerd',
      'LOGIN_RESEND_CODE': 'Nieuwe code verzenden',
      'LOGIN_SNACKBAR_COPIED': 'Code gekopieerd naar het klembord',
      'LOGIN_ERROR_EMPTY_EMAIL': 'Voer je e-mailadres in',
      'LOGIN_ERROR_INVALID_EMAIL': 'Ongeldig e-mailadres',
      'LOGIN_ERROR_EMPTY_CODE':
          'Voer de code in die je per e-mail hebt ontvangen',
      'LOGIN_ERROR_GENERIC':
          'Er is een fout opgetreden bij het inloggen. Probeer het opnieuw.',
      'LOGIN_ERROR_INVALID_CODE':
          'Ongeldige code. Controleer de per e-mail ontvangen code en probeer het opnieuw.',
      'LOGIN_ERROR_CODE_OR_CONNECTION':
          'Ongeldige code of verbindingsfout. Controleer de code en probeer het opnieuw.',
      'LOGIN_MESSAGE_RETURN_APP':
          'Keer na het inloggen terug naar deze app.',
      'LOGIN_ERROR_GOOGLE':
          'Er is een fout opgetreden bij het inloggen met Google',
      'LOGIN_ERROR_FACEBOOK':
          'Er is een fout opgetreden bij het inloggen met Facebook',
      'LOGIN_SUCCESS_TITLE': 'Inloggen geslaagd!',
      'LOGIN_SUCCESS_MESSAGE': 'Je wordt zo meteen doorgestuurd...',
      // Clés pour le titre de la page de sélection de pays
      'SELECT_COUNTRY_TITLE_PART1': 'Vind je artikelen ',
      'SELECT_COUNTRY_TITLE_PART2': ' goedkoper met ',
      // Textes fixes pour les éléments non traduits
      'SELECT_COUNTRY_ORIGIN_COUNTRY': 'Uw land van herkomst',
      'SELECT_COUNTRY_SEARCH_PLACEHOLDER': 'Zoek uw land...',
      'SELECT_COUNTRY_ACCEPT_TERMS': 'Ik accepteer de gebruiksvoorwaarden',
      'SELECT_COUNTRY_VIEW_TERMS': 'Bekijk voorwaarden',
      'SELECT_COUNTRY_FINISH_BUTTON': 'Valideren',
      'SELECT_COUNTRY_FOOTER_TEXT': 'Door op Valideren te klikken, accepteert u onze gebruiksvoorwaarden. ',
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
      // Product search - initial state
      'PRODUCTSEARCH_ENTER_CODE': 'Voer een artikelcode in om te beginnen met zoeken',
      // Product search - input field
      'PRODUCTSEARCH_HINT_CODE': 'IKEA-referentie (bijv. 123.456.78)',
      // Product search - backend errors
      'HTML_SEARCH_BADREFERENCE': 'De referentie lijkt niet correct te zijn.\nEen referentie is een reeks van 8 cijfers gescheiden door 2 punten (bijv. 123.456.78)',
      // Wishlist labels
      'BEST_PRICE': 'Beste prijs',
      'OPTIMAL': 'Optimaal',
      'CURRENT_PRICE': 'Huidige prijs',
      'CURRENT': 'Huidig',
      'PROFIT': 'Winst',
      'ADD_ITEM': 'Toevoegen',
      // Wishlist - dialogs
      'CONFIRM_TITLE': 'Bevestiging',
      'CONFIRM_DELETE_ITEM': 'Weet u zeker dat u dit item wilt verwijderen?',
      'BUTTON_NO': 'Nee',
      'BUTTON_YES': 'Ja',
      'SUCCESS_TITLE': 'Succes',
      'SUCCESS_DELETE_ARTICLE': 'Het item is succesvol verwijderd.',
      'ERROR_TITLE': 'Fout',
      'DELETE_ERROR': 'Er is een fout opgetreden bij het verwijderen.',
      // Kaart - knoppen
      'BUTTON_STORES': 'Winkels',
      'BUTTON_CLOSE': 'Sluiten',
      // Kaart - winkels
      'STORES_NEARBY': 'Winkels in de buurt',
      'SORTED_BY_PROXIMITY': 'Gesorteerd op nabijheid',
      'YOUR_POSITION': 'Uw positie',
      'IKEA_STORES': 'IKEA Winkels',
      'IKEA_STORES_NEARBY': 'IKEA Winkels in de buurt',
      'SEARCH_STORE_PLACEHOLDER': 'Zoek een winkel (naam, land, stad)',
      'SEARCH_LOCATION_PLACEHOLDER': 'Zoek een stad, indirizzo of postcode...',
      // Zoekmodaal - titel
      'FRONTPAGE_Msg05': 'Zoek een artikel',
      // Zoekmodaal - landselectie
      'FRONTPAGE_Msg04': 'Kies landen om te vergelijken:',
      // Zoekmodaal - scanner knop
      'FRONTPAGE_Msg08': 'Scan een product',
      // Verlanglijst - lege winkelwagen
      'EMPTY_CART_TITLE': 'Lege winkelwagen',
      'EMPTY_CART_MESSAGE': 'Geen artikel gevonden in deze winkelwagen',
      // Profile detail
      'PROFILE_EDIT_BUTTON': 'Mijn profiel bewerken',
      'PROFILE_MAIN_COUNTRY': 'Hoofdland',
      'PROFILE_NOT_SELECTED': 'Niet geselecteerd',
      'PROFILE_FAVORITE_COUNTRIES': 'Favoriete landen',
      'PROFILE_NO_FAVORITE_COUNTRIES': 'Geen favoriete landen geselecteerd',
    },
  };

  /// Charger les traductions pour une langue
  Future<void> loadTranslations(String language) async {
    if (_currentLanguage == language && _translations.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _currentLanguage = language;

    await _saveLanguageToProfileIfDifferent(language);

    try {
      final apiTranslations = await _apiService.getTranslations(language);

      if (apiTranslations.isNotEmpty) {
        _translations = Map<String, String>.from(apiTranslations);

        try {
          final matchedKeys = <String>[];
          apiTranslations.forEach((key, value) {
            final text = (value ?? '').toString();
            final normalized =
                text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
            if (normalized == 'trouvez votre produit') {
              matchedKeys.add(key.toString());
            }
          });
          if (matchedKeys.isNotEmpty) {
            print(
                '🔎 TRANSLATION SERVICE: Clés avec traduction = "Trouvez Votre Produit": $matchedKeys');
          } else {
            print(
                '🔎 TRANSLATION SERVICE: Aucune clé dont la traduction est exactement "Trouvez Votre Produit"');
          }
        } catch (e) {
          print(
              '⚠️ TRANSLATION SERVICE: Debug recherche "Trouvez Votre Produit" a échoué: $e');
        }

        print('✅ TRANSLATION SERVICE: Traductions chargées depuis l\'API');
      } else {
        throw Exception('Aucune traduction reçue de l\'API');
      }
    } catch (e) {
      print('❌ TRANSLATION SERVICE: Erreur API - aucune traduction disponible: $e');
      _translations = {};
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtenir une traduction
  String translate(String key) {
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

    final defaultTranslations = _defaultTranslations[_currentLanguage];
    if (defaultTranslations != null && defaultTranslations.containsKey(key)) {
      return defaultTranslations[key]!;
    }

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
