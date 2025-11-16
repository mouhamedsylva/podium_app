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
    'HTML_SEARCH_BADREFERENCE': {
      'fr': 'La référence ne semble pas être correcte.<br>Une référence est une suite de 8 chiffres séparée par 2 points (ex. 123.456.78)',
      'en': 'The reference does not seem to be correct.<br>A reference is a sequence of 8 digits separated by 2 dots (e.g. 123.456.78)',
      'de': 'Die Referenz scheint nicht korrekt zu sein.<br>Eine Referenz ist eine Folge von 8 Ziffern, getrennt durch 2 Punkte (z.B. 123.456.78)',
      'es': 'La referencia no parece ser correcta.<br>Una referencia es una secuencia de 8 dígitos separados por 2 puntos (ej. 123.456.78)',
      'it': 'Il riferimento non sembra essere corretto.<br>Un riferimento è una sequenza di 8 cifre separate da 2 punti (es. 123.456.78)',
      'pt': 'A referência não parece estar correta.<br>Uma referência é uma sequência de 8 dígitos separados por 2 pontos (ex. 123.456.78)',
      'nl': 'De referentie lijkt niet correct te zijn.<br>Een referentie is een reeks van 8 cijfers gescheiden door 2 punten (bijv. 123.456.78)',
    },
    'PRODUCTCODE_Msg04': {
      'fr': 'Erreur de recherche',
      'en': 'Search error',
      'de': 'Suchfehler',
      'es': 'Error de búsqueda',
      'it': 'Errore di ricerca',
      'pt': 'Erro de pesquisa',
      'nl': 'Zoekfout',
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
      'fr': 'Envoyer le lien',
      'en': 'Send link',
      'de': 'Link senden',
      'es': 'Enviar enlace',
      'it': 'Invia link',
      'pt': 'Enviar link',
      'nl': 'Link verzenden',
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

    // ===== Fallbacks locaux pour les écrans de profil =====
    'PROFIL_UPDATE_PROFIL': {
      'fr': 'Modifier mon profil',
      'en': 'Edit my profile',
      'de': 'Mein Profil bearbeiten',
      'es': 'Editar mi perfil',
      'it': 'Modifica il mio profilo',
      'pt': 'Editar meu perfil',
      'nl': 'Mijn profiel bewerken',
    },
    'PROFIL_MAJ_PROFIL': {
      'fr': 'Mettre à jour le profil',
      'en': 'Update profile',
      'de': 'Profil aktualisieren',
      'es': 'Actualizar perfil',
      'it': 'Aggiorna profilo',
      'pt': 'Atualizar perfil',
      'nl': 'Profiel bijwerken',
    },
    'PROFIL_COUNTRY': {
      'fr': 'Pays principal',
      'en': 'Main country',
      'de': 'Hauptland',
      'es': 'País principal',
      'it': 'Paese principale',
      'pt': 'País principal',
      'nl': 'Hoofdland',
    },
    'PROFIL_FAVOCOUNTRY': {
      'fr': 'Pays favoris',
      'en': 'Favorite countries',
      'de': 'Lieblingsländer',
      'es': 'Países favoritos',
      'it': 'Paesi preferiti',
      'pt': 'Países favoritos',
      'nl': 'Favoriete landen',
    },
    'PROFIL_NOT_SELECTED': {
      'fr': 'Non sélectionné',
      'en': 'Not selected',
      'de': 'Nicht ausgewählt',
      'es': 'No seleccionado',
      'it': 'Non selezionato',
      'pt': 'Não selecionado',
      'nl': 'Niet geselecteerd',
    },
    'PROFILE_ENTER_MAIL': {
      'fr': 'Entrez votre email',
      'en': 'Enter your email',
      'de': 'Geben Sie Ihre E‑Mail ein',
      'es': 'Introduce tu correo electrónico',
      'it': 'Inserisci la tua email',
      'pt': 'Digite seu e‑mail',
      'nl': 'Vul uw e‑mail in',
    },
    'PROFILE_ENTER_PHONE': {
      'fr': 'Entrez votre téléphone',
      'en': 'Enter your phone',
      'de': 'Geben Sie Ihre Telefonnummer ein',
      'es': 'Introduce tu teléfono',
      'it': 'Inserisci il tuo telefono',
      'pt': 'Digite seu telefone',
      'nl': 'Vul uw telefoon in',
    },
    'PROFILE_ENTER_POSTAL_CITY': {
      'fr': 'Entrez votre ville',
      'en': 'Enter your city',
      'de': 'Geben Sie Ihre Stadt ein',
      'es': 'Introduce tu ciudad',
      'it': 'Inserisci la tua città',
      'pt': 'Digite sua cidade',
      'nl': 'Vul uw stad in',
    },
    'PROFILE_ENTER_POSTAL_CODE': {
      'fr': 'Entrez votre code postal',
      'en': 'Enter your postal code',
      'de': 'Geben Sie Ihre Postleitzahl ein',
      'es': 'Introduce tu código postal',
      'it': 'Inserisci il tuo CAP',
      'pt': 'Digite seu CEP',
      'nl': 'Vul uw postcode in',
    },
    'PROFILE_ENTER_SREET': {
      'fr': 'Entrez votre rue',
      'en': 'Enter your street',
      'de': 'Geben Sie Ihre Straße ein',
      'es': 'Introduce tu calle',
      'it': 'Inserisci la tua via',
      'pt': 'Digite sua rua',
      'nl': 'Vul uw straat in',
    },
    'PROFILE_Enter-FIRST_NAME': {
      'fr': 'Entrez votre prénom',
      'en': 'Enter your first name',
      'de': 'Geben Sie Ihren Vornamen ein',
      'es': 'Introduce tu nombre',
      'it': 'Inserisci il tuo nome',
      'pt': 'Digite seu primeiro nome',
      'nl': 'Vul uw voornaam in',
    },
    'PROFILE_POSTAL_CODE': {
      'fr': 'Code postal',
      'en': 'Postal code',
      'de': 'Postleitzahl',
      'es': 'Código postal',
      'it': 'CAP',
      'pt': 'CEP',
      'nl': 'Postcode',
    },
    'PROFILE_UPDATED': {
      'fr': 'Le profil a été modifié avec succès.',
      'en': 'The profile has been updated successfully.',
      'de': 'Das Profil wurde erfolgreich aktualisiert.',
      'es': 'El perfil se ha actualizado correctamente.',
      'it': 'Il profilo è stato aggiornato con successo.',
      'pt': 'O perfil foi atualizado com sucesso.',
      'nl': 'Het profiel is succesvol bijgewerkt.',
    },
    'PROFILE_UPDATE_CANCELLED': {
      'fr': 'La modification du profil a été annulée.',
      'en': 'Profile update was cancelled.',
      'de': 'Die Profilaktualisierung wurde abgebrochen.',
      'es': 'La actualización del perfil fue cancelada.',
      'it': 'L’aggiornamento del profilo è stato annullato.',
      'pt': 'A atualização do perfil foi cancelada.',
      'nl': 'De profielbewerking is geannuleerd.',
    },
    'WISHLIST_Msg30': {
      'fr': 'Annuler',
      'en': 'Cancel',
      'de': 'Abbrechen',
      'es': 'Cancelar',
      'it': 'Annulla',
      'pt': 'Cancelar',
      'nl': 'Annuleren',
    },
    'PROFILE_UPDATE_ERROR': {
      'fr': 'Erreur lors de la mise à jour du profil:',
      'en': 'Error while updating profile:',
      'de': 'Fehler beim Aktualisieren des Profils:',
      'es': 'Error al actualizar el perfil:',
      'it': 'Errore durante l\'aggiornamento del profilo:',
      'pt': 'Erro ao atualizar o perfil:',
      'nl': 'Fout bij het bijwerken van het profiel:',
    },
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
    'PROFIL_CITY': {
      'fr': 'Ville',
      'en': 'City',
      'de': 'Stadt',
      'es': 'Ciudad',
      'it': 'Città',
      'pt': 'Cidade',
      'nl': 'Stad',
    },
    'PROFIL_EMAIL': {
      'fr': 'Email',
      'en': 'Email',
      'de': 'E‑Mail',
      'es': 'Correo',
      'it': 'Email',
      'pt': 'E‑mail',
      'nl': 'E‑mail',
    },
    'PROFIL_ENTER_SECOND_NAME': {
      'fr': 'Entrez votre nom',
      'en': 'Enter your last name',
      'de': 'Geben Sie Ihren Nachnamen ein',
      'es': 'Introduce tu apellido',
      'it': 'Inserisci il tuo cognome',
      'pt': 'Digite seu sobrenome',
      'nl': 'Vul uw achternaam in',
    },
    'PROFIL_FIRST_NAME': {
      'fr': 'Prénom',
      'en': 'First name',
      'de': 'Vorname',
      'es': 'Nombre',
      'it': 'Nome',
      'pt': 'Primeiro nome',
      'nl': 'Voornaam',
    },
    'PROFIL_PHONE': {
      'fr': 'Téléphone',
      'en': 'Phone',
      'de': 'Telefon',
      'es': 'Teléfono',
      'it': 'Telefono',
      'pt': 'Telefone',
      'nl': 'Telefoon',
    },
    'PROFIL_SECOND_NAME': {
      'fr': 'Nom',
      'en': 'Last name',
      'de': 'Nachname',
      'es': 'Apellido',
      'it': 'Cognome',
      'pt': 'Sobrenome',
      'nl': 'Achternaam',
    },
    'PROFIL_STREET': {
      'fr': 'Rue',
      'en': 'Street',
      'de': 'Straße',
      'es': 'Calle',
      'it': 'Via',
      'pt': 'Rua',
      'nl': 'Straat',
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
